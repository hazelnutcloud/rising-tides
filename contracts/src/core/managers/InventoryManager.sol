// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SlotType, ItemType} from "../../types/InventoryTypes.sol";
import "../GameStateBase.sol";

/**
 * @title InventoryManager
 * @dev Manages all inventory operations, item placement, movement, and validation
 */
abstract contract InventoryManager is GameStateBase {
    using InventoryLib for InventoryLib.InventoryGrid;

    /**
     * @dev Get player's full inventory grid
     */
    function getPlayerInventory(address player)
        external
        view
        returns (uint8 width, uint8 height, SlotType[] memory slotTypes, InventoryLib.GridItem[] memory items)
    {
        InventoryLib.InventoryGrid storage inventory = playerInventories[player];
        width = inventory.width;
        height = inventory.height;
        slotTypes = inventory.slotTypes;

        uint256 totalSlots = uint256(width) * uint256(height);
        items = new InventoryLib.GridItem[](totalSlots);

        for (uint256 i = 0; i < totalSlots; i++) {
            items[i] = inventory.grid[i];
        }
    }

    /**
     * @dev Get inventory item at specific coordinates
     */
    function getInventoryItem(address player, uint8 x, uint8 y) external view returns (InventoryLib.GridItem memory) {
        return InventoryLib.getItemAt(playerInventories[player], x, y);
    }

    /**
     * @dev Update inventory item position and/or rotation
     * @param fromX Source X position
     * @param fromY Source Y position
     * @param toX Target X position (use fromX if only rotating)
     * @param toY Target Y position (use fromY if only rotating)
     * @param rotation New rotation (0=up, 1=right, 2=down, 3=left)
     */
    function updateInventoryItem(uint8 fromX, uint8 fromY, uint8 toX, uint8 toY, uint8 rotation)
        external
        onlyRegisteredPlayer
        whenNotPaused
    {
        require(rotation < 4, "Invalid rotation value");

        InventoryLib.InventoryGrid storage inventory = playerInventories[msg.sender];

        // Get item at source position
        InventoryLib.GridItem memory item = InventoryLib.getItemAt(inventory, fromX, fromY);
        require(item.itemType != ItemType.Empty, "No item at source position");

        // Get item shape from registry
        InventoryLib.ItemShape memory shape = _getItemShape(item.itemType, item.itemId);

        // Remove from old position
        require(InventoryLib.removeItem(inventory, shape, fromX, fromY, item.rotation, item.instanceId), "Failed to remove item");

        // Place at new position with rotation if specified
            require(
                inventory.placeItem(shape, toX, toY, rotation, item.itemType, item.itemId, item.instanceId),
                "Failed to place item at new position"
            );
    }

    /**
     * @dev Discard inventory item to free space
     */
    function discardInventoryItem(uint8 x, uint8 y) external onlyRegisteredPlayer whenNotPaused {
        InventoryLib.InventoryGrid storage inventory = playerInventories[msg.sender];
        InventoryLib.GridItem memory item = InventoryLib.getItemAt(inventory, x, y);
        require(item.itemType != ItemType.Empty, "No item at position");

        // Get item shape from registry
        InventoryLib.ItemShape memory shape = _getItemShape(item.itemType, item.itemId);

        require(inventory.removeItem(shape, x, y, item.rotation, item.instanceId), "Failed to remove item");

        // Could emit event for discarded item
        // emit ItemDiscarded(msg.sender, item.itemType, item.itemId);
    }

    /**
     * @dev Place fish in player's inventory at specified coordinates
     */
    function _placeFishInInventory(address player, uint256 species, uint8 x, uint8 y, uint8 rotation)
        internal
        override
        returns (bool)
    {
        InventoryLib.InventoryGrid storage inventory = playerInventories[player];

        // Get fish shape from registry
        InventoryLib.ItemShape memory fishShape = _getItemShape(ItemType.Fish, species);

        // Place the fish in inventory
        return inventory.placeItem(fishShape, x, y, rotation, ItemType.Fish, species, 0);
    }

    /**
     * @dev Get proper item shape from registry based on item type and ID
     */
    function _getItemShape(ItemType itemType, uint256 itemId) internal view returns (InventoryLib.ItemShape memory) {
        if (itemType == ItemType.Fish) {
            // Fish item - get shape from fish registry
            require(fishRegistry.isValidSpecies(itemId), "Invalid fish species");
            FishRegistry.FishSpecies memory species = fishRegistry.getFishSpecies(itemId);
            return InventoryLib.ItemShape({
                width: species.shapeWidth,
                height: species.shapeHeight,
                data: species.shapeData
            });
        } else if (itemType == ItemType.Engine) {
            // Engine item - get shape from engine registry
            require(engineRegistry.isValidEngine(itemId), "Invalid engine ID");
            IEngineRegistry.Engine memory engine = engineRegistry.getEngine(itemId);
            return
                InventoryLib.ItemShape({width: engine.shapeWidth, height: engine.shapeHeight, data: engine.shapeData});
        } else if (itemType == ItemType.FishingRod) {
            // Equipment item (fishing rod) - get shape from fishing rod registry
            require(fishingRodRegistry.isValidFishingRod(itemId), "Invalid fishing rod ID");
            IFishingRodRegistry.FishingRod memory rod = fishingRodRegistry.getFishingRod(itemId);
            return InventoryLib.ItemShape({width: rod.shapeWidth, height: rod.shapeHeight, data: rod.shapeData});
        } else {
            revert("Invalid item type");
        }
    }

        /**
     * @dev Check if a player has any equipment of a specific type equipped
     */
    function hasEquippedItemType(address player, ItemType itemType) external view returns (bool) {
        InventoryLib.InventoryGrid storage inventory = playerInventories[player];
        IShipRegistry.Ship memory ship = shipRegistry.getShip(playerStates[player].shipId);

        SlotType requiredSlotType = itemType == ItemType.Engine ? SlotType.Engine : SlotType.FishingRod;

        uint256 shipArea = ship.cargoHeight * ship.cargoHeight;

        // Check all appropriate slots for the item type
        for (uint256 i = 0; i < shipArea; i++) {
            if (ship.slotTypes[i] == requiredSlotType) {
                InventoryLib.GridItem memory item = inventory.grid[i];
                if (item.itemType == itemType) {
                    // Additional validation for engines and fishing rods
                    if (itemType == ItemType.Engine && engineRegistry.isValidEngine(item.itemId)) {
                        return true;
                    } else if (itemType == ItemType.FishingRod && fishingRodRegistry.isValidFishingRod(item.itemId)) {
                        return true;
                    } else if (itemType != ItemType.Engine && itemType != ItemType.FishingRod) {
                        return true; // For other item types, just check presence
                    }
                }
            }
        }
        return false;
    }
}
