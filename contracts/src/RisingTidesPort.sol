// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
                                                                               ,----,
                                               ,--.                          ,/   .`|
,-.----.     ,---,  .--.--.      ,---,       ,--.'|  ,----..               ,`   .'  :   ,---,    ,---,        ,---,.  .--.--.
\    /  \ ,`--.' | /  /    '. ,`--.' |   ,--,:  : | /   /   \            ;    ;     /,`--.' |  .'  .' `\    ,'  .' | /  /    '.
;   :    \|   :  :|  :  /`. / |   :  :,`--.'`|  ' :|   :     :         .'___,/    ,' |   :  :,---.'     \ ,---.'   ||  :  /`. /
|   | .\ ::   |  ';  |  |--`  :   |  '|   :  :  | |.   |  ;. /         |    :     |  :   |  '|   |  .`\  ||   |   .';  |  |--`
.   : |: ||   :  ||  :  ;_    |   :  |:   |   \ | :.   ; /--`          ;    |.';  ;  |   :  |:   : |  '  |:   :  |-,|  :  ;_
|   |  \ :'   '  ; \  \    `. '   '  ;|   : '  '; |;   | ;  __         `----'  |  |  '   '  ;|   ' '  ;  ::   |  ;/| \  \    `.
|   : .  /|   |  |  `----.   \|   |  |'   ' ;.    ;|   : |.' .'            '   :  ;  |   |  |'   | ;  .  ||   :   .'  `----.   \
;   | |  \'   :  ;  __ \  \  |'   :  ;|   | | \   |.   | '_.' :            |   |  '  '   :  ;|   | :  |  '|   |  |-,  __ \  \  |
|   | ;\  \   |  ' /  /`--'  /|   |  ''   : |  ; .''   ; : \  |            '   :  |  |   |  ''   : | /  ; '   :  ;/| /  /`--'  /
:   ' | \.'   :  |'--'.     / '   :  ||   | '`--'  '   | '/  .'            ;   |.'   '   :  ||   | '` ,/  |   |    \'--'.     /
:   : :-' ;   |.'   `--'---'  ;   |.' '   : |      |   :    /              '---'     ;   |.' ;   :  .'    |   :   .'  `--'---'
|   |.'   '---'               '---'   ;   |.'       \   \ .'                         '---'   |   ,.'      |   | ,'
`---'                                 '---'          `---`                                   '---'        `----'

                                                $DBL - Doubloons of the Seven Seas
*/

import {IRisingTidesPort} from "./interfaces/IRisingTidesPort.sol";
import {IRisingTidesWorld} from "./interfaces/IRisingTidesWorld.sol";
import {IRisingTidesInventory} from "./interfaces/IRisingTidesInventory.sol";
import {IRisingTidesFishing} from "./interfaces/IRisingTidesFishing.sol";
import {IRisingTidesFishingRod} from "./interfaces/IRisingTidesFishingRod.sol";
import {IDoubloons} from "./interfaces/IDoubloons.sol";
import {IERC20} from "../lib/forge-std/src/interfaces/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IVRFConsumer} from "./interfaces/IVRFConsumer.sol";
import {IVRFCoordinator} from "./interfaces/IVRFCoordinator.sol";

