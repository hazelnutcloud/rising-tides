// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IEngineRegistry {
    struct Engine {
        uint256 id;
        string name;
        uint256 enginePowerPerCell; // Power rating per cell for movement calculations
        uint256 fuelConsumptionRatePerCell; // Fuel consumption rate per cell (100 = baseline, higher = more fuel used)
        uint8 shapeWidth; // Physical inventory size
        uint8 shapeHeight;
        bytes shapeData; // Tetris-like shape bitmap
        uint256 purchasePrice;
        uint256 weight; // Affects ship weight calculations
        bool isActive;
    }

    struct EngineStats {
        uint256 enginePowerPerCell;
        uint256 fuelConsumptionRatePerCell;
        uint256 weight;
    }

    // Events
    event EngineRegistered(uint256 indexed engineId, string name, uint256 enginePowerPerCell, uint256 price);
    event EngineStatsUpdated(uint256 indexed engineId, EngineStats stats);
    event EngineStatusUpdated(uint256 indexed engineId, bool isActive);

    // Engine Management
    function registerEngine(
        uint256 id,
        string calldata name,
        uint256 enginePowerPerCell,
        uint256 fuelConsumptionRatePerCell,
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
        uint256 enginePowerPerCell,
        uint256 fuelConsumptionRatePerCell,
        uint256 weight,
        uint256 purchasePrice
    ) external;
    function setEngineStatus(uint256 engineId, bool isActive) external;
}
