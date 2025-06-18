// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "../src/registries/EngineRegistry.sol";
import "../src/interfaces/IEngineRegistry.sol";
import "../src/utils/Errors.sol";

contract EngineRegistryTest is Test {
    EngineRegistry public engineRegistry;

    address public admin = address(this);
    address public user = address(0x1);

    function setUp() public {
        engineRegistry = new EngineRegistry();

        // Add test engines
        _addTestEngines();
    }

    function testEngineRegistration() public {
        bytes memory shape = new bytes(1);
        shape[0] = 0x01; // 1x1 shape

        engineRegistry.registerEngine(
            10, // id
            "Test Engine", // name
            50, // enginePowerPerCell
            100, // fuelConsumptionRatePerCell
            1, // shapeWidth
            1, // shapeHeight
            shape,
            100 * 10 ** 18, // purchasePrice
            25 // weight
        );

        assertTrue(engineRegistry.isValidEngine(10));
        assertEq(engineRegistry.getEngineCount(), 4); // 3 from setup + 1 new

        IEngineRegistry.Engine memory engine = engineRegistry.getEngine(10);
        assertEq(engine.id, 10);
        assertEq(engine.name, "Test Engine");
        assertEq(engine.enginePowerPerCell, 50);
        assertEq(engine.fuelConsumptionRatePerCell, 100);
        assertTrue(engine.isActive);
    }

    function testEngineStats() public view {
        IEngineRegistry.EngineStats memory stats = engineRegistry.getEngineStats(1);
        assertEq(stats.enginePowerPerCell, 30);
        assertEq(stats.fuelConsumptionRatePerCell, 90);
        assertEq(stats.weight, 50);
    }

    function testInvalidEngineOperations() public {
        // Test invalid engine ID
        vm.expectRevert(abi.encodeWithSelector(InvalidEngine.selector, 999));
        engineRegistry.getEngine(999);

        // Test getting stats for invalid engine
        vm.expectRevert(abi.encodeWithSelector(InvalidEngine.selector, 999));
        engineRegistry.getEngineStats(999);
    }

    function testUpdateEngineStats() public {
        engineRegistry.updateEngineStats(1, 35, 95, 55, 120 * 10 ** 18);

        IEngineRegistry.EngineStats memory stats = engineRegistry.getEngineStats(1);
        assertEq(stats.enginePowerPerCell, 35);
        assertEq(stats.fuelConsumptionRatePerCell, 95);
        assertEq(stats.weight, 55);

        IEngineRegistry.Engine memory engine = engineRegistry.getEngine(1);
        assertEq(engine.purchasePrice, 120 * 10 ** 18);
    }

    function testEngineStatusUpdate() public {
        assertTrue(engineRegistry.isValidEngine(1));

        engineRegistry.setEngineStatus(1, false);

        IEngineRegistry.Engine memory engine = engineRegistry.getEngine(1);
        assertFalse(engine.isActive);
    }

    function testGetAllEngines() public view {
        IEngineRegistry.Engine[] memory allEngines = engineRegistry.getAllEngines();
        assertEq(allEngines.length, 3);

        assertEq(allEngines[0].name, "Small Engine");
        assertEq(allEngines[1].name, "Medium Engine");
        assertEq(allEngines[2].name, "Large Engine");
    }

    function testAccessControl() public {
        vm.prank(user);
        vm.expectRevert();
        engineRegistry.registerEngine(100, "Unauthorized", 10, 100, 1, 1, new bytes(1), 0, 1);

        vm.prank(user);
        vm.expectRevert();
        engineRegistry.updateEngineStats(1, 100, 100, 100, 100);
    }

    function _addTestEngines() private {
        // 1. Small Engine (1x1)
        bytes memory smallEngineShape = new bytes(1);
        smallEngineShape[0] = 0x01; // 1x1 shape

        engineRegistry.registerEngine(
            1, // id
            "Small Engine", // name
            30, // enginePowerPerCell (1x1 = 1 cell, total power = 30)
            90, // fuelConsumptionRatePerCell (90% consumption = 10% more efficient)
            1, // shapeWidth
            1, // shapeHeight
            smallEngineShape,
            100 * 10 ** 18, // purchasePrice (100 RTC)
            50 // weight
        );

        // 2. Medium Engine (1x2)
        bytes memory mediumEngineShape = new bytes(1);
        mediumEngineShape[0] = 0x03; // 1x2 shape (bits: 11)

        engineRegistry.registerEngine(
            2, // id
            "Medium Engine", // name
            30, // enginePowerPerCell (1x2 = 2 cells, total power = 60)
            55, // fuelConsumptionRatePerCell (110/2 = 55% per cell)
            1, // shapeWidth
            2, // shapeHeight
            mediumEngineShape,
            250 * 10 ** 18, // purchasePrice (250 RTC)
            80 // weight
        );

        // 3. Large Engine (2x2)
        bytes memory largeEngineShape = new bytes(1);
        largeEngineShape[0] = 0x0F; // 2x2 shape (bits: 1111)

        engineRegistry.registerEngine(
            3, // id
            "Large Engine", // name
            25, // enginePowerPerCell (2x2 = 4 cells, total power = 100)
            32, // fuelConsumptionRatePerCell (130/4 = 32.5, rounded to 32)
            2, // shapeWidth
            2, // shapeHeight
            largeEngineShape,
            500 * 10 ** 18, // purchasePrice (500 RTC)
            120 // weight
        );
    }
}
