// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/IEngineRegistry.sol";

/**
 * @title EngineRegistry
 * @dev Registry contract for managing engine types and their properties
 * Engines are inventory items that provide engine power for ship movement
 */
contract EngineRegistry is IEngineRegistry, AccessControl, Pausable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    mapping(uint256 => Engine) private engines;
    uint256 private engineCount;
    uint256[] private engineIds;

    modifier validEngineId(uint256 engineId) {
        require(isValidEngine(engineId), "Invalid engine ID");
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @dev Register a new engine type
     */
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
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        require(id > 0, "Engine ID must be greater than 0");
        require(!isValidEngine(id), "Engine ID already exists");
        require(bytes(name).length > 0, "Engine name cannot be empty");
        require(enginePower > 0, "Engine power must be greater than 0");
        require(fuelEfficiency > 0, "Fuel efficiency must be greater than 0");
        require(shapeWidth > 0 && shapeHeight > 0, "Shape dimensions must be greater than 0");
        require(weight > 0, "Engine weight must be greater than 0");

        // Validate shape data size
        uint256 expectedShapeSize = (uint256(shapeWidth) * uint256(shapeHeight) + 7) / 8;
        require(shapeData.length >= expectedShapeSize, "Shape data too small");

        engines[id] = Engine({
            id: id,
            name: name,
            enginePower: enginePower,
            fuelEfficiency: fuelEfficiency,
            shapeWidth: shapeWidth,
            shapeHeight: shapeHeight,
            shapeData: shapeData,
            purchasePrice: purchasePrice,
            weight: weight,
            isActive: true
        });

        engineIds.push(id);
        engineCount++;

        emit EngineRegistered(id, name, enginePower, purchasePrice);
    }

    /**
     * @dev Get complete engine data
     */
    function getEngine(uint256 engineId) external view validEngineId(engineId) returns (Engine memory) {
        return engines[engineId];
    }

    /**
     * @dev Get engine performance stats
     */
    function getEngineStats(uint256 engineId) external view validEngineId(engineId) returns (EngineStats memory) {
        Engine memory engine = engines[engineId];
        return EngineStats({
            enginePower: engine.enginePower,
            fuelEfficiency: engine.fuelEfficiency,
            weight: engine.weight
        });
    }

    /**
     * @dev Check if an engine ID is valid
     */
    function isValidEngine(uint256 engineId) public view returns (bool) {
        return engines[engineId].id == engineId && engines[engineId].id > 0;
    }

    /**
     * @dev Get total number of registered engines
     */
    function getEngineCount() external view returns (uint256) {
        return engineCount;
    }

    /**
     * @dev Get all registered engines
     */
    function getAllEngines() external view returns (Engine[] memory) {
        Engine[] memory allEngines = new Engine[](engineCount);

        for (uint256 i = 0; i < engineIds.length; i++) {
            allEngines[i] = engines[engineIds[i]];
        }

        return allEngines;
    }

    /**
     * @dev Update engine stats (admin only)
     */
    function updateEngineStats(
        uint256 engineId,
        uint256 enginePower,
        uint256 fuelEfficiency,
        uint256 weight,
        uint256 purchasePrice
    ) external onlyRole(ADMIN_ROLE) validEngineId(engineId) whenNotPaused {
        require(enginePower > 0, "Engine power must be greater than 0");
        require(fuelEfficiency > 0, "Fuel efficiency must be greater than 0");
        require(weight > 0, "Engine weight must be greater than 0");

        Engine storage engine = engines[engineId];
        engine.enginePower = enginePower;
        engine.fuelEfficiency = fuelEfficiency;
        engine.weight = weight;
        engine.purchasePrice = purchasePrice;

        emit EngineStatsUpdated(
            engineId,
            EngineStats({
                enginePower: enginePower,
                fuelEfficiency: fuelEfficiency,
                weight: weight
            })
        );
    }

    /**
     * @dev Set engine active status (admin only)
     */
    function setEngineStatus(uint256 engineId, bool isActive) 
        external 
        onlyRole(ADMIN_ROLE) 
        validEngineId(engineId) 
        whenNotPaused 
    {
        engines[engineId].isActive = isActive;
        emit EngineStatusUpdated(engineId, isActive);
    }

    /**
     * @dev Calculate combined power of multiple engines
     */
    function calculateCombinedPower(uint256[] calldata _engineIds) external view returns (uint256 totalPower) {
        for (uint256 i = 0; i < _engineIds.length; i++) {
            if (isValidEngine(_engineIds[i]) && engines[_engineIds[i]].isActive) {
                totalPower += engines[_engineIds[i]].enginePower;
            }
        }
    }

    /**
     * @dev Calculate combined fuel efficiency of multiple engines (weighted average)
     */
    function calculateCombinedEfficiency(uint256[] calldata _engineIds) external view returns (uint256 avgEfficiency) {
        uint256 totalPower = 0;
        uint256 weightedEfficiency = 0;

        for (uint256 i = 0; i < _engineIds.length; i++) {
            if (isValidEngine(_engineIds[i]) && engines[_engineIds[i]].isActive) {
                uint256 power = engines[_engineIds[i]].enginePower;
                uint256 efficiency = engines[_engineIds[i]].fuelEfficiency;
                
                totalPower += power;
                weightedEfficiency += power * efficiency;
            }
        }

        if (totalPower == 0) {
            return 100; // Default efficiency
        }

        return weightedEfficiency / totalPower;
    }

    /**
     * @dev Calculate combined weight of multiple engines
     */
    function calculateCombinedWeight(uint256[] calldata _engineIds) external view returns (uint256 totalWeight) {
        for (uint256 i = 0; i < _engineIds.length; i++) {
            if (isValidEngine(_engineIds[i]) && engines[_engineIds[i]].isActive) {
                totalWeight += engines[_engineIds[i]].weight;
            }
        }
    }

    /**
     * @dev Remove an engine type (admin only)
     */
    function removeEngine(uint256 engineId) external onlyRole(ADMIN_ROLE) validEngineId(engineId) whenNotPaused {
        delete engines[engineId];

        // Remove from engineIds array
        for (uint256 i = 0; i < engineIds.length; i++) {
            if (engineIds[i] == engineId) {
                engineIds[i] = engineIds[engineIds.length - 1];
                engineIds.pop();
                break;
            }
        }

        engineCount--;
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