// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../interfaces/IRisingTidesFishing.sol";
import "../interfaces/IRisingTidesInventory.sol";
import "../interfaces/IRisingTides.sol";
import "../interfaces/IMapRegistry.sol";
import "../registries/FishRegistry.sol";
import "../tokens/RisingTidesCurrency.sol";
import "../utils/Errors.sol";

/**
 * @title RisingTidesFishing
 * @dev Manages all fishing operations, bait management, and server-signed fishing results
 * Separated from main game contract for modularity and gas optimization
 */
contract RisingTidesFishing is IRisingTidesFishing, AccessControl, Pausable, ReentrancyGuard, EIP712 {
    using ECDSA for bytes32;

    // Access control roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");

    // Contract dependencies
    address public gameContract;
    FishRegistry public fishRegistry;
    IRisingTidesInventory public inventoryContract;
    IMapRegistry public mapRegistry;
    RisingTidesCurrency public currency;

    // Signature verification
    address public serverSigner;
    mapping(bytes32 => bool) internal usedSignatures;

    // Fishing state
    mapping(address => mapping(uint256 => uint256)) internal playerBait;
    mapping(address => uint256) internal playerFishingNonce;
    mapping(address => uint256) internal pendingFishingRequest;
    mapping(address => uint256) internal pendingBaitType;

    // Fishing configuration constants
    uint256 public constant SIGNATURE_TIMEOUT = 300; // 5 minutes

    // EIP712 type hashes
    bytes32 internal constant FISHING_RESULT_TYPEHASH =
        keccak256("FishingResult(address player,uint256 nonce,uint256 species,uint16 weight,uint256 timestamp)");

    constructor(
        address _gameContract,
        address _fishRegistry,
        address _inventoryContract,
        address _mapRegistry,
        address _currency,
        address _serverSigner
    ) EIP712("RisingTidesFishing", "1") {
        if (_gameContract == address(0)) revert InvalidAddress(_gameContract);
        if (_fishRegistry == address(0)) revert InvalidAddress(_fishRegistry);
        if (_inventoryContract == address(0)) revert InvalidAddress(_inventoryContract);
        if (_mapRegistry == address(0)) revert InvalidAddress(_mapRegistry);
        if (_currency == address(0)) revert InvalidAddress(_currency);
        if (_serverSigner == address(0)) revert InvalidAddress(_serverSigner);

        gameContract = _gameContract;
        fishRegistry = FishRegistry(_fishRegistry);
        inventoryContract = IRisingTidesInventory(_inventoryContract);
        mapRegistry = IMapRegistry(_mapRegistry);
        currency = RisingTidesCurrency(_currency);
        serverSigner = _serverSigner;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(GAME_ROLE, _gameContract);
    }

    /**
     * @dev Initiate fishing at current position with chosen bait (server will complete the action)
     */
    function initiateFishing(address player, uint256 baitType)
        external
        onlyRole(GAME_ROLE)
        whenNotPaused
        nonReentrant
        returns (uint256 fishingNonce)
    {
        // Validate if a fishing rod is currently equipped
        if (!hasEquippedFishingRod(player)) revert NoFishingRodEquipped(player);

        // Validate bait type and check if player has it
        if (!fishRegistry.isValidBait(baitType)) revert InvalidBait(baitType);
        if (playerBait[player][baitType] == 0) revert InsufficientBait(baitType, 1, 0);

        // Check if player already has a pending fishing request
        if (pendingFishingRequest[player] != 0) {
            revert PendingFishingRequest(player, pendingFishingRequest[player]);
        }

        // Consume one bait
        playerBait[player][baitType]--;

        // Increment player's fishing nonce
        playerFishingNonce[player]++;
        fishingNonce = playerFishingNonce[player];

        // Store pending request info
        pendingFishingRequest[player] = fishingNonce;
        pendingBaitType[player] = baitType;

        // Get player state for event emission
        (uint8 shard, uint256 mapId, int32 x, int32 y) = getPlayerStateForFishing(player);
        
        emit FishingInitiated(player, shard, mapId, x, y, baitType, fishingNonce);

        return fishingNonce;
    }

    /**
     * @dev Fulfill fishing with server-signed result and fish placement
     */
    function fulfillFishing(FishingResult memory result, bytes memory signature, FishPlacement memory fishPlacement)
        external
        onlyRole(GAME_ROLE)
        whenNotPaused
        nonReentrant
        returns (uint256 instanceId)
    {
        if (pendingFishingRequest[result.player] != result.nonce) revert ExpiredFishingRequest(result.nonce);
        if (result.nonce == 0) revert InvalidFishingResult("Invalid nonce");

        // Verify signature timestamp is recent
        if (block.timestamp > result.timestamp + SIGNATURE_TIMEOUT) {
            revert SignatureExpired(block.timestamp, result.timestamp + SIGNATURE_TIMEOUT);
        }
        if (result.timestamp > block.timestamp) revert FutureTimestamp(result.timestamp, block.timestamp);

        // Verify signature hasn't been used before
        bytes32 signatureHash = keccak256(signature);
        if (usedSignatures[signatureHash]) revert SignatureAlreadyUsed(signatureHash);

        // Verify server signature
        bytes32 structHash = keccak256(
            abi.encode(
                FISHING_RESULT_TYPEHASH, result.player, result.nonce, result.species, result.weight, result.timestamp
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address recoveredSigner = hash.recover(signature);
        if (recoveredSigner != serverSigner) revert InvalidSignature(recoveredSigner, serverSigner);

        // Mark signature as used
        usedSignatures[signatureHash] = true;

        // Clear pending request
        delete pendingFishingRequest[result.player];
        delete pendingBaitType[result.player];

        // If server determined a catch occurred, handle fish placement
        if (result.species > 0) {
            if (!fishRegistry.isValidSpecies(result.species)) revert InvalidSpecies(result.species);

            if (fishPlacement.shouldPlace) {
                // Player wants to place the fish in inventory
                instanceId = inventoryContract.placeFishInInventory(
                    result.player, result.species, result.weight, fishPlacement.x, fishPlacement.y, fishPlacement.rotation
                );

                if (instanceId == 0) revert OperationFailed("Failed to place fish in inventory");

                emit FishCaught(result.player, result.species, result.weight);
            }
            // If shouldPlace is false, fish is discarded (no storage, no inventory placement)
        }

        return instanceId;
    }

    /**
     * @dev Purchase bait at a harbor
     */
    function purchaseBait(address player, uint256 baitType, uint256 amount) 
        external 
        onlyRole(GAME_ROLE) 
        whenNotPaused 
        nonReentrant 
    {
        if (amount == 0) revert InvalidAmount(amount);

        // Get player state for position validation
        (,uint256 mapId, int32 x, int32 y) = getPlayerStateForFishing(player);

        // Check if player is at a harbor
        if (!mapRegistry.isHarbor(mapId, x, y)) {
            revert NotAtHarbor(mapId, x, y);
        }

        // Validate bait type exists
        if (!fishRegistry.isValidBait(baitType)) revert InvalidBait(baitType);

        // Calculate cost
        FishRegistry.BaitType memory bait = fishRegistry.getBaitType(baitType);
        uint256 totalCost = bait.price * amount;
        if (currency.balanceOf(player) < totalCost) {
            revert InsufficientBalance(player, totalCost, currency.balanceOf(player));
        }

        // Burn currency and add bait to inventory
        currency.burn(player, totalCost, "Bait purchase");
        playerBait[player][baitType] += amount;

        emit BaitPurchased(player, baitType, amount, totalCost);
    }

    /**
     * @dev Get player's bait inventory
     */
    function getPlayerBait(address player, uint256 baitType) external view returns (uint256) {
        return playerBait[player][baitType];
    }

    /**
     * @dev Get all available bait types and amounts for a player
     */
    function getPlayerAvailableBait(address player)
        external
        view
        returns (uint256[] memory baitTypes, uint256[] memory amounts)
    {
        // Count available bait types first
        uint256 availableCount = 0;
        for (uint256 i = 1; i <= 1000; i++) {
            if (playerBait[player][i] > 0) {
                availableCount++;
            }
            if (!fishRegistry.isValidBait(i) && i > 50) {
                break; // Stop checking after a reasonable range
            }
        }

        // Populate arrays
        baitTypes = new uint256[](availableCount);
        amounts = new uint256[](availableCount);

        uint256 index = 0;
        for (uint256 i = 1; i <= 1000 && index < availableCount; i++) {
            if (playerBait[player][i] > 0) {
                baitTypes[index] = i;
                amounts[index] = playerBait[player][i];
                index++;
            }
            if (!fishRegistry.isValidBait(i) && i > 50) {
                break;
            }
        }

        return (baitTypes, amounts);
    }

    /**
     * @dev Get player's fishing status
     */
    function getPlayerFishingStatus(address player)
        external
        view
        returns (uint256 pendingNonce, uint256 baitTypeUsed, uint256 currentNonce)
    {
        pendingNonce = pendingFishingRequest[player];
        baitTypeUsed = pendingBaitType[player];
        currentNonce = playerFishingNonce[player];
    }

    /**
     * @dev Check if a player has a fishing rod equipped
     */
    function hasEquippedFishingRod(address player) public view returns (bool) {
        return inventoryContract.hasEquippedFishingRod(player);
    }

    /**
     * @dev Get player state for fishing events and validation
     */
    function getPlayerStateForFishing(address player) 
        public 
        view 
        returns (uint8 shard, uint256 mapId, int32 x, int32 y) 
    {
        // Call the game contract to get player state
        IRisingTides.PlayerState memory playerState = IRisingTides(gameContract).getPlayerState(player);
        return (playerState.shard, playerState.mapId, playerState.position.x, playerState.position.y);
    }


    // Admin functions
    function setGameContract(address _gameContract) external onlyRole(ADMIN_ROLE) {
        if (_gameContract == address(0)) revert InvalidAddress(_gameContract);
        gameContract = _gameContract;
        _grantRole(GAME_ROLE, _gameContract);
    }

    function updateServerSigner(address newSigner) external onlyRole(ADMIN_ROLE) {
        if (newSigner == address(0)) revert InvalidAddress(newSigner);
        address oldSigner = serverSigner;
        serverSigner = newSigner;
        emit ServerSignerUpdated(oldSigner, newSigner);
    }

    function updateRegistries(
        address _fishRegistry,
        address _inventoryContract,
        address _mapRegistry,
        address _currency
    ) external onlyRole(ADMIN_ROLE) {
        if (_fishRegistry != address(0)) {
            fishRegistry = FishRegistry(_fishRegistry);
        }
        if (_inventoryContract != address(0)) {
            inventoryContract = IRisingTidesInventory(_inventoryContract);
        }
        if (_mapRegistry != address(0)) {
            mapRegistry = IMapRegistry(_mapRegistry);
        }
        if (_currency != address(0)) {
            currency = RisingTidesCurrency(_currency);
        }
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}