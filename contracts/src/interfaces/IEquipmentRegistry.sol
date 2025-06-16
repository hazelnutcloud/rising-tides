// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IEquipmentRegistry {
    enum EquipmentType {
        FISHING_ROD,    // Affects fishing success rates
        FISHING_NET,    // Allows net fishing (different mechanics)
        CRAB_POT,       // Passive crab catching
        SONAR,          // Reveals fish locations
        FUEL_TANK       // Increases fuel capacity
    }

    struct Equipment {
        uint256 id;
        string name;
        EquipmentType equipmentType;
        uint8 shapeWidth;           // Physical inventory size
        uint8 shapeHeight;
        bytes shapeData;            // Tetris-like shape bitmap
        uint256 purchasePrice;
        uint256 weight;             // Affects ship weight calculations
        bool isActive;
    }

    struct EquipmentStats {
        EquipmentType equipmentType;
        uint256 weight;
        mapping(string => uint256) stats; // Flexible stats system
    }

    // Events
    event EquipmentRegistered(uint256 indexed equipmentId, string name, EquipmentType equipmentType, uint256 price);
    event EquipmentStatsUpdated(uint256 indexed equipmentId, string statName, uint256 value);
    event EquipmentStatusUpdated(uint256 indexed equipmentId, bool isActive);

    // Equipment Management
    function registerEquipment(
        uint256 id,
        string calldata name,
        EquipmentType equipmentType,
        uint8 shapeWidth,
        uint8 shapeHeight,
        bytes calldata shapeData,
        uint256 purchasePrice,
        uint256 weight
    ) external;

    // Queries
    function getEquipment(uint256 equipmentId) external view returns (Equipment memory);
    function isValidEquipment(uint256 equipmentId) external view returns (bool);
    function getEquipmentCount() external view returns (uint256);
    function getAllEquipment() external view returns (Equipment[] memory);
    function getEquipmentsByType(EquipmentType equipmentType) external view returns (Equipment[] memory);

    // Stats Management
    function setEquipmentStat(uint256 equipmentId, string calldata statName, uint256 value) external;
    function getEquipmentStat(uint256 equipmentId, string calldata statName) external view returns (uint256);
    function getEquipmentStats(uint256 equipmentId, string[] calldata statNames) 
        external view returns (uint256[] memory values);

    // Admin Functions
    function updateEquipmentBasics(
        uint256 equipmentId,
        uint256 purchasePrice,
        uint256 weight
    ) external;
    function setEquipmentStatus(uint256 equipmentId, bool isActive) external;

    // Utility Functions
    function calculateCombinedWeight(uint256[] calldata equipmentIds) external view returns (uint256 totalWeight);
    function getEquippedEffects(uint256[] calldata equipmentIds, string calldata statName) 
        external view returns (uint256 totalEffect);
}