contract RisingTidesPort is IRisingTidesPort, AccessControl, Pausable, ReentrancyGuard, IVRFConsumer {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 private constant GAME_MASTER_ROLE = keccak256("GAME_MASTER_ROLE");

    uint256 private constant PRECISION = 1e18;
    uint256 private constant MIN_PRICE_PERCENT = 10; // Can't sell below 10% of base price
    uint256 private constant STRANGE_CHANCE = 10; // 10% chance for Strange quality
    uint256 private constant TROPHY_MULTIPLIER = 150; // 1.5x for trophy quality
    uint256 private constant PERCENT_DIVISOR = 100;
    uint256 private constant REPAIR_COST_PER_DURABILITY = 1e18; // 1 DBL per durability point

    // Freshness value percentages
    uint256 private constant FRESH_VALUE = 100;
    uint256 private constant STALE_VALUE = 66;
    uint256 private constant ROTTING_VALUE = 33;
    uint256 private constant ROTTEN_VALUE = 0;

    // Freshness decay thresholds
    uint256 private constant STALE_THRESHOLD = 33;
    uint256 private constant ROTTING_THRESHOLD = 66;
    uint256 private constant ROTTEN_THRESHOLD = 100;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    // Core contracts
    IRisingTidesWorld public world;
    IRisingTidesInventory public inventory;
    IRisingTidesFishing public fishing;
    IRisingTidesFishingRod public fishingRod;
    IDoubloons public doubloons;

    // VRF coordinator for crafting randomness
    IVRFCoordinator public vrfCoordinator;

    // Repair cost per durability point (configurable)
    uint256 public repairCostPerDurability = REPAIR_COST_PER_DURABILITY;

    // Market data
    mapping(uint256 => MarketData) public marketData;

    // Shop inventory: mapId => itemType => itemId => ShopItem
    mapping(uint256 => mapping(IRisingTidesInventory.ItemType => mapping(uint256 => ShopItem))) public shopInventory;

    // Crafting
    mapping(uint256 => CraftingRecipe) public craftingRecipes;
    mapping(address => CraftingRequest) public activeCraftingRequests;
    mapping(uint256 => address) public requestIdToPlayer;
    uint256 public nextRequestId = 1;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAtPort() {
        // Get player's current position
        (int32 q, int32 r, uint256 mapId) = world.getPlayerLocation(msg.sender);

        // Check if player is at a port region
        if (!world.isPortRegion(mapId, q, r)) revert NotAtPort();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _world,
        address _inventory,
        address _fishing,
        address _fishingRod,
        address _doubloons,
        address _admin,
        address _gameMaster,
        address _vrfCoordinator
    ) {
        world = IRisingTidesWorld(_world);
        inventory = IRisingTidesInventory(_inventory);
        fishing = IRisingTidesFishing(_fishing);
        fishingRod = IRisingTidesFishingRod(_fishingRod);
        doubloons = IDoubloons(_doubloons);
        vrfCoordinator = IVRFCoordinator(_vrfCoordinator);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(GAME_MASTER_ROLE, _gameMaster);
    }

    /*//////////////////////////////////////////////////////////////
                            MARKET FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function sellFish(uint256[] calldata fishIndices) external onlyAtPort whenNotPaused nonReentrant {
        uint256 totalEarnings = 0;

        // Process each fish
        for (uint256 i = 0; i < fishIndices.length; i++) {
            uint256 earnings = _processFishSale(fishIndices[i]);
            totalEarnings += earnings;
        }

        // Mint earnings to player
        if (totalEarnings > 0) {
            doubloons.mint(msg.sender, totalEarnings);
        }
    }

    function sellAllFish() external onlyAtPort whenNotPaused nonReentrant {
        IRisingTidesInventory.Fish[] memory allFish = inventory.getFish(msg.sender);
        uint256 totalEarnings = 0;

        // Process fish in reverse order to avoid index shifting issues
        for (uint256 i = allFish.length; i > 0; i--) {
            uint256 earnings = _processFishSale(i - 1);
            totalEarnings += earnings;
        }

        // Mint earnings to player
        if (totalEarnings > 0) {
            doubloons.mint(msg.sender, totalEarnings);
        }
    }

    function _processFishSale(uint256 fishIndex) internal returns (uint256 earnings) {
        // Remove fish from inventory
        IRisingTidesInventory.Fish memory fish = inventory.removeFish(msg.sender, fishIndex);

        // Calculate freshness
        (FreshnessLevel freshness, uint256 valuePercent) =
            _calculateFreshnessLevel(fish.caughtAt, fish.fishId, fish.freshnessModifier);

        // Discard rotten fish
        if (freshness == FreshnessLevel.ROTTEN) {
            emit FishDiscarded(msg.sender, fish.fishId, fish.weight, "Rotten");
            return 0;
        }

        // Update market price before sale
        _updateMarketPrice(fish.fishId);

        // Calculate earnings
        MarketData storage market = marketData[fish.fishId];
        uint256 baseValue = (market.currentPrice * fish.weight) / PRECISION;
        earnings = (baseValue * valuePercent) / PERCENT_DIVISOR;

        // Apply trophy quality bonus
        if (fish.isTrophyQuality) {
            earnings = (earnings * TROPHY_MULTIPLIER) / PERCENT_DIVISOR;
        }

        // Apply price drop after sale
        _applyPriceDrop(fish.fishId, earnings);

        emit FishSold(msg.sender, fish.fishId, fish.weight, earnings, freshness, fish.isTrophyQuality);
    }

    function _calculateFreshnessLevel(uint256 caughtAt, uint256 fishId, uint256 freshnessModifier)
        internal
        view
        returns (FreshnessLevel level, uint256 valuePercent)
    {
        IRisingTidesFishing.FishSpecies memory species = fishing.getFishSpecies(fishId);
        uint256 decayRate = species.decayRate;

        // Apply freshness modifier (e.g., from Icy enchantment)
        if (freshnessModifier > 0 && freshnessModifier != 100) {
            decayRate = (decayRate * freshnessModifier) / PERCENT_DIVISOR;
        }

        uint256 timeSinceCatch = block.timestamp - caughtAt;
        uint256 decayPercent = (timeSinceCatch * PERCENT_DIVISOR) / decayRate;

        if (decayPercent >= ROTTEN_THRESHOLD) {
            return (FreshnessLevel.ROTTEN, ROTTEN_VALUE);
        } else if (decayPercent >= ROTTING_THRESHOLD) {
            return (FreshnessLevel.ROTTING, ROTTING_VALUE);
        } else if (decayPercent >= STALE_THRESHOLD) {
            return (FreshnessLevel.STALE, STALE_VALUE);
        } else {
            return (FreshnessLevel.FRESH, FRESH_VALUE);
        }
    }

    function _updateMarketPrice(uint256 fishId) internal {
        MarketData storage market = marketData[fishId];
        if (!market.exists) revert InvalidMarketData();

        if (block.timestamp > market.lastUpdateTime) {
            uint256 timePassed = block.timestamp - market.lastUpdateTime;
            uint256 recovery = timePassed * market.priceRecoveryRate;

            uint256 oldPrice = market.currentPrice;
            market.currentPrice = market.currentPrice + recovery;

            if (market.currentPrice > market.basePrice) {
                market.currentPrice = market.basePrice;
            }

            market.lastUpdateTime = block.timestamp;

            if (oldPrice != market.currentPrice) {
                emit MarketPriceUpdated(fishId, oldPrice, market.currentPrice, false);
            }
        }
    }

    function _applyPriceDrop(uint256 fishId, uint256 dblEarned) internal {
        MarketData storage market = marketData[fishId];

        uint256 priceDrop = (dblEarned * market.priceDropRate) / PRECISION;
        uint256 minPrice = (market.basePrice * MIN_PRICE_PERCENT) / PERCENT_DIVISOR;

        uint256 oldPrice = market.currentPrice;

        if (market.currentPrice > priceDrop + minPrice) {
            market.currentPrice -= priceDrop;
        } else {
            market.currentPrice = minPrice;
        }

        if (oldPrice != market.currentPrice) {
            emit MarketPriceUpdated(fishId, oldPrice, market.currentPrice, true);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            SHOP FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function buyItem(IRisingTidesInventory.ItemType itemType, uint256 itemId, uint256 amount)
        external
        onlyAtPort
        whenNotPaused
        nonReentrant
    {
        if (amount == 0) revert InvalidAmount();

        // Get player location for shop inventory
        (,, uint256 mapId) = world.getPlayerLocation(msg.sender);

        // Get shop item
        ShopItem memory item = shopInventory[mapId][itemType][itemId];
        if (!item.available) revert ItemNotAvailable();

        // Check player level
        if (world.getPlayerLevel(msg.sender) < item.requiredLevel) revert InsufficientLevel();

        // Calculate total cost
        uint256 totalCost = item.price * amount;

        // Burn payment from player
        doubloons.burn(msg.sender, totalCost);

        // Special handling for ships
        if (itemType == IRisingTidesInventory.ItemType.SHIP) {
            if (amount != 1) revert InvalidAmount();
            if (inventory.hasShip(msg.sender, itemId)) {
                revert ShipAlreadyOwned();
            }
        }

        // Grant items using unified function
        inventory.addItem(msg.sender, itemType, itemId, amount);

        emit ItemPurchased(msg.sender, itemType, itemId, amount, totalCost);
    }

    /*//////////////////////////////////////////////////////////////
                          CRAFTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function craftRod(uint256 recipeId) external onlyAtPort whenNotPaused nonReentrant returns (uint256 requestId) {
        // Check for existing crafting request
        if (activeCraftingRequests[msg.sender].isPending) {
            revert CraftingRequestPending();
        }

        // Get recipe
        CraftingRecipe storage recipe = craftingRecipes[recipeId];
        if (!recipe.exists) revert InvalidRecipe();

        // Check player level
        if (world.getPlayerLevel(msg.sender) < recipe.requiredLevel) revert InsufficientLevel();

        // Check map restriction if any (0 means all maps allowed)
        if (recipe.allowedMapsBitfield != 0) {
            (,, uint256 mapId) = world.getPlayerLocation(msg.sender);
            // Check if bit at position mapId is set
            if (mapId >= 256 || (recipe.allowedMapsBitfield & (uint256(1) << mapId)) == 0) {
                revert RecipeNotAvailableAtThisLocation();
            }
        }

        // Consume materials
        for (uint256 i = 0; i < recipe.materialIds.length; i++) {
            inventory.consumeItem(
                msg.sender, IRisingTidesInventory.ItemType.MATERIAL, recipe.materialIds[i], recipe.materialAmounts[i]
            );
        }

        // Burn DBL cost
        doubloons.burn(msg.sender, recipe.dblCost);

        // Create crafting request
        requestId = nextRequestId++;
        activeCraftingRequests[msg.sender] = CraftingRequest({
            player: msg.sender,
            requestId: requestId,
            recipeId: recipeId,
            timestamp: block.timestamp,
            isPending: true
        });
        requestIdToPlayer[requestId] = msg.sender;

        vrfCoordinator.requestRandomNumbers(1, uint256(blockhash(block.number - 1)));

        emit RodCraftingInitiated(msg.sender, requestId, recipeId, recipe.rodTypeId);
    }

    function rawFulfillRandomNumbers(uint256 requestId, uint256[] memory randomWords) external override {
        if (msg.sender != address(vrfCoordinator)) revert Unauthorized();
        address player = requestIdToPlayer[requestId];
        if (player == address(0)) revert InvalidRequestId();

        CraftingRequest storage request = activeCraftingRequests[player];
        if (!request.isPending || request.requestId != requestId) {
            revert InvalidRequestId();
        }

        // Get recipe
        CraftingRecipe storage recipe = craftingRecipes[request.recipeId];

        // Mint rod with random seed
        uint256 tokenId = fishingRod.mint(player, recipe.rodTypeId, randomWords[0]);

        // Check if rod is Strange (10% chance)
        bool isStrange = (randomWords[0] >> 192) % 100 < STRANGE_CHANCE;

        // Clear request
        request.isPending = false;
        delete requestIdToPlayer[requestId];

        emit RodCrafted(player, tokenId, recipe.rodTypeId, isStrange);
    }

    function repairRod(uint256 tokenId, uint256 durabilityToAdd) external onlyAtPort whenNotPaused nonReentrant {
        // Verify ownership
        if (IERC721(address(fishingRod)).ownerOf(tokenId) != msg.sender) {
            revert RodNotOwned();
        }

        // Get rod info
        (IRisingTidesFishingRod.RodInstance memory rod,,) = fishingRod.getRodInfo(tokenId);

        // Check if repair needed
        if (rod.currentDurability >= rod.maxDurability) {
            revert RodFullyRepaired();
        }

        // Cap durability to add at max
        uint256 actualDurabilityAdded = durabilityToAdd;
        if (rod.currentDurability + durabilityToAdd > rod.maxDurability) {
            actualDurabilityAdded = rod.maxDurability - rod.currentDurability;
        }

        // Calculate cost in DBL
        uint256 totalCost = actualDurabilityAdded * repairCostPerDurability;

        // Burn payment from player
        doubloons.burn(msg.sender, totalCost);

        // Repair rod
        fishingRod.repair(tokenId, actualDurabilityAdded);

        emit RodRepaired(msg.sender, tokenId, actualDurabilityAdded, totalCost);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getMarketPrice(uint256 fishId) external view returns (uint256 currentPrice, uint256 basePrice) {
        MarketData storage market = marketData[fishId];
        if (!market.exists) revert InvalidMarketData();

        // Calculate current price with recovery
        currentPrice = market.currentPrice;
        if (block.timestamp > market.lastUpdateTime) {
            uint256 timePassed = block.timestamp - market.lastUpdateTime;
            uint256 recovery = timePassed * market.priceRecoveryRate;
            currentPrice = currentPrice + recovery;
            if (currentPrice > market.basePrice) {
                currentPrice = market.basePrice;
            }
        }

        basePrice = market.basePrice;
    }

    function calculateFishValue(uint256 fishId, uint256 weight, FreshnessLevel freshness, bool isTrophyQuality)
        external
        view
        returns (uint256 value)
    {
        MarketData storage market = marketData[fishId];
        if (!market.exists) revert InvalidMarketData();

        // Get freshness value percent
        uint256 valuePercent;
        if (freshness == FreshnessLevel.FRESH) {
            valuePercent = FRESH_VALUE;
        } else if (freshness == FreshnessLevel.STALE) {
            valuePercent = STALE_VALUE;
        } else if (freshness == FreshnessLevel.ROTTING) {
            valuePercent = ROTTING_VALUE;
        } else {
            valuePercent = ROTTEN_VALUE;
        }

        // Calculate base value
        uint256 baseValue = (market.currentPrice * weight) / PRECISION;
        value = (baseValue * valuePercent) / PERCENT_DIVISOR;

        // Apply trophy bonus
        if (isTrophyQuality) {
            value = (value * TROPHY_MULTIPLIER) / PERCENT_DIVISOR;
        }
    }

    function getShopItem(uint256 mapId, IRisingTidesInventory.ItemType itemType, uint256 itemId)
        external
        view
        returns (ShopItem memory)
    {
        return shopInventory[mapId][itemType][itemId];
    }

    function getCraftingRecipe(uint256 recipeId) external view returns (CraftingRecipe memory) {
        return craftingRecipes[recipeId];
    }

    function getMarketData(uint256 fishId) external view returns (MarketData memory) {
        return marketData[fishId];
    }

    function getFreshnessLevel(uint256 caughtAt, uint256 decayRate, uint256 freshnessModifier)
        external
        view
        returns (FreshnessLevel level, uint256 valuePercent)
    {
        // Apply freshness modifier
        if (freshnessModifier > 0 && freshnessModifier != 100) {
            decayRate = (decayRate * freshnessModifier) / PERCENT_DIVISOR;
        }

        uint256 timeSinceCatch = block.timestamp - caughtAt;
        uint256 decayPercent = (timeSinceCatch * PERCENT_DIVISOR) / decayRate;

        if (decayPercent >= ROTTEN_THRESHOLD) {
            return (FreshnessLevel.ROTTEN, ROTTEN_VALUE);
        } else if (decayPercent >= ROTTING_THRESHOLD) {
            return (FreshnessLevel.ROTTING, ROTTING_VALUE);
        } else if (decayPercent >= STALE_THRESHOLD) {
            return (FreshnessLevel.STALE, STALE_VALUE);
        } else {
            return (FreshnessLevel.FRESH, FRESH_VALUE);
        }
    }

    function getActiveCraftingRequest(address player) external view returns (CraftingRequest memory) {
        return activeCraftingRequests[player];
    }

    function isRecipeAvailableAtMap(uint256 recipeId, uint256 mapId) external view returns (bool) {
        CraftingRecipe storage recipe = craftingRecipes[recipeId];
        if (!recipe.exists) return false;

        // Map ID must be less than 256
        if (mapId >= 256) return false;

        // If bitfield is 0, available everywhere
        if (recipe.allowedMapsBitfield == 0) return true;

        // Check if bit at position mapId is set
        return (recipe.allowedMapsBitfield & (uint256(1) << mapId)) != 0;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setMarketData(uint256 fishId, MarketData calldata data) external onlyRole(GAME_MASTER_ROLE) {
        if (data.basePrice == 0 || data.priceRecoveryRate == 0) {
            revert InvalidMarketData();
        }

        marketData[fishId] = data;
        marketData[fishId].exists = true;

        // Initialize current price if not set
        if (data.currentPrice == 0) {
            marketData[fishId].currentPrice = data.basePrice;
        }

        // Set last update time
        marketData[fishId].lastUpdateTime = block.timestamp;

        emit MarketDataSet(fishId, data.basePrice, data.priceDropRate, data.priceRecoveryRate);
    }

    function setShopItem(uint256 mapId, IRisingTidesInventory.ItemType itemType, uint256 itemId, ShopItem calldata item)
        external
        onlyRole(GAME_MASTER_ROLE)
    {
        shopInventory[mapId][itemType][itemId] = item;
        emit ShopItemSet(mapId, itemType, itemId, item.price, item.requiredLevel);
    }

    function setCraftingRecipe(uint256 recipeId, CraftingRecipe calldata recipe) external onlyRole(GAME_MASTER_ROLE) {
        craftingRecipes[recipeId] = recipe;
        craftingRecipes[recipeId].exists = true;
        emit CraftingRecipeSet(recipeId, recipe.rodTypeId, recipe.dblCost, recipe.requiredLevel);
    }

    function setVRFCoordinator(address coordinator) external onlyRole(ADMIN_ROLE) {
        vrfCoordinator = IVRFCoordinator(coordinator);
    }

    function setRepairCostPerDurability(uint256 cost) external onlyRole(GAME_MASTER_ROLE) {
        repairCostPerDurability = cost;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
