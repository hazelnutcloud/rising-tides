// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/IEquipmentRegistry.sol";

/**
 * @title EquipmentRegistry
 * @dev Registry contract for managing equipment types and their properties
 * Equipment are inventory items that provide various gameplay bonuses
 */
contract EquipmentRegistry is IEquipmentRegistry, AccessControl, Pausable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    mapping(uint256 => Equipment) private equipment;
    mapping(uint256 => mapping(string => uint256)) private equipmentStats;
    uint256 private equipmentCount;
    uint256[] private equipmentIds;

    modifier validEquipmentId(uint256 equipmentId) {
        require(isValidEquipment(equipmentId), "Invalid equipment ID");
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @dev Register a new equipment type
     */
    function registerEquipment(
        uint256 id,
        string calldata name,
        EquipmentType equipmentType,
        uint8 shapeWidth,
        uint8 shapeHeight,
        bytes calldata shapeData,
        uint256 purchasePrice,
        uint256 weight
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        require(id > 0, "Equipment ID must be greater than 0");
        require(!isValidEquipment(id), "Equipment ID already exists");
        require(bytes(name).length > 0, "Equipment name cannot be empty");
        require(shapeWidth > 0 && shapeHeight > 0, "Shape dimensions must be greater than 0");
        require(weight > 0, "Equipment weight must be greater than 0");

        // Validate shape data size
        uint256 expectedShapeSize = (uint256(shapeWidth) * uint256(shapeHeight) + 7) / 8;
        require(shapeData.length >= expectedShapeSize, "Shape data too small");

        equipment[id] = Equipment({
            id: id,
            name: name,
            equipmentType: equipmentType,
            shapeWidth: shapeWidth,
            shapeHeight: shapeHeight,
            shapeData: shapeData,
            purchasePrice: purchasePrice,
            weight: weight,
            isActive: true
        });

        equipmentIds.push(id);
        equipmentCount++;

        emit EquipmentRegistered(id, name, equipmentType, purchasePrice);
    }

    /**
     * @dev Get complete equipment data
     */
    function getEquipment(uint256 equipmentId) external view validEquipmentId(equipmentId) returns (Equipment memory) {
        return equipment[equipmentId];
    }

    /**
     * @dev Check if an equipment ID is valid
     */
    function isValidEquipment(uint256 equipmentId) public view returns (bool) {
        return equipment[equipmentId].id == equipmentId && equipment[equipmentId].id > 0;
    }

    /**
     * @dev Get total number of registered equipment
     */
    function getEquipmentCount() external view returns (uint256) {
        return equipmentCount;
    }

    /**
     * @dev Get all registered equipment
     */
    function getAllEquipment() external view returns (Equipment[] memory) {
        Equipment[] memory allEquipment = new Equipment[](equipmentCount);

        for (uint256 i = 0; i < equipmentIds.length; i++) {
            allEquipment[i] = equipment[equipmentIds[i]];
        }

        return allEquipment;
    }

    /**
     * @dev Get equipment by type
     */
    function getEquipmentsByType(EquipmentType equipmentType) external view returns (Equipment[] memory) {
        // Count equipment of this type first
        uint256 typeCount = 0;
        for (uint256 i = 0; i < equipmentIds.length; i++) {
            if (equipment[equipmentIds[i]].equipmentType == equipmentType && equipment[equipmentIds[i]].isActive) {
                typeCount++;
            }
        }

        // Populate array
        Equipment[] memory typeEquipment = new Equipment[](typeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < equipmentIds.length && index < typeCount; i++) {
            if (equipment[equipmentIds[i]].equipmentType == equipmentType && equipment[equipmentIds[i]].isActive) {
                typeEquipment[index] = equipment[equipmentIds[i]];
                index++;
            }
        }

        return typeEquipment;
    }

    /**
     * @dev Set equipment stat value (admin only)
     */
    function setEquipmentStat(uint256 equipmentId, string calldata statName, uint256 value)
        external
        onlyRole(ADMIN_ROLE)
        validEquipmentId(equipmentId)
        whenNotPaused
    {
        require(bytes(statName).length > 0, "Stat name cannot be empty");
        
        equipmentStats[equipmentId][statName] = value;
        emit EquipmentStatsUpdated(equipmentId, statName, value);
    }

    /**
     * @dev Get equipment stat value
     */
    function getEquipmentStat(uint256 equipmentId, string calldata statName)
        external
        view
        validEquipmentId(equipmentId)
        returns (uint256)
    {
        return equipmentStats[equipmentId][statName];
    }

    /**
     * @dev Get multiple equipment stats
     */
    function getEquipmentStats(uint256 equipmentId, string[] calldata statNames)
        external
        view
        validEquipmentId(equipmentId)
        returns (uint256[] memory values)
    {
        values = new uint256[](statNames.length);
        for (uint256 i = 0; i < statNames.length; i++) {
            values[i] = equipmentStats[equipmentId][statNames[i]];
        }
    }

    /**
     * @dev Update equipment basics (admin only)
     */
    function updateEquipmentBasics(
        uint256 equipmentId,
        uint256 purchasePrice,
        uint256 weight
    ) external onlyRole(ADMIN_ROLE) validEquipmentId(equipmentId) whenNotPaused {
        require(weight > 0, "Equipment weight must be greater than 0");

        Equipment storage equip = equipment[equipmentId];
        equip.purchasePrice = purchasePrice;
        equip.weight = weight;
    }

    /**
     * @dev Set equipment active status (admin only)
     */
    function setEquipmentStatus(uint256 equipmentId, bool isActive)
        external
        onlyRole(ADMIN_ROLE)
        validEquipmentId(equipmentId)
        whenNotPaused
    {
        equipment[equipmentId].isActive = isActive;
        emit EquipmentStatusUpdated(equipmentId, isActive);
    }

    /**
     * @dev Calculate combined weight of multiple equipment
     */
    function calculateCombinedWeight(uint256[] calldata _equipmentIds) external view returns (uint256 totalWeight) {
        for (uint256 i = 0; i < _equipmentIds.length; i++) {
            if (isValidEquipment(_equipmentIds[i]) && equipment[_equipmentIds[i]].isActive) {
                totalWeight += equipment[_equipmentIds[i]].weight;
            }
        }
    }

    /**
     * @dev Get combined effect of equipped items for a specific stat
     */
    function getEquippedEffects(uint256[] calldata _equipmentIds, string calldata statName)
        external
        view
        returns (uint256 totalEffect)
    {
        for (uint256 i = 0; i < _equipmentIds.length; i++) {
            if (isValidEquipment(_equipmentIds[i]) && equipment[_equipmentIds[i]].isActive) {
                totalEffect += equipmentStats[_equipmentIds[i]][statName];
            }
        }
    }

    /**
     * @dev Remove an equipment type (admin only)
     */
    function removeEquipment(uint256 equipmentId)
        external
        onlyRole(ADMIN_ROLE)
        validEquipmentId(equipmentId)
        whenNotPaused
    {
        delete equipment[equipmentId];

        // Remove from equipmentIds array
        for (uint256 i = 0; i < equipmentIds.length; i++) {
            if (equipmentIds[i] == equipmentId) {
                equipmentIds[i] = equipmentIds[equipmentIds.length - 1];
                equipmentIds.pop();
                break;
            }
        }

        equipmentCount--;
    }

    /**
     * @dev Batch set equipment stats (admin only)
     */
    function batchSetEquipmentStats(
        uint256 equipmentId,
        string[] calldata statNames,
        uint256[] calldata values
    ) external onlyRole(ADMIN_ROLE) validEquipmentId(equipmentId) whenNotPaused {
        require(statNames.length == values.length, "Arrays length mismatch");

        for (uint256 i = 0; i < statNames.length; i++) {
            require(bytes(statNames[i]).length > 0, "Stat name cannot be empty");
            equipmentStats[equipmentId][statNames[i]] = values[i];
            emit EquipmentStatsUpdated(equipmentId, statNames[i], values[i]);
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