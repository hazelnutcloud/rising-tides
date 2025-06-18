// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./managers/ResourceManager.sol";
import "./managers/PlayerManager.sol";
import "./managers/FishingManager.sol";
import "./managers/InventoryManager.sol";
import "./managers/MovementManager.sol";
import "./managers/FishMarketManager.sol";
import "../interfaces/IRisingTides.sol";
import "../utils/Errors.sol";

/**
 * @title RisingTides
 * @dev Main game state contract that inherits from all managers
 * Provides the complete IRisingTides interface while keeping functionality modular
 */
contract RisingTides is
    ResourceManager,
    PlayerManager,
    FishingManager,
    InventoryManager,
    MovementManager,
    FishMarketManager
{
    constructor(
        address _currency,
        address _shipRegistry,
        address _fishRegistry,
        address _engineRegistry,
        address _fishingRodRegistry,
        address _mapRegistry,
        address _serverSigner
    ) EIP712("RisingTides", "1") {
        if (_currency == address(0)) revert InvalidAddress(_currency);
        if (_shipRegistry == address(0)) revert InvalidAddress(_shipRegistry);
        if (_fishRegistry == address(0)) revert InvalidAddress(_fishRegistry);
        if (_engineRegistry == address(0)) revert InvalidAddress(_engineRegistry);
        if (_fishingRodRegistry == address(0)) revert InvalidAddress(_fishingRodRegistry);
        if (_mapRegistry == address(0)) revert InvalidAddress(_mapRegistry);
        if (_serverSigner == address(0)) revert InvalidAddress(_serverSigner);

        currency = RisingTidesCurrency(_currency);
        shipRegistry = IShipRegistry(_shipRegistry);
        fishRegistry = FishRegistry(_fishRegistry);
        engineRegistry = EngineRegistry(_engineRegistry);
        fishingRodRegistry = FishingRodRegistry(_fishingRodRegistry);
        mapRegistry = IMapRegistry(_mapRegistry);
        serverSigner = _serverSigner;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(SERVER_ROLE, msg.sender);
    }

    /**
     * @dev Update contract dependencies (admin only)
     */
    function updateDependencies(
        address _currency,
        address _shipRegistry,
        address _fishRegistry,
        address _engineRegistry,
        address _fishingRodRegistry,
        address _mapRegistry
    ) external onlyRole(ADMIN_ROLE) {
        if (_currency != address(0)) {
            currency = RisingTidesCurrency(_currency);
        }
        if (_shipRegistry != address(0)) {
            shipRegistry = IShipRegistry(_shipRegistry);
        }
        if (_fishRegistry != address(0)) {
            fishRegistry = FishRegistry(_fishRegistry);
        }
        if (_engineRegistry != address(0)) {
            engineRegistry = EngineRegistry(_engineRegistry);
        }
        if (_fishingRodRegistry != address(0)) {
            fishingRodRegistry = FishingRodRegistry(_fishingRodRegistry);
        }
        if (_mapRegistry != address(0)) {
            mapRegistry = IMapRegistry(_mapRegistry);
        }
    }

    /**
     * @dev Pause the contract
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
