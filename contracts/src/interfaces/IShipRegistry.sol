// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IShipRegistry {
    struct Ship {
        uint256 id;
        string name;
        uint256 fuelCapacity;
        uint256 enginePower;
        uint256 durability;
        uint256 maxDurability;
        uint8 cargoWidth;
        uint8 cargoHeight;
        bytes cargoShape; // Packed bitmap of cargo grid
        uint8[] engineSlots; // Positions where engines can be placed
        uint8[] equipmentSlots; // Positions where equipment can be placed
        uint256 purchasePrice;
        uint256 repairCostPerPoint;
    }

    struct ShipStats {
        uint256 enginePower;
        uint256 fuelEfficiency; // Lower is better
        uint256 cargoCapacity;
        uint256 durability;
    }

    // Events
    event ShipRegistered(uint256 indexed shipId, string name, uint256 price);
    event ShipStatsUpdated(uint256 indexed shipId, ShipStats stats);

    // Ship Management
    function registerShip(
        uint256 id,
        string calldata name,
        uint256 fuelCapacity,
        uint256 enginePower,
        uint256 maxDurability,
        uint8 cargoWidth,
        uint8 cargoHeight,
        bytes calldata cargoShape,
        uint8[] calldata engineSlots,
        uint8[] calldata equipmentSlots,
        uint256 purchasePrice,
        uint256 repairCostPerPoint
    ) external;

    // Queries
    function getShip(uint256 shipId) external view returns (Ship memory);
    function getShipStats(uint256 shipId) external view returns (ShipStats memory);
    function isValidShip(uint256 shipId) external view returns (bool);
    function getShipCount() external view returns (uint256);
    function getAllShips() external view returns (Ship[] memory);

    // Validation
    function isValidCargoPosition(uint256 shipId, uint8 x, uint8 y) external view returns (bool);
    function isEngineSlot(uint256 shipId, uint8 position) external view returns (bool);
    function isEquipmentSlot(uint256 shipId, uint8 position) external view returns (bool);
}