// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PlayerManager.sol";

/**
 * @title MovementManager
 * @dev Manages player movement, fuel consumption, and navigation
 */
abstract contract MovementManager is PlayerManager {
    /**
     * @dev Move player using array of directions (0=NE, 1=E, 2=SE, 3=SW, 4=W, 5=NW)
     */
    function move(uint8[] calldata directions) external onlyRegisteredPlayer whenNotPaused {
        IGameState.PlayerState storage player = playerStates[msg.sender];
        require(block.timestamp >= player.nextMoveTime, "Movement still on cooldown");
        require(directions.length > 0, "No directions provided");
        require(directions.length <= 10, "Too many moves at once"); // Limit batch size

        // Validate movement path and terrain collision
        (int32 finalX, int32 finalY) = _validateMovementPath(player.mapId, player.position, directions);

        // Calculate fuel cost for the entire movement
        uint256 fuelCost = calculateFuelCost(msg.sender, directions);
        require(player.currentFuel >= fuelCost, "Insufficient fuel");

        // Update position and fuel
        player.position = IGameState.Position(finalX, finalY);
        player.currentFuel -= fuelCost;
        player.lastMoveTimestamp = block.timestamp;

        // Set next move time based on movement speed
        player.nextMoveTime = block.timestamp + (player.movementSpeed * directions.length);

        emit IGameState.PlayerMoved(msg.sender, player.shard, player.mapId, finalX, finalY, fuelCost);
    }

    /**
     * @dev Calculate fuel cost for movement directions
     */
    function calculateFuelCost(address player, uint8[] calldata directions) public view returns (uint256) {
        // Each direction costs base amount
        uint256 distance = directions.length;

        // Use equipped engine consumption rate or fallback to ship default
        uint256 fuelConsumptionRate = calculateCombinedFuelConsumptionRate(player);

        // Fuel cost = distance * base_cost * fuel_consumption_rate / 100
        return distance * HEX_MOVE_COST * fuelConsumptionRate / 100;
    }

    /**
     * @dev Purchase fuel
     */
    function purchaseFuel(uint256 amount) external onlyRegisteredPlayer whenNotPaused nonReentrant {
        require(amount > 0, "Amount must be greater than zero");

        uint256 totalCost = amount * FUEL_PRICE_PER_UNIT;
        require(currency.balanceOf(msg.sender) >= totalCost, "Insufficient currency");

        // Burn currency and add fuel (convert amount to 18 decimal precision)
        currency.burn(msg.sender, totalCost, "Fuel purchase");
        playerStates[msg.sender].currentFuel += amount * 1e18;

        emit IGameState.FuelPurchased(msg.sender, amount, totalCost);
    }

    /**
     * @dev Get current fuel for player
     */
    function getCurrentFuel(address player) external view returns (uint256) {
        return playerStates[player].currentFuel;
    }

    /**
     * @dev Calculate total fuel consumption rate from equipped engines (additive)
     */
    function calculateCombinedFuelConsumptionRate(address player) public view returns (uint256 totalConsumptionRate) {
        InventoryLib.InventoryGrid storage inventory = playerInventories[player];

        totalConsumptionRate = 0;
        uint256 engineCount = 0;

        // Iterate through inventory slots looking for engines in engine slots
        for (uint256 i = 0; i < inventory.slotTypes.length; i++) {
            if (inventory.slotTypes[i] == 1) {
                // Engine slot
                InventoryLib.GridItem memory item = inventory.grid[i];
                if (item.isOccupied && item.itemType == 2) {
                    // Engine item type
                    if (engineRegistry.isValidEngine(item.itemId)) {
                        IEngineRegistry.EngineStats memory stats = engineRegistry.getEngineStats(item.itemId);
                        totalConsumptionRate += stats.fuelConsumptionRatePerCell;
                        engineCount++;
                    }
                }
            }
        }

        if (engineCount == 0) {
            // Fallback to default fuel consumption rate if no engines equipped (should not happen with default equipment)
            return 0; // 100 consumption rate (baseline)
        }

        return totalConsumptionRate;
    }

    /**
     * @dev Validate movement path and check terrain collisions
     */
    function _validateMovementPath(uint256 mapId, IGameState.Position memory startPos, uint8[] calldata directions)
        private
        view
        returns (int32 finalX, int32 finalY)
    {
        finalX = startPos.x;
        finalY = startPos.y;

        for (uint256 i = 0; i < directions.length; i++) {
            require(directions[i] < 6, "Invalid direction");

            // Calculate next position
            int32 nextX = finalX + hexDirectionsX[directions[i]];
            int32 nextY = finalY + hexDirectionsY[directions[i]];

            // Check if position is valid and passable
            require(mapRegistry.isValidPosition(mapId, nextX, nextY), "Position out of map bounds");
            require(mapRegistry.isPassable(mapId, nextX, nextY), "Terrain is not passable");

            finalX = nextX;
            finalY = nextY;
        }

        return (finalX, finalY);
    }
}
