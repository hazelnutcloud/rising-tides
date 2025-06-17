// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "../../interfaces/IGameState.sol";
import "../../interfaces/IShipRegistry.sol";
import "../../interfaces/IMapRegistry.sol";
import "../../tokens/RisingTidesCurrency.sol";
import "../../registries/FishRegistry.sol";
import "../../registries/EngineRegistry.sol";
import "../../registries/FishingRodRegistry.sol";
import "../../libraries/InventoryLib.sol";

/**
 * @title GameStateBase
 * @dev Base contract containing shared state variables and dependencies for all game managers
 */
abstract contract GameStateBase is AccessControl, Pausable, ReentrancyGuard, EIP712 {
    using InventoryLib for InventoryLib.InventoryGrid;

    // Access control roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SERVER_ROLE = keccak256("SERVER_ROLE");

    // Contract dependencies
    RisingTidesCurrency public currency;
    IShipRegistry public shipRegistry;
    FishRegistry public fishRegistry;
    EngineRegistry public engineRegistry;
    FishingRodRegistry public fishingRodRegistry;
    IMapRegistry public mapRegistry;

    // Signature verification
    address public serverSigner;
    mapping(bytes32 => bool) internal usedSignatures;

    // Game state mappings
    mapping(address => IGameState.PlayerState) internal playerStates;
    mapping(address => InventoryLib.InventoryGrid) internal playerInventories;
    mapping(address => bool) internal registeredPlayers;
    mapping(address => mapping(uint256 => IGameState.FishCatch)) internal playerFish;
    mapping(address => uint256) internal playerFishCount;

    // Player bait inventory
    mapping(address => mapping(uint256 => uint256)) internal playerBait;

    // Fishing system
    mapping(address => uint256) internal playerFishingNonce;
    mapping(address => uint256) internal pendingFishingRequest;
    mapping(address => uint256) internal pendingBaitType;

    // Shard management
    mapping(uint8 => uint256) internal playersPerShard;
    uint256 public maxPlayersPerShard = 1000; // Default limit, can be updated by admin

    // Game configuration constants
    uint256 public constant FUEL_PRICE_PER_UNIT = 10 * 10 ** 18; // 10 RTC per fuel unit
    uint256 public constant MAX_SHARDS = 100;
    uint256 public constant HEX_MOVE_COST = 1; // Base fuel cost per hex
    uint256 public constant BASE_MOVEMENT_SPEED = 1000; // Base movement speed (lower = faster)
    uint256 public constant SIGNATURE_TIMEOUT = 300; // 5 minutes

    // Movement constraints
    int32 public constant MAX_COORDINATE = 1000;
    int32 public constant MIN_COORDINATE = -1000;

    // Hex movement directions (0=NE, 1=E, 2=SE, 3=SW, 4=W, 5=NW)
    int32[6] internal hexDirectionsX = [int32(1), int32(1), int32(0), int32(-1), int32(-1), int32(0)];
    int32[6] internal hexDirectionsY = [int32(0), int32(-1), int32(-1), int32(0), int32(1), int32(1)];

    // EIP712 type hashes
    bytes32 internal constant FISHING_RESULT_TYPEHASH =
        keccak256("FishingResult(address player,uint256 nonce,uint256 species,uint16 weight,uint256 timestamp)");

    // Modifiers
    modifier onlyRegisteredPlayer() {
        require(registeredPlayers[msg.sender], "Player not registered");
        _;
    }

    modifier validCoordinates(int32 x, int32 y) {
        require(x >= MIN_COORDINATE && x <= MAX_COORDINATE, "X coordinate out of bounds");
        require(y >= MIN_COORDINATE && y <= MAX_COORDINATE, "Y coordinate out of bounds");
        _;
    }

    modifier validShard(uint8 shard) {
        require(shard < MAX_SHARDS, "Invalid shard ID");
        _;
    }

    /**
     * @dev Check if a player has a fishing rod equipped
     */
    function hasEquippedFishingRod(address player) internal view returns (bool) {
        InventoryLib.InventoryGrid storage inventory = playerInventories[player];
        IShipRegistry.Ship memory ship = shipRegistry.getShip(playerStates[player].shipId);
        
        // Check all equipment slots for fishing rods
        for (uint256 i = 0; i < ship.slotTypes.length; i++) {
            if (ship.slotTypes[i] == 2) { // Equipment slot
                InventoryLib.GridItem memory item = inventory.grid[i];
                if (item.isOccupied && item.itemType == 3) { // Equipment type
                    if (fishingRodRegistry.isValidFishingRod(item.itemId)) {
                        return true;
                    }
                }
            }
        }
        return false;
    }
}
