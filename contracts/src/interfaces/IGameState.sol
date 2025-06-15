// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGameState {
    struct Position {
        int32 x;
        int32 y;
    }

    struct PlayerState {
        Position position;
        uint8 shard;
        uint256 shipId;
        uint256 currentFuel;
        uint256 lastMoveTimestamp;
        bool isActive;
    }

    struct FishCatch {
        uint8 species;
        uint16 weight;
        uint256 caughtAt;
    }

    // Events
    event PlayerRegistered(address indexed player, uint8 shard);
    event PlayerMoved(address indexed player, uint8 shard, int32 x, int32 y, uint256 fuelConsumed);
    event FishCaught(address indexed player, uint8 species, uint16 weight, uint256 inventorySlot);
    event FuelPurchased(address indexed player, uint256 amount, uint256 cost);
    event ShipChanged(address indexed player, uint256 newShipId);
    event ShardChanged(address indexed player, uint8 oldShard, uint8 newShard);

    // Player Management
    function registerPlayer(uint8 shard) external;
    function getPlayerState(address player) external view returns (PlayerState memory);
    function isPlayerRegistered(address player) external view returns (bool);

    // Movement
    function move(int32 newX, int32 newY) external;
    function calculateFuelCost(address player, int32 targetX, int32 targetY) external view returns (uint256);

    // Fuel Management
    function purchaseFuel(uint256 amount) external;
    function getCurrentFuel(address player) external view returns (uint256);

    // Fishing
    function fish(uint8 baitType) external returns (uint8 species, uint16 weight);

    // Ship Management
    function changeShip(uint256 newShipId) external;

    // Shard Management
    function changeShard(uint8 newShard) external;
}