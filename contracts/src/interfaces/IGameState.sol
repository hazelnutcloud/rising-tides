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
        uint256 mapId;
        uint256 shipId;
        uint256 currentFuel;
        uint256 lastMoveTimestamp;
        uint256 nextMoveTime;
        uint256 movementSpeed;
        uint256 totalWeight;
        bool isActive;
    }

    struct FishCatch {
        uint256 species;
        uint16 weight;
        uint256 caughtAt;
    }

    // Events
    event PlayerRegistered(address indexed player, uint8 shard);
    event PlayerMoved(address indexed player, uint8 shard, uint256 mapId, int32 x, int32 y, uint256 fuelConsumed);
    event FishingInitiated(
        address indexed player, uint8 shard, uint256 mapId, int32 x, int32 y, uint256 baitType, uint256 nonce
    );
    event FishCaught(address indexed player, uint256 species, uint16 weight, uint256 inventorySlot);
    event FuelPurchased(address indexed player, uint256 amount, uint256 cost);
    event ShipChanged(address indexed player, uint256 newShipId);
    event ShardChanged(address indexed player, uint8 oldShard, uint8 newShard);
    event MapChanged(address indexed player, uint256 oldMapId, uint256 newMapId, uint256 cost);
    event BaitPurchased(address indexed player, uint256 baitType, uint256 amount, uint256 cost);

    // Player Management
    function registerPlayer(uint8 shard, uint256 mapId) external;
    function getPlayerState(address player) external view returns (PlayerState memory);
    function isPlayerRegistered(address player) external view returns (bool);

    // Movement
    function move(uint8[] calldata directions) external;
    function calculateFuelCost(address player, uint8[] calldata directions) external view returns (uint256);

    // Fuel Management
    function purchaseFuel(uint256 amount) external;
    function getCurrentFuel(address player) external view returns (uint256);

    // Fishing
    function initiateFishing(uint256 baitType) external returns (uint256 fishingNonce);
    function completeServerFishing(address player, uint256 nonce, uint256 species, uint16 weight) external;

    // Bait Management
    function purchaseBait(uint256 baitType, uint256 amount) external;
    function getPlayerBait(address player, uint256 baitType) external view returns (uint256);
    function getPlayerAvailableBait(address player)
        external
        view
        returns (uint256[] memory baitTypes, uint256[] memory amounts);
    function getPlayerFishingStatus(address player)
        external
        view
        returns (uint256 pendingNonce, uint256 baitTypeUsed, uint256 currentNonce);

    // Map Travel
    function travelToMap(uint256 newMapId) external;

    // Ship Management
    function changeShip(uint256 newShipId) external;

    // Shard Management
    function changeShard(uint8 newShard) external;

    // Weight Management
    function updatePlayerWeight(address player) external;
}
