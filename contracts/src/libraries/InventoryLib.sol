// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title InventoryLib
 * @dev Library for handling 2D grid-based inventory operations
 * Supports Tetris-like item placement with various shapes
 */
library InventoryLib {
    struct GridItem {
        uint8 itemType; // 0 = empty, 1 = fish, 2 = engine, 3 = equipment
        uint16 itemId;
        bool isOccupied;
    }

    struct ItemShape {
        uint8 width;
        uint8 height;
        bytes data; // Packed bitmap representing the shape
    }

    struct InventoryGrid {
        uint8 width;
        uint8 height;
        mapping(uint256 => GridItem) grid; // position => GridItem
        uint8[] slotTypes; // Slot type for each position: 0=normal, 1=engine, 2=equipment
    }

    /**
     * @dev Convert 2D coordinates to 1D array index
     * @param x X coordinate
     * @param y Y coordinate
     * @param width Grid width
     * @return 1D index
     */
    function coordsToIndex(uint8 x, uint8 y, uint8 width) internal pure returns (uint256) {
        return uint256(y) * uint256(width) + uint256(x);
    }

    /**
     * @dev Convert 1D index to 2D coordinates
     * @param index 1D index
     * @param width Grid width
     * @return x X coordinate
     * @return y Y coordinate
     */
    function indexToCoords(uint256 index, uint8 width) internal pure returns (uint8 x, uint8 y) {
        x = uint8(index % uint256(width));
        y = uint8(index / uint256(width));
    }

    /**
     * @dev Check if coordinates are within grid bounds
     * @param x X coordinate
     * @param y Y coordinate
     * @param width Grid width
     * @param height Grid height
     * @return True if coordinates are valid
     */
    function isValidPosition(uint8 x, uint8 y, uint8 width, uint8 height) internal pure returns (bool) {
        return x < width && y < height;
    }

    /**
     * @dev Check if an item shape can fit at a given position
     * @param grid The inventory grid
     * @param shape Item shape to place
     * @param startX Starting X position
     * @param startY Starting Y position
     * @return True if the item can fit
     */
    function canPlaceItem(InventoryGrid storage grid, ItemShape memory shape, uint8 startX, uint8 startY)
        internal
        view
        returns (bool)
    {
        // Check if shape extends beyond grid boundaries
        if (startX + shape.width > grid.width || startY + shape.height > grid.height) {
            return false;
        }

        // Check each cell of the shape
        for (uint8 y = 0; y < shape.height; y++) {
            for (uint8 x = 0; x < shape.width; x++) {
                // Check if this part of the shape is occupied
                if (isShapeOccupied(shape, x, y)) {
                    uint256 gridIndex = coordsToIndex(startX + x, startY + y, grid.width);

                    // Check if grid cell is already occupied
                    if (grid.grid[gridIndex].isOccupied) {
                        return false;
                    }
                }
            }
        }

        return true;
    }

    /**
     * @dev Place an item in the inventory grid
     * @param grid The inventory grid
     * @param shape Item shape to place
     * @param startX Starting X position
     * @param startY Starting Y position
     * @param itemType Type of item (fish, engine, equipment)
     * @param itemId ID of the item
     * @return True if placement was successful
     */
    function placeItem(
        InventoryGrid storage grid,
        ItemShape memory shape,
        uint8 startX,
        uint8 startY,
        uint8 itemType,
        uint16 itemId
    ) internal returns (bool) {
        if (!canPlaceItem(grid, shape, startX, startY)) {
            return false;
        }

        // Place the item in all required cells
        for (uint8 y = 0; y < shape.height; y++) {
            for (uint8 x = 0; x < shape.width; x++) {
                if (isShapeOccupied(shape, x, y)) {
                    uint256 gridIndex = coordsToIndex(startX + x, startY + y, grid.width);

                    grid.grid[gridIndex] = GridItem({itemType: itemType, itemId: itemId, isOccupied: true});
                }
            }
        }

        return true;
    }

    /**
     * @dev Remove an item from the inventory grid
     * @param grid The inventory grid
     * @param shape Item shape to remove
     * @param startX Starting X position
     * @param startY Starting Y position
     * @return True if removal was successful
     */
    function removeItem(InventoryGrid storage grid, ItemShape memory shape, uint8 startX, uint8 startY)
        internal
        returns (bool)
    {
        // Verify the item exists at this position
        for (uint8 y = 0; y < shape.height; y++) {
            for (uint8 x = 0; x < shape.width; x++) {
                if (isShapeOccupied(shape, x, y)) {
                    uint8 gridX = startX + x;
                    uint8 gridY = startY + y;

                    if (!isValidPosition(gridX, gridY, grid.width, grid.height)) {
                        return false;
                    }

                    uint256 gridIndex = coordsToIndex(gridX, gridY, grid.width);

                    if (!grid.grid[gridIndex].isOccupied) {
                        return false;
                    }
                }
            }
        }

        // Remove the item from all cells
        for (uint8 y = 0; y < shape.height; y++) {
            for (uint8 x = 0; x < shape.width; x++) {
                if (isShapeOccupied(shape, x, y)) {
                    uint256 gridIndex = coordsToIndex(startX + x, startY + y, grid.width);

                    delete grid.grid[gridIndex];
                }
            }
        }

        return true;
    }

    /**
     * @dev Check if a specific cell in an item shape is occupied
     * @param shape Item shape
     * @param x X coordinate within the shape
     * @param y Y coordinate within the shape
     * @return True if the cell is occupied in the shape
     */
    function isShapeOccupied(ItemShape memory shape, uint8 x, uint8 y) internal pure returns (bool) {
        if (x >= shape.width || y >= shape.height) {
            return false;
        }

        uint256 bitIndex = uint256(y) * uint256(shape.width) + uint256(x);
        uint256 byteIndex = bitIndex / 8;
        uint256 bitOffset = bitIndex % 8;

        if (byteIndex >= shape.data.length) {
            return false;
        }

        uint8 byte_ = uint8(shape.data[byteIndex]);
        return (byte_ >> bitOffset) & 1 == 1;
    }

    /**
     * @dev Check if a position is designated for engines
     * @param grid The inventory grid
     * @param position Grid position (1D index)
     * @return True if position is an engine slot
     */
    function isEngineSlot(InventoryGrid storage grid, uint8 position) internal view returns (bool) {
        if (position >= grid.slotTypes.length) {
            return false;
        }
        return grid.slotTypes[position] == 1; // 1 = engine slot
    }

    /**
     * @dev Check if a position is designated for equipment
     * @param grid The inventory grid
     * @param position Grid position (1D index)
     * @return True if position is an equipment slot
     */
    function isEquipmentSlot(InventoryGrid storage grid, uint8 position) internal view returns (bool) {
        if (position >= grid.slotTypes.length) {
            return false;
        }
        return grid.slotTypes[position] == 2; // 2 = equipment slot
    }

    /**
     * @dev Get the item at a specific grid position
     * @param grid The inventory grid
     * @param x X coordinate
     * @param y Y coordinate
     * @return GridItem at the position
     */
    function getItemAt(InventoryGrid storage grid, uint8 x, uint8 y) internal view returns (GridItem memory) {
        if (!isValidPosition(x, y, grid.width, grid.height)) {
            return GridItem(0, 0, false);
        }

        uint256 index = coordsToIndex(x, y, grid.width);
        return grid.grid[index];
    }

    /**
     * @dev Get the total number of occupied slots in the grid
     * @param grid The inventory grid
     * @return Number of occupied slots
     */
    function getOccupiedSlots(InventoryGrid storage grid) internal view returns (uint256) {
        uint256 occupied = 0;
        uint256 totalSlots = uint256(grid.width) * uint256(grid.height);

        for (uint256 i = 0; i < totalSlots; i++) {
            if (grid.grid[i].isOccupied) {
                occupied++;
            }
        }

        return occupied;
    }
}
