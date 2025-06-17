// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IShipRegistry {
    struct Ship {
        uint256 id;
        string name;
        uint256 fuelCapacity;
        uint256 durability;
        uint256 maxDurability;
        uint8 cargoWidth;
        uint8 cargoHeight;
        uint8[] slotTypes; // Slot type for each position: 0=normal, 1=engine, 2=equipment, 3=blocked
        uint256 purchasePrice;
        uint256 repairCostPerPoint;
    }

    struct ShipStats {
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
        uint256 maxDurability,
        uint8 cargoWidth,
        uint8 cargoHeight,
        uint8[] calldata slotTypes, // 0=normal, 1=engine, 2=equipment, 3=blocked
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
    function isBlockedSlot(uint256 shipId, uint8 position) external view returns (bool);
}
