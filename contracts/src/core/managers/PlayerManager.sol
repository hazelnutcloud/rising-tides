// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./GameStateBase.sol";

/**
 * @title PlayerManager
 * @dev Manages player registration, state, and weight calculations
 */
abstract contract PlayerManager is GameStateBase {
    /**
     * @dev Register a new player
     */
    function registerPlayer(uint8 shard, uint256 mapId) external validShard(shard) whenNotPaused {
        require(!registeredPlayers[msg.sender], "Player already registered");
        require(mapRegistry.isValidMap(mapId), "Invalid map ID");

        // Initialize player with default ship (ID 1) and calculate initial weight
        IShipRegistry.ShipStats memory shipStats = shipRegistry.getShipStats(1);

        // Calculate initial player weight (ship base weight + engine weight)
        uint256 totalWeight = _calculatePlayerWeight(msg.sender, 1);

        playerStates[msg.sender] = IGameState.PlayerState({
            position: IGameState.Position(0, 0),
            shard: shard,
            mapId: mapId,
            shipId: 1,
            currentFuel: 100, // Starting fuel
            lastMoveTimestamp: block.timestamp,
            nextMoveTime: block.timestamp,
            movementSpeed: _calculateMovementSpeed(shipStats.enginePower, totalWeight),
            totalWeight: totalWeight,
            isActive: true
        });

        // Initialize inventory grid based on default ship
        _initializeInventory(msg.sender, 1);

        registeredPlayers[msg.sender] = true;

        emit IGameState.PlayerRegistered(msg.sender, shard);
    }

    /**
     * @dev Get player state
     */
    function getPlayerState(address player) external view returns (IGameState.PlayerState memory) {
        return playerStates[player];
    }

    /**
     * @dev Check if player is registered
     */
    function isPlayerRegistered(address player) external view returns (bool) {
        return registeredPlayers[player];
    }

    /**
     * @dev Change player's shard
     */
    function changeShard(uint8 newShard) external onlyRegisteredPlayer validShard(newShard) whenNotPaused {
        IGameState.PlayerState storage player = playerStates[msg.sender];
        uint8 oldShard = player.shard;

        require(newShard != oldShard, "Already in this shard");

        player.shard = newShard;

        emit IGameState.ShardChanged(msg.sender, oldShard, newShard);
    }

    /**
     * @dev Update player's total weight (used when inventory changes)
     */
    function updatePlayerWeight(address player) external onlyRegisteredPlayer {
        require(player == msg.sender, "Can only update own weight");
        IGameState.PlayerState storage playerState = playerStates[player];

        uint256 newWeight = _calculatePlayerWeight(player, playerState.shipId);
        playerState.totalWeight = newWeight;

        // Recalculate movement speed with new weight and engine power
        uint256 enginePower = _calculateTotalEnginePower(player);
        playerState.movementSpeed = _calculateMovementSpeed(enginePower, newWeight);
    }

    /**
     * @dev Calculate player's total weight based on ship and inventory
     */
    function _calculatePlayerWeight(address, /* player */ uint256 shipId) internal view returns (uint256) {
        // Get base ship weight
        IShipRegistry.Ship memory ship = shipRegistry.getShip(shipId);
        uint256 baseWeight = ship.durability; // Using durability as proxy for ship weight

        // TODO: Add inventory weight calculation
        // This would iterate through player's inventory and sum up item weights
        // For now, return base weight

        return baseWeight;
    }

    /**
     * @dev Calculate movement speed based on engine power and total weight
     */
    function _calculateMovementSpeed(uint256 enginePower, uint256 totalWeight) internal pure returns (uint256) {
        if (enginePower == 0 || totalWeight == 0) {
            return BASE_MOVEMENT_SPEED;
        }

        // Speed inversely proportional to weight, proportional to engine power
        // Formula: speed = (enginePower * BASE_MOVEMENT_SPEED) / totalWeight
        return (enginePower * BASE_MOVEMENT_SPEED) / totalWeight;
    }

    /**
     * @dev Calculate total engine power from equipped engines
     */
    function _calculateTotalEnginePower(address player) internal view returns (uint256 totalPower) {
        InventoryLib.InventoryGrid storage inventory = playerInventories[player];
        IShipRegistry.Ship memory ship = shipRegistry.getShip(playerStates[player].shipId);
        
        // Iterate through inventory slots looking for engines in engine slots
        for (uint256 i = 0; i < ship.slotTypes.length; i++) {
            if (ship.slotTypes[i] == 1) { // Engine slot
                InventoryLib.GridItem memory item = inventory.grid[i];
                if (item.isOccupied && item.itemType == 2) { // Engine item type
                    if (engineRegistry.isValidEngine(item.itemId)) {
                        IEngineRegistry.EngineStats memory stats = engineRegistry.getEngineStats(item.itemId);
                        totalPower += stats.enginePower;
                    }
                }
            }
        }
        
        // Fallback to ship's base engine power if no engines equipped
        if (totalPower == 0) {
            IShipRegistry.ShipStats memory shipStats = shipRegistry.getShipStats(playerStates[player].shipId);
            return shipStats.enginePower;
        }
        
        return totalPower;
    }

    /**
     * @dev Initialize player inventory based on ship
     */
    function _initializeInventory(address player, uint256 shipId) internal {
        IShipRegistry.Ship memory ship = shipRegistry.getShip(shipId);

        InventoryLib.InventoryGrid storage inventory = playerInventories[player];
        inventory.width = ship.cargoWidth;
        inventory.height = ship.cargoHeight;
        inventory.slotTypes = ship.slotTypes;
    }

    /**
     * @dev Get player's fish by ID
     */
    function getPlayerFish(address player, uint256 fishId) external view returns (IGameState.FishCatch memory) {
        require(fishId < playerFishCount[player], "Invalid fish ID");
        return playerFish[player][fishId];
    }

    /**
     * @dev Get player's total fish count
     */
    function getPlayerFishCount(address player) external view returns (uint256) {
        return playerFishCount[player];
    }
}