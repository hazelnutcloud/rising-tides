// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMapRegistry {
    struct Position {
        int32 x;
        int32 y;
    }

    struct Map {
        uint256 id;
        string name;
        uint8 tier;
        uint256 travelCost;
        int32 minX;
        int32 maxX;
        int32 minY;
        int32 maxY;
        bool isActive;
    }

    struct FishDistribution {
        uint256[] species;
        uint256 lastUpdated;
    }

    struct BaitShop {
        Position position;
        uint256[] availableBait;
        bool isActive;
    }

    // Events
    event MapRegistered(uint256 indexed mapId, string name, uint8 tier, uint256 travelCost);
    event MapUpdated(uint256 indexed mapId, string name, uint8 tier, uint256 travelCost);
    event FishDistributionUpdated(uint256 indexed mapId, int32 x, int32 y, uint256[] species);
    event BaitShopAdded(uint256 indexed mapId, uint256 indexed shopId, int32 x, int32 y);
    event BaitShopUpdated(uint256 indexed mapId, uint256 indexed shopId, uint256[] availableBait);
    event TerrainUpdated(uint256 indexed mapId, int32 x, int32 y, bool isPassable);

    // Map Management
    function registerMap(
        uint256 id,
        string calldata name,
        uint8 tier,
        uint256 travelCost,
        int32 minX,
        int32 maxX,
        int32 minY,
        int32 maxY
    ) external;
    
    function updateMap(
        uint256 mapId,
        string calldata name,
        uint8 tier,
        uint256 travelCost
    ) external;

    // Fish Distribution Management
    function updateFishDistribution(
        uint256 mapId,
        int32 x,
        int32 y,
        uint256[] calldata species
    ) external;

    function getFishDistribution(uint256 mapId, int32 x, int32 y) external view returns (FishDistribution memory);

    // Bait Shop Management
    function addBaitShop(
        uint256 mapId,
        int32 x,
        int32 y,
        uint256[] calldata availableBait
    ) external returns (uint256 shopId);

    function updateBaitShop(
        uint256 mapId,
        uint256 shopId,
        uint256[] calldata availableBait
    ) external;

    function getBaitShop(uint256 mapId, uint256 shopId) external view returns (BaitShop memory);
    function getBaitShopsCount(uint256 mapId) external view returns (uint256);

    // Terrain Management
    function setTerrain(uint256 mapId, int32 x, int32 y, bool isPassable) external;
    function setTerrainBatch(
        uint256 mapId,
        int32[] calldata x,
        int32[] calldata y,
        bool[] calldata isPassable
    ) external;
    function isPassable(uint256 mapId, int32 x, int32 y) external view returns (bool);

    // Map Queries
    function getMap(uint256 mapId) external view returns (Map memory);
    function isValidMap(uint256 mapId) external view returns (bool);
    function getMapCount() external view returns (uint256);
    function getAllMaps() external view returns (Map[] memory);
    function isValidPosition(uint256 mapId, int32 x, int32 y) external view returns (bool);
}