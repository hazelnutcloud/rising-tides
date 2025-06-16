// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/IShipRegistry.sol";

/**
 * @title ShipRegistry
 * @dev Registry contract for managing ship types and configurations
 * Stores ship templates that define cargo space, stats, and costs
 */
contract ShipRegistry is IShipRegistry, AccessControl, Pausable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    mapping(uint256 => Ship) private ships;
    uint256 private shipCount;
    uint256[] private shipIds;

    modifier validShipId(uint256 shipId) {
        require(isValidShip(shipId), "Invalid ship ID");
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @dev Register a new ship type
     */
    function registerShip(
        uint256 id,
        string calldata name,
        uint256 fuelCapacity,
        uint256 maxDurability,
        uint8 cargoWidth,
        uint8 cargoHeight,
        bytes calldata cargoShape,
        uint8[] calldata slotTypes,
        uint256 purchasePrice,
        uint256 repairCostPerPoint
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        _validateShipParams(id, name, fuelCapacity, maxDurability, cargoWidth, cargoHeight, cargoShape);
        _validateSlotTypes(slotTypes, cargoWidth, cargoHeight);

        ships[id] = Ship({
            id: id,
            name: name,
            fuelCapacity: fuelCapacity,
            durability: maxDurability,
            maxDurability: maxDurability,
            cargoWidth: cargoWidth,
            cargoHeight: cargoHeight,
            cargoShape: cargoShape,
            slotTypes: slotTypes,
            purchasePrice: purchasePrice,
            repairCostPerPoint: repairCostPerPoint
        });

        shipIds.push(id);
        shipCount++;

        emit ShipRegistered(id, name, purchasePrice);
    }

    /**
     * @dev Get complete ship data
     */
    function getShip(uint256 shipId) external view validShipId(shipId) returns (Ship memory) {
        return ships[shipId];
    }

    /**
     * @dev Get ship performance stats
     */
    function getShipStats(uint256 shipId) external view validShipId(shipId) returns (ShipStats memory) {
        Ship memory ship = ships[shipId];

        return ShipStats({
            enginePower: 50,  // Deprecated default value for backward compatibility
            fuelEfficiency: 100,  // Deprecated default value for backward compatibility
            cargoCapacity: uint256(ship.cargoWidth) * uint256(ship.cargoHeight),
            durability: ship.durability
        });
    }

    /**
     * @dev Check if a ship ID is valid
     */
    function isValidShip(uint256 shipId) public view returns (bool) {
        return ships[shipId].id == shipId && ships[shipId].id > 0;
    }

    /**
     * @dev Get total number of registered ships
     */
    function getShipCount() external view returns (uint256) {
        return shipCount;
    }

    /**
     * @dev Get all registered ships
     */
    function getAllShips() external view returns (Ship[] memory) {
        Ship[] memory allShips = new Ship[](shipCount);

        for (uint256 i = 0; i < shipIds.length; i++) {
            allShips[i] = ships[shipIds[i]];
        }

        return allShips;
    }

    /**
     * @dev Check if a cargo position is valid for a ship
     */
    function isValidCargoPosition(uint256 shipId, uint8 x, uint8 y) external view validShipId(shipId) returns (bool) {
        Ship memory ship = ships[shipId];

        if (x >= ship.cargoWidth || y >= ship.cargoHeight) {
            return false;
        }

        // Check if position is occupied in cargo shape
        uint256 bitIndex = uint256(y) * uint256(ship.cargoWidth) + uint256(x);
        uint256 byteIndex = bitIndex / 8;
        uint256 bitOffset = bitIndex % 8;

        if (byteIndex >= ship.cargoShape.length) {
            return false;
        }

        uint8 byte_ = uint8(ship.cargoShape[byteIndex]);
        return (byte_ >> bitOffset) & 1 == 1;
    }

    /**
     * @dev Check if a position is an engine slot
     */
    function isEngineSlot(uint256 shipId, uint8 position) external view validShipId(shipId) returns (bool) {
        Ship memory ship = ships[shipId];

        if (position >= ship.slotTypes.length) {
            return false;
        }

        return ship.slotTypes[position] == 1; // 1 = engine slot
    }

    /**
     * @dev Check if a position is an equipment slot
     */
    function isEquipmentSlot(uint256 shipId, uint8 position) external view validShipId(shipId) returns (bool) {
        Ship memory ship = ships[shipId];

        if (position >= ship.slotTypes.length) {
            return false;
        }

        return ship.slotTypes[position] == 2; // 2 = equipment slot
    }

    /**
     * @dev Update ship stats (admin only)
     */
    function updateShipStats(
        uint256 shipId,
        uint256 fuelCapacity,
        uint256 maxDurability,
        uint256 purchasePrice,
        uint256 repairCostPerPoint
    ) external onlyRole(ADMIN_ROLE) validShipId(shipId) whenNotPaused {
        Ship storage ship = ships[shipId];

        ship.fuelCapacity = fuelCapacity;
        ship.maxDurability = maxDurability;
        ship.purchasePrice = purchasePrice;
        ship.repairCostPerPoint = repairCostPerPoint;

        // Reset durability to max if it was higher
        if (ship.durability > maxDurability) {
            ship.durability = maxDurability;
        }

        emit ShipStatsUpdated(
            shipId,
            ShipStats({
                enginePower: 50,  // Deprecated default
                fuelEfficiency: 100,  // Deprecated default
                cargoCapacity: uint256(ship.cargoWidth) * uint256(ship.cargoHeight),
                durability: ship.durability
            })
        );
    }


    /**
     * @dev Remove a ship type (admin only)
     */
    function removeShip(uint256 shipId) external onlyRole(ADMIN_ROLE) validShipId(shipId) whenNotPaused {
        delete ships[shipId];

        // Remove from shipIds array
        for (uint256 i = 0; i < shipIds.length; i++) {
            if (shipIds[i] == shipId) {
                shipIds[i] = shipIds[shipIds.length - 1];
                shipIds.pop();
                break;
            }
        }

        shipCount--;
    }

    /**
     * @dev Validate ship parameters (internal helper to reduce stack depth)
     */
    function _validateShipParams(
        uint256 id,
        string calldata name,
        uint256 fuelCapacity,
        uint256 maxDurability,
        uint8 cargoWidth,
        uint8 cargoHeight,
        bytes calldata cargoShape
    ) private view {
        require(id > 0, "Ship ID must be greater than 0");
        require(!isValidShip(id), "Ship ID already exists");
        require(bytes(name).length > 0, "Ship name cannot be empty");
        require(fuelCapacity > 0, "Fuel capacity must be greater than 0");
        require(maxDurability > 0, "Max durability must be greater than 0");
        require(cargoWidth > 0 && cargoHeight > 0, "Cargo dimensions must be greater than 0");
        require(cargoShape.length > 0, "Cargo shape cannot be empty");

        // Validate cargo shape size matches dimensions
        uint256 expectedShapeSize = (uint256(cargoWidth) * uint256(cargoHeight) + 7) / 8;
        require(cargoShape.length >= expectedShapeSize, "Cargo shape data too small");
    }

    /**
     * @dev Validate slot types array (internal helper to reduce stack depth)
     */
    function _validateSlotTypes(uint8[] calldata slotTypes, uint8 cargoWidth, uint8 cargoHeight) private pure {
        uint256 totalSlots = uint256(cargoWidth) * uint256(cargoHeight);

        require(slotTypes.length == totalSlots, "Slot types array length must match cargo dimensions");

        for (uint256 i = 0; i < slotTypes.length; i++) {
            require(slotTypes[i] <= 2, "Invalid slot type (must be 0=normal, 1=engine, 2=equipment)");
        }
    }

    /**
     * @dev Pause the contract (emergency use)
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
