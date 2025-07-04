// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRisingTidesFishingRod {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct RodType {
        uint256 minDurability;
        uint256 maxDurability;
        uint256 minMaxFishWeight;
        uint256 maxMaxFishWeight;
        uint256 minCritRate;
        uint256 maxCritRate;
        uint256 minCritMultiplier;
        uint256 maxCritMultiplier;
        uint256 minStrength;
        uint256 maxStrength;
        uint256 minEfficiency;
        uint256 maxEfficiency;
        uint256 compatibleBaitMask;
        bool exists;
    }

    struct RodInstance {
        uint256 rodId;
        uint256 maxDurability;
        uint256 currentDurability;
        uint256 maxFishWeight;
        uint256 critRate;
        uint256 critMultiplier;
        uint256 strength;
        uint256 efficiency;
        uint256 totalCatches;
        uint256 enchantmentMask;
        bool isStrange; // Whether this rod can gain titles
    }

    struct Bonus {
        uint256 durabilityBonus;
        uint256 efficiencyBonus;
        uint256 critRateBonus;
        uint256 maxWeightBonus;
        uint256 strengthBonus;
        uint256 freshnessModifier;
        uint256 critMultiplierBonus; // Additional rolls on crit (0 = normal, 1 = one extra roll, etc.)
        bool hasPerfectCatch;
        bool hasTrophyQuality;
        bool hasDoubleCatch;
        uint256 regionMask;
    }

    struct FishModifiers {
        bool isTrophyQuality;
        uint256 freshnessModifier;
        bool doubleCatch;
        uint256 actualDurabilityLoss;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event RodMinted(uint256 indexed tokenId, address indexed owner, uint256 rodId, uint256 enchantmentMask);

    event RodRepaired(uint256 indexed tokenId, uint256 durabilityAdded, uint256 newDurability);

    event CatchProcessed(uint256 indexed tokenId, uint256 durabilityLoss, uint256 newTotalCatches, bool perfectCatch);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error InvalidRodType();
    error RodNotUsable();
    error InvalidTokenId();
    error OnlyPort();
    error OnlyFishing();

    /*//////////////////////////////////////////////////////////////
                            MINTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function mint(address to, uint256 rodId, uint256 randomSeed) external returns (uint256 tokenId);

    /*//////////////////////////////////////////////////////////////
                            FISHING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function checkRodUsability(uint256 tokenId) external view returns (bool isUsable, uint256 compatibleBaitMask);

    function getFishingAttributes(uint256 tokenId, uint256 regionType)
        external
        view
        returns (
            uint256 effectiveMaxFishWeight,
            uint256 effectiveCritRate,
            uint256 effectiveEfficiency,
            uint256 effectiveCritMultiplierBonus
        );

    function processCatch(uint256 tokenId, uint256 fishWeight, uint256 regionType, uint256 randomSeed)
        external
        returns (FishModifiers memory modifiers);

    /*//////////////////////////////////////////////////////////////
                            REPAIR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function repair(uint256 tokenId, uint256 durabilityToAdd) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getRodInfo(uint256 tokenId)
        external
        view
        returns (RodInstance memory rod, string memory currentTitle, uint256 titleIndex);

    function getCurrentTitleIndex(uint256 totalCatches) external view returns (uint256);

    function getEnchantmentInfo(uint256 enchantmentId) external view returns (string memory name, Bonus memory bonus);

    function getTitleInfo(uint256 titleIndex)
        external
        view
        returns (string memory name, uint256 threshold, Bonus memory bonus);
}
