// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SlotType, ItemType} from "../types/InventoryTypes.sol";
import "../interfaces/IRisingTidesInventory.sol";
import "../interfaces/IRisingTides.sol";
import "../interfaces/IShipRegistry.sol";
import "../registries/FishRegistry.sol";
import "../registries/EngineRegistry.sol";
import "../registries/FishingRodRegistry.sol";
import "../libraries/InventoryLib.sol";
import "../utils/Errors.sol";

/**
 * @title RisingTidesInventory
 * @dev Manages all player inventory operations, item placement, and equipment
 * Separated from main game contract for modularity and gas optimization
 */
contract RisingTidesInventory is IRisingTidesInventory, AccessControl, Pausable, ReentrancyGuard {
    using InventoryLib for InventoryLib.InventoryGrid;

    // Access control roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");

    // Contract dependencies
    address public gameContract;
    address public fishingContract;
    FishRegistry public fishRegistry;
    EngineRegistry public engineRegistry;
    FishingRodRegistry public fishingRodRegistry;
    IShipRegistry public shipRegistry;

    // Inventory state
    mapping(address => InventoryLib.InventoryGrid) internal playerInventories;
    mapping(address player => mapping(uint256 instanceId => IRisingTides.FishCatch)) internal playerFish;

    // Modifiers
    modifier onlyGame() {
        if (msg.sender != gameContract) revert Unauthorized(msg.sender);
        _;
    }

    modifier onlyGameOrFishing() {
        if (msg.sender != gameContract && msg.sender != fishingContract) revert Unauthorized(msg.sender);
        _;
    }

    modifier onlyGameOrPlayer(address player) {
        if (msg.sender != gameContract && msg.sender != player) revert Unauthorized(msg.sender);
        _;
    }

    constructor(
        address _gameContract,
        address _fishRegistry,
        address _engineRegistry,
        address _fishingRodRegistry,
        address _shipRegistry
    ) {
        if (_gameContract == address(0)) revert InvalidAddress(_gameContract);
        if (_fishRegistry == address(0)) revert InvalidAddress(_fishRegistry);
        if (_engineRegistry == address(0)) revert InvalidAddress(_engineRegistry);
        if (_fishingRodRegistry == address(0)) revert InvalidAddress(_fishingRodRegistry);
        if (_shipRegistry == address(0)) revert InvalidAddress(_shipRegistry);

        gameContract = _gameContract;
        fishRegistry = FishRegistry(_fishRegistry);
        engineRegistry = EngineRegistry(_engineRegistry);
        fishingRodRegistry = FishingRodRegistry(_fishingRodRegistry);
        shipRegistry = IShipRegistry(_shipRegistry);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(GAME_ROLE, _gameContract);
    }

    /**
     * @dev Initialize player inventory based on ship
     */
    function initializeInventory(
        address player,
        uint256 shipId,
        uint8 width,
        uint8 height,
        SlotType[] calldata slotTypes
    ) external onlyGame {
        if (player == address(0)) revert InvalidAddress(player);
        if (shipId == 0) revert InvalidId(shipId);

        InventoryLib.InventoryGrid storage inventory = playerInventories[player];
        inventory.width = width;
        inventory.height = height;
        inventory.slotTypes = slotTypes;

        emit InventoryInitialized(player, shipId, width, height);
    }

    /**
     * @dev Assign default equipment (Engine ID 1 and Fishing Rod ID 1) to new player
     */
    function assignDefaultEquipment(address player, uint256 engineId, uint256 fishingRodId) external onlyGame {
        if (player == address(0)) revert InvalidAddress(player);

        InventoryLib.InventoryGrid storage inventory = playerInventories[player];

        // Get engine shape from registry
        IEngineRegistry.Engine memory engine = engineRegistry.getEngine(engineId);
        InventoryLib.ItemShape memory engineShape =
            InventoryLib.ItemShape({width: engine.shapeWidth, height: engine.shapeHeight, data: engine.shapeData});

        // Get fishing rod shape from registry
        IFishingRodRegistry.FishingRod memory rod = fishingRodRegistry.getFishingRod(fishingRodId);
        InventoryLib.ItemShape memory rodShape =
            InventoryLib.ItemShape({width: rod.shapeWidth, height: rod.shapeHeight, data: rod.shapeData});

        // Place engine in first engine slot
        bool enginePlaced = false;
        bool rodPlaced = false;

        uint256 inventoryArea = inventory.width * inventory.height;

        for (uint256 i = 0; i < inventoryArea && (!enginePlaced || !rodPlaced); i++) {
            if (inventory.slotTypes[i] == SlotType.Engine && !enginePlaced) {
                (uint8 x, uint8 y) = InventoryLib.indexToCoords(i, inventory.width);
                uint256 instanceId = inventory.placeItem(engineShape, x, y, 0, ItemType.Engine, engineId, 0);
                if (instanceId > 0) {
                    enginePlaced = true;
                    emit ItemPlaced(player, ItemType.Engine, engineId, instanceId, x, y, 0);
                }
            }
            if (inventory.slotTypes[i] == SlotType.FishingRod && !rodPlaced) {
                (uint8 x, uint8 y) = InventoryLib.indexToCoords(i, inventory.width);
                uint256 instanceId = inventory.placeItem(rodShape, x, y, 0, ItemType.FishingRod, fishingRodId, 0);
                if (instanceId > 0) {
                    rodPlaced = true;
                    emit ItemPlaced(player, ItemType.FishingRod, fishingRodId, instanceId, x, y, 0);
                }
            }
        }

        if (!enginePlaced) revert OperationFailed("Failed to place default engine");
        if (!rodPlaced) revert OperationFailed("Failed to place default fishing rod");
    }

    /**
     * @dev Get player's full inventory grid
     */
    function getPlayerInventory(address player) external view returns (InventoryData memory) {
        InventoryLib.InventoryGrid storage inventory = playerInventories[player];
        
        uint256 totalSlots = uint256(inventory.width) * uint256(inventory.height);
        InventoryLib.GridItem[] memory items = new InventoryLib.GridItem[](totalSlots);

        for (uint256 i = 0; i < totalSlots; i++) {
            items[i] = inventory.grid[i];
        }

        return InventoryData({
            width: inventory.width,
            height: inventory.height,
            slotTypes: inventory.slotTypes,
            items: items
        });
    }

    /**
     * @dev Get inventory item at specific coordinates
     */
    function getInventoryItem(address player, uint8 x, uint8 y) external view returns (InventoryLib.GridItem memory) {
        return InventoryLib.getItemAt(playerInventories[player], x, y);
    }

    /**
     * @dev Update inventory item position and/or rotation
     * @param player Player address (must be msg.sender or game contract)
     * @param fromX Source X position
     * @param fromY Source Y position
     * @param toX Target X position (use fromX if only rotating)
     * @param toY Target Y position (use fromY if only rotating)
     * @param rotation New rotation (0=up, 1=right, 2=down, 3=left)
     */
    function updateInventoryItem(
        address player,
        uint8 fromX,
        uint8 fromY,
        uint8 toX,
        uint8 toY,
        uint8 rotation
    ) external onlyGameOrPlayer(player) whenNotPaused {
        if (rotation >= 4) revert InvalidRotation(rotation);

        InventoryLib.InventoryGrid storage inventory = playerInventories[player];

        // Get item at source position
        InventoryLib.GridItem memory item = InventoryLib.getItemAt(inventory, fromX, fromY);
        if (item.itemType == ItemType.Empty) revert ItemNotFound(fromX, fromY);

        // Get item shape from registry
        InventoryLib.ItemShape memory shape = _getItemShape(item.itemType, item.itemId);

        // Remove from old position
        if (!InventoryLib.removeItem(inventory, shape, fromX, fromY, item.rotation, item.instanceId)) {
            revert OperationFailed("Failed to remove item");
        }

        // Place at new position with rotation
        uint256 newInstanceId = inventory.placeItem(shape, toX, toY, rotation, item.itemType, item.itemId, item.instanceId);
        if (newInstanceId == 0) {
            revert CannotPlaceItem("Failed to place item at new position");
        }

        emit ItemMoved(player, item.instanceId, fromX, fromY, toX, toY, rotation);
    }

    /**
     * @dev Discard inventory item to free space
     */
    function discardInventoryItem(address player, uint8 x, uint8 y) external onlyGameOrPlayer(player) whenNotPaused {
        InventoryLib.InventoryGrid storage inventory = playerInventories[player];
        InventoryLib.GridItem memory item = InventoryLib.getItemAt(inventory, x, y);
        if (item.itemType == ItemType.Empty) revert ItemNotFound(x, y);

        // Get item shape from registry
        InventoryLib.ItemShape memory shape = _getItemShape(item.itemType, item.itemId);

        if (!inventory.removeItem(shape, x, y, item.rotation, item.instanceId)) {
            revert OperationFailed("Failed to remove item");
        }

        // Remove fish data if it's a fish
        if (item.itemType == ItemType.Fish) {
            delete playerFish[player][item.instanceId];
        }

        emit ItemDiscarded(player, item.itemType, item.itemId, item.instanceId);
    }

    /**
     * @dev Place fish in player's inventory at specified coordinates
     */
    function placeFishInInventory(
        address player,
        uint256 species,
        uint16 weight,
        uint8 x,
        uint8 y,
        uint8 rotation
    ) external onlyGameOrFishing returns (uint256 instanceId) {
        InventoryLib.InventoryGrid storage inventory = playerInventories[player];

        // Get fish shape from registry
        InventoryLib.ItemShape memory fishShape = _getItemShape(ItemType.Fish, species);

        // Place the fish in inventory
        instanceId = inventory.placeItem(fishShape, x, y, rotation, ItemType.Fish, species, 0);
        if (instanceId == 0) revert CannotPlaceItem("Failed to place fish in inventory");

        // Store fish data
        playerFish[player][instanceId] = IRisingTides.FishCatch({
            species: species,
            weight: weight,
            caughtTimestamp: block.timestamp
        });

        emit FishStored(player, species, instanceId, weight, x, y);
        return instanceId;
    }

    /**
     * @dev Remove fish from inventory and return fish data
     */
    function removeFishFromInventory(address player, uint256 instanceId) external onlyGameOrFishing returns (IRisingTides.FishCatch memory fishData) {
        // Get fish data first
        fishData = playerFish[player][instanceId];
        if (fishData.species == 0) revert ItemNotFound(0, 0); // Fish not found

        // Find and remove the fish from inventory
        InventoryLib.InventoryGrid storage inventory = playerInventories[player];
        uint256 totalSlots = uint256(inventory.width) * uint256(inventory.height);
        
        for (uint256 i = 0; i < totalSlots; i++) {
            InventoryLib.GridItem memory item = inventory.grid[i];
            if (item.itemType == ItemType.Fish && item.instanceId == instanceId) {
                // Get fish shape to remove it properly
                InventoryLib.ItemShape memory fishShape = _getItemShape(ItemType.Fish, item.itemId);
                (uint8 x, uint8 y) = InventoryLib.indexToCoords(i, inventory.width);
                
                if (!inventory.removeItem(fishShape, x, y, item.rotation, instanceId)) {
                    revert OperationFailed("Failed to remove fish from inventory");
                }
                break;
            }
        }

        // Clear fish data
        delete playerFish[player][instanceId];
        return fishData;
    }

    /**
     * @dev Get fish data for a specific instance
     */
    function getFishData(address player, uint256 instanceId) external view returns (IRisingTides.FishCatch memory) {
        return playerFish[player][instanceId];
    }

    /**
     * @dev Check if a player has any equipment of a specific type equipped
     */
    function hasEquippedItemType(address player, ItemType itemType) external view returns (bool) {
        InventoryLib.InventoryGrid storage inventory = playerInventories[player];
        
        // We need ship data to check slot types - this requires a callback to the game contract
        // For now, let's simplify and check all slots
        uint256 totalSlots = uint256(inventory.width) * uint256(inventory.height);

        for (uint256 i = 0; i < totalSlots; i++) {
            InventoryLib.GridItem memory item = inventory.grid[i];
            if (item.itemType == itemType) {
                // Additional validation for engines and fishing rods
                if (itemType == ItemType.Engine && engineRegistry.isValidEngine(item.itemId)) {
                    return true;
                } else if (itemType == ItemType.FishingRod && fishingRodRegistry.isValidFishingRod(item.itemId)) {
                    return true;
                } else if (itemType != ItemType.Engine && itemType != ItemType.FishingRod) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * @dev Calculate total engine power from equipped engines
     */
    function getTotalEnginePower(address player, uint256 shipId) external view returns (uint256 totalPower) {
        InventoryLib.InventoryGrid storage inventory = playerInventories[player];
        IShipRegistry.Ship memory ship = shipRegistry.getShip(shipId);

        uint256 shipArea = ship.cargoWidth * ship.cargoHeight;

        // Iterate through inventory slots looking for engines in engine slots
        for (uint256 i = 0; i < shipArea; i++) {
            if (ship.slotTypes[i] == SlotType.Engine) {
                InventoryLib.GridItem memory item = inventory.grid[i];
                if (item.itemType == ItemType.Engine) {
                    if (engineRegistry.isValidEngine(item.itemId)) {
                        IEngineRegistry.EngineStats memory stats = engineRegistry.getEngineStats(item.itemId);
                        totalPower += stats.enginePowerPerCell;
                    }
                }
            }
        }

        // Fallback to default engine power if no engines equipped
        if (totalPower == 0) {
            return 30; // Default engine power for basic gameplay
        }

        return totalPower;
    }

    /**
     * @dev Check if player has an equipped fishing rod
     */
    function hasEquippedFishingRod(address player) external view returns (bool) {
        return this.hasEquippedItemType(player, ItemType.FishingRod);
    }

    /**
     * @dev Get proper item shape from registry based on item type and ID
     */
    function _getItemShape(ItemType itemType, uint256 itemId) internal view returns (InventoryLib.ItemShape memory) {
        if (itemType == ItemType.Fish) {
            if (!fishRegistry.isValidSpecies(itemId)) revert InvalidSpecies(itemId);
            FishRegistry.FishSpecies memory species = fishRegistry.getFishSpecies(itemId);
            return InventoryLib.ItemShape({
                width: species.shapeWidth,
                height: species.shapeHeight,
                data: species.shapeData
            });
        } else if (itemType == ItemType.Engine) {
            if (!engineRegistry.isValidEngine(itemId)) revert InvalidEngine(itemId);
            IEngineRegistry.Engine memory engine = engineRegistry.getEngine(itemId);
            return InventoryLib.ItemShape({
                width: engine.shapeWidth,
                height: engine.shapeHeight,
                data: engine.shapeData
            });
        } else if (itemType == ItemType.FishingRod) {
            if (!fishingRodRegistry.isValidFishingRod(itemId)) revert InvalidFishingRod(itemId);
            IFishingRodRegistry.FishingRod memory rod = fishingRodRegistry.getFishingRod(itemId);
            return InventoryLib.ItemShape({
                width: rod.shapeWidth,
                height: rod.shapeHeight,
                data: rod.shapeData
            });
        } else {
            revert InvalidItemType(uint8(itemType));
        }
    }

    // Admin functions
    function setGameContract(address _gameContract) external onlyRole(ADMIN_ROLE) {
        if (_gameContract == address(0)) revert InvalidAddress(_gameContract);
        gameContract = _gameContract;
        _grantRole(GAME_ROLE, _gameContract);
    }

    function setFishingContract(address _fishingContract) external onlyRole(ADMIN_ROLE) {
        if (_fishingContract == address(0)) revert InvalidAddress(_fishingContract);
        fishingContract = _fishingContract;
    }

    function updateRegistries(
        address _fishRegistry,
        address _engineRegistry,
        address _fishingRodRegistry,
        address _shipRegistry
    ) external onlyRole(ADMIN_ROLE) {
        if (_fishRegistry != address(0)) {
            fishRegistry = FishRegistry(_fishRegistry);
        }
        if (_engineRegistry != address(0)) {
            engineRegistry = EngineRegistry(_engineRegistry);
        }
        if (_fishingRodRegistry != address(0)) {
            fishingRodRegistry = FishingRodRegistry(_fishingRodRegistry);
        }
        if (_shipRegistry != address(0)) {
            shipRegistry = IShipRegistry(_shipRegistry);
        }
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}