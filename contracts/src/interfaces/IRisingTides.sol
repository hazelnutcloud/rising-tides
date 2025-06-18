// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/InventoryLib.sol";
import "./IRisingTidesInventory.sol";
import "./IRisingTidesFishing.sol";


interface IRisingTides {
    struct Position {
        int32 x;
        int32 y;
    }

    struct PlayerState {
        uint256 mapId;
        uint256 shipId;
        uint256 currentFuel;
        uint256 lastMoveTimestamp;
        uint256 nextMoveTime;
        uint256 movementSpeed;
        Position position;
        uint8 shard;
        bool isActive;
    }

    struct FishCatch {
        uint256 species;
        uint256 caughtTimestamp;
        uint16 weight;
    }

    struct FishMarketData {
        uint256 value;
        uint256 lastSoldTimestamp;
    }

    // Events
    event PlayerRegistered(address indexed player, uint8 shard);
    event PlayerMoved(address indexed player, uint8 shard, uint256 mapId, int32 x, int32 y, uint256 fuelConsumed);
    event FuelPurchased(address indexed player, uint256 amount, uint256 cost);
    event ShipPurchased(address indexed player, uint256 shipId, uint256 cost);
    event EnginePurchased(address indexed player, uint256 engineId, uint256 cost);
    event FishingRodPurchased(address indexed player, uint256 rodId, uint256 cost);
    event ShipChanged(address indexed player, uint256 newShipId);
    event ShardChanged(address indexed player, uint8 oldShard, uint8 newShard);
    event MapChanged(address indexed player, uint256 oldMapId, uint256 newMapId, uint256 cost);
    event BaitPurchased(address indexed player, uint256 baitType, uint256 amount, uint256 cost);
    event MaxPlayersPerShardUpdated(uint256 oldLimit, uint256 newLimit);
    event FishSold(uint256 indexed species, uint256 weight, uint256 freshness, uint256 salePrice);
    event FishMarketUpdated(uint256 indexed species, uint256 value, uint256 timestamp);

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

    // Equipment Purchasing (Harbor Required)
    function purchaseShip(uint256 shipId) external;
    function purchaseEngine(uint256 engineId) external;
    function purchaseFishingRod(uint256 rodId) external;

    // Fishing (delegates to fishing contract)
    function initiateFishing(uint256 baitType) external returns (uint256 fishingNonce);
    function fulfillFishing(FishingResult memory result, bytes memory signature, FishPlacement memory fishPlacement)
        external
        returns (uint256 instanceId);
    function sellFish(uint256 instanceId) external returns (uint256 salePrice);

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

    // Contract Access
    function inventoryContract() external view returns (IRisingTidesInventory);
    function fishingContract() external view returns (IRisingTidesFishing);
    
    // Inventory Management (delegates to inventory contract)
    function getPlayerInventory(address player)
        external
        view
        returns (uint8 width, uint8 height, SlotType[] memory slotTypes, InventoryLib.GridItem[] memory items);
    function getInventoryItem(address player, uint8 x, uint8 y) external view returns (InventoryLib.GridItem memory);
    function updateInventoryItem(uint8 fromX, uint8 fromY, uint8 toX, uint8 toY, uint8 rotation) external;
    function discardInventoryItem(uint8 x, uint8 y) external;

    // Shard Management
    function getShardPlayerCount(uint8 shard) external view returns (uint256);
    function getMaxPlayersPerShard() external view returns (uint256);
    function isShardAvailable(uint8 shard) external view returns (bool);
    function getAllShardOccupancy()
        external
        view
        returns (uint8[] memory shardIds, uint256[] memory playerCounts, bool[] memory available);
    function setMaxPlayersPerShard(uint256 newLimit) external;

    // Admin Functions
    function updateServerSigner(address newSigner) external;
    function adminChangePlayerShard(address player, uint8 newShard, bool bypassLimit) external;
}
