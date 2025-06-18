// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "../interfaces/IRisingTides.sol";
import "../interfaces/IRisingTidesInventory.sol";
import "../interfaces/IShipRegistry.sol";
import "../interfaces/IMapRegistry.sol";
import "../tokens/RisingTidesCurrency.sol";
import "../registries/FishRegistry.sol";
import "../registries/EngineRegistry.sol";
import "../registries/FishingRodRegistry.sol";
import "../libraries/InventoryLib.sol";
import "../utils/Errors.sol";

/**
 * @title RisingTidesBase
 * @dev Base contract containing shared state variables and dependencies for all game managers
 */
abstract contract RisingTidesBase is AccessControl, Pausable, ReentrancyGuard, EIP712, IRisingTides {
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
    IRisingTidesInventory public inventoryContract;

    // Signature verification
    address public serverSigner;
    mapping(bytes32 => bool) internal usedSignatures;

    // Game state mappings
    mapping(address => IRisingTides.PlayerState) internal playerStates;
    mapping(address => bool) internal registeredPlayers;

    // Player bait inventory
    mapping(address => mapping(uint256 => uint256)) internal playerBait;

    // Fishing system
    mapping(address => uint256) internal playerFishingNonce;
    mapping(address => uint256) internal pendingFishingRequest;
    mapping(address => uint256) internal pendingBaitType;

    // Fish market
    mapping(uint256 species => FishMarketData) internal fishMarketData;

    // Shard management
    mapping(uint8 => uint256) internal playersPerShard;
    uint256 public maxPlayersPerShard = 1000; // Default limit, can be updated by admin

    // Game configuration constants
    uint256 public constant FUEL_PRICE_PER_UNIT = 10e18; // 10 RTC per fuel unit
    uint256 public constant MAX_SHARDS = 100;
    uint256 public constant HEX_MOVE_COST = 1e18; // Base fuel cost per hex
    uint256 public constant BASE_MOVEMENT_SPEED = 1000; // Base movement speed (lower = faster)
    uint256 public constant SIGNATURE_TIMEOUT = 300; // 5 minutes
    uint256 public constant PRICE_DECAY_RATE = 5; // 5% decrease per fish sale
    uint256 public constant PRICE_RECOVERY_RATE = 463; // ~100% in 6 hours
    uint256 public constant FRESHNESS_DECAY_PERIOD = 15 minutes;
    uint256 public constant FRESHNESS_DECAY_RATE = 25; // 25%

    // Movement constraints
    int32 public constant MAX_COORDINATE = 1000;
    int32 public constant MIN_COORDINATE = -1000;

    // Hex movement directions (0=NE, 1=E, 2=SE, 3=SW, 4=W, 5=NW)
    int32[6] internal hexDirectionsX = [int32(1), int32(1), int32(0), int32(-1), int32(-1), int32(0)];
    int32[6] internal hexDirectionsY = [int32(0), int32(-1), int32(-1), int32(0), int32(1), int32(1)];

    // EIP712 type hashes
    bytes32 internal constant FISHING_RESULT_TYPEHASH =
        keccak256("FishingResult(address player,uint256 nonce,uint256 species,uint16 weight,uint256 timestamp)");

    function _calculatePlayerWeight(address, /* player */ uint256 shipId) internal view virtual returns (uint256);
    function _calculateTotalEnginePower(address player, uint256 shipId)
        internal
        view
        virtual
        returns (uint256 totalPower);
    function _calculateMovementSpeed(uint256 enginePower, uint256 totalWeight)
        internal
        pure
        virtual
        returns (uint256);

    // Modifiers
    modifier onlyRegisteredPlayer() {
        if (!registeredPlayers[msg.sender]) revert PlayerNotRegistered(msg.sender);
        _;
    }

    modifier validShard(uint8 shard) {
        if (shard >= MAX_SHARDS) revert InvalidShardId(shard, MAX_SHARDS);
        _;
    }
}
