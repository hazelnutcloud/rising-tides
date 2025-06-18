// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SlotType, ItemType} from "../../types/InventoryTypes.sol";
import "../GameStateBase.sol";

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
        require(playersPerShard[shard] < maxPlayersPerShard, "Shard is full");

        // Initialize inventory grid based on default ship
        _initializeInventory(msg.sender, 1);

        // Place default equipment (Engine ID 1 and Fishing Rod ID 1)
        _assignDefaultEquipment(msg.sender);

        // Calculate initial player weight (ship base weight + engine weight)
        uint256 totalWeight = _calculatePlayerWeight(msg.sender, 1);

        // Calculate initial engine power from equipped engines
        uint256 enginePower = _calculateTotalEnginePower(msg.sender, 1);

        playerStates[msg.sender] = IGameState.PlayerState({
            position: IGameState.Position(0, 0),
            shard: shard,
            mapId: mapId,
            shipId: 1,
            currentFuel: 100e18, // Starting fuel (100 units with 18 decimals precision)
            lastMoveTimestamp: block.timestamp,
            nextMoveTime: block.timestamp,
            movementSpeed: _calculateMovementSpeed(enginePower, totalWeight),
            totalWeight: totalWeight,
            isActive: true
        });

        registeredPlayers[msg.sender] = true;
        playersPerShard[shard]++;

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
        require(playersPerShard[newShard] < maxPlayersPerShard, "Target shard is full");

        // Update shard counts
        playersPerShard[oldShard]--;
        playersPerShard[newShard]++;

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
        uint256 enginePower = _calculateTotalEnginePower(player, playerState.shipId);
        playerState.movementSpeed = _calculateMovementSpeed(enginePower, newWeight);
    }

    /**
     * @dev Calculate player's total weight based on ship and inventory
     */
    function _calculatePlayerWeight(address, /* player */ uint256 shipId) internal view override returns (uint256) {
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
    function _calculateMovementSpeed(uint256 enginePower, uint256 totalWeight)
        internal
        pure
        override
        returns (uint256)
    {
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
    function _calculateTotalEnginePower(address player, uint256 shipId)
        internal
        view
        override
        returns (uint256 totalPower)
    {
        InventoryLib.InventoryGrid storage inventory = playerInventories[player];
        IShipRegistry.Ship memory ship = shipRegistry.getShip(shipId);

        // Iterate through inventory slots looking for engines in engine slots
        for (uint256 i = 0; i < ship.slotTypes.length; i++) {
            if (ship.slotTypes[i] == SlotType.Engine) {
                // Engine slot
                InventoryLib.GridItem memory item = inventory.grid[i];
                if (item.isOccupied && item.itemType == ItemType.Engine) {
                    // Engine item type
                    if (engineRegistry.isValidEngine(item.itemId)) {
                        IEngineRegistry.EngineStats memory stats = engineRegistry.getEngineStats(item.itemId);
                        totalPower += stats.enginePowerPerCell;
                    }
                }
            }
        }

        // Fallback to default engine power if no engines equipped (should not happen with default equipment)
        if (totalPower == 0) {
            return 30; // Default engine power for basic gameplay
        }

        return totalPower;
    }

    /**
     * @dev Initialize player inventory based on ship
     */
    function _initializeInventory(address player, uint256 shipId) internal override {
        IShipRegistry.Ship memory ship = shipRegistry.getShip(shipId);

        InventoryLib.InventoryGrid storage inventory = playerInventories[player];
        inventory.width = ship.cargoWidth;
        inventory.height = ship.cargoHeight;
        inventory.slotTypes = ship.slotTypes;
    }

    /**
     * @dev Assign default equipment (Engine ID 1 and Fishing Rod ID 1) to new player
     */
    function _assignDefaultEquipment(address player) internal {
        InventoryLib.InventoryGrid storage inventory = playerInventories[player];

        // Get engine ID 1 shape from registry
        IEngineRegistry.Engine memory engine = engineRegistry.getEngine(1);
        InventoryLib.ItemShape memory engineShape =
            InventoryLib.ItemShape({width: engine.shapeWidth, height: engine.shapeHeight, data: engine.shapeData});

        // Get fishing rod ID 1 shape from registry
        IFishingRodRegistry.FishingRod memory rod = fishingRodRegistry.getFishingRod(1);
        InventoryLib.ItemShape memory rodShape =
            InventoryLib.ItemShape({width: rod.shapeWidth, height: rod.shapeHeight, data: rod.shapeData});

        // Place engine in first engine slot
        bool enginePlaced = false;
        bool rodPlaced = false;

        for (uint256 i = 0; i < inventory.slotTypes.length && (!enginePlaced || !rodPlaced); i++) {
            if (inventory.slotTypes[i] == SlotType.Engine && !enginePlaced) {
                // Engine slot
                (uint8 x, uint8 y) = InventoryLib.indexToCoords(i, inventory.width);
                if (InventoryLib.placeItem(inventory, engineShape, x, y, ItemType.Engine, 1)) {
                    enginePlaced = true;
                }
            }
            if (inventory.slotTypes[i] == SlotType.Equipment && !rodPlaced) {
                // Equipment slot
                (uint8 x, uint8 y) = InventoryLib.indexToCoords(i, inventory.width);
                if (InventoryLib.placeItem(inventory, rodShape, x, y, ItemType.Equipment, 1)) {
                    rodPlaced = true;
                }
            }
        }

        require(enginePlaced, "Failed to place default engine");
        require(rodPlaced, "Failed to place default fishing rod");
    }

    /**
     * @dev Get current player count for a shard
     */
    function getShardPlayerCount(uint8 shard) external view validShard(shard) returns (uint256) {
        return playersPerShard[shard];
    }

    /**
     * @dev Get maximum players allowed per shard
     */
    function getMaxPlayersPerShard() external view returns (uint256) {
        return maxPlayersPerShard;
    }

    /**
     * @dev Check if a shard has available slots
     */
    function isShardAvailable(uint8 shard) external view validShard(shard) returns (bool) {
        return playersPerShard[shard] < maxPlayersPerShard;
    }

    /**
     * @dev Get all shard occupancy data
     */
    function getAllShardOccupancy()
        external
        view
        returns (uint8[] memory shardIds, uint256[] memory playerCounts, bool[] memory available)
    {
        shardIds = new uint8[](MAX_SHARDS);
        playerCounts = new uint256[](MAX_SHARDS);
        available = new bool[](MAX_SHARDS);

        for (uint8 i = 0; i < MAX_SHARDS; i++) {
            shardIds[i] = i;
            playerCounts[i] = playersPerShard[i];
            available[i] = playersPerShard[i] < maxPlayersPerShard;
        }
    }

    /**
     * @dev Update maximum players per shard (admin only)
     */
    function setMaxPlayersPerShard(uint256 newLimit) external onlyRole(ADMIN_ROLE) {
        require(newLimit > 0, "Limit must be greater than zero");
        require(newLimit <= 10000, "Limit too high"); // Reasonable upper bound

        uint256 oldLimit = maxPlayersPerShard;
        maxPlayersPerShard = newLimit;

        emit MaxPlayersPerShardUpdated(oldLimit, newLimit);
    }

    /**
     * @dev Admin function to forcefully change a player's shard
     * @param player The player's address to move
     * @param newShard The target shard
     * @param bypassLimit Whether to bypass the shard player limit (for emergency rebalancing)
     */
    function adminChangePlayerShard(address player, uint8 newShard, bool bypassLimit)
        external
        onlyRole(ADMIN_ROLE)
        validShard(newShard)
        whenNotPaused
    {
        require(registeredPlayers[player], "Player not registered");

        IGameState.PlayerState storage playerState = playerStates[player];
        uint8 oldShard = playerState.shard;

        require(newShard != oldShard, "Player already in target shard");

        // Check shard capacity unless bypassing limit
        if (!bypassLimit) {
            require(playersPerShard[newShard] < maxPlayersPerShard, "Target shard is full");
        }

        // Update shard counts
        playersPerShard[oldShard]--;
        playersPerShard[newShard]++;

        // Update player's shard
        playerState.shard = newShard;

        emit IGameState.ShardChanged(player, oldShard, newShard);
        emit AdminShardChangeExecuted(msg.sender, player, oldShard, newShard, bypassLimit);
    }

    /**
     * @dev Event emitted when admin changes a player's shard
     */
    event AdminShardChangeExecuted(
        address indexed admin, address indexed player, uint8 oldShard, uint8 newShard, bool bypassedLimit
    );
}
