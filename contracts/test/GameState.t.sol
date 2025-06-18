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

contract GameStateTest is Test {
    RisingTidesCurrency public currency;
    ShipRegistry public shipRegistry;
    FishRegistry public fishRegistry;
    EngineRegistry public engineRegistry;
    FishingRodRegistry public fishingRodRegistry;
    MapRegistry public mapRegistry;
    RisingTides public gameState;

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

        gameState = new RisingTides(
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
        _addTestEngines();
        _addTestFishingRods();
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

        IRisingTides.PlayerState memory state = gameState.getPlayerState(player1);
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

        IRisingTides.PlayerState memory state = gameState.getPlayerState(player1);
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

        assertEq(gameState.getCurrentFuel(player1), initialFuel + fuelToBuy * 1e18);
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

        // Create fish placement (place fish at 2,2 to avoid equipment slots)
        FishPlacement memory fishPlacement = FishPlacement({shouldPlace: true, x: 2, y: 2, rotation: 0});

        // Fulfill fishing
        vm.prank(player1);
        gameState.fulfillFishing(result, signature, fishPlacement);

        InventoryLib.GridItem memory item = gameState.getInventoryItem(player1, 2, 2);
        assertTrue(item.itemType != ItemType.Empty);
        assertEq(uint8(item.itemType), uint8(ItemType.Fish));
        assertEq(item.itemId, 1);
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
        FishPlacement memory noCatchPlacement = FishPlacement({
            shouldPlace: false, // No fish to place since no catch
            x: 0,
            y: 0,
            rotation: 0
        });

        vm.prank(player1);
        gameState.fulfillFishing(noCatchResult, noCatchSignature, noCatchPlacement);

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

        IRisingTides.PlayerState memory state = gameState.getPlayerState(player1);
        assertEq(state.shard, 5);
    }

    function _addTestShip() private {
        // Create slot types array (16 slots for 4x4 grid)
        SlotType[] memory slotTypes = new SlotType[](16);
        // Initialize all as normal cargo slots
        for (uint256 i = 0; i < 16; i++) {
            slotTypes[i] = SlotType.Normal;
        }
        // Set engine slot
        slotTypes[0] = SlotType.Engine; // Top-left corner
        // Set equipment slot
        slotTypes[15] = SlotType.FishingRod; // Bottom-right corner

        shipRegistry.registerShip(1, "Test Ship", 100, 100, 4, 4, slotTypes, 0, 10 * 10 ** 18);
    }

    function _addTestFish() private {
        bytes memory shape = new bytes(1);
        shape[0] = 0x01;

        fishRegistry.registerFishSpecies(1, 100 * 10 ** 18, 1, 1, 1, shape, 5);
    }

    function _addTestBait() private {
        fishRegistry.registerBaitType(1, "Test Bait", 5 * 10 ** 18);
    }

    function _addTestEngines() private {
        // Add basic test engine (ID 1)
        bytes memory engineShape = new bytes(1);
        engineShape[0] = 0x01; // 1x1 shape

        engineRegistry.registerEngine(
            1, // id
            "Test Engine", // name
            30, // enginePowerPerCell
            100, // fuelConsumptionRatePerCell
            1, // shapeWidth
            1, // shapeHeight
            engineShape,
            100 * 10 ** 18, // purchasePrice
            50 // weight
        );
    }

    function _addTestFishingRods() private {
        // Add basic test fishing rod (ID 1)
        bytes memory rodShape = new bytes(1);
        rodShape[0] = 0x01; // 1x1 shape

        fishingRodRegistry.registerFishingRod(
            1, // id
            "Test Fishing Rod", // name
            1, // shapeWidth
            1, // shapeHeight
            rodShape,
            50 * 10 ** 18, // purchasePrice
            10 // weight
        );
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
        (uint8 width, uint8 height, SlotType[] memory slotTypes, InventoryLib.GridItem[] memory items) =
            gameState.getPlayerInventory(player1);

        assertEq(width, 4);
        assertEq(height, 4);
        assertEq(slotTypes.length, 16);
        assertEq(items.length, 16);

        // Check that initial inventory has default equipment
        // Slot 0 should have default engine (ID 1)
        assertTrue(items[0].itemType != ItemType.Empty);
        assertEq(uint8(items[0].itemType), uint8(ItemType.Engine)); // Engine item type
        assertEq(items[0].itemId, 1); // Default engine ID

        // Slot 15 should have default fishing rod (ID 1)
        assertTrue(items[15].itemType != ItemType.Empty);
        assertEq(uint8(items[15].itemType), uint8(ItemType.FishingRod)); // Equipment item type
        assertEq(items[15].itemId, 1); // Default fishing rod ID

        // All other slots should be empty
        for (uint256 i = 1; i < 15; i++) {
            assertFalse(items[i].itemType != ItemType.Empty);
        }
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

        // Create fish placement to place the fish with rotation
        FishPlacement memory fishPlacement = FishPlacement({
            shouldPlace: true,
            x: 1,
            y: 1,
            rotation: 2 // 180 degree rotation
        });

        // Fulfill fishing with fish placement
        vm.prank(player1);
        gameState.fulfillFishing(result, signature, fishPlacement);

        // Check inventory item was placed
        InventoryLib.GridItem memory item = gameState.getInventoryItem(player1, 1, 1);
        assertTrue(item.itemType != ItemType.Empty);
        assertEq(uint8(item.itemType), uint8(ItemType.Fish));
        assertEq(item.itemId, 1);
    }

    /**
     * @dev Helper function to create test signatures for fishing results
     * Note: This creates a simplified signature for testing. In production,
     * signatures would be created server-side with proper private key management.
     */
    function _createTestSignature(FishingResult memory result) private view returns (bytes memory) {
        // Create EIP712 domain separator
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("RisingTides"),
                keccak256("1"),
                block.chainid,
                address(gameState)
            )
        );

        // Create struct hash
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

        // Create digest
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        // Create a test signature by simulating server signing
        // In production, this would be done by the server with its private key
        // For testing, we'll create a mock signature that matches the test server signer
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(TEST_SERVER_PRIVATE_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    function testShardLimits() public {
        // Test default limit is set
        assertEq(gameState.getMaxPlayersPerShard(), 1000);

        // Test shard 0 starts empty
        assertEq(gameState.getShardPlayerCount(0), 0);
        assertTrue(gameState.isShardAvailable(0));

        // Register player1 to shard 0
        vm.prank(player1);
        gameState.registerPlayer(0, 1);

        // Check shard count updated
        assertEq(gameState.getShardPlayerCount(0), 1);
        assertTrue(gameState.isShardAvailable(0));
    }

    function testShardChangeWithLimits() public {
        // Register player1 to shard 0
        vm.prank(player1);
        gameState.registerPlayer(0, 1);

        // Register player2 to shard 1
        vm.prank(player2);
        gameState.registerPlayer(1, 1);

        // Verify counts
        assertEq(gameState.getShardPlayerCount(0), 1);
        assertEq(gameState.getShardPlayerCount(1), 1);

        // Move player1 from shard 0 to shard 1
        vm.prank(player1);
        gameState.changeShard(1);

        // Verify counts updated
        assertEq(gameState.getShardPlayerCount(0), 0);
        assertEq(gameState.getShardPlayerCount(1), 2);
    }

    function testShardFullRegistration() public {
        // Set a very low limit for testing
        gameState.setMaxPlayersPerShard(1);

        // Register player1 to shard 0 (should succeed)
        vm.prank(player1);
        gameState.registerPlayer(0, 1);

        // Try to register player2 to shard 0 (should fail)
        vm.prank(player2);
        vm.expectRevert("Shard is full");
        gameState.registerPlayer(0, 1);

        // But player2 can register to shard 1
        vm.prank(player2);
        gameState.registerPlayer(1, 1);

        assertEq(gameState.getShardPlayerCount(0), 1);
        assertEq(gameState.getShardPlayerCount(1), 1);
    }

    function testShardFullChangeAttempt() public {
        // Set limit to 1
        gameState.setMaxPlayersPerShard(1);

        // Register players to different shards
        vm.prank(player1);
        gameState.registerPlayer(0, 1);

        vm.prank(player2);
        gameState.registerPlayer(1, 1);

        // Try to move player2 to shard 0 (should fail)
        vm.prank(player2);
        vm.expectRevert("Target shard is full");
        gameState.changeShard(0);

        // Verify no changes
        assertEq(gameState.getShardPlayerCount(0), 1);
        assertEq(gameState.getShardPlayerCount(1), 1);
    }

    function testSetMaxPlayersPerShard() public {
        // Test updating the limit
        gameState.setMaxPlayersPerShard(500);
        assertEq(gameState.getMaxPlayersPerShard(), 500);

        // Test zero limit should fail
        vm.expectRevert("Limit must be greater than zero");
        gameState.setMaxPlayersPerShard(0);

        // Test very high limit should fail
        vm.expectRevert("Limit too high");
        gameState.setMaxPlayersPerShard(20000);
    }

    function testGetAllShardOccupancy() public {
        // Register some players to different shards
        vm.prank(player1);
        gameState.registerPlayer(0, 1);

        vm.prank(player2);
        gameState.registerPlayer(2, 1);

        // Get all shard data
        (uint8[] memory shardIds, uint256[] memory playerCounts, bool[] memory available) =
            gameState.getAllShardOccupancy();

        // Verify data structure
        assertEq(shardIds.length, 100); // MAX_SHARDS
        assertEq(playerCounts.length, 100);
        assertEq(available.length, 100);

        // Check specific shard data
        assertEq(shardIds[0], 0);
        assertEq(playerCounts[0], 1);
        assertTrue(available[0]);

        assertEq(shardIds[2], 2);
        assertEq(playerCounts[2], 1);
        assertTrue(available[2]);

        assertEq(playerCounts[1], 0); // Empty shard
        assertTrue(available[1]);
    }

    function testShardLimitAccessControl() public {
        // Non-admin cannot set limit
        vm.prank(player1);
        vm.expectRevert();
        gameState.setMaxPlayersPerShard(100);
    }

    function testAdminChangePlayerShard() public {
        // Register player1 to shard 0
        vm.prank(player1);
        gameState.registerPlayer(0, 1);

        // Verify initial state
        assertEq(gameState.getShardPlayerCount(0), 1);
        assertEq(gameState.getShardPlayerCount(1), 0);

        IRisingTides.PlayerState memory state = gameState.getPlayerState(player1);
        assertEq(state.shard, 0);

        // Admin moves player1 from shard 0 to shard 1
        gameState.adminChangePlayerShard(player1, 1, false);

        // Verify shard counts updated
        assertEq(gameState.getShardPlayerCount(0), 0);
        assertEq(gameState.getShardPlayerCount(1), 1);

        // Verify player's shard updated
        state = gameState.getPlayerState(player1);
        assertEq(state.shard, 1);
    }

    function testAdminChangePlayerShardWithBypass() public {
        // Set very low limit
        gameState.setMaxPlayersPerShard(1);

        // Register player1 to shard 0, player2 to shard 1
        vm.prank(player1);
        gameState.registerPlayer(0, 1);

        vm.prank(player2);
        gameState.registerPlayer(1, 1);

        // Both shards are now full
        assertFalse(gameState.isShardAvailable(0));
        assertFalse(gameState.isShardAvailable(1));

        // Admin can still move player2 to shard 0 by bypassing the limit
        gameState.adminChangePlayerShard(player2, 0, true);

        // Verify the move worked despite the limit
        assertEq(gameState.getShardPlayerCount(0), 2); // Over the limit!
        assertEq(gameState.getShardPlayerCount(1), 0);

        IRisingTides.PlayerState memory state = gameState.getPlayerState(player2);
        assertEq(state.shard, 0);
    }

    function testAdminChangePlayerShardRespectLimit() public {
        // Set low limit
        gameState.setMaxPlayersPerShard(1);

        // Register players to different shards
        vm.prank(player1);
        gameState.registerPlayer(0, 1);

        vm.prank(player2);
        gameState.registerPlayer(1, 1);

        // Admin tries to move player2 to full shard 0 without bypass (should fail)
        vm.expectRevert("Target shard is full");
        gameState.adminChangePlayerShard(player2, 0, false);

        // Verify no changes
        assertEq(gameState.getShardPlayerCount(0), 1);
        assertEq(gameState.getShardPlayerCount(1), 1);
    }

    function testAdminChangePlayerShardValidation() public {
        // Register player1
        vm.prank(player1);
        gameState.registerPlayer(0, 1);

        // Test moving to same shard fails
        vm.expectRevert("Player already in target shard");
        gameState.adminChangePlayerShard(player1, 0, false);

        // Test moving unregistered player fails
        vm.expectRevert("Player not registered");
        gameState.adminChangePlayerShard(player2, 1, false);

        // Test invalid shard fails
        vm.expectRevert("Invalid shard ID");
        gameState.adminChangePlayerShard(player1, 200, false);
    }

    function testAdminChangePlayerShardAccessControl() public {
        // Register player1
        vm.prank(player1);
        gameState.registerPlayer(0, 1);

        // Non-admin cannot change player's shard
        vm.prank(player2);
        vm.expectRevert();
        gameState.adminChangePlayerShard(player1, 1, false);

        // Player cannot use admin function on themselves
        vm.prank(player1);
        vm.expectRevert();
        gameState.adminChangePlayerShard(player1, 1, false);
    }

    function testAdminChangePlayerShardEvents() public {
        // Register player1
        vm.prank(player1);
        gameState.registerPlayer(0, 1);

        // Expect both events to be emitted
        vm.expectEmit(true, true, true, true);
        emit IRisingTides.ShardChanged(player1, 0, 1);

        // The admin event is internal to PlayerManager, so we can't test it directly
        // but we can verify the functionality works
        gameState.adminChangePlayerShard(player1, 1, false);

        // Verify the change took effect
        IRisingTides.PlayerState memory state = gameState.getPlayerState(player1);
        assertEq(state.shard, 1);
    }

    function testFishingWithoutEquippedRod() public {
        // Register player
        vm.prank(player1);
        gameState.registerPlayer(0, 1);

        // Manually remove the equipped fishing rod by discarding it
        // First, find the equipment slot position
        uint8 equipmentSlotX = 0;
        uint8 equipmentSlotY = 0;

        // Get the player's inventory to find equipment slot
        (uint8 width,, SlotType[] memory slotTypes, InventoryLib.GridItem[] memory items) =
            gameState.getPlayerInventory(player1);

        // Find equipment slot with fishing rod
        bool foundEquipmentSlot = false;
        for (uint256 i = 0; i < slotTypes.length; i++) {
            if (slotTypes[i] == SlotType.FishingRod && items[i].itemType == ItemType.FishingRod) {
                equipmentSlotX = uint8(i % width);
                equipmentSlotY = uint8(i / width);
                foundEquipmentSlot = true;
                break;
            }
        }

        require(foundEquipmentSlot, "Could not find equipped fishing rod");

        // Discard the fishing rod
        vm.prank(player1);
        gameState.discardInventoryItem(equipmentSlotX, equipmentSlotY);

        // Player should no longer have fishing rod equipped
        assertFalse(gameState.hasEquippedItemType(player1, ItemType.FishingRod)); // Equipment type (fishing rod)

        // Give player some bait
        uint256 baitType = 1;
        uint256 baitAmount = 1;

        vm.prank(player1);
        gameState.purchaseBait(baitType, baitAmount);

        // Trying to fish without equipped rod should fail
        vm.prank(player1);
        vm.expectRevert("No fishing rod equipped");
        gameState.initiateFishing(baitType);
    }

    function testFishingWithDiscardPlacement() public {
        // Register player
        vm.prank(player1);
        gameState.registerPlayer(0, 1);

        // Purchase bait
        uint256 baitType = 1;
        uint256 baitAmount = 1;

        vm.prank(player1);
        gameState.purchaseBait(baitType, baitAmount);

        // Initiate fishing
        vm.prank(player1);
        uint256 fishingNonce = gameState.initiateFishing(baitType);

        // Create fishing result with catch
        FishingResult memory result =
            FishingResult({player: player1, nonce: fishingNonce, species: 1, weight: 100, timestamp: block.timestamp});

        bytes memory signature = _createTestSignature(result);

        // Create fish placement to discard the fish
        FishPlacement memory fishPlacement = FishPlacement({
            shouldPlace: false, // Discard the fish
            x: 0,
            y: 0,
            rotation: 0
        });

        // Fulfill fishing with discard placement
        vm.prank(player1);
        gameState.fulfillFishing(result, signature, fishPlacement);

        // Check that the inventory remains unchanged (no fish placed)
        InventoryLib.GridItem memory item = gameState.getInventoryItem(player1, 0, 0);
        // Equipment should still be there, but no fish
        if (item.itemType != ItemType.Empty) {
            // If occupied, it should be equipment (itemType 2 or 3), not fish (itemType 1)
            assertTrue(item.itemType == ItemType.Engine || item.itemType == ItemType.FishingRod);
        }
    }

    function testFishingWithInvalidPlacement() public {
        // Register player
        vm.prank(player1);
        gameState.registerPlayer(0, 1);

        // Purchase bait
        uint256 baitType = 1;
        uint256 baitAmount = 1;

        vm.prank(player1);
        gameState.purchaseBait(baitType, baitAmount);

        // Initiate fishing
        vm.prank(player1);
        uint256 fishingNonce = gameState.initiateFishing(baitType);

        // Create fishing result with catch
        FishingResult memory result =
            FishingResult({player: player1, nonce: fishingNonce, species: 1, weight: 100, timestamp: block.timestamp});

        bytes memory signature = _createTestSignature(result);

        // Create fish placement with invalid coordinates (outside inventory bounds)
        FishPlacement memory fishPlacement = FishPlacement({
            shouldPlace: true,
            x: 255, // Invalid position (outside inventory bounds)
            y: 255, // Invalid position (outside inventory bounds)
            rotation: 0
        });

        // Fulfill fishing should fail due to invalid placement
        vm.prank(player1);
        vm.expectRevert("Failed to place fish in inventory");
        gameState.fulfillFishing(result, signature, fishPlacement);
    }

    function testBasicFuelConsumptionCalculation() public {
        vm.prank(player1);
        gameState.registerPlayer(0, 1);

        // Test basic fuel calculation with default Test Engine (100 consumption rate)
        uint8[] memory directions = new uint8[](2);
        directions[0] = 1; // East
        directions[1] = 2; // Southeast

        uint256 fuelCost = gameState.calculateFuelCost(player1, directions);

        // With new additive system:
        // Test Engine: 100 consumption rate (1 cell * 100 per cell)
        // Expected: 2 * 1e18 * 100 / 100 = 2e18
        assertEq(fuelCost, 2e18, "Basic fuel cost calculation should be 2e18");
    }

    function testFuelCalculationWithDifferentDistances() public {
        vm.prank(player1);
        gameState.registerPlayer(0, 1);

        // Test with different movement distances
        uint8[] memory shortMove = new uint8[](1);
        shortMove[0] = 1; // East

        uint8[] memory longMove = new uint8[](3);
        longMove[0] = 1; // East
        longMove[1] = 2; // Southeast
        longMove[2] = 3; // Southwest

        uint256 shortFuelCost = gameState.calculateFuelCost(player1, shortMove);
        uint256 longFuelCost = gameState.calculateFuelCost(player1, longMove);

        // Fuel cost should scale linearly with distance
        // Test Engine has 100 consumption rate: 1 * 1e18 * 100 / 100 = 1e18
        assertEq(shortFuelCost, 1e18, "Short move fuel cost should be 1e18");
        assertEq(longFuelCost, 3e18, "Long move fuel cost should be 3e18");
        assertEq(longFuelCost, shortFuelCost * 3, "Fuel cost should scale with distance");
    }

    function testActualFuelConsumptionDuringMovement() public {
        vm.prank(player1);
        gameState.registerPlayer(0, 1);

        // Check initial fuel
        uint256 initialFuel = gameState.getCurrentFuel(player1);
        assertEq(initialFuel, 100e18, "Initial fuel should be 100e18");

        // Make a movement
        uint8[] memory directions = new uint8[](1);
        directions[0] = 1; // East

        vm.prank(player1);
        gameState.move(directions);

        // Check fuel after movement
        uint256 finalFuel = gameState.getCurrentFuel(player1);
        uint256 expectedCost = 1e18; // 1 * 1e18 * 100 / 100
        assertEq(finalFuel, initialFuel - expectedCost, "Fuel should decrease by calculated amount");
    }

    function testBlockedSlotPreventsFishPlacement() public {
        // Register ship with blocked slots
        _addShipWithBlockedSlots();

        vm.prank(player1);
        gameState.registerPlayer(0, 1); // Use map ID 1

        // Change to ship with blocked slots
        vm.prank(player1);
        gameState.changeShip(2);

        // Manually place fishing rod in equipment slot after ship change
        _placeFishingRodManually(player1, 1, 15); // Place fishing rod ID 1 in slot 15 (equipment slot)

        // Try to initiate and fulfill fishing to place a fish on a blocked slot
        uint256 baitType = 1;
        uint256 baitAmount = 1;

        vm.prank(player1);
        gameState.purchaseBait(baitType, baitAmount);

        vm.prank(player1);
        uint256 fishingNonce = gameState.initiateFishing(baitType);

        // Create fishing result
        FishingResult memory result =
            FishingResult({player: player1, nonce: fishingNonce, species: 1, weight: 100, timestamp: block.timestamp});

        bytes memory signature = _createTestSignature(result);

        // Try to place fish on blocked slot (position 1, which is x=1, y=0 in 4x4 grid)
        FishPlacement memory fishPlacement = FishPlacement({
            shouldPlace: true,
            x: 1, // This position should be blocked
            y: 0,
            rotation: 0
        });

        // Fulfill fishing should fail due to blocked slot
        vm.prank(player1);
        vm.expectRevert("Failed to place fish in inventory");
        gameState.fulfillFishing(result, signature, fishPlacement);
    }

    function testBlockedSlotPreventsItemMovement() public {
        // Register ship with blocked slots
        _addShipWithBlockedSlots();

        vm.prank(player1);
        gameState.registerPlayer(0, 1); // Use map ID 1

        // Change to ship with blocked slots
        vm.prank(player1);
        gameState.changeShip(2);

        // Place a fish in a normal slot first
        _placeFishManually(player1, 1, 0, 0); // Place sardine at position (0,0)

        // Try to move the fish to a blocked slot
        vm.prank(player1);
        vm.expectRevert("Failed to place item at new position");
        gameState.updateInventoryItem(0, 0, 1, 0, 0); // Try to move to position (1,0) which is blocked
    }

    function testInventoryShapeWithBlockedSlots() public {
        // Register ship with blocked slots
        _addShipWithBlockedSlots();

        vm.prank(player1);
        gameState.registerPlayer(0, 1); // Use map ID 1

        // Change to ship with blocked slots
        vm.prank(player1);
        gameState.changeShip(2);

        // Get inventory to verify blocked slots affect the layout
        (uint8 width, uint8 height, SlotType[] memory slotTypes,) = gameState.getPlayerInventory(player1);

        assertEq(width, 4, "Inventory width should be 4");
        assertEq(height, 4, "Inventory height should be 4");
        assertEq(uint8(slotTypes[1]), uint8(SlotType.Blocked), "Position 1 should be blocked");
        assertEq(uint8(slotTypes[2]), uint8(SlotType.Blocked), "Position 2 should be blocked");
        assertEq(uint8(slotTypes[0]), uint8(SlotType.Normal), "Position 0 should be normal");
    }

    // Helper function to add a ship with blocked slots for testing
    function _addShipWithBlockedSlots() private {
        // Create slot types array with some blocked slots
        SlotType[] memory slotTypes = new SlotType[](16);
        for (uint256 i = 0; i < 16; i++) {
            slotTypes[i] = SlotType.Normal; // Initialize as normal slots
        }
        // Set some slots as blocked
        slotTypes[1] = SlotType.Blocked; // Block position 1
        slotTypes[2] = SlotType.Blocked; // Block position 2

        // Add equipment slots for fishing rods
        slotTypes[15] = SlotType.FishingRod; // Bottom-right corner as equipment slot

        shipRegistry.registerShip(
            2, // id
            "Test Ship with Blocked Slots",
            100, // fuelCapacity
            100, // maxDurability
            4, // cargoWidth
            4, // cargoHeight
            slotTypes,
            0, // purchasePrice
            10 * 10 ** 18 // repairCostPerPoint
        );
    }

    // Helper function to manually place fish in inventory for testing
    function _placeFishManually(address player, uint256 species, uint8 x, uint8 y) private {
        // This is a simplified manual placement for testing blocked slot behavior
        // In a real scenario, fish would be placed through the fishing system
        vm.store(
            address(gameState),
            keccak256(abi.encode(keccak256(abi.encode(player, uint256(11))), uint256(y) * 4 + uint256(x))),
            bytes32(abi.encode(uint8(1), species, true)) // itemType=1 (fish), itemId=species, isOccupied=true
        );
    }

    // Helper function to manually place fishing rod for testing
    function _placeFishingRodManually(address player, uint256 rodId, uint8 slotIndex) private {
        // Place fishing rod in inventory slot for testing
        vm.store(
            address(gameState),
            keccak256(abi.encode(keccak256(abi.encode(player, uint256(11))), slotIndex)),
            bytes32(abi.encode(uint8(3), rodId, true)) // itemType=3 (equipment), itemId=rodId, isOccupied=true
        );
    }
}
