// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/IMapRegistry.sol";
import "../utils/Errors.sol";

/**
 * @title MapRegistry
 * @dev Registry for managing game maps, fish distributions, harbors, and terrain
 */
contract MapRegistry is IMapRegistry, AccessControl, Pausable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SERVER_ROLE = keccak256("SERVER_ROLE");

    // Maps storage
    mapping(uint256 => Map) private maps;
    uint256 private mapCount;

    // Fish distributions per map
    mapping(uint256 => mapping(int32 => mapping(int32 => FishDistribution))) private fishDistributions;

    // Harbor locations per map
    mapping(uint256 => mapping(int32 => mapping(int32 => bool))) private harbors;

    // Terrain data per map (true = passable, false = blocked)
    mapping(uint256 => mapping(int32 => mapping(int32 => bool))) private terrain;

    modifier validMap(uint256 mapId) {
        if (!isValidMap(mapId)) revert InvalidMap(mapId);
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(SERVER_ROLE, msg.sender);
    }

    /**
     * @dev Register a new map
     */
    function registerMap(
        uint256 id,
        string calldata name,
        uint8 tier,
        uint256 travelCost,
        int32 minX,
        int32 maxX,
        int32 minY,
        int32 maxY
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        if (isValidMap(id)) revert AlreadyExists("Map", id);
        if (minX >= maxX || minY >= maxY) revert InvalidBoundaries(minX, maxX, minY, maxY);
        if (bytes(name).length == 0) revert EmptyString();

        maps[id] = Map({
            id: id,
            name: name,
            tier: tier,
            travelCost: travelCost,
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            isActive: true
        });

        mapCount++;

        // Initialize all terrain as passable by default
        for (int32 x = minX; x <= maxX; x++) {
            for (int32 y = minY; y <= maxY; y++) {
                terrain[id][x][y] = true;
            }
        }

        emit MapRegistered(id, name, tier, travelCost);
    }

    /**
     * @dev Update an existing map
     */
    function updateMap(uint256 mapId, string calldata name, uint8 tier, uint256 travelCost)
        external
        onlyRole(ADMIN_ROLE)
        validMap(mapId)
        whenNotPaused
    {
        if (bytes(name).length == 0) revert EmptyString();

        Map storage map = maps[mapId];
        map.name = name;
        map.tier = tier;
        map.travelCost = travelCost;

        emit MapUpdated(mapId, name, tier, travelCost);
    }

    /**
     * @dev Update fish distribution at specific coordinates on a map
     */
    function updateFishDistribution(uint256 mapId, int32 x, int32 y, uint256[] calldata species)
        external
        onlyRole(SERVER_ROLE)
        validMap(mapId)
        whenNotPaused
    {
        if (species.length == 0) revert EmptyDistribution();
        if (!isValidPosition(mapId, x, y)) revert PositionOutOfBounds(mapId, uint256(uint32(x)), uint256(uint32(y)));

        FishDistribution storage distribution = fishDistributions[mapId][x][y];
        distribution.species = species;
        distribution.lastUpdated = block.timestamp;

        emit FishDistributionUpdated(mapId, x, y, species);
    }

    /**
     * @dev Get fish distribution at coordinates on a map
     */
    function getFishDistribution(uint256 mapId, int32 x, int32 y)
        external
        view
        validMap(mapId)
        returns (FishDistribution memory)
    {
        return fishDistributions[mapId][x][y];
    }

    /**
     * @dev Set harbor status for a single position
     */
    function setHarbor(uint256 mapId, int32 x, int32 y, bool harborStatus)
        external
        onlyRole(ADMIN_ROLE)
        validMap(mapId)
        whenNotPaused
    {
        if (!isValidPosition(mapId, x, y)) revert PositionOutOfBounds(mapId, uint256(uint32(x)), uint256(uint32(y)));

        harbors[mapId][x][y] = harborStatus;
        emit HarborUpdated(mapId, x, y, harborStatus);
    }

    /**
     * @dev Set harbor status for multiple positions
     */
    function setHarborBatch(uint256 mapId, int32[] calldata x, int32[] calldata y, bool[] calldata harborStatus)
        external
        onlyRole(ADMIN_ROLE)
        validMap(mapId)
        whenNotPaused
    {
        if (x.length != y.length || y.length != harborStatus.length) revert InvalidArrayLength();

        for (uint256 i = 0; i < x.length; i++) {
            if (!isValidPosition(mapId, x[i], y[i])) {
                revert PositionOutOfBounds(mapId, uint256(uint32(x[i])), uint256(uint32(y[i])));
            }
            harbors[mapId][x[i]][y[i]] = harborStatus[i];
            emit HarborUpdated(mapId, x[i], y[i], harborStatus[i]);
        }
    }

    /**
     * @dev Check if a position is a harbor
     */
    function isHarbor(uint256 mapId, int32 x, int32 y) external view validMap(mapId) returns (bool) {
        return harbors[mapId][x][y];
    }

    /**
     * @dev Set terrain passability for a single tile
     */
    function setTerrain(uint256 mapId, int32 x, int32 y, bool passable)
        external
        onlyRole(ADMIN_ROLE)
        validMap(mapId)
        whenNotPaused
    {
        if (!isValidPosition(mapId, x, y)) revert PositionOutOfBounds(mapId, uint256(uint32(x)), uint256(uint32(y)));
        terrain[mapId][x][y] = passable;
        emit TerrainUpdated(mapId, x, y, passable);
    }

    /**
     * @dev Set terrain passability for multiple tiles
     */
    function setTerrainBatch(uint256 mapId, int32[] calldata x, int32[] calldata y, bool[] calldata passable)
        external
        onlyRole(ADMIN_ROLE)
        validMap(mapId)
        whenNotPaused
    {
        if (x.length != y.length || y.length != passable.length) {
            revert ArrayLengthMismatch(x.length, y.length);
        }

        for (uint256 i = 0; i < x.length; i++) {
            if (!isValidPosition(mapId, x[i], y[i])) {
                revert PositionOutOfBounds(mapId, uint256(uint32(x[i])), uint256(uint32(y[i])));
            }
            terrain[mapId][x[i]][y[i]] = passable[i];
            emit TerrainUpdated(mapId, x[i], y[i], passable[i]);
        }
    }

    /**
     * @dev Check if a position is passable (not blocked by terrain)
     */
    function isPassable(uint256 mapId, int32 x, int32 y) public view validMap(mapId) returns (bool) {
        if (!isValidPosition(mapId, x, y)) {
            return false;
        }
        return terrain[mapId][x][y];
    }

    /**
     * @dev Get map information
     */
    function getMap(uint256 mapId) external view returns (Map memory) {
        return maps[mapId];
    }

    /**
     * @dev Check if map exists and is active
     */
    function isValidMap(uint256 mapId) public view returns (bool) {
        return maps[mapId].isActive;
    }

    /**
     * @dev Get total number of registered maps
     */
    function getMapCount() external view returns (uint256) {
        return mapCount;
    }

    /**
     * @dev Get all maps
     */
    function getAllMaps() external view returns (Map[] memory) {
        Map[] memory allMaps = new Map[](mapCount);
        uint256 index = 0;

        // This is inefficient but works for small numbers of maps
        // In production, you'd want to keep an array of map IDs
        for (uint256 i = 0; i < 1000 && index < mapCount; i++) {
            if (isValidMap(i)) {
                allMaps[index] = maps[i];
                index++;
            }
        }

        return allMaps;
    }

    /**
     * @dev Check if position is within map boundaries
     */
    function isValidPosition(uint256 mapId, int32 x, int32 y) public view validMap(mapId) returns (bool) {
        Map memory map = maps[mapId];
        return x >= map.minX && x <= map.maxX && y >= map.minY && y <= map.maxY;
    }

    /**
     * @dev Pause the contract
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
