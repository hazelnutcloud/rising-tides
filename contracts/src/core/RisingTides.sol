// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./managers/ResourceManager.sol";
import "./managers/PlayerManager.sol";
import "./managers/FishingManager.sol";
import "./managers/MovementManager.sol";
import "./managers/FishMarketManager.sol";
import "../interfaces/IRisingTides.sol";
import "../interfaces/IRisingTidesInventory.sol";
import {SlotType, ItemType} from "../types/InventoryTypes.sol";
import "../libraries/InventoryLib.sol";
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
        address _inventoryContract,
        address _serverSigner
    ) EIP712("RisingTides", "1") {
        if (_currency == address(0)) revert InvalidAddress(_currency);
        if (_shipRegistry == address(0)) revert InvalidAddress(_shipRegistry);
        if (_fishRegistry == address(0)) revert InvalidAddress(_fishRegistry);
        if (_engineRegistry == address(0)) revert InvalidAddress(_engineRegistry);
        if (_fishingRodRegistry == address(0)) revert InvalidAddress(_fishingRodRegistry);
        if (_mapRegistry == address(0)) revert InvalidAddress(_mapRegistry);
        if (_inventoryContract == address(0)) revert InvalidAddress(_inventoryContract);
        if (_serverSigner == address(0)) revert InvalidAddress(_serverSigner);

        currency = RisingTidesCurrency(_currency);
        shipRegistry = IShipRegistry(_shipRegistry);
        fishRegistry = FishRegistry(_fishRegistry);
        engineRegistry = EngineRegistry(_engineRegistry);
        fishingRodRegistry = FishingRodRegistry(_fishingRodRegistry);
        mapRegistry = IMapRegistry(_mapRegistry);
        inventoryContract = IRisingTidesInventory(_inventoryContract);
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
        address _mapRegistry,
        address _inventoryContract
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
        if (_inventoryContract != address(0)) {
            inventoryContract = IRisingTidesInventory(_inventoryContract);
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

    /**
     * @dev Get inventory contract reference
     */
    function getInventoryContract() external view returns (IRisingTidesInventory) {
        return inventoryContract;
    }

    /**
     * @dev Inventory management functions that delegate to inventory contract
     */
    function getPlayerInventory(address player)
        external
        view
        returns (uint8 width, uint8 height, SlotType[] memory slotTypes, InventoryLib.GridItem[] memory items)
    {
        IRisingTidesInventory.InventoryData memory data = inventoryContract.getPlayerInventory(player);
        return (data.width, data.height, data.slotTypes, data.items);
    }

    function getInventoryItem(address player, uint8 x, uint8 y) external view returns (InventoryLib.GridItem memory) {
        return inventoryContract.getInventoryItem(player, x, y);
    }

    function updateInventoryItem(uint8 fromX, uint8 fromY, uint8 toX, uint8 toY, uint8 rotation) external {
        inventoryContract.updateInventoryItem(msg.sender, fromX, fromY, toX, toY, rotation);
    }

    function discardInventoryItem(uint8 x, uint8 y) external {
        inventoryContract.discardInventoryItem(msg.sender, x, y);
    }

    function hasEquippedItemType(address player, ItemType itemType) external view returns (bool) {
        return inventoryContract.hasEquippedItemType(player, itemType);
    }
}
