// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "../src/registries/EquipmentRegistry.sol";
import "../src/interfaces/IEquipmentRegistry.sol";

contract EquipmentRegistryTest is Test {
    EquipmentRegistry public equipmentRegistry;
    
    address public admin = address(this);
    address public user = address(0x1);

    function setUp() public {
        equipmentRegistry = new EquipmentRegistry();
        
        // Add test equipment
        _addTestEquipment();
    }

    function testEquipmentRegistration() public {
        bytes memory shape = new bytes(1);
        shape[0] = 0x01; // 1x1 shape

        equipmentRegistry.registerEquipment(
            10, // id
            "Test Rod", // name
            IEquipmentRegistry.EquipmentType.FISHING_ROD, // type
            1, // shapeWidth
            1, // shapeHeight
            shape,
            75 * 10 ** 18, // purchasePrice
            15 // weight
        );

        assertTrue(equipmentRegistry.isValidEquipment(10));
        assertEq(equipmentRegistry.getEquipmentCount(), 5); // 4 from setup + 1 new
        
        IEquipmentRegistry.Equipment memory equipment = equipmentRegistry.getEquipment(10);
        assertEq(equipment.id, 10);
        assertEq(equipment.name, "Test Rod");
        assertEq(uint8(equipment.equipmentType), uint8(IEquipmentRegistry.EquipmentType.FISHING_ROD));
        assertTrue(equipment.isActive);
    }

    function testEquipmentStats() public {
        // Set a stat
        equipmentRegistry.setEquipmentStat(1, "fishingBonus", 25);
        
        uint256 bonus = equipmentRegistry.getEquipmentStat(1, "fishingBonus");
        assertEq(bonus, 25);
    }

    function testMultipleStats() public {
        string[] memory statNames = new string[](2);
        statNames[0] = "damage";
        statNames[1] = "accuracy";
        
        uint256[] memory values = new uint256[](2);
        values[0] = 50;
        values[1] = 75;
        
        equipmentRegistry.batchSetEquipmentStats(1, statNames, values);
        
        uint256[] memory retrievedValues = equipmentRegistry.getEquipmentStats(1, statNames);
        assertEq(retrievedValues[0], 50);
        assertEq(retrievedValues[1], 75);
    }

    function testEquipmentsByType() public {
        IEquipmentRegistry.Equipment[] memory fishingRods = 
            equipmentRegistry.getEquipmentsByType(IEquipmentRegistry.EquipmentType.FISHING_ROD);
        
        assertEq(fishingRods.length, 1);
        assertEq(fishingRods[0].name, "Basic Fishing Rod");
        
        IEquipmentRegistry.Equipment[] memory nets = 
            equipmentRegistry.getEquipmentsByType(IEquipmentRegistry.EquipmentType.FISHING_NET);
        
        assertEq(nets.length, 1);
        assertEq(nets[0].name, "Fishing Net");
    }

    function testCombinedWeight() public {
        uint256[] memory equipmentIds = new uint256[](3);
        equipmentIds[0] = 1; // 10 weight
        equipmentIds[1] = 2; // 20 weight
        equipmentIds[2] = 3; // 15 weight
        
        uint256 totalWeight = equipmentRegistry.calculateCombinedWeight(equipmentIds);
        assertEq(totalWeight, 45);
    }

    function testEquippedEffects() public {
        // Set stats for equipment
        equipmentRegistry.setEquipmentStat(1, "fishingBonus", 10);
        equipmentRegistry.setEquipmentStat(2, "fishingBonus", 5);
        equipmentRegistry.setEquipmentStat(3, "fishingBonus", 15);
        
        uint256[] memory equipmentIds = new uint256[](3);
        equipmentIds[0] = 1;
        equipmentIds[1] = 2; 
        equipmentIds[2] = 3;
        
        uint256 totalEffect = equipmentRegistry.getEquippedEffects(equipmentIds, "fishingBonus");
        assertEq(totalEffect, 30); // 10 + 5 + 15
    }

    function testEquipmentStatusUpdate() public {
        assertTrue(equipmentRegistry.isValidEquipment(1));
        
        equipmentRegistry.setEquipmentStatus(1, false);
        
        IEquipmentRegistry.Equipment memory equipment = equipmentRegistry.getEquipment(1);
        assertFalse(equipment.isActive);
        
        // Inactive equipment shouldn't contribute to combined calculations
        uint256[] memory equipmentIds = new uint256[](1);
        equipmentIds[0] = 1;
        
        uint256 totalWeight = equipmentRegistry.calculateCombinedWeight(equipmentIds);
        assertEq(totalWeight, 0);
    }

    function testUpdateEquipmentBasics() public {
        equipmentRegistry.updateEquipmentBasics(1, 80 * 10 ** 18, 12);
        
        IEquipmentRegistry.Equipment memory equipment = equipmentRegistry.getEquipment(1);
        assertEq(equipment.purchasePrice, 80 * 10 ** 18);
        assertEq(equipment.weight, 12);
    }

    function testGetAllEquipment() public {
        IEquipmentRegistry.Equipment[] memory allEquipment = equipmentRegistry.getAllEquipment();
        assertEq(allEquipment.length, 4);
        
        assertEq(allEquipment[0].name, "Basic Fishing Rod");
        assertEq(allEquipment[1].name, "Fishing Net");
        assertEq(allEquipment[2].name, "Sonar");
        assertEq(allEquipment[3].name, "Extra Fuel Tank");
    }

    function testInvalidEquipmentOperations() public {
        // Test invalid equipment ID
        vm.expectRevert("Invalid equipment ID");
        equipmentRegistry.getEquipment(999);
        
        // Test setting stats for invalid equipment
        vm.expectRevert("Invalid equipment ID");
        equipmentRegistry.setEquipmentStat(999, "test", 100);
    }

    function testAccessControl() public {
        vm.prank(user);
        vm.expectRevert();
        equipmentRegistry.registerEquipment(
            100, "Unauthorized", 
            IEquipmentRegistry.EquipmentType.FISHING_ROD, 
            1, 1, new bytes(1), 0, 1
        );
        
        vm.prank(user);
        vm.expectRevert();
        equipmentRegistry.setEquipmentStat(1, "test", 100);
    }

    function _addTestEquipment() private {
        // 1. Basic Fishing Rod (1x1)
        bytes memory rodShape = new bytes(1);
        rodShape[0] = 0x01; // 1x1 shape

        equipmentRegistry.registerEquipment(
            1, // id
            "Basic Fishing Rod", // name
            IEquipmentRegistry.EquipmentType.FISHING_ROD, // type
            1, // shapeWidth
            1, // shapeHeight
            rodShape,
            50 * 10 ** 18, // purchasePrice (50 RTC)
            10 // weight
        );

        // 2. Fishing Net (1x2)
        bytes memory netShape = new bytes(1);
        netShape[0] = 0x03; // 1x2 shape

        equipmentRegistry.registerEquipment(
            2, // id
            "Fishing Net", // name
            IEquipmentRegistry.EquipmentType.FISHING_NET, // type
            1, // shapeWidth
            2, // shapeHeight
            netShape,
            150 * 10 ** 18, // purchasePrice (150 RTC)
            20 // weight
        );

        // 3. Sonar (1x1)
        bytes memory sonarShape = new bytes(1);
        sonarShape[0] = 0x01; // 1x1 shape

        equipmentRegistry.registerEquipment(
            3, // id
            "Sonar", // name
            IEquipmentRegistry.EquipmentType.SONAR, // type
            1, // shapeWidth
            1, // shapeHeight
            sonarShape,
            200 * 10 ** 18, // purchasePrice (200 RTC)
            15 // weight
        );

        // 4. Fuel Tank (2x1)
        bytes memory tankShape = new bytes(1);
        tankShape[0] = 0x03; // 2x1 shape

        equipmentRegistry.registerEquipment(
            4, // id
            "Extra Fuel Tank", // name
            IEquipmentRegistry.EquipmentType.FUEL_TANK, // type
            2, // shapeWidth
            1, // shapeHeight
            tankShape,
            100 * 10 ** 18, // purchasePrice (100 RTC)
            30 // weight
        );
    }
}