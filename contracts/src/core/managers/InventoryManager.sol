// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FishingManager.sol";

/**
 * @title InventoryManager
 * @dev Manages all inventory operations, item placement, movement, and validation
 */
abstract contract InventoryManager is FishingManager {
    /**
     * @dev Get player's full inventory grid
     */
    function getPlayerInventory(address player)
        external
        view
        returns (uint8 width, uint8 height, uint8[] memory slotTypes, InventoryLib.GridItem[] memory items)
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
     * @dev Move inventory item to new position
     */
    function moveInventoryItem(uint8 fromX, uint8 fromY, uint8 toX, uint8 toY, uint8 rotation)
        external
        onlyRegisteredPlayer
        whenNotPaused
    {
        InventoryLib.InventoryGrid storage inventory = playerInventories[msg.sender];

        // Get item at source position
        InventoryLib.GridItem memory item = InventoryLib.getItemAt(inventory, fromX, fromY);
        require(item.isOccupied, "No item at source position");

        // Get item shape from registry (simplified for now)
        InventoryLib.ItemShape memory shape = InventoryLib.ItemShape({width: 1, height: 1, data: hex"01"});

        // Remove from old position
        require(InventoryLib.removeItem(inventory, shape, fromX, fromY), "Failed to remove item");

        // Place at new position (simplified - rotation not supported yet)
        require(
            InventoryLib.placeItem(inventory, shape, toX, toY, item.itemType, item.itemId),
            "Failed to place item at new position"
        );
    }

    /**
     * @dev Rotate inventory item in place
     */
    function rotateInventoryItem(uint8 x, uint8 y, uint8 newRotation) external onlyRegisteredPlayer whenNotPaused {
        require(newRotation < 4, "Invalid rotation value");

        InventoryLib.InventoryGrid storage inventory = playerInventories[msg.sender];
        InventoryLib.GridItem memory item = InventoryLib.getItemAt(inventory, x, y);
        require(item.isOccupied, "No item at position");

        // Get item shape (simplified for now)
        InventoryLib.ItemShape memory shape = InventoryLib.ItemShape({width: 1, height: 1, data: hex"01"});

        // Remove and replace with new rotation
        require(InventoryLib.removeItem(inventory, shape, x, y), "Failed to remove item");
        require(
            InventoryLib.placeItemWithRotation(inventory, shape, x, y, newRotation, item.itemType, item.itemId),
            "Failed to place rotated item"
        );
    }

    /**
     * @dev Discard inventory item to free space
     */
    function discardInventoryItem(uint8 x, uint8 y) external onlyRegisteredPlayer whenNotPaused {
        InventoryLib.InventoryGrid storage inventory = playerInventories[msg.sender];
        InventoryLib.GridItem memory item = InventoryLib.getItemAt(inventory, x, y);
        require(item.isOccupied, "No item at position");

        // Get item shape (simplified for now)
        InventoryLib.ItemShape memory shape = InventoryLib.ItemShape({width: 1, height: 1, data: hex"01"});

        require(InventoryLib.removeItem(inventory, shape, x, y), "Failed to remove item");

        // Could emit event for discarded item
        // emit ItemDiscarded(msg.sender, item.itemType, item.itemId);
    }

    /**
     * @dev Get available inventory space for placement
     */
    function getAvailableInventorySpace(address player, uint8 itemWidth, uint8 itemHeight)
        external
        view
        returns (uint8[] memory validX, uint8[] memory validY)
    {
        InventoryLib.InventoryGrid storage inventory = playerInventories[player];

        // Simple shape for testing placement
        InventoryLib.ItemShape memory shape = InventoryLib.ItemShape({
            width: itemWidth,
            height: itemHeight,
            data: new bytes((itemWidth * itemHeight + 7) / 8)
        });

        // Fill shape data (all bits set)
        for (uint256 i = 0; i < shape.data.length; i++) {
            shape.data[i] = bytes1(uint8(255));
        }

        // Count valid positions
        uint256 validCount = 0;
        for (uint8 y = 0; y <= inventory.height - itemHeight; y++) {
            for (uint8 x = 0; x <= inventory.width - itemWidth; x++) {
                if (InventoryLib.canPlaceItem(inventory, shape, x, y)) {
                    validCount++;
                }
            }
        }

        // Populate arrays
        validX = new uint8[](validCount);
        validY = new uint8[](validCount);
        uint256 index = 0;

        for (uint8 y = 0; y <= inventory.height - itemHeight; y++) {
            for (uint8 x = 0; x <= inventory.width - itemWidth; x++) {
                if (InventoryLib.canPlaceItem(inventory, shape, x, y)) {
                    validX[index] = x;
                    validY[index] = y;
                    index++;
                }
            }
        }
    }

    /**
     * @dev Validate engine placement in engine slots
     */
    function validateEngineEquipment(address player, uint256 engineId, uint8 x, uint8 y) external view returns (bool) {
        require(engineRegistry.isValidEngine(engineId), "Invalid engine ID");

        IShipRegistry.Ship memory ship = shipRegistry.getShip(playerStates[player].shipId);

        // Check if position is within bounds
        if (x >= ship.cargoWidth || y >= ship.cargoHeight) {
            return false;
        }

        // Convert 2D coordinates to 1D index
        uint256 index = uint256(y) * uint256(ship.cargoWidth) + uint256(x);

        // Check if position is an engine slot
        if (index >= ship.slotTypes.length || ship.slotTypes[index] != 1) {
            return false;
        }

        return true;
    }

    /**
     * @dev Validate fishing rod placement in equipment slots
     */
    function validateFishingRodPlacement(address player, uint256 fishingRodId, uint8 x, uint8 y)
        external
        view
        returns (bool)
    {
        require(fishingRodRegistry.isValidFishingRod(fishingRodId), "Invalid fishing rod ID");

        IShipRegistry.Ship memory ship = shipRegistry.getShip(playerStates[player].shipId);

        // Check if position is within bounds
        if (x >= ship.cargoWidth || y >= ship.cargoHeight) {
            return false;
        }

        // Convert 2D coordinates to 1D index
        uint256 index = uint256(y) * uint256(ship.cargoWidth) + uint256(x);

        // Check if position is an equipment slot
        if (index >= ship.slotTypes.length || ship.slotTypes[index] != 2) {
            return false;
        }

        return true;
    }


    /**
     * @dev Check if a player has a fishing rod equipped (public interface)
     */
    function isPlayerFishingRodEquipped(address player) external view returns (bool) {
        return hasEquippedFishingRod(player);
    }

    /**
     * @dev Check if a player has any equipment of a specific type equipped
     */
    function hasEquippedItemType(address player, uint8 itemType) external view returns (bool) {
        InventoryLib.InventoryGrid storage inventory = playerInventories[player];
        IShipRegistry.Ship memory ship = shipRegistry.getShip(playerStates[player].shipId);
        
        uint8 requiredSlotType = itemType == 2 ? 1 : 2; // Engine items need slot type 1, others need slot type 2
        
        // Check all appropriate slots for the item type
        for (uint256 i = 0; i < ship.slotTypes.length; i++) {
            if (ship.slotTypes[i] == requiredSlotType) {
                InventoryLib.GridItem memory item = inventory.grid[i];
                if (item.isOccupied && item.itemType == itemType) {
                    // Additional validation for engines and fishing rods
                    if (itemType == 2 && engineRegistry.isValidEngine(item.itemId)) {
                        return true;
                    } else if (itemType == 3 && fishingRodRegistry.isValidFishingRod(item.itemId)) {
                        return true;
                    } else if (itemType != 2 && itemType != 3) {
                        return true; // For other item types, just check presence
                    }
                }
            }
        }
        return false;
    }

    /**
     * @dev Get all equipped fishing rods for a player
     */
    function getEquippedFishingRods(address player) external view returns (uint256[] memory fishingRodIds) {
        InventoryLib.InventoryGrid storage inventory = playerInventories[player];
        IShipRegistry.Ship memory ship = shipRegistry.getShip(playerStates[player].shipId);
        
        // Count equipped fishing rods first
        uint256 equippedCount = 0;
        for (uint256 i = 0; i < ship.slotTypes.length; i++) {
            if (ship.slotTypes[i] == 2) { // Equipment slot
                InventoryLib.GridItem memory item = inventory.grid[i];
                if (item.isOccupied && item.itemType == 3) { // Equipment type
                    if (fishingRodRegistry.isValidFishingRod(item.itemId)) {
                        equippedCount++;
                    }
                }
            }
        }
        
        // Populate the array
        fishingRodIds = new uint256[](equippedCount);
        uint256 index = 0;
        for (uint256 i = 0; i < ship.slotTypes.length && index < equippedCount; i++) {
            if (ship.slotTypes[i] == 2) { // Equipment slot
                InventoryLib.GridItem memory item = inventory.grid[i];
                if (item.isOccupied && item.itemType == 3) { // Equipment type
                    if (fishingRodRegistry.isValidFishingRod(item.itemId)) {
                        fishingRodIds[index] = item.itemId;
                        index++;
                    }
                }
            }
        }
    }

    /**
     * @dev Get engine and equipment registries (for external access)
     */
    function getEngineRegistry() external view returns (address) {
        return address(engineRegistry);
    }

    function getFishingRodRegistry() external view returns (address) {
        return address(fishingRodRegistry);
    }

    /**
     * @dev Process array of inventory actions
     */
    function _processInventoryActions(address player, InventoryAction[] memory actions) internal override {
        InventoryLib.InventoryGrid storage inventory = playerInventories[player];

        for (uint256 i = 0; i < actions.length; i++) {
            InventoryAction memory action = actions[i];

            if (action.actionType == 0) {
                // Place item - simplified implementation
                InventoryLib.ItemShape memory shape = InventoryLib.ItemShape({width: 1, height: 1, data: hex"01"});

                require(
                    InventoryLib.placeItemWithRotation(
                        inventory, shape, action.toX, action.toY, action.rotation, 1, action.itemId
                    ),
                    "Failed to place item"
                );
            } else if (action.actionType == 1) {
                // Move item
                InventoryLib.GridItem memory item = InventoryLib.getItemAt(inventory, action.fromX, action.fromY);
                require(item.isOccupied, "No item to move");

                InventoryLib.ItemShape memory shape = InventoryLib.ItemShape({width: 1, height: 1, data: hex"01"});

                require(InventoryLib.removeItem(inventory, shape, action.fromX, action.fromY), "Failed to remove item");
                require(
                    InventoryLib.placeItemWithRotation(
                        inventory, shape, action.toX, action.toY, action.rotation, item.itemType, item.itemId
                    ),
                    "Failed to place moved item"
                );
            } else if (action.actionType == 2) {
                // Discard item
                InventoryLib.GridItem memory item = InventoryLib.getItemAt(inventory, action.fromX, action.fromY);
                require(item.isOccupied, "No item to discard");

                InventoryLib.ItemShape memory shape = InventoryLib.ItemShape({width: 1, height: 1, data: hex"01"});

                require(InventoryLib.removeItem(inventory, shape, action.fromX, action.fromY), "Failed to discard item");
            } else if (action.actionType == 3) {
                // Rotate item in place
                InventoryLib.GridItem memory item = InventoryLib.getItemAt(inventory, action.fromX, action.fromY);
                require(item.isOccupied, "No item to rotate");

                InventoryLib.ItemShape memory shape = InventoryLib.ItemShape({width: 1, height: 1, data: hex"01"});

                require(InventoryLib.removeItem(inventory, shape, action.fromX, action.fromY), "Failed to remove item");
                require(
                    InventoryLib.placeItemWithRotation(
                        inventory, shape, action.fromX, action.fromY, action.rotation, item.itemType, item.itemId
                    ),
                    "Failed to place rotated item"
                );
            }
        }
    }
}
