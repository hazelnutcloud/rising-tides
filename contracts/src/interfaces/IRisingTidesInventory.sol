// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SlotType, ItemType} from "../types/InventoryTypes.sol";
import "../libraries/InventoryLib.sol";
import "./IRisingTides.sol";

/**
 * @title IRisingTidesInventory
 * @dev Interface for the RisingTidesInventory contract
 * Defines all inventory management functions and events
 */
interface IRisingTidesInventory {
    // Events
    event InventoryInitialized(address indexed player, uint256 indexed shipId, uint8 width, uint8 height);
    event ItemPlaced(address indexed player, ItemType itemType, uint256 itemId, uint256 instanceId, uint8 x, uint8 y, uint8 rotation);
    event ItemMoved(address indexed player, uint256 instanceId, uint8 fromX, uint8 fromY, uint8 toX, uint8 toY, uint8 rotation);
    event ItemDiscarded(address indexed player, ItemType itemType, uint256 itemId, uint256 instanceId);
    event FishStored(address indexed player, uint256 species, uint256 instanceId, uint16 weight, uint8 x, uint8 y);
    
    // Structs for return data
    struct InventoryData {
        uint8 width;
        uint8 height;
        SlotType[] slotTypes;
        InventoryLib.GridItem[] items;
    }

    // Core inventory functions
    function initializeInventory(address player, uint256 shipId, uint8 width, uint8 height, SlotType[] calldata slotTypes) external;
    function assignDefaultEquipment(address player, uint256 engineId, uint256 fishingRodId) external;
    
    // Item management
    function getPlayerInventory(address player) external view returns (InventoryData memory);
    function getInventoryItem(address player, uint8 x, uint8 y) external view returns (InventoryLib.GridItem memory);
    function updateInventoryItem(address player, uint8 fromX, uint8 fromY, uint8 toX, uint8 toY, uint8 rotation) external;
    function discardInventoryItem(address player, uint8 x, uint8 y) external;
    
    // Fish management
    function placeFishInInventory(address player, uint256 species, uint16 weight, uint8 x, uint8 y, uint8 rotation) external returns (uint256 instanceId);
    function removeFishFromInventory(address player, uint256 instanceId) external returns (IRisingTides.FishCatch memory);
    function getFishData(address player, uint256 instanceId) external view returns (IRisingTides.FishCatch memory);
    
    // Equipment queries
    function hasEquippedItemType(address player, ItemType itemType) external view returns (bool);
    function getTotalEnginePower(address player, uint256 shipId) external view returns (uint256);
    function hasEquippedFishingRod(address player) external view returns (bool);
    
    // Admin functions
    function setGameContract(address gameContract) external;
    function updateRegistries(
        address fishRegistry,
        address engineRegistry, 
        address fishingRodRegistry,
        address shipRegistry
    ) external;
}