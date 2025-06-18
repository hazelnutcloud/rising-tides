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
        uint256 enginePowerPerCell,
        uint256 fuelConsumptionRatePerCell,
        uint8 shapeWidth,
        uint8 shapeHeight,
        bytes calldata shapeData,
        uint256 purchasePrice,
        uint256 weight
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        require(id > 0, "Engine ID must be greater than 0");
        require(!isValidEngine(id), "Engine ID already exists");
        require(bytes(name).length > 0, "Engine name cannot be empty");
        require(enginePowerPerCell > 0, "Engine power per cell must be greater than 0");
        require(fuelConsumptionRatePerCell > 0, "Fuel consumption rate per cell must be greater than 0");
        require(shapeWidth > 0 && shapeHeight > 0, "Shape dimensions must be greater than 0");
        require(weight > 0, "Engine weight must be greater than 0");

        // Validate shape data size
        uint256 expectedShapeSize = (uint256(shapeWidth) * uint256(shapeHeight) + 7) / 8;
        require(shapeData.length >= expectedShapeSize, "Shape data too small");

        engines[id] = Engine({
            id: id,
            name: name,
            enginePowerPerCell: enginePowerPerCell,
            fuelConsumptionRatePerCell: fuelConsumptionRatePerCell,
            shapeWidth: shapeWidth,
            shapeHeight: shapeHeight,
            shapeData: shapeData,
            purchasePrice: purchasePrice,
            weight: weight,
            isActive: true
        });

        engineIds.push(id);
        engineCount++;

        emit EngineRegistered(id, name, enginePowerPerCell, purchasePrice);
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
            enginePowerPerCell: engine.enginePowerPerCell,
            fuelConsumptionRatePerCell: engine.fuelConsumptionRatePerCell,
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
        uint256 enginePowerPerCell,
        uint256 fuelConsumptionRatePerCell,
        uint256 weight,
        uint256 purchasePrice
    ) external onlyRole(ADMIN_ROLE) validEngineId(engineId) whenNotPaused {
        require(enginePowerPerCell > 0, "Engine power per cell must be greater than 0");
        require(fuelConsumptionRatePerCell > 0, "Fuel consumption rate per cell must be greater than 0");
        require(weight > 0, "Engine weight must be greater than 0");

        Engine storage engine = engines[engineId];
        engine.enginePowerPerCell = enginePowerPerCell;
        engine.fuelConsumptionRatePerCell = fuelConsumptionRatePerCell;
        engine.weight = weight;
        engine.purchasePrice = purchasePrice;

        emit EngineStatsUpdated(
            engineId,
            EngineStats({
                enginePowerPerCell: enginePowerPerCell,
                fuelConsumptionRatePerCell: fuelConsumptionRatePerCell,
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
