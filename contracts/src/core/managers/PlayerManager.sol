// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SlotType, ItemType} from "../../types/InventoryTypes.sol";
import "../RisingTidesBase.sol";

/**
 * @title PlayerManager
 * @dev Manages player registration, state, and weight calculations
 */
abstract contract PlayerManager is RisingTidesBase {

    /**
     * @dev Register a new player
     */
    function registerPlayer(uint8 shard, uint256 mapId) external validShard(shard) whenNotPaused {
        if (registeredPlayers[msg.sender]) revert PlayerAlreadyRegistered(msg.sender);
        if (!mapRegistry.isValidMap(mapId)) revert InvalidMap(mapId);
        if (playersPerShard[shard] >= maxPlayersPerShard) {
            revert ShardFull(shard, playersPerShard[shard], maxPlayersPerShard);
        }

        // Initialize inventory grid based on default ship
        _initializeInventory(msg.sender, 1);

        // Place default equipment (Engine ID 1 and Fishing Rod ID 1)
        inventoryContract.assignDefaultEquipment(msg.sender, 1, 1);

        // Calculate initial player weight (ship base weight + engine weight)
        uint256 totalWeight = _calculatePlayerWeight(msg.sender, 1);

        // Calculate initial engine power from equipped engines
        uint256 enginePower = _calculateTotalEnginePower(msg.sender, 1);

        playerStates[msg.sender] = IRisingTides.PlayerState({
            position: IRisingTides.Position(0, 0),
            shard: shard,
            mapId: mapId,
            shipId: 1,
            currentFuel: 100e18, // Starting fuel (100 units with 18 decimals precision)
            lastMoveTimestamp: block.timestamp,
            nextMoveTime: block.timestamp,
            movementSpeed: _calculateMovementSpeed(enginePower, totalWeight),
            isActive: true
        });

        registeredPlayers[msg.sender] = true;
        playersPerShard[shard]++;

        emit IRisingTides.PlayerRegistered(msg.sender, shard);
    }

    /**
     * @dev Get player state
     */
    function getPlayerState(address player) external view returns (IRisingTides.PlayerState memory) {
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
        IRisingTides.PlayerState storage player = playerStates[msg.sender];
        uint8 oldShard = player.shard;

        if (newShard == oldShard) revert AlreadyInShard(msg.sender, newShard);
        if (playersPerShard[newShard] >= maxPlayersPerShard) {
            revert ShardFull(newShard, playersPerShard[newShard], maxPlayersPerShard);
        }

        // Update shard counts
        playersPerShard[oldShard]--;
        playersPerShard[newShard]++;

        player.shard = newShard;

        emit IRisingTides.ShardChanged(msg.sender, oldShard, newShard);
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
        return inventoryContract.getTotalEnginePower(player, shipId);
    }

    /**
     * @dev Initialize player inventory based on ship
     */
    function _initializeInventory(address player, uint256 shipId) internal {
        IShipRegistry.Ship memory ship = shipRegistry.getShip(shipId);
        inventoryContract.initializeInventory(player, shipId, ship.cargoWidth, ship.cargoHeight, ship.slotTypes);
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
        if (newLimit == 0) revert LimitOutOfBounds(newLimit, 1, 10000);
        if (newLimit > 10000) revert LimitOutOfBounds(newLimit, 1, 10000); // Reasonable upper bound

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
        if (!registeredPlayers[player]) revert PlayerNotRegistered(player);

        IRisingTides.PlayerState storage playerState = playerStates[player];
        uint8 oldShard = playerState.shard;

        if (newShard == oldShard) revert AlreadyInShard(player, newShard);

        // Check shard capacity unless bypassing limit
        if (!bypassLimit) {
            if (playersPerShard[newShard] >= maxPlayersPerShard) {
                revert ShardFull(newShard, playersPerShard[newShard], maxPlayersPerShard);
            }
        }

        // Update shard counts
        playersPerShard[oldShard]--;
        playersPerShard[newShard]++;

        // Update player's shard
        playerState.shard = newShard;

        emit IRisingTides.ShardChanged(player, oldShard, newShard);
        emit AdminShardChangeExecuted(msg.sender, player, oldShard, newShard, bypassLimit);
    }

    /**
     * @dev Event emitted when admin changes a player's shard
     */
    event AdminShardChangeExecuted(
        address indexed admin, address indexed player, uint8 oldShard, uint8 newShard, bool bypassedLimit
    );
}
