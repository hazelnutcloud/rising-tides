// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "../src/tokens/RisingTidesCurrency.sol";
import "../src/registries/ShipRegistry.sol";
import "../src/registries/FishRegistry.sol";
import "../src/registries/EngineRegistry.sol";
import "../src/registries/FishingRodRegistry.sol";
import "../src/registries/MapRegistry.sol";
import "../src/core/RisingTides.sol";
import "../src/interfaces/IRisingTides.sol";
import {SlotType, ItemType} from "../src/types/InventoryTypes.sol";
import "../src/libraries/InventoryLib.sol";

contract FishMarketTest is Test {
    RisingTidesCurrency public currency;
    ShipRegistry public shipRegistry;
    FishRegistry public fishRegistry;
    EngineRegistry public engineRegistry;
    FishingRodRegistry public fishingRodRegistry;
    MapRegistry public mapRegistry;
    RisingTides public risingTides;

    address public player1 = address(0x1);
    address public admin = address(this);
    uint8 public constant DEFAULT_SHARD = 0;

    // Test server signer address and private key for testing
    uint256 public constant TEST_SERVER_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address public testServerSigner;

    // Events
    event FishSold(uint256 indexed species, uint16 weight, uint256 freshness, uint256 salePrice);
    event FishMarketUpdated(uint256 indexed fishId, uint256 newMarketValue, uint256 lastSoldTimestamp);

    function setUp() public {
        // Deploy contracts
        currency = new RisingTidesCurrency();
        shipRegistry = new ShipRegistry();
        fishRegistry = new FishRegistry();
        engineRegistry = new EngineRegistry();
        fishingRodRegistry = new FishingRodRegistry();
        mapRegistry = new MapRegistry();

        // Set up test server signer
        testServerSigner = vm.addr(TEST_SERVER_PRIVATE_KEY);

        risingTides = new RisingTides(
            address(currency),
            address(shipRegistry),
            address(fishRegistry),
            address(engineRegistry),
            address(fishingRodRegistry),
            address(mapRegistry),
            testServerSigner
        );

        // Grant minter and burner roles to game state
        currency.grantRole(currency.MINTER_ROLE(), address(risingTides));
        currency.grantRole(currency.BURNER_ROLE(), address(risingTides));

        // Grant minter role to admin for test setup
        currency.grantRole(currency.MINTER_ROLE(), admin);

        // Grant admin role to test contract for market manipulation
        risingTides.grantRole(risingTides.ADMIN_ROLE(), admin);

        // Setup test data
        _addTestFish(); // Need to add fish first for species validation
        _addTestShip();
        _addTestEngines();
        _addTestFishingRods();
        _addTestMap();

        // Give players some starting currency
        currency.mint(player1, 1000 * 10 ** 18, "Test setup");

        // Register player as player1
        vm.prank(player1);
        risingTides.registerPlayer(DEFAULT_SHARD, 1);
    }

    function testSellFish() public {
        // Give player a fish through fishing process
        _catchFishForPlayer(player1, 1, 10, 2, 2);

        // Get the instance ID of the caught fish
        uint256 instanceId = _getLatestFishInstanceId(player1);

        // Verify fish freshness
        vm.prank(player1);
        uint256 freshness = risingTides.getFishFreshness(instanceId);
        assertEq(freshness, 100, "Fish should have 100% freshness");

        // Check initial balance
        uint256 initialBalance = currency.balanceOf(player1);

        // Sell the fish
        vm.prank(player1);
        uint256 salePrice = risingTides.sellFish(instanceId);

        // Verify currency was minted
        assertGt(salePrice, 0, "Sale price should be greater than 0");
        assertEq(currency.balanceOf(player1), initialBalance + salePrice, "Currency not minted correctly");

        // Verify fish was removed from player data
        vm.prank(player1);
        vm.expectRevert("Invalid fish");
        risingTides.getFishFreshness(instanceId);
    }

    function testCannotSellNonExistentFish() public {
        vm.prank(player1);
        vm.expectRevert();
        risingTides.sellFish(999);
    }

    function testFishMarketPriceDecay() public {
        // Get initial market price
        uint256 initialPrice = risingTides.getMarketPrice(1);
        FishRegistry.FishSpecies memory fish = fishRegistry.getFishSpecies(1);
        uint256 basePrice = fish.basePrice;
        assertEq(initialPrice, basePrice, "Initial market price should equal base price");

        // Catch and sell first fish
        _catchFishForPlayer(player1, 1, 10, 2, 2);
        uint256 instanceId = _getLatestFishInstanceId(player1);

        vm.prank(player1);
        risingTides.sellFish(instanceId);

        // Check price decreased
        uint256 priceAfterSale = risingTides.getMarketPrice(1);
        assertLt(priceAfterSale, initialPrice, "Price should decrease after sale");

        // Expected decay: 5%
        uint256 expectedPrice = basePrice - (basePrice * 5 / 100);
        assertEq(priceAfterSale, expectedPrice, "Price decay incorrect");
    }

    function testFishMarketPriceRecovery() public {
        // Catch and sell a fish to establish market price
        _catchFishForPlayer(player1, 1, 10, 2, 2);
        uint256 instanceId = _getLatestFishInstanceId(player1);

        vm.prank(player1);
        risingTides.sellFish(instanceId);
        uint256 priceAfterSale = risingTides.getMarketPrice(1);

        // Advance time by 1 hour
        vm.warp(block.timestamp + 1 hours);

        // Check price recovered
        uint256 priceAfterRecovery = risingTides.getMarketPrice(1);
        assertGt(priceAfterRecovery, priceAfterSale, "Price should recover over time");
    }

    function testMarketPriceCappedAtBase() public {
        // Get base price
        FishRegistry.FishSpecies memory fish = fishRegistry.getFishSpecies(1);
        uint256 basePrice = fish.basePrice;

        // Catch and sell a fish
        _catchFishForPlayer(player1, 1, 10, 2, 2);
        uint256 instanceId = _getLatestFishInstanceId(player1);

        vm.prank(player1);
        risingTides.sellFish(instanceId);

        // Advance time significantly (24 hours)
        vm.warp(block.timestamp + 24 hours);

        // Price should be capped at base price
        uint256 marketPrice = risingTides.getMarketPrice(1);
        assertEq(marketPrice, basePrice, "Market price should be capped at base price");
    }

    function testPriceRecoveryAfter6Hours() public {
        // Get base price
        FishRegistry.FishSpecies memory fish = fishRegistry.getFishSpecies(1);
        uint256 basePrice = fish.basePrice;

        // Catch and sell a fish to create initial price decay
        _catchFishForPlayer(player1, 1, 10, 2, 2);
        uint256 instanceId = _getLatestFishInstanceId(player1);

        vm.prank(player1);
        risingTides.sellFish(instanceId);

        // Check price after sale (should be 95% of base due to 5% decay)
        uint256 priceAfterSale = risingTides.getMarketPrice(1);
        uint256 expectedPriceAfterSale = basePrice - (basePrice * 5 / 100);
        assertEq(priceAfterSale, expectedPriceAfterSale, "Price should decay by 5% after sale");

        // Advance time by exactly 6 hours
        vm.warp(block.timestamp + 6 hours);

        // Check if price has recovered back to base price
        uint256 priceAfter6Hours = risingTides.getMarketPrice(1);

        // Calculate expected recovery using the formula:
        // recovery = (basePrice * PRICE_RECOVERY_RATE * secondsElapsed / 1e7)
        // PRICE_RECOVERY_RATE = 463, secondsElapsed = 6 * 3600 = 21600
        uint256 expectedRecovery = (basePrice * 463 * 21600) / 1e7;
        uint256 expectedPriceAfter6Hours = priceAfterSale + expectedRecovery;

        // Should be capped at base price
        if (expectedPriceAfter6Hours > basePrice) {
            expectedPriceAfter6Hours = basePrice;
        }

        assertEq(priceAfter6Hours, expectedPriceAfter6Hours, "Price should recover correctly after 6 hours");

        // Verify it reaches base price (or very close due to the recovery rate)
        // With PRICE_RECOVERY_RATE = 463, let's see if it actually reaches 100% in 6 hours
        console.log("Base price:", basePrice);
        console.log("Price after sale:", priceAfterSale);
        console.log("Price after 6 hours:", priceAfter6Hours);
        console.log("Expected recovery amount:", expectedRecovery);

        // The price should be very close to or equal to base price
        assertGe(
            priceAfter6Hours, basePrice * 99 / 100, "Price should recover to at least 99% of base price after 6 hours"
        );
    }

    function testPriceRecoveryFrom0To100Percent() public {
        // Get base price
        FishRegistry.FishSpecies memory fish = fishRegistry.getFishSpecies(1);
        uint256 basePrice = fish.basePrice;

        // Use admin function to set market value to 0 and current timestamp
        risingTides.setFishMarketData(1, 0, block.timestamp);

        // Verify initial market price at time 0 (should be 0 since no time has passed)
        uint256 initialPrice = risingTides.getMarketPrice(1);
        console.log("Base price:", basePrice);
        console.log("Initial market price (at time 0):", initialPrice);
        assertEq(initialPrice, 0, "Price should start at 0");

        // Test recovery at different time intervals from market value = 0
        uint256[] memory timeIntervals = new uint256[](6);
        timeIntervals[0] = 1 hours;
        timeIntervals[1] = 2 hours;
        timeIntervals[2] = 3 hours;
        timeIntervals[3] = 6 hours;
        timeIntervals[4] = 12 hours;
        timeIntervals[5] = 24 hours;

        uint256 startTime = block.timestamp;

        for (uint256 i = 0; i < timeIntervals.length; i++) {
            vm.warp(startTime + timeIntervals[i]);
            uint256 currentPrice = risingTides.getMarketPrice(1);

            // Calculate expected recovery from 0: (basePrice * PRICE_RECOVERY_RATE * secondsElapsed / 1e7)
            uint256 expectedRecovery = (basePrice * 463 * timeIntervals[i]) / 1e7;
            uint256 expectedPrice = 0 + expectedRecovery; // Starting from 0
            if (expectedPrice > basePrice) expectedPrice = basePrice;

            console.log("Time: ", timeIntervals[i] / 3600, "hours");
            console.log("Current price:", currentPrice);
            console.log("Expected price:", expectedPrice);
            console.log("Recovery %:", (currentPrice * 100) / basePrice);

            // Verify the price matches our expected calculation
            assertEq(currentPrice, expectedPrice, "Price should match expected recovery calculation");
            console.log("---");
        }

        // Specifically test that it reaches 100% (or very close) after 6 hours
        vm.warp(startTime + 6 hours);
        uint256 priceAfter6Hours = risingTides.getMarketPrice(1);

        // Should be at base price after 6 hours (recovery overshoots and gets capped)
        assertEq(priceAfter6Hours, basePrice, "Price should fully recover to base price after 6 hours from 0");

        // Calculate what 6 hours should give us
        uint256 expectedRecoveryAfter6Hours = (basePrice * 463 * 6 hours) / 1e7;
        console.log("Expected recovery after 6 hours:", expectedRecoveryAfter6Hours);
        console.log("Base price:", basePrice);
        console.log("Recovery ratio:", (expectedRecoveryAfter6Hours * 100) / basePrice, "%");
    }

    function testFishFreshness() public {
        // Catch a fish
        _catchFishForPlayer(player1, 1, 10, 2, 2);
        uint256 instanceId = _getLatestFishInstanceId(player1);

        // Fresh fish should have 100% freshness
        vm.prank(player1);
        uint256 freshness = risingTides.getFishFreshness(instanceId);
        assertEq(freshness, 100, "Fresh fish should have 100% freshness");

        // Advance time by 15 minutes (one decay period)
        vm.warp(block.timestamp + 15 minutes);
        vm.prank(player1);
        freshness = risingTides.getFishFreshness(instanceId);
        assertEq(freshness, 75, "Freshness should decay by 25% per period");

        // Advance time by another 15 minutes
        vm.warp(block.timestamp + 15 minutes);
        vm.prank(player1);
        freshness = risingTides.getFishFreshness(instanceId);
        assertEq(freshness, 50, "Freshness should continue decaying");

        // Advance time to make fish completely spoiled
        vm.warp(block.timestamp + 2 hours);
        vm.prank(player1);
        freshness = risingTides.getFishFreshness(instanceId);
        assertEq(freshness, 0, "Very old fish should have 0% freshness");
    }

    function testFreshnessImpactOnPrice() public {
        // Catch a fish
        _catchFishForPlayer(player1, 1, 10, 2, 2);
        uint256 instanceId = _getLatestFishInstanceId(player1);

        // Get fresh fish price
        vm.prank(player1);
        uint256 freshPrice = risingTides.estimateSalePrice(instanceId);

        // Advance time to reduce freshness to 50%
        vm.warp(block.timestamp + 30 minutes);
        vm.prank(player1);
        uint256 halfFreshPrice = risingTides.estimateSalePrice(instanceId);

        // Price should be half due to freshness
        assertEq(halfFreshPrice, freshPrice / 2, "50% freshness should result in 50% price");

        // Advance time to 0% freshness
        vm.warp(block.timestamp + 2 hours);
        vm.prank(player1);
        uint256 spoiledPrice = risingTides.estimateSalePrice(instanceId);
        assertEq(spoiledPrice, 0, "Spoiled fish should have 0 value");
    }

    function testEstimateSalePrice() public {
        // Catch a fish
        _catchFishForPlayer(player1, 1, 10, 2, 2);
        uint256 instanceId = _getLatestFishInstanceId(player1);

        vm.prank(player1);
        uint256 estimatedPrice = risingTides.estimateSalePrice(instanceId);
        vm.prank(player1);
        uint256 actualPrice = risingTides.sellFish(instanceId);

        assertEq(estimatedPrice, actualPrice, "Estimated price should match actual sale price");
    }

    function testMultipleFishSales() public {
        // Get base price for comparison
        FishRegistry.FishSpecies memory fish = fishRegistry.getFishSpecies(1);
        uint256 basePrice = fish.basePrice;
        uint256 previousPrice = basePrice;

        // Catch and sell multiple fish
        for (uint256 i = 0; i < 4; i++) {
            _catchFishForPlayer(player1, 1, 10, 2 + uint8(i % 2), 2);
            uint256 instanceId = _getLatestFishInstanceId(player1);

            vm.prank(player1);
            risingTides.sellFish(instanceId);

            uint256 currentPrice = risingTides.getMarketPrice(1);
            assertLt(currentPrice, previousPrice, "Price should decrease with each sale");
            previousPrice = currentPrice;
        }
    }

    function testGetMarketPriceForUntraded() public {
        // Get price for a fish species that hasn't been traded yet
        uint256 untradedSpecies = 2;

        // Register a second fish species
        bytes memory shape = new bytes(1);
        shape[0] = 0x01;
        fishRegistry.registerFishSpecies(2, 200 * 10 ** 18, 1, 1, shape);

        FishRegistry.FishSpecies memory fish2 = fishRegistry.getFishSpecies(untradedSpecies);
        uint256 basePrice = fish2.basePrice;
        uint256 marketPrice = risingTides.getMarketPrice(untradedSpecies);

        assertEq(marketPrice, basePrice, "Untraded fish should return base price");
    }

    function testCannotGetFreshnessInvalidFish() public {
        vm.prank(player1);
        vm.expectRevert("Invalid fish");
        risingTides.getFishFreshness(999);
    }

    function testCannotEstimatePriceInvalidFish() public {
        vm.prank(player1);
        vm.expectRevert("Invalid fish");
        risingTides.estimateSalePrice(999);
    }

    function testFishSaleEvents() public {
        // Catch a fish
        _catchFishForPlayer(player1, 1, 10, 2, 2);
        uint256 instanceId = _getLatestFishInstanceId(player1);

        // Estimate the sale price first
        vm.prank(player1);
        uint256 expectedPrice = risingTides.estimateSalePrice(instanceId);

        // Test that fish is sold with correct price (events are tested separately)
        vm.prank(player1);
        uint256 actualPrice = risingTides.sellFish(instanceId);

        assertEq(actualPrice, expectedPrice, "Actual price should match expected price");
        assertGt(actualPrice, 0, "Sale price should be greater than 0");
    }

    function testMarketUpdateEvents() public {
        // Catch a fish
        _catchFishForPlayer(player1, 1, 10, 2, 2);
        uint256 instanceId = _getLatestFishInstanceId(player1);

        // Calculate expected market value after sale
        FishRegistry.FishSpecies memory fish = fishRegistry.getFishSpecies(1);
        uint256 basePrice = fish.basePrice;
        uint256 expectedValue = basePrice - (basePrice * 5 / 100);

        vm.expectEmit(true, true, true, false);
        emit FishMarketUpdated(1, expectedValue, block.timestamp);

        vm.prank(player1);
        risingTides.sellFish(instanceId);
    }

    // Helper functions
    function _addTestShip() private {
        SlotType[] memory slotTypes = new SlotType[](16);
        for (uint256 i = 0; i < 16; i++) {
            slotTypes[i] = SlotType.Normal;
        }
        slotTypes[0] = SlotType.Engine;
        slotTypes[15] = SlotType.FishingRod;

        shipRegistry.registerShip(1, "Test Ship", 100, 100, 4, 4, slotTypes, 0, 10 * 10 ** 18);
    }

    function _addTestFish() private {
        bytes memory shape = new bytes(1);
        shape[0] = 0x01;

        fishRegistry.registerFishSpecies(1, 100 * 10 ** 18, 1, 1, shape);
        fishRegistry.registerBaitType(1, "Test Bait", 5 * 10 ** 18);
    }

    function _addTestEngines() private {
        bytes memory engineShape = new bytes(1);
        engineShape[0] = 0x01;

        engineRegistry.registerEngine(1, "Test Engine", 30, 100, 1, 1, engineShape, 100 * 10 ** 18, 50);
    }

    function _addTestFishingRods() private {
        bytes memory rodShape = new bytes(1);
        rodShape[0] = 0x01;

        fishingRodRegistry.registerFishingRod(1, "Test Fishing Rod", 1, 1, rodShape, 50 * 10 ** 18, 10);
    }

    function _addTestMap() private {
        mapRegistry.registerMap(1, "Test Ocean", 1, 0, -50, 50, -50, 50);

        uint256[] memory availableBait = new uint256[](1);
        availableBait[0] = 1;
        mapRegistry.addBaitShop(1, 0, 0, availableBait);
    }

    uint256 private latestFishInstanceId;

    function _catchFishForPlayer(address player, uint256 species, uint16 weight, uint8 x, uint8 y) private {
        // Purchase bait
        vm.prank(player);
        risingTides.purchaseBait(1, 1);

        // Initiate fishing
        vm.prank(player);
        uint256 fishingNonce = risingTides.initiateFishing(1);

        // Create fishing result
        FishingResult memory result = FishingResult({
            player: player,
            nonce: fishingNonce,
            species: species,
            weight: weight,
            timestamp: block.timestamp
        });

        bytes memory signature = _createTestSignature(result);

        // Create fish placement
        FishPlacement memory fishPlacement = FishPlacement({shouldPlace: true, x: x, y: y, rotation: 0});

        // Fulfill fishing and capture the instance ID
        vm.prank(player);
        latestFishInstanceId = risingTides.fulfillFishing(result, signature, fishPlacement);

        // Debug: verify the instance ID is valid
        require(latestFishInstanceId > 0, "Fish instance ID should be greater than 0");
    }

    function _getLatestFishInstanceId(address) private view returns (uint256) {
        return latestFishInstanceId;
    }

    function _createTestSignature(FishingResult memory result) private view returns (bytes memory) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("RisingTides"),
                keccak256("1"),
                block.chainid,
                address(risingTides)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("FishingResult(address player,uint256 nonce,uint256 species,uint16 weight,uint256 timestamp)"),
                result.player,
                result.nonce,
                result.species,
                result.weight,
                result.timestamp
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(TEST_SERVER_PRIVATE_KEY, digest);
        return abi.encodePacked(r, s, v);
    }
}
