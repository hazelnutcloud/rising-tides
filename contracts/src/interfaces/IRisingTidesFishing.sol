// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRisingTidesFishing {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct FishSpecies {
        string name;
        uint256 minWeight;        // in kg with 1e18 precision
        uint256 maxWeight;        // in kg with 1e18 precision
        uint256 baseValue;        // in DBL per kg
        uint256 minCooldown;      // in seconds
        uint256 maxCooldown;      // in seconds
        uint256 decayRate;        // seconds for 100% freshness decay
        bool exists;
    }

    struct FishingRequest {
        address player;
        uint256 requestId;
        uint256 randomSeed;
        uint256 timestamp;
        uint256 rodTokenId;
        uint256 baitId;
        uint256 mapId;
        uint256 regionId;
        int32 q;
        int32 r;
        bool isPending;
        bool isDayTime;
    }

    struct AliasTable {
        uint256[] probabilities;  // Probability values for each fish
        uint256[] aliases;        // Alias indices for each fish
        uint256[] fishIds;        // Fish species IDs
        uint256 totalProbability; // Sum of all probabilities
        bool exists;
    }

    struct OffchainResult {
        bool success;
        uint256 nonce;
        uint256 expiry;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event FishingInitiated(
        address indexed player,
        uint256 indexed requestId,
        uint256 rodTokenId,
        uint256 baitId,
        uint256 mapId,
        uint256 regionId,
        int32 q,
        int32 r,
        bool isDayTime,
        uint256 timestamp
    );

    event FishingCompleted(
        address indexed player,
        uint256 indexed requestId,
        bool success,
        uint256 fishId,
        uint256 weight,
        bool isTrophyQuality,
        uint256 freshnessModifier,
        uint256 cooldownUntil,
        bool baitConsumed,
        uint256 durabilityLoss,
        bool perfectCatch,
        bool isOffchain
    );

    event FishingFailed(
        address indexed player,
        uint256 indexed requestId,
        string reason,
        bool baitConsumed,
        bool isOffchain
    );

    event BaitConsumed(
        address indexed player,
        uint256 indexed baitId,
        uint256 amount
    );

    event FishDiscarded(
        address indexed player,
        uint256[] fishIndices
    );

    event FishSpeciesSet(
        uint256 indexed fishId,
        string name,
        uint256 minWeight,
        uint256 maxWeight,
        uint256 baseValue,
        uint256 minCooldown,
        uint256 maxCooldown,
        uint256 decayRate
    );

    event AliasTableSet(
        uint256 indexed mapId,
        uint256 indexed regionType,
        uint256 indexed baitId,
        bool isDayTime,
        uint256[] probabilities,
        uint256[] aliases,
        uint256[] fishIds
    );

    event OnchainFailureRateSet(uint256 newRate);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error AlreadyFishing();
    error StillOnCooldown();
    error NoActiveFishingRequest();
    error InvalidRequestId();
    error RequestExpired();
    error InvalidSignature();
    error InvalidFishSpecies();
    error InvalidAliasTable();
    error NoFishingRodEquipped();
    error InvalidBaitId();
    error InsufficientBait();
    error CannotFishWhileMoving();
    error InvalidFishingLocation();
    error InventoryFull();
    error InvalidDiscardIndices();
    error Unauthorized();
    error InvalidFailureRate();

    /*//////////////////////////////////////////////////////////////
                            FISHING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function initiateFishing(uint256 baitId) external returns (uint256 requestId);

    function completeFishingOffchain(
        uint256 requestId,
        OffchainResult calldata result,
        bytes calldata signature,
        uint256[] calldata fishToDiscard
    ) external;

    function completeFishingOnchain(
        uint256 requestId,
        uint256[] calldata fishToDiscard
    ) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getActiveFishingRequest(address player) external view returns (FishingRequest memory);

    function getFishSpecies(uint256 fishId) external view returns (FishSpecies memory);

    function getAliasTable(
        uint256 mapId,
        uint256 regionType,
        uint256 baitId,
        bool isDayTime
    ) external view returns (AliasTable memory);

    function getPlayerCooldown(address player) external view returns (uint256);

    function isDayTime() external view returns (bool);

    function getOnchainFailureRate() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setFishSpecies(uint256 fishId, FishSpecies calldata species) external;

    function setAliasTable(
        uint256 mapId,
        uint256 regionType,
        uint256 baitId,
        bool isDayTime,
        uint256[] calldata probabilities,
        uint256[] calldata aliases,
        uint256[] calldata fishIds
    ) external;

    function setDefaultBaitTable(
        uint256 baitId,
        uint256[] calldata probabilities,
        uint256[] calldata aliases,
        uint256[] calldata fishIds
    ) external;

    function setGlobalDefaultTable(
        uint256[] calldata probabilities,
        uint256[] calldata aliases,
        uint256[] calldata fishIds
    ) external;

    function setOnchainFailureRate(uint256 rate) external;

    function setVRFCoordinator(address coordinator) external;

    function setOffchainSigner(address signer) external;

    function pause() external;

    function unpause() external;

    /*//////////////////////////////////////////////////////////////
                            VRF CALLBACK
    //////////////////////////////////////////////////////////////*/

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external;
}
