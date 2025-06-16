// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "../src/tokens/RisingTidesCurrency.sol";
import "../src/registries/ShipRegistry.sol";
import "../src/registries/FishRegistry.sol";
import "../src/registries/MapRegistry.sol";
import "../src/core/GameState.sol";
import "../src/interfaces/IGameState.sol";

contract GameStateTest is Test {
    RisingTidesCurrency public currency;
    ShipRegistry public shipRegistry;
    FishRegistry public fishRegistry;
    MapRegistry public mapRegistry;
    GameState public gameState;

    address public player1 = address(0x1);
    address public player2 = address(0x2);
    address public admin = address(this);

    function setUp() public {
        // Deploy contracts
        currency = new RisingTidesCurrency();
        shipRegistry = new ShipRegistry();
        fishRegistry = new FishRegistry();
        mapRegistry = new MapRegistry();

        gameState = new GameState(address(currency), address(shipRegistry), address(fishRegistry), address(mapRegistry));

        // Setup roles
        currency.grantRole(currency.MINTER_ROLE(), address(this));
        currency.grantRole(currency.BURNER_ROLE(), address(gameState));

        // Add test ship, map, fish and bait
        _addTestShip();
        _addTestMap();
        _addTestFish();
        _addTestBait();

        // Give players some starting currency
        currency.mint(player1, 1000 * 10 ** 18, "Test setup");
        currency.mint(player2, 1000 * 10 ** 18, "Test setup");
    }

    function testPlayerRegistration() public {
        vm.prank(player1);
        gameState.registerPlayer(0, 1); // shard 0, map 1

        assertTrue(gameState.isPlayerRegistered(player1));

        GameState.PlayerState memory state = gameState.getPlayerState(player1);
        assertEq(state.position.x, 0);
        assertEq(state.position.y, 0);
        assertEq(state.shard, 0);
        assertEq(state.mapId, 1);
        assertEq(state.shipId, 1);
        assertTrue(state.isActive);
    }

    function testPlayerMovement() public {
        vm.prank(player1);
        gameState.registerPlayer(0, 1); // shard 0, map 1

        // Test valid movement using direction array
        // Direction 1 = E, Direction 2 = SE
        uint8[] memory directions = new uint8[](2);
        directions[0] = 1; // East
        directions[1] = 2; // Southeast

        vm.prank(player1);
        gameState.move(directions);

        GameState.PlayerState memory state = gameState.getPlayerState(player1);
        // After E then SE: (0,0) -> (1,-1) -> (1,-2)
        assertEq(state.position.x, 1);
        assertEq(state.position.y, -2);
    }

    function testFuelPurchase() public {
        vm.prank(player1);
        gameState.registerPlayer(0, 1); // shard 0, map 1

        uint256 initialFuel = gameState.getCurrentFuel(player1);
        uint256 fuelToBuy = 50;
        uint256 expectedCost = fuelToBuy * 10 * 10 ** 18; // FUEL_PRICE_PER_UNIT

        vm.prank(player1);
        gameState.purchaseFuel(fuelToBuy);

        assertEq(gameState.getCurrentFuel(player1), initialFuel + fuelToBuy);
        assertEq(currency.balanceOf(player1), 1000 * 10 ** 18 - expectedCost);
    }

    function testFishing() public {
        vm.prank(player1);
        gameState.registerPlayer(0, 1); // shard 0, map 1

        // Give player some bait first
        uint256 baitType = 1;
        uint256 baitAmount = 5;

        vm.prank(player1);
        gameState.purchaseBait(baitType, baitAmount);

        uint256 initialBaitCount = gameState.getPlayerBait(player1, baitType);
        assertEq(initialBaitCount, baitAmount);

        // Test initiate fishing - should succeed and return nonce
        vm.prank(player1);
        uint256 fishingNonce = gameState.initiateFishing(baitType);
        assertEq(fishingNonce, 1); // First fishing attempt should be nonce 1

        // Check bait was consumed
        uint256 afterBaitCount = gameState.getPlayerBait(player1, baitType);
        assertEq(afterBaitCount, baitAmount - 1);

        // Test server completing the fishing with a catch
        uint256 species = 1;
        uint16 weight = 500;
        gameState.completeServerFishing(player1, fishingNonce, species, weight);

        // Check fish was added to player inventory
        assertEq(gameState.getPlayerFishCount(player1), 1);

        // Check the specific fish data
        IGameState.FishCatch memory caughtFish = gameState.getPlayerFish(player1, 0);
        assertEq(caughtFish.species, species);
        assertEq(caughtFish.weight, weight);
    }

    function testFishingPendingGuard() public {
        vm.prank(player1);
        gameState.registerPlayer(0, 1); // shard 0, map 1

        // Give player some bait
        uint256 baitType = 1;
        uint256 baitAmount = 5;

        vm.prank(player1);
        gameState.purchaseBait(baitType, baitAmount);

        // First fishing attempt should succeed
        vm.prank(player1);
        uint256 fishingNonce = gameState.initiateFishing(baitType);
        assertEq(fishingNonce, 1);

        // Second fishing attempt should fail due to pending request
        vm.prank(player1);
        vm.expectRevert("Already have pending fishing request");
        gameState.initiateFishing(baitType);

        // Complete the first fishing request
        gameState.completeServerFishing(player1, fishingNonce, 0, 0); // No catch

        // Now a new fishing attempt should work
        vm.prank(player1);
        uint256 secondNonce = gameState.initiateFishing(baitType);
        assertEq(secondNonce, 2);
    }

    function testInvalidMovement() public {
        vm.prank(player1);
        gameState.registerPlayer(0, 1); // shard 0, map 1

        // Test movement with too many directions first
        uint8[] memory tooManyDirections = new uint8[](15); // More than limit of 10
        for (uint256 i = 0; i < 15; i++) {
            tooManyDirections[i] = 1; // East
        }

        vm.prank(player1);
        vm.expectRevert("Too many moves at once");
        gameState.move(tooManyDirections);

        // Test movement out of map bounds
        uint8[] memory boundaryDirections = new uint8[](10);
        for (uint256 i = 0; i < 10; i++) {
            boundaryDirections[i] = 1; // East - should hit boundary
        }

        // Move multiple times to get close to boundary
        for (uint256 j = 0; j < 20; j++) {
            vm.prank(player1);
            try gameState.move(boundaryDirections) {
                // Movement succeeded, continue
            } catch {
                // Movement failed due to boundary, which is expected
                break;
            }
        }
    }

    function testUnregisteredPlayerActions() public {
        // Test that unregistered players cannot perform actions
        uint8[] memory directions = new uint8[](1);
        directions[0] = 1;

        vm.prank(player1);
        vm.expectRevert("Player not registered");
        gameState.move(directions);

        vm.prank(player1);
        vm.expectRevert("Player not registered");
        gameState.purchaseFuel(10);

        vm.prank(player1);
        vm.expectRevert("Player not registered");
        gameState.initiateFishing(1);
    }

    function testShardChange() public {
        vm.prank(player1);
        gameState.registerPlayer(0, 1); // shard 0, map 1

        vm.prank(player1);
        gameState.changeShard(5);

        GameState.PlayerState memory state = gameState.getPlayerState(player1);
        assertEq(state.shard, 5);
    }

    function _addTestShip() private {
        bytes memory cargoShape = new bytes(2);
        cargoShape[0] = 0xFF;
        cargoShape[1] = 0xFF;

        // Create slot types array (16 slots for 4x4 grid)
        // 0=normal, 1=engine, 2=equipment
        uint8[] memory slotTypes = new uint8[](16);
        // Initialize all as normal cargo slots
        for (uint256 i = 0; i < 16; i++) {
            slotTypes[i] = 0; // normal slot
        }
        // Set engine slot
        slotTypes[0] = 1; // Top-left corner
        // Set equipment slot
        slotTypes[15] = 2; // Bottom-right corner

        shipRegistry.registerShip(1, "Test Ship", 100, 50, 100, 4, 4, cargoShape, slotTypes, 0, 10 * 10 ** 18);
    }

    function _addTestFish() private {
        bytes memory shape = new bytes(1);
        shape[0] = 0x01;

        fishRegistry.registerFishSpecies(1, 100 * 10 ** 18, 1, 1, 1, shape, 5);
    }

    function _addTestBait() private {
        fishRegistry.registerBaitType(1, "Test Bait", 5 * 10 ** 18);
    }

    function _addTestMap() private {
        // Register a test map
        mapRegistry.registerMap(
            1, // id
            "Test Ocean", // name
            1, // tier
            0, // travel cost (free for test)
            -50, // minX
            50, // maxX
            -50, // minY
            50 // maxY
        );

        // Add a bait shop at (0,0)
        uint256[] memory availableBait = new uint256[](1);
        availableBait[0] = 1;
        mapRegistry.addBaitShop(1, 0, 0, availableBait);
    }

    function testBaitPurchase() public {
        vm.prank(player1);
        gameState.registerPlayer(0, 1); // shard 0, map 1

        // Player should be at (0,0) where the bait shop is
        uint256 baitType = 1;
        uint256 amount = 10;
        uint256 expectedCost = 5 * 10 ** 18 * amount; // bait price * amount

        uint256 initialBalance = currency.balanceOf(player1);

        vm.prank(player1);
        gameState.purchaseBait(baitType, amount);

        assertEq(gameState.getPlayerBait(player1, baitType), amount);
        assertEq(currency.balanceOf(player1), initialBalance - expectedCost);
    }

    function testBaitPurchaseWrongLocation() public {
        vm.prank(player1);
        gameState.registerPlayer(0, 1); // shard 0, map 1

        // Move player away from bait shop
        uint8[] memory directions = new uint8[](1);
        directions[0] = 1; // East

        vm.prank(player1);
        gameState.move(directions);

        // Try to buy bait when not at shop
        vm.prank(player1);
        vm.expectRevert("No bait shop at current position");
        gameState.purchaseBait(1, 1);
    }

    function testFishingWithoutBait() public {
        vm.prank(player1);
        gameState.registerPlayer(0, 1); // shard 0, map 1

        // Try to fish without bait
        vm.prank(player1);
        vm.expectRevert("Insufficient bait");
        gameState.initiateFishing(1);
    }

    function testGetAvailableBait() public {
        vm.prank(player1);
        gameState.registerPlayer(0, 1); // shard 0, map 1

        // Purchase different types of bait
        vm.prank(player1);
        gameState.purchaseBait(1, 5);

        // Check available bait
        (uint256[] memory baitTypes, uint256[] memory amounts) = gameState.getPlayerAvailableBait(player1);

        assertEq(baitTypes.length, 1);
        assertEq(amounts.length, 1);
        assertEq(baitTypes[0], 1);
        assertEq(amounts[0], 5);
    }
}
