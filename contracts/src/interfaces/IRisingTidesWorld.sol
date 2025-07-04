// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRisingTidesWorld {
    // Custom errors
    error PlayerNotRegistered();
    error PlayerAlreadyRegistered();
    error InvalidMap();
    error InvalidPosition();
    error MustSpawnInPortRegion();
    error NoDirectionsProvided();
    error TooManySteps();
    error NoShipEquipped();
    error ShipEngineTooWeak();
    error CargoExceedsCapacity();
    error InsufficientFuel();
    error NotCurrentlyMoving();
    error CannotTravelWhileMoving();
    error AlreadyOnThisMap();
    error MustBeAtPortToTravel();
    error MustTravelToPortRegion();
    error InsufficientLevel();
    error InsufficientDoubloons();
    error InvalidShard();
    error MapAlreadyExists();
    error InvalidBoundaries();
    error MustHaveAtLeastOneShard();
    error EnginePowerTooLow();
    error MustMoveToDifferentPosition();
    error ShipCannotNavigateRegion();

    enum Direction {
        EAST, // +q, 0r
        NORTHEAST, // +q, -r
        NORTHWEST, // 0q, -r
        WEST, // -q, 0r
        SOUTHWEST, // -q, +r
        SOUTHEAST // 0q, +r
    }

    struct Coordinate {
        int32 q;
        int32 r;
    }

    struct Player {
        Coordinate[] path;
        uint256 currentPathIndex;
        uint256 mapId;
        uint256 shardId;
        uint256 xp;
        uint256 moveStartTime;
        uint256 segmentDuration;
        bool isRegistered;
    }

    struct Map {
        string name;
        uint256 travelCost;
        uint256 requiredLevel;
        int32 radius; // Radius of the hexagonal map
        bool exists;
    }
    
    function getPlayerLevel(address player) external view returns (uint256 level);
    
    function getPlayerLocation(address player) external view returns (int32 q, int32 r, uint256 mapId);

    function getCurrentPosition(address player) external view returns (int32 q, int32 r);

    function isMoving(address player) external view returns (bool);

    function getPlayerInfo(address player) external view returns (Player memory);

    function validateFishingLocation(address player)
        external
        view
        returns (bool canFish, int32 q, int32 r, uint256 regionId, uint256 mapId);

    function isPortRegion(uint256 mapId, int32 q, int32 r) external view returns (bool);

    function getRegionType(uint256 mapId, int32 q, int32 r) external view returns (uint256);

    function grantXP(address player, uint256 amount) external;
}
