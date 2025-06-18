// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/IShipRegistry.sol";
import {SlotType} from "../types/InventoryTypes.sol";
import "../utils/Errors.sol";

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
        if (!isValidShip(shipId)) revert InvalidShip(shipId);
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
        SlotType[] calldata slotTypes,
        uint256 purchasePrice,
        uint256 repairCostPerPoint
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        _validateShipParams(id, name, fuelCapacity, maxDurability, cargoWidth, cargoHeight);
        _validateSlotTypes(slotTypes, cargoWidth, cargoHeight);

        ships[id] = Ship({
            id: id,
            name: name,
            fuelCapacity: fuelCapacity,
            durability: maxDurability,
            maxDurability: maxDurability,
            cargoWidth: cargoWidth,
            cargoHeight: cargoHeight,
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
            ShipStats({cargoCapacity: uint256(ship.cargoWidth) * uint256(ship.cargoHeight), durability: ship.durability})
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
        uint8 cargoHeight
    ) private view {
        if (id == 0) revert InvalidId(id);
        if (isValidShip(id)) revert AlreadyExists("Ship", id);
        if (bytes(name).length == 0) revert EmptyString();
        if (fuelCapacity == 0) revert InvalidAmount(fuelCapacity);
        if (maxDurability == 0) revert InvalidAmount(maxDurability);
        if (cargoWidth == 0 || cargoHeight == 0) revert InvalidDimensions(cargoWidth, cargoHeight);
    }

    /**
     * @dev Validate slot types array (internal helper to reduce stack depth)
     */
    function _validateSlotTypes(SlotType[] calldata slotTypes, uint8 cargoWidth, uint8 cargoHeight) private pure {
        uint256 totalSlots = uint256(cargoWidth) * uint256(cargoHeight);

        if (slotTypes.length != totalSlots) revert ArrayLengthMismatch(totalSlots, slotTypes.length);

        // All SlotType enum values are valid by definition, no need to check range
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
