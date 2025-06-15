// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "../src/tokens/RisingTidesCurrency.sol";
import "../src/registries/ShipRegistry.sol";
import "../src/registries/FishRegistry.sol";
import "../src/core/GameState.sol";

contract GameStateTest is Test {
    RisingTidesCurrency public currency;
    ShipRegistry public shipRegistry;
    FishRegistry public fishRegistry;
    GameState public gameState;

    address public player1 = address(0x1);
    address public player2 = address(0x2);
    address public admin = address(this);

    function setUp() public {
        // Deploy contracts
        currency = new RisingTidesCurrency();
        shipRegistry = new ShipRegistry();
        fishRegistry = new FishRegistry();
        gameState = new GameState(
            address(currency),
            address(shipRegistry),
            address(fishRegistry)
        );

        // Setup roles
        currency.grantRole(currency.MINTER_ROLE(), address(this));
        currency.grantRole(currency.BURNER_ROLE(), address(gameState));

        // Add test ship
        _addTestShip();
        
        // Add test fish and bait
        _addTestFish();
        _addTestBait();

        // Give players some starting currency
        currency.mint(player1, 1000 * 10**18, "Test setup");
        currency.mint(player2, 1000 * 10**18, "Test setup");
    }

    function testPlayerRegistration() public {
        vm.prank(player1);
        gameState.registerPlayer(0);

        assertTrue(gameState.isPlayerRegistered(player1));
        
        GameState.PlayerState memory state = gameState.getPlayerState(player1);
        assertEq(state.position.x, 0);
        assertEq(state.position.y, 0);
        assertEq(state.shard, 0);
        assertEq(state.shipId, 1);
        assertTrue(state.isActive);
    }

    function testPlayerMovement() public {
        vm.prank(player1);
        gameState.registerPlayer(0);

        // Test valid movement
        vm.prank(player1);
        gameState.move(5, 3);

        GameState.PlayerState memory state = gameState.getPlayerState(player1);
        assertEq(state.position.x, 5);
        assertEq(state.position.y, 3);
    }

    function testFuelPurchase() public {
        vm.prank(player1);
        gameState.registerPlayer(0);

        uint256 initialFuel = gameState.getCurrentFuel(player1);
        uint256 fuelToBuy = 50;
        uint256 expectedCost = fuelToBuy * 10 * 10**18; // FUEL_PRICE_PER_UNIT

        vm.prank(player1);
        gameState.purchaseFuel(fuelToBuy);

        assertEq(gameState.getCurrentFuel(player1), initialFuel + fuelToBuy);
        assertEq(currency.balanceOf(player1), 1000 * 10**18 - expectedCost);
    }

    function testFishing() public {
        vm.prank(player1);
        gameState.registerPlayer(0);

        uint256 initialBalance = currency.balanceOf(player1);
        uint8 baitType = 1;

        vm.prank(player1);
        (uint8 species, uint16 weight) = gameState.fish(baitType);

        // Check that bait cost was deducted
        uint256 baitCost = 5 * 10**18; // Basic bait price
        assertEq(currency.balanceOf(player1), initialBalance - baitCost);

        // If a fish was caught, check that it was recorded
        if (species > 0) {
            assertEq(gameState.getPlayerFishCount(player1), 1);
            
            GameState.FishCatch memory fish = gameState.getPlayerFish(player1, 0);
            assertEq(fish.species, species);
            assertEq(fish.weight, weight);
            assertTrue(fish.caughtAt > 0);
        }
    }

    function testInvalidMovement() public {
        vm.prank(player1);
        gameState.registerPlayer(0);

        // Test movement out of bounds
        vm.prank(player1);
        vm.expectRevert("X coordinate out of bounds");
        gameState.move(2000, 0);

        vm.prank(player1);
        vm.expectRevert("Y coordinate out of bounds");
        gameState.move(0, -2000);
    }

    function testUnregisteredPlayerActions() public {
        // Test that unregistered players cannot perform actions
        vm.prank(player1);
        vm.expectRevert("Player not registered");
        gameState.move(1, 1);

        vm.prank(player1);
        vm.expectRevert("Player not registered");
        gameState.purchaseFuel(10);

        vm.prank(player1);
        vm.expectRevert("Player not registered");
        gameState.fish(1);
    }

    function testShardChange() public {
        vm.prank(player1);
        gameState.registerPlayer(0);

        vm.prank(player1);
        gameState.changeShard(5);

        GameState.PlayerState memory state = gameState.getPlayerState(player1);
        assertEq(state.shard, 5);
    }

    function _addTestShip() private {
        bytes memory cargoShape = new bytes(2);
        cargoShape[0] = 0xFF;
        cargoShape[1] = 0xFF;
        
        uint8[] memory engineSlots = new uint8[](1);
        engineSlots[0] = 0;
        
        uint8[] memory equipmentSlots = new uint8[](1);
        equipmentSlots[0] = 15;

        shipRegistry.registerShip(
            1,
            "Test Ship",
            100,
            50,
            100,
            4,
            4,
            cargoShape,
            engineSlots,
            equipmentSlots,
            0,
            10 * 10**18
        );
    }

    function _addTestFish() private {
        uint8[] memory baits = new uint8[](1);
        baits[0] = 1;
        uint16[] memory probabilities = new uint16[](1);
        probabilities[0] = 5000;
        
        bytes memory shape = new bytes(1);
        shape[0] = 0x01;
        
        fishRegistry.registerFishSpecies(
            1,
            "Test Fish",
            100 * 10**18,
            1,
            50,
            150,
            1,
            1,
            shape,
            5,
            baits,
            probabilities
        );
    }

    function _addTestBait() private {
        fishRegistry.registerBaitType(
            1,
            "Test Bait",
            5 * 10**18
        );
    }
}