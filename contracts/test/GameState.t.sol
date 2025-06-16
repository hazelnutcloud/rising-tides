// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "../src/tokens/RisingTidesCurrency.sol";
import "../src/registries/ShipRegistry.sol";
import "../src/registries/FishRegistry.sol";
import "../src/registries/EngineRegistry.sol";
import "../src/registries/FishingRodRegistry.sol";
import "../src/registries/MapRegistry.sol";
import "../src/core/GameStateCore.sol";
import "../src/interfaces/IGameState.sol";

contract GameStateTest is Test {
    RisingTidesCurrency public currency;
    ShipRegistry public shipRegistry;
    FishRegistry public fishRegistry;
    EngineRegistry public engineRegistry;
    FishingRodRegistry public fishingRodRegistry;
    MapRegistry public mapRegistry;
    GameStateCore public gameState;

    address public player1 = address(0x1);
    address public player2 = address(0x2);
    address public admin = address(this);
    
    // Test server signer address and private key for testing
    uint256 public constant TEST_SERVER_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address public testServerSigner;

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

        gameState = new GameStateCore(
            address(currency), 
            address(shipRegistry), 
            address(fishRegistry), 
            address(engineRegistry),
            address(fishingRodRegistry),
            address(mapRegistry), 
            testServerSigner
        );

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

        IGameState.PlayerState memory state = gameState.getPlayerState(player1);
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

        IGameState.PlayerState memory state = gameState.getPlayerState(player1);
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

        // Test fulfilling the fishing with a signed result and inventory management
        uint256 species = 1;
        uint16 weight = 500;
        uint256 timestamp = block.timestamp;
        
        // Create fishing result
        FishingResult memory result = FishingResult({
            player: player1,
            nonce: fishingNonce,
            species: species,
            weight: weight,
            timestamp: timestamp
        });
        
        // Create signature (simplified for testing - in production would be created server-side)
        bytes memory signature = _createTestSignature(result);
        
        // Create inventory actions (empty for this basic test)
        InventoryAction[] memory actions = new InventoryAction[](0);
        
        // Fulfill fishing
        vm.prank(player1);
        gameState.fulfillFishing(result, signature, actions);

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

        // Complete the first fishing request with no catch
        FishingResult memory noCatchResult = FishingResult({
            player: player1,
            nonce: fishingNonce,
            species: 0, // No catch
            weight: 0,
            timestamp: block.timestamp
        });
        
        bytes memory noCatchSignature = _createTestSignature(noCatchResult);
        InventoryAction[] memory emptyActions = new InventoryAction[](0);
        
        vm.prank(player1);
        gameState.fulfillFishing(noCatchResult, noCatchSignature, emptyActions);

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

        IGameState.PlayerState memory state = gameState.getPlayerState(player1);
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

        shipRegistry.registerShip(1, "Test Ship", 100, 100, 4, 4, cargoShape, slotTypes, 0, 10 * 10 ** 18);
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

    function testInventoryManagement() public {
        vm.prank(player1);
        gameState.registerPlayer(0, 1); // shard 0, map 1

        // Test getting initial empty inventory
        (uint8 width, uint8 height, uint8[] memory slotTypes, InventoryLib.GridItem[] memory items) = 
            gameState.getPlayerInventory(player1);
        
        assertEq(width, 4);
        assertEq(height, 4);
        assertEq(slotTypes.length, 16);
        assertEq(items.length, 16);
        
        // Check that initial inventory is empty
        for (uint256 i = 0; i < items.length; i++) {
            assertFalse(items[i].isOccupied);
        }
    }

    function testInventoryRotation() public {
        vm.prank(player1);
        gameState.registerPlayer(0, 1); // shard 0, map 1

        // Test getting available space for different item sizes
        (uint8[] memory validX, uint8[] memory validY) = 
            gameState.getAvailableInventorySpace(player1, 1, 1);
        
        // Should have many valid positions for 1x1 items in empty 4x4 grid
        assertEq(validX.length, 16);
        assertEq(validY.length, 16);
        
        // Test with 2x2 item
        (validX, validY) = gameState.getAvailableInventorySpace(player1, 2, 2);
        // Should have 9 valid positions for 2x2 items (3x3 possible placements)
        assertEq(validX.length, 9);
        assertEq(validY.length, 9);
    }

    function testFulfillFishingWithInventoryActions() public {
        vm.prank(player1);
        gameState.registerPlayer(0, 1); // shard 0, map 1

        // Purchase bait
        vm.prank(player1);
        gameState.purchaseBait(1, 5);

        // Initiate fishing
        vm.prank(player1);
        uint256 fishingNonce = gameState.initiateFishing(1);

        // Create fishing result with rotation
        uint256 species = 1;
        uint16 weight = 500;
        uint256 timestamp = block.timestamp;
        
        FishingResult memory result = FishingResult({
            player: player1,
            nonce: fishingNonce,
            species: species,
            weight: weight,
            timestamp: timestamp
        });
        
        bytes memory signature = _createTestSignature(result);
        
        // Create inventory actions to place the fish with rotation
        InventoryAction[] memory actions = new InventoryAction[](1);
        actions[0] = InventoryAction({
            actionType: 0, // place
            fromX: 0,
            fromY: 0,
            toX: 1,
            toY: 1,
            rotation: 2, // 180 degree rotation
            itemId: 1
        });
        
        // Fulfill fishing with inventory management
        vm.prank(player1);
        gameState.fulfillFishing(result, signature, actions);

        // Check fish was added
        assertEq(gameState.getPlayerFishCount(player1), 1);
        
        // Check inventory item was placed
        InventoryLib.GridItem memory item = gameState.getInventoryItem(player1, 1, 1);
        assertTrue(item.isOccupied);
        assertEq(item.itemType, 1);
        assertEq(item.itemId, 1);
    }

    /**
     * @dev Helper function to create test signatures for fishing results
     * Note: This creates a simplified signature for testing. In production,
     * signatures would be created server-side with proper private key management.
     */
    function _createTestSignature(FishingResult memory result) private view returns (bytes memory) {
        // Create EIP712 domain separator
        bytes32 domainSeparator = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("RisingTides"),
            keccak256("1"),
            block.chainid,
            address(gameState)
        ));
        
        // Create struct hash
        bytes32 structHash = keccak256(abi.encode(
            keccak256("FishingResult(address player,uint256 nonce,uint256 species,uint16 weight,uint256 timestamp)"),
            result.player,
            result.nonce,
            result.species,
            result.weight,
            result.timestamp
        ));
        
        // Create digest
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        // Create a test signature by simulating server signing
        // In production, this would be done by the server with its private key
        // For testing, we'll create a mock signature that matches the test server signer
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(TEST_SERVER_PRIVATE_KEY, digest);
        return abi.encodePacked(r, s, v);
    }
}
