// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRisingTidesInventory} from "./IRisingTidesInventory.sol";

interface IRisingTidesPort {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct MarketData {
        uint256 currentPrice; // Current market price in DBL per kg (with PRECISION)
        uint256 basePrice; // Base price for minimum calculation (with PRECISION)
        uint256 priceDropRate; // Multiplier for price drop per DBL sold (with PRECISION)
        uint256 priceRecoveryRate; // DBL per second recovery (with PRECISION)
        uint256 lastUpdateTime; // Last time price was updated
        bool exists;
    }

    struct ShopItem {
        uint256 price; // Price in DBL (18 decimals)
        uint256 requiredLevel; // Minimum player level to purchase
        bool available; // If item is available at this port
    }

    struct CraftingRecipe {
        uint256[] materialIds; // Required material IDs
        uint256[] materialAmounts; // Required amounts for each material
        uint256 dblCost; // DBL cost to craft (18 decimals)
        uint256 requiredLevel; // Minimum player level
        uint256 rodTypeId; // Which rod type to create
        uint256 allowedMapsBitfield; // Bitfield for allowed maps (bit i = map i allowed, 0 = all maps)
        bool exists;
    }

    struct CraftingRequest {
        address player;
        uint256 requestId;
        uint256 recipeId;
        uint256 timestamp;
        bool isPending;
    }

    enum FreshnessLevel {
        ROTTEN, // 0% value
        ROTTING, // 33% value
        STALE, // 66% value
        FRESH // 100% value

    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    // Market events
    event FishSold(
        address indexed player,
        uint256 indexed fishId,
        uint256 weight,
        uint256 earnings,
        FreshnessLevel freshness,
        bool isTrophyQuality
    );

    event FishDiscarded(address indexed player, uint256 indexed fishId, uint256 weight, string reason);

    event MarketPriceUpdated(uint256 indexed fishId, uint256 oldPrice, uint256 newPrice, bool isPriceDrop);

    // Shop events
    event ItemPurchased(
        address indexed player,
        IRisingTidesInventory.ItemType indexed itemType,
        uint256 indexed itemId,
        uint256 amount,
        uint256 totalCost
    );

    // Crafting events
    event RodCraftingInitiated(address indexed player, uint256 indexed requestId, uint256 recipeId, uint256 rodTypeId);

    event RodCrafted(address indexed player, uint256 indexed tokenId, uint256 indexed rodTypeId, bool isStrange);

    event RodRepaired(address indexed player, uint256 indexed tokenId, uint256 durabilityAdded, uint256 dblCost);

    // Admin events
    event MarketDataSet(uint256 indexed fishId, uint256 basePrice, uint256 priceDropRate, uint256 priceRecoveryRate);

    event ShopItemSet(
        uint256 indexed mapId,
        IRisingTidesInventory.ItemType indexed itemType,
        uint256 indexed itemId,
        uint256 price,
        uint256 requiredLevel
    );

    event CraftingRecipeSet(uint256 indexed recipeId, uint256 rodTypeId, uint256 dblCost, uint256 requiredLevel);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotAtPort();
    error InsufficientLevel();
    error InsufficientDoubloons();
    error InsufficientMaterials();
    error InvalidFishIndex();
    error InvalidItemType();
    error ItemNotAvailable();
    error InvalidRecipe();
    error CraftingRequestPending();
    error InvalidRequestId();
    error RecipeNotAvailableAtThisLocation();
    error RodNotOwned();
    error RodFullyRepaired();
    error InvalidAmount();
    error InsufficientFuel();
    error InsufficientFuelReserves();
    error ShipNotOwned();
    error ShipAlreadyOwned();
    error Unauthorized();
    error InvalidMarketData();
    error PriceBelowMinimum();

    /*//////////////////////////////////////////////////////////////
                            MARKET FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function sellFish(uint256[] calldata fishIndices) external;

    function sellAllFish() external;

    function getMarketPrice(uint256 fishId) external view returns (uint256 currentPrice, uint256 basePrice);

    function calculateFishValue(uint256 fishId, uint256 weight, FreshnessLevel freshness, bool isTrophyQuality)
        external
        view
        returns (uint256 value);

    /*//////////////////////////////////////////////////////////////
                            SHOP FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function buyItem(IRisingTidesInventory.ItemType itemType, uint256 itemId, uint256 amount) external;

    function getShopItem(uint256 mapId, IRisingTidesInventory.ItemType itemType, uint256 itemId)
        external
        view
        returns (ShopItem memory);

    /*//////////////////////////////////////////////////////////////
                          CRAFTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function craftRod(uint256 recipeId) external returns (uint256 requestId);

    function repairRod(uint256 tokenId, uint256 durabilityToAdd) external;

    function getCraftingRecipe(uint256 recipeId) external view returns (CraftingRecipe memory);

    function isRecipeAvailableAtMap(uint256 recipeId, uint256 mapId) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getMarketData(uint256 fishId) external view returns (MarketData memory);

    function getFreshnessLevel(uint256 caughtAt, uint256 decayRate, uint256 freshnessModifier)
        external
        view
        returns (FreshnessLevel level, uint256 valuePercent);

    function getActiveCraftingRequest(address player) external view returns (CraftingRequest memory);

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setMarketData(uint256 fishId, MarketData calldata data) external;

    function setShopItem(uint256 mapId, IRisingTidesInventory.ItemType itemType, uint256 itemId, ShopItem calldata item)
        external;

    function setCraftingRecipe(uint256 recipeId, CraftingRecipe calldata recipe) external;

    function setVRFCoordinator(address coordinator) external;

    function setRepairCostPerDurability(uint256 cost) external;

    function pause() external;

    function unpause() external;
}
