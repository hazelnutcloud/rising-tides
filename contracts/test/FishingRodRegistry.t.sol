// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "../src/registries/FishingRodRegistry.sol";
import "../src/interfaces/IFishingRodRegistry.sol";

contract FishingRodRegistryTest is Test {
    FishingRodRegistry public fishingRodRegistry;

    address public admin = address(this);
    address public user = address(0x1);

    function setUp() public {
        fishingRodRegistry = new FishingRodRegistry();

        // Add test fishing rods
        _addTestFishingRods();
    }

    function testFishingRodRegistration() public {
        bytes memory shape = new bytes(1);
        shape[0] = 0x01; // 1x1 shape

        fishingRodRegistry.registerFishingRod(
            10, // id
            "Test Rod", // name
            1, // shapeWidth
            1, // shapeHeight
            shape,
            75 * 10 ** 18, // purchasePrice
            15 // weight
        );

        assertTrue(fishingRodRegistry.isValidFishingRod(10));
        assertEq(fishingRodRegistry.getFishingRodCount(), 5); // 4 from setup + 1 new

        IFishingRodRegistry.FishingRod memory rod = fishingRodRegistry.getFishingRod(10);
        assertEq(rod.id, 10);
        assertEq(rod.name, "Test Rod");
        assertEq(rod.shapeWidth, 1);
        assertEq(rod.shapeHeight, 1);
        assertEq(rod.purchasePrice, 75 * 10 ** 18);
        assertEq(rod.weight, 15);
        assertTrue(rod.isActive);
    }

    function testUpdateFishingRod() public {
        fishingRodRegistry.updateFishingRod(1, 60 * 10 ** 18, 12);

        IFishingRodRegistry.FishingRod memory rod = fishingRodRegistry.getFishingRod(1);
        assertEq(rod.purchasePrice, 60 * 10 ** 18);
        assertEq(rod.weight, 12);
    }

    function testFishingRodStatusUpdate() public {
        assertTrue(fishingRodRegistry.isValidFishingRod(1));

        fishingRodRegistry.setFishingRodStatus(1, false);

        IFishingRodRegistry.FishingRod memory rod = fishingRodRegistry.getFishingRod(1);
        assertFalse(rod.isActive);
        assertFalse(fishingRodRegistry.isValidFishingRod(1));
    }

    function testCombinedWeight() public {
        uint256[] memory rodIds = new uint256[](3);
        rodIds[0] = 1; // 10 weight
        rodIds[1] = 2; // 15 weight
        rodIds[2] = 3; // 20 weight

        uint256 totalWeight = fishingRodRegistry.calculateCombinedWeight(rodIds);
        assertEq(totalWeight, 45);
    }

    function testCombinedWeightWithInactive() public {
        // Deactivate rod 2
        fishingRodRegistry.setFishingRodStatus(2, false);

        uint256[] memory rodIds = new uint256[](3);
        rodIds[0] = 1; // 10 weight
        rodIds[1] = 2; // 0 weight (inactive)
        rodIds[2] = 3; // 20 weight

        uint256 totalWeight = fishingRodRegistry.calculateCombinedWeight(rodIds);
        assertEq(totalWeight, 30);
    }

    function testGetAllFishingRods() public {
        IFishingRodRegistry.FishingRod[] memory allRods = fishingRodRegistry.getAllFishingRods();
        assertEq(allRods.length, 4);

        assertEq(allRods[0].name, "Basic Fishing Rod");
        assertEq(allRods[1].name, "Advanced Fishing Rod");
        assertEq(allRods[2].name, "Professional Fishing Rod");
        assertEq(allRods[3].name, "Master Fishing Rod");
    }

    function testInvalidFishingRodOperations() public {
        // Test invalid fishing rod ID
        vm.expectRevert("Invalid fishing rod ID");
        fishingRodRegistry.getFishingRod(999);

        // Test updating invalid fishing rod
        vm.expectRevert("Invalid fishing rod ID");
        fishingRodRegistry.updateFishingRod(999, 100, 10);
    }

    function testAccessControl() public {
        vm.prank(user);
        vm.expectRevert();
        fishingRodRegistry.registerFishingRod(100, "Unauthorized", 1, 1, new bytes(1), 0, 1);

        vm.prank(user);
        vm.expectRevert();
        fishingRodRegistry.updateFishingRod(1, 100, 10);

        vm.prank(user);
        vm.expectRevert();
        fishingRodRegistry.setFishingRodStatus(1, false);
    }

    function testDuplicateRegistration() public {
        bytes memory shape = new bytes(1);
        shape[0] = 0x01;

        vm.expectRevert("Fishing rod already exists");
        fishingRodRegistry.registerFishingRod(1, "Duplicate", 1, 1, shape, 100, 10);
    }

    function testInvalidRegistrationParameters() public {
        bytes memory shape = new bytes(1);
        shape[0] = 0x01;

        // Test invalid ID
        vm.expectRevert("Invalid ID");
        fishingRodRegistry.registerFishingRod(0, "Invalid", 1, 1, shape, 100, 10);

        // Test empty name
        vm.expectRevert("Name cannot be empty");
        fishingRodRegistry.registerFishingRod(10, "", 1, 1, shape, 100, 10);

        // Test invalid dimensions
        vm.expectRevert("Invalid dimensions");
        fishingRodRegistry.registerFishingRod(10, "Invalid", 0, 1, shape, 100, 10);

        // Test empty shape data
        vm.expectRevert("Shape data cannot be empty");
        fishingRodRegistry.registerFishingRod(10, "Invalid", 1, 1, new bytes(0), 100, 10);
    }

    function _addTestFishingRods() private {
        // 1. Basic Fishing Rod (1x1)
        bytes memory basicRodShape = new bytes(1);
        basicRodShape[0] = 0x01; // 1x1 shape

        fishingRodRegistry.registerFishingRod(
            1, // id
            "Basic Fishing Rod", // name
            1, // shapeWidth
            1, // shapeHeight
            basicRodShape,
            50 * 10 ** 18, // purchasePrice (50 RTC)
            10 // weight
        );

        // 2. Advanced Fishing Rod (1x2)
        bytes memory advancedRodShape = new bytes(1);
        advancedRodShape[0] = 0x03; // 1x2 shape

        fishingRodRegistry.registerFishingRod(
            2, // id
            "Advanced Fishing Rod", // name
            1, // shapeWidth
            2, // shapeHeight
            advancedRodShape,
            150 * 10 ** 18, // purchasePrice (150 RTC)
            15 // weight
        );

        // 3. Professional Fishing Rod (2x1)
        bytes memory proRodShape = new bytes(1);
        proRodShape[0] = 0x03; // 2x1 shape

        fishingRodRegistry.registerFishingRod(
            3, // id
            "Professional Fishing Rod", // name
            2, // shapeWidth
            1, // shapeHeight
            proRodShape,
            300 * 10 ** 18, // purchasePrice (300 RTC)
            20 // weight
        );

        // 4. Master Fishing Rod (2x2)
        bytes memory masterRodShape = new bytes(1);
        masterRodShape[0] = 0x0F; // 2x2 shape

        fishingRodRegistry.registerFishingRod(
            4, // id
            "Master Fishing Rod", // name
            2, // shapeWidth
            2, // shapeHeight
            masterRodShape,
            500 * 10 ** 18, // purchasePrice (500 RTC)
            25 // weight
        );
    }
}
