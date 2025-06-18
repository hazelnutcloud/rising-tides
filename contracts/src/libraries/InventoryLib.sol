// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SlotType, ItemType} from "../types/InventoryTypes.sol";

/**
 * @title InventoryLib
 * @dev Library for handling 2D grid-based inventory operations
 * Supports Tetris-like item placement with various shapes
 */
library InventoryLib {
    struct GridItem {
        ItemType itemType;
        uint256 itemId;
        uint256 instanceId;
        uint8 rotation;
    }

    struct ItemShape {
        uint8 width;
        uint8 height;
        bytes data; // Packed bitmap representing the shape
    }

    struct InventoryGrid {
        uint256 nextInstanceId; // Counter for generating unique instance IDs
        uint8 width;
        uint8 height;
        mapping(uint256 => GridItem) grid; // position => GridItem
        SlotType[] slotTypes; // Slot type for each position
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
     * @dev Place an item with rotation and specific instance ID (used for rotating items in place)
     * @param grid The inventory grid
     * @param shape Item shape to place
     * @param startX Starting X position
     * @param startY Starting Y position
     * @param rotation Rotation value (0=up, 1=right, 2=down, 3=left)
     * @param itemType Type of item
     * @param itemId ID of the item
     * @param instanceId Specific instance ID to use
     * @return True if placement was successful
     */
    function placeItem(
        InventoryGrid storage grid,
        ItemShape memory shape,
        uint8 startX,
        uint8 startY,
        uint8 rotation,
        ItemType itemType,
        uint256 itemId,
        uint256 instanceId
    ) internal returns (uint256) {
        ItemShape memory rotatedShape = rotateItemShape(shape, rotation);

        uint256 newInstanceId = instanceId;
        if (instanceId == 0) {
            grid.nextInstanceId++;
            newInstanceId = grid.nextInstanceId;
        }

        uint256 gridArea = grid.width * grid.height;

        // Place the item in all required cells with the specified instance ID and rotation
        for (uint8 y = 0; y < rotatedShape.height; y++) {
            for (uint8 x = 0; x < rotatedShape.width; x++) {
                if (isShapeOccupied(rotatedShape, x, y)) {
                    uint256 gridIndex = coordsToIndex(startX + x, startY + y, grid.width);

                    if (gridIndex >= gridArea) {
                        return 0;
                    }

                    GridItem storage gridItem = grid.grid[gridIndex];

                    if (gridItem.itemType != ItemType.Empty || grid.slotTypes[gridIndex] == SlotType.Blocked) {
                        return 0;
                    }

                    grid.grid[gridIndex] =
                        GridItem({itemType: itemType, itemId: itemId, instanceId: newInstanceId, rotation: rotation});
                }
            }
        }

        return newInstanceId;
    }

    /**
     * @dev Remove an item from the inventory grid
     * @param grid The inventory grid
     * @param shape Item shape to remove (unrotated)
     * @param startX Starting X position
     * @param startY Starting Y position
     * @param instanceId The instance ID of the item to remove
     * @return True if removal was successful
     */
    function removeItem(
        InventoryGrid storage grid,
        ItemShape memory shape,
        uint8 startX,
        uint8 startY,
        uint8 rotation,
        uint256 instanceId
    ) internal returns (bool) {
        ItemShape memory rotatedShape = rotateItemShape(shape, rotation);

        for (uint8 y = 0; y < rotatedShape.height; y++) {
            for (uint8 x = 0; x < rotatedShape.width; x++) {
                if (isShapeOccupied(rotatedShape, x, y)) {
                    uint8 gridX = startX + x;
                    uint8 gridY = startY + y;

                    uint256 gridIndex = coordsToIndex(gridX, gridY, grid.width);

                    if (grid.grid[gridIndex].itemType == ItemType.Empty) {
                        return false;
                    }

                    if (grid.grid[gridIndex].instanceId != instanceId) {
                        return false;
                    }
                }
            }
        }

        // Remove the item from all cells
        for (uint8 y = 0; y < rotatedShape.height; y++) {
            for (uint8 x = 0; x < rotatedShape.width; x++) {
                if (isShapeOccupied(rotatedShape, x, y)) {
                    uint256 gridIndex = coordsToIndex(startX + x, startY + y, grid.width);

                    delete grid.grid[gridIndex];
                }
            }
        }

        return true;
    }

    /**
     * @dev Check if a position is designated for engines
     * @param grid The inventory grid
     * @param position Grid position (1D index)
     * @return True if position is an engine slot
     */
    function isEngineSlot(InventoryGrid storage grid, uint8 position) internal view returns (bool) {
        return grid.slotTypes[position] == SlotType.Engine;
    }

    /**
     * @dev Check if a position is designated for equipment
     * @param grid The inventory grid
     * @param position Grid position (1D index)
     * @return True if position is an equipment slot
     */
    function isEquipmentSlot(InventoryGrid storage grid, uint8 position) internal view returns (bool) {
        return grid.slotTypes[position] == SlotType.FishingRod;
    }

    /**
     * @dev Check if a position is blocked (no items can be placed)
     * @param grid The inventory grid
     * @param position Grid position (1D index)
     * @return True if position is a blocked slot
     */
    function isBlockedSlot(InventoryGrid storage grid, uint8 position) internal view returns (bool) {
        return grid.slotTypes[position] == SlotType.Blocked;
    }

    /**
     * @dev Get the item at a specific grid position
     * @param grid The inventory grid
     * @param x X coordinate
     * @param y Y coordinate
     * @return GridItem at the position
     */
    function getItemAt(InventoryGrid storage grid, uint8 x, uint8 y) internal view returns (GridItem memory) {
        uint256 index = coordsToIndex(x, y, grid.width);
        return grid.grid[index];
    }

    function getItemByInstanceId(InventoryGrid storage grid, uint256 instanceId)
        internal
        view
        returns (GridItem memory, uint8 x, uint8 y)
    {
        uint256 gridArea = grid.width * grid.height;

        for (uint256 i = 0; i < gridArea; i++) {
            if (grid.grid[i].instanceId == instanceId) {
                (uint8 _x, uint8 _y) = indexToCoords(i, grid.width);

                return (grid.grid[i], _x, _y);
            }
        }

        return (GridItem({itemType: ItemType.Empty, itemId: 0, instanceId: 0, rotation: 0}), 0, 0);
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
