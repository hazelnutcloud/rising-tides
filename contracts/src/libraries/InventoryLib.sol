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
        uint256 itemId;
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
        uint256 itemId
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

    /**
     * @dev Rotate an item shape by 90-degree increments
     * @param shape Original item shape
     * @param rotation Rotation value (0=up, 1=right, 2=down, 3=left)
     * @return Rotated item shape
     */
    function rotateItemShape(ItemShape memory shape, uint8 rotation) internal pure returns (ItemShape memory) {
        require(rotation < 4, "Invalid rotation value");

        if (rotation == 0) {
            return shape; // No rotation needed
        }

        ItemShape memory rotated;

        if (rotation == 1 || rotation == 3) {
            // 90° or 270° rotation - swap width and height
            rotated.width = shape.height;
            rotated.height = shape.width;
        } else {
            // 180° rotation - keep same dimensions
            rotated.width = shape.width;
            rotated.height = shape.height;
        }

        // Calculate rotated bitmap data
        rotated.data = _rotateShapeData(shape, rotation);

        return rotated;
    }

    /**
     * @dev Check if an item shape can fit at a given position with rotation
     * @param grid The inventory grid
     * @param shape Item shape to place
     * @param startX Starting X position
     * @param startY Starting Y position
     * @param rotation Rotation value (0=up, 1=right, 2=down, 3=left)
     * @return True if the item can fit
     */
    function canPlaceItemWithRotation(
        InventoryGrid storage grid,
        ItemShape memory shape,
        uint8 startX,
        uint8 startY,
        uint8 rotation
    ) internal view returns (bool) {
        ItemShape memory rotatedShape = rotateItemShape(shape, rotation);
        return canPlaceItem(grid, rotatedShape, startX, startY);
    }

    /**
     * @dev Place an item in the inventory grid with rotation
     * @param grid The inventory grid
     * @param shape Item shape to place
     * @param startX Starting X position
     * @param startY Starting Y position
     * @param rotation Rotation value (0=up, 1=right, 2=down, 3=left)
     * @param itemType Type of item (fish, engine, equipment)
     * @param itemId ID of the item
     * @return True if placement was successful
     */
    function placeItemWithRotation(
        InventoryGrid storage grid,
        ItemShape memory shape,
        uint8 startX,
        uint8 startY,
        uint8 rotation,
        uint8 itemType,
        uint256 itemId
    ) internal returns (bool) {
        ItemShape memory rotatedShape = rotateItemShape(shape, rotation);
        return placeItem(grid, rotatedShape, startX, startY, itemType, itemId);
    }

    /**
     * @dev Get rotated dimensions for an item shape
     * @param shape Original item shape
     * @param rotation Rotation value (0=up, 1=right, 2=down, 3=left)
     * @return width Rotated width
     * @return height Rotated height
     */
    function getRotatedDimensions(ItemShape memory shape, uint8 rotation)
        internal
        pure
        returns (uint8 width, uint8 height)
    {
        require(rotation < 4, "Invalid rotation value");

        if (rotation == 1 || rotation == 3) {
            // 90° or 270° rotation - swap dimensions
            return (shape.height, shape.width);
        } else {
            // 0° or 180° rotation - keep same dimensions
            return (shape.width, shape.height);
        }
    }

    /**
     * @dev Remove an item from the inventory grid with rotation
     * @param grid The inventory grid
     * @param shape Item shape to remove
     * @param startX Starting X position
     * @param startY Starting Y position
     * @param rotation Rotation value that was used when placing
     * @return True if removal was successful
     */
    function removeItemWithRotation(
        InventoryGrid storage grid,
        ItemShape memory shape,
        uint8 startX,
        uint8 startY,
        uint8 rotation
    ) internal returns (bool) {
        ItemShape memory rotatedShape = rotateItemShape(shape, rotation);
        return removeItem(grid, rotatedShape, startX, startY);
    }

    /**
     * @dev Rotate shape data bitmap by 90-degree increments
     * @param shape Original item shape
     * @param rotation Rotation value (0=up, 1=right, 2=down, 3=left)
     * @return Rotated bitmap data
     */
    function _rotateShapeData(ItemShape memory shape, uint8 rotation) private pure returns (bytes memory) {
        if (rotation == 0) {
            return shape.data;
        }

        uint8 newWidth;
        uint8 newHeight;

        if (rotation == 1 || rotation == 3) {
            newWidth = shape.height;
            newHeight = shape.width;
        } else {
            newWidth = shape.width;
            newHeight = shape.height;
        }

        uint256 totalBits = uint256(newWidth) * uint256(newHeight);
        uint256 totalBytes = (totalBits + 7) / 8; // Round up to nearest byte
        bytes memory rotatedData = new bytes(totalBytes);

        // Rotate each bit position
        for (uint8 y = 0; y < shape.height; y++) {
            for (uint8 x = 0; x < shape.width; x++) {
                if (isShapeOccupied(shape, x, y)) {
                    uint8 newX;
                    uint8 newY;

                    if (rotation == 1) {
                        // 90° clockwise: (x,y) -> (height-1-y, x)
                        newX = shape.height - 1 - y;
                        newY = x;
                    } else if (rotation == 2) {
                        // 180°: (x,y) -> (width-1-x, height-1-y)
                        newX = shape.width - 1 - x;
                        newY = shape.height - 1 - y;
                    } else if (rotation == 3) {
                        // 270° clockwise: (x,y) -> (y, width-1-x)
                        newX = y;
                        newY = shape.width - 1 - x;
                    }

                    // Set bit in rotated data
                    uint256 bitIndex = uint256(newY) * uint256(newWidth) + uint256(newX);
                    uint256 byteIndex = bitIndex / 8;
                    uint256 bitOffset = bitIndex % 8;

                    if (byteIndex < rotatedData.length) {
                        rotatedData[byteIndex] |= bytes1(uint8(uint256(1) << bitOffset));
                    }
                }
            }
        }

        return rotatedData;
    }
}
