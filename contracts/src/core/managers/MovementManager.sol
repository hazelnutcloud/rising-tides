// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SlotType, ItemType} from "../../types/InventoryTypes.sol";
import "../RisingTidesBase.sol";

/**
 * @title MovementManager
 * @dev Manages player movement, fuel consumption, and navigation
 */
abstract contract MovementManager is RisingTidesBase {
    /**
     * @dev Move player using array of directions (0=NE, 1=E, 2=SE, 3=SW, 4=W, 5=NW)
     */
    function move(uint8[] calldata directions) external onlyRegisteredPlayer whenNotPaused {
        IRisingTides.PlayerState storage player = playerStates[msg.sender];
        if (block.timestamp < player.nextMoveTime) {
            revert OnCooldown(block.timestamp, player.nextMoveTime);
        }
        if (directions.length == 0) revert NoDirectionsProvided();
        if (directions.length > 20) revert TooManyMoves(directions.length, 20); // Limit batch size

        // Validate movement path and terrain collision
        (int32 finalX, int32 finalY) = _validateMovementPath(player.mapId, player.position, directions);

        // Calculate fuel cost for the entire movement
        uint256 fuelCost = calculateFuelCost(msg.sender, directions);
        if (player.currentFuel < fuelCost) revert InsufficientFuel(fuelCost, player.currentFuel);

        // Update position and fuel
        player.position = IRisingTides.Position(finalX, finalY);
        player.currentFuel -= fuelCost;
        player.lastMoveTimestamp = block.timestamp;

        // Set next move time based on movement speed
        player.nextMoveTime = block.timestamp + (player.movementSpeed * directions.length);

        emit IRisingTides.PlayerMoved(msg.sender, player.shard, player.mapId, finalX, finalY, fuelCost);
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
        if (amount == 0) revert InvalidAmount(amount);

        uint256 totalCost = amount * FUEL_PRICE_PER_UNIT;
        if (currency.balanceOf(msg.sender) < totalCost) {
            revert InsufficientBalance(msg.sender, totalCost, currency.balanceOf(msg.sender));
        }

        // Burn currency and add fuel (convert amount to 18 decimal precision)
        currency.burn(msg.sender, totalCost, "Fuel purchase");
        playerStates[msg.sender].currentFuel += amount * 1e18;

        emit IRisingTides.FuelPurchased(msg.sender, amount, totalCost);
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

        uint256 inventoryArea = inventory.width * inventory.height;

        // Iterate through inventory slots looking for engines in engine slots
        for (uint256 i = 0; i < inventoryArea; i++) {
            if (inventory.slotTypes[i] == SlotType.Engine) {
                // Engine slot
                InventoryLib.GridItem memory item = inventory.grid[i];
                if (item.itemType == ItemType.Engine) {
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
    function _validateMovementPath(uint256 mapId, IRisingTides.Position memory startPos, uint8[] calldata directions)
        private
        view
        returns (int32 finalX, int32 finalY)
    {
        finalX = startPos.x;
        finalY = startPos.y;

        for (uint256 i = 0; i < directions.length; i++) {
            if (directions[i] >= 6) revert InvalidDirection(directions[i]);

            // Calculate next position
            int32 nextX = finalX + hexDirectionsX[directions[i]];
            int32 nextY = finalY + hexDirectionsY[directions[i]];

            // Check if position is valid and passable
            if (!mapRegistry.isValidPosition(mapId, nextX, nextY)) {
                revert PositionOutOfBounds(mapId, uint256(uint32(nextX)), uint256(uint32(nextY)));
            }
            if (!mapRegistry.isPassable(mapId, nextX, nextY)) {
                revert TerrainNotPassable(mapId, uint256(uint32(nextX)), uint256(uint32(nextY)));
            }

            finalX = nextX;
            finalY = nextY;
        }

        return (finalX, finalY);
    }
}
