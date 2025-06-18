// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Fishing result data structure for server signatures
 */
struct FishingResult {
    address player;
    uint256 nonce;
    uint256 species; // 0 = no catch
    uint16 weight;
    uint256 timestamp; // Server-side timestamp for validation
}

/**
 * @dev Fish placement data for fishing fulfillment
 */
struct FishPlacement {
    bool shouldPlace; // true = place fish in inventory, false = discard fish
    uint8 x; // X coordinate for placement (only used if shouldPlace = true)
    uint8 y; // Y coordinate for placement (only used if shouldPlace = true)
    uint8 rotation; // Rotation for placement: 0=up, 1=right, 2=down, 3=left (only used if shouldPlace = true)
}

/**
 * @title IRisingTidesFishing
 * @dev Interface for the RisingTidesFishing contract
 * Defines all fishing management functions and events
 */
interface IRisingTidesFishing {
    // Events
    event FishingInitiated(
        address indexed player, uint8 shard, uint256 mapId, int32 x, int32 y, uint256 baitType, uint256 nonce
    );
    event FishCaught(address indexed player, uint256 species, uint16 weight);
    event BaitPurchased(address indexed player, uint256 baitType, uint256 amount, uint256 cost);
    event ServerSignerUpdated(address indexed oldSigner, address indexed newSigner);

    // Core fishing functions
    function initiateFishing(address player, uint256 baitType) external returns (uint256 fishingNonce);
    function fulfillFishing(FishingResult memory result, bytes memory signature, FishPlacement memory fishPlacement)
        external
        returns (uint256 instanceId);
    
    // Bait management
    function purchaseBait(address player, uint256 baitType, uint256 amount) external;
    function getPlayerBait(address player, uint256 baitType) external view returns (uint256);
    function getPlayerAvailableBait(address player)
        external
        view
        returns (uint256[] memory baitTypes, uint256[] memory amounts);
    
    // Fishing status and queries
    function getPlayerFishingStatus(address player)
        external
        view
        returns (uint256 pendingNonce, uint256 baitTypeUsed, uint256 currentNonce);
    function hasEquippedFishingRod(address player) external view returns (bool);
    
    // Player state access for fishing events
    function getPlayerStateForFishing(address player) 
        external 
        view 
        returns (uint8 shard, uint256 mapId, int32 x, int32 y);
    
    // Admin functions
    function setGameContract(address gameContract) external;
    function updateServerSigner(address newSigner) external;
    function updateRegistries(
        address fishRegistry,
        address inventoryContract,
        address mapRegistry,
        address currency
    ) external;
    function pause() external;
    function unpause() external;
}