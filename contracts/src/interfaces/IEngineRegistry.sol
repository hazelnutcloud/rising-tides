// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IEngineRegistry {
    struct Engine {
        uint256 id;
        string name;
        uint256 enginePower; // Power rating for movement calculations
        uint256 fuelEfficiency; // Fuel consumption modifier (100 = baseline)
        uint8 shapeWidth; // Physical inventory size
        uint8 shapeHeight;
        bytes shapeData; // Tetris-like shape bitmap
        uint256 purchasePrice;
        uint256 weight; // Affects ship weight calculations
        bool isActive;
    }

    struct EngineStats {
        uint256 enginePower;
        uint256 fuelEfficiency;
        uint256 weight;
    }

    // Events
    event EngineRegistered(uint256 indexed engineId, string name, uint256 enginePower, uint256 price);
    event EngineStatsUpdated(uint256 indexed engineId, EngineStats stats);
    event EngineStatusUpdated(uint256 indexed engineId, bool isActive);

    // Engine Management
    function registerEngine(
        uint256 id,
        string calldata name,
        uint256 enginePower,
        uint256 fuelEfficiency,
        uint8 shapeWidth,
        uint8 shapeHeight,
        bytes calldata shapeData,
        uint256 purchasePrice,
        uint256 weight
    ) external;

    // Queries
    function getEngine(uint256 engineId) external view returns (Engine memory);
    function getEngineStats(uint256 engineId) external view returns (EngineStats memory);
    function isValidEngine(uint256 engineId) external view returns (bool);
    function getEngineCount() external view returns (uint256);
    function getAllEngines() external view returns (Engine[] memory);

    // Admin Functions
    function updateEngineStats(
        uint256 engineId,
        uint256 enginePower,
        uint256 fuelEfficiency,
        uint256 weight,
        uint256 purchasePrice
    ) external;
    function setEngineStatus(uint256 engineId, bool isActive) external;

    // Utility Functions
    function calculateCombinedPower(uint256[] calldata engineIds) external view returns (uint256 totalPower);
    function calculateCombinedEfficiency(uint256[] calldata engineIds) external view returns (uint256 avgEfficiency);
    function calculateCombinedWeight(uint256[] calldata engineIds) external view returns (uint256 totalWeight);
}
