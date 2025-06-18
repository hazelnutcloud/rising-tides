// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title InventoryTypes
 * @dev Defines enum types for inventory system to replace hardcoded numeric values
 */

/**
 * @dev Enum for different slot types in the inventory grid
 */
enum SlotType {
    Normal, // 0 - Regular cargo slot, can hold fish and other items
    Engine, // 1 - Engine slot, can only hold engines
    FishingRod, // 2 - Equipment slot, can hold fishing rods and other equipment
    Blocked // 3 - Blocked slot, cannot hold any items

}

/**
 * @dev Enum for different item types that can be placed in inventory
 */
enum ItemType {
    Empty, // 0 - No item (used when slot is not occupied)
    Fish, // 1 - Fish items
    Engine, // 2 - Engine items
    FishingRod // 3 - Equipment items (fishing rods, etc.)

}
