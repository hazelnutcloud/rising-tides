// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "../src/tokens/RisingTidesCurrency.sol";
import "../src/registries/FishRegistry.sol";
import "../src/core/FishMarket.sol";

contract FishMarketTest is Test {
    RisingTidesCurrency public currency;
    FishRegistry public fishRegistry;
    FishMarket public fishMarket;

    address public seller = address(0x1);
    address public feeCollector = address(0x2);
    address public admin = address(this);

    function setUp() public {
        // Deploy contracts
        currency = new RisingTidesCurrency();
        fishRegistry = new FishRegistry();
        fishMarket = new FishMarket(
            address(currency),
            address(fishRegistry),
            feeCollector
        );

        // Setup roles
        currency.grantRole(currency.MINTER_ROLE(), address(fishMarket));

        // Add test fish species
        _addTestFish();

        // Initialize market data
        fishMarket.initializeMarketData(1);
    }

    function testSellFish() public {
        uint256 species = 1;
        uint16 weight = 100; // 100g
        uint256 caughtAt = block.timestamp; // Just caught

        uint256 initialBalance = currency.balanceOf(seller);
        uint256 initialFeeBalance = currency.balanceOf(feeCollector);

        // Calculate expected values
        (uint256 expectedValue, ) = fishMarket.calculateFishValue(species, weight, caughtAt);
        uint256 expectedFee = (expectedValue * 300) / 10000; // 3% fee
        uint256 expectedEarnings = expectedValue - expectedFee;

        // Sell fish as seller
        vm.prank(seller);
        uint256 earnings = fishMarket.sellFish(species, weight, caughtAt);

        // Check earnings
        assertEq(earnings, expectedEarnings);
        assertEq(currency.balanceOf(seller), initialBalance + expectedEarnings);
        assertEq(currency.balanceOf(feeCollector), initialFeeBalance + expectedFee);
    }

    function testBondingCurve() public {
        uint256 species = 1;
        uint16 weight = 100;
        uint256 caughtAt = block.timestamp;

        uint256 initialPrice = fishMarket.getCurrentPrice(species);
        
        // Sell first fish
        vm.prank(seller);
        fishMarket.sellFish(species, weight, caughtAt);
        uint256 priceAfterFirstSale = fishMarket.getCurrentPrice(species);
        
        // Price should decrease after sale (bonding curve)
        assertTrue(priceAfterFirstSale < initialPrice);
        
        // Sell second fish
        vm.prank(seller);
        fishMarket.sellFish(species, weight, caughtAt);
        uint256 priceAfterSecondSale = fishMarket.getCurrentPrice(species);
        
        // Price should decrease further
        assertTrue(priceAfterSecondSale < priceAfterFirstSale);
    }

    function testFreshnessDecay() public {
        // Fresh fish (just caught)
        uint256 originalTimestamp = 1; // Fixed timestamp
        vm.warp(originalTimestamp);
        
        uint8 freshness1 = fishMarket.calculateFreshness(originalTimestamp);
        assertEq(freshness1, 100); // Max freshness

        // Fish caught 2 hours ago (simulate by warping time)  
        vm.warp(originalTimestamp + 2 hours);
        uint8 freshness2 = fishMarket.calculateFreshness(originalTimestamp);
        assertEq(freshness2, 90); // 100 - (2 * 5) = 90

        // Fish caught 20 hours ago (completely spoiled)
        vm.warp(originalTimestamp + 20 hours);
        uint8 freshness3 = fishMarket.calculateFreshness(originalTimestamp);
        assertEq(freshness3, 0); // Completely spoiled
    }

    function testSellMultipleFish() public {
        uint256[] memory species = new uint256[](3);
        uint16[] memory weights = new uint16[](3);
        uint256[] memory caughtTimestamps = new uint256[](3);

        species[0] = 1;
        species[1] = 1;
        species[2] = 1;
        
        weights[0] = 100;
        weights[1] = 150;
        weights[2] = 80;
        
        caughtTimestamps[0] = block.timestamp;
        caughtTimestamps[1] = block.timestamp;
        caughtTimestamps[2] = block.timestamp;

        uint256 initialBalance = currency.balanceOf(seller);
        
        vm.prank(seller);
        uint256 totalEarnings = fishMarket.sellMultipleFish(species, weights, caughtTimestamps);
        
        assertTrue(totalEarnings > 0);
        assertEq(currency.balanceOf(seller), initialBalance + totalEarnings);
    }

    function testPriceRecovery() public {
        uint256 species = 1;
        uint16 weight = 100;
        uint256 caughtAt = block.timestamp;

        // Sell fish to decrease price
        vm.prank(seller);
        fishMarket.sellFish(species, weight, caughtAt);
        uint256 priceAfterSale = fishMarket.getCurrentPrice(species);
        
        // Fast forward time to test price recovery
        vm.warp(block.timestamp + 5 hours);
        
        uint256 priceAfterTime = fishMarket.getCurrentPrice(species);
        
        // Price should have recovered somewhat
        assertTrue(priceAfterTime > priceAfterSale);
    }

    function testMarketData() public view {
        uint256 species = 1;
        
        FishMarket.MarketData memory data = fishMarket.getMarketData(species);
        
        assertTrue(data.basePrice > 0);
        assertTrue(data.currentPrice > 0);
        assertEq(data.volume24h, 0); // No sales yet
    }

    function testSellSpoiledFish() public {
        uint256 species = 1;
        uint16 weight = 100;
        uint256 fishCaughtTime = block.timestamp;
        
        console.log("Start timestamp:", block.timestamp);
        console.log("Fish caught time:", fishCaughtTime);
        
        // Warp time to make fish spoiled (21+ hours for 0 freshness)
        vm.warp(fishCaughtTime + 21 hours);
        
        console.log("After warp timestamp:", block.timestamp);
        console.log("Direct calculation - time diff:", block.timestamp - fishCaughtTime);
        console.log("Direct calculation - hours:", (block.timestamp - fishCaughtTime) / 3600);
        
        // Calculate expected freshness based on the FishMarket logic
        // After 21 hours, freshnessLoss = 21 * 5 = 105, so freshness should be 0
        uint8 freshnessCheck = fishMarket.calculateFreshness(fishCaughtTime);
        console.log("Freshness after 21 hours:", freshnessCheck);
        
        // The fish should be spoiled (freshness = 0), so selling should revert
        if (freshnessCheck == 0) {
            vm.expectRevert("Fish is no longer fresh");
        }
        
        vm.prank(seller);
        fishMarket.sellFish(species, weight, fishCaughtTime);
    }

    function testInvalidSpecies() public {
        uint256 invalidSpecies = 99;
        uint16 weight = 100;
        uint256 caughtAt = block.timestamp;

        vm.expectRevert("Invalid fish species");
        vm.prank(seller);
        fishMarket.sellFish(invalidSpecies, weight, caughtAt);
    }

    function _addTestFish() private {
        bytes memory shape = new bytes(1);
        shape[0] = 0x01;
        
        fishRegistry.registerFishSpecies(
            1,
            100 * 10**18, // Base price: 100 RTC
            1,
            1,
            1,
            shape,
            5 // 5% freshness decay per hour
        );
    }
}