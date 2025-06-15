// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "../src/tokens/RisingTidesCurrency.sol";
import "../src/registries/ShipRegistry.sol";
import "../src/registries/FishRegistry.sol";
import "../src/core/GameState.sol";
import "../src/core/FishMarket.sol";
import "../src/core/SeasonPass.sol";

/**
 * @title Deploy
 * @dev Deployment script for Rising Tides game contracts
 */
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts with address:", deployerAddress);
        console.log("Deployer balance:", deployerAddress.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Currency Token
        console.log("\n=== Deploying RisingTidesCurrency ===");
        RisingTidesCurrency currency = new RisingTidesCurrency();
        console.log("RisingTidesCurrency deployed to:", address(currency));

        // 2. Deploy Ship Registry
        console.log("\n=== Deploying ShipRegistry ===");
        ShipRegistry shipRegistry = new ShipRegistry();
        console.log("ShipRegistry deployed to:", address(shipRegistry));

        // 3. Deploy Fish Registry
        console.log("\n=== Deploying FishRegistry ===");
        FishRegistry fishRegistry = new FishRegistry();
        console.log("FishRegistry deployed to:", address(fishRegistry));

        // 4. Deploy Game State
        console.log("\n=== Deploying GameState ===");
        GameState gameState = new GameState(
            address(currency),
            address(shipRegistry),
            address(fishRegistry)
        );
        console.log("GameState deployed to:", address(gameState));

        // 5. Deploy Fish Market
        console.log("\n=== Deploying FishMarket ===");
        FishMarket fishMarket = new FishMarket(
            address(currency),
            address(fishRegistry),
            deployerAddress // Fee collector
        );
        console.log("FishMarket deployed to:", address(fishMarket));

        // 6. Deploy Season Pass
        console.log("\n=== Deploying SeasonPass ===");
        SeasonPass seasonPass = new SeasonPass();
        console.log("SeasonPass deployed to:", address(seasonPass));

        // 7. Setup Roles and Permissions
        console.log("\n=== Setting up roles and permissions ===");
        
        // Grant MINTER_ROLE to FishMarket for currency rewards
        currency.grantRole(currency.MINTER_ROLE(), address(fishMarket));
        console.log("Granted MINTER_ROLE to FishMarket");

        // Grant BURNER_ROLE to GameState for fuel/bait purchases
        currency.grantRole(currency.BURNER_ROLE(), address(gameState));
        console.log("Granted BURNER_ROLE to GameState");

        // Grant ADMIN_ROLE to SeasonPass for updating player stats
        seasonPass.grantRole(seasonPass.ADMIN_ROLE(), address(gameState));
        console.log("Granted ADMIN_ROLE to SeasonPass for GameState");

        // 8. Initialize with sample data
        console.log("\n=== Initializing sample data ===");
        
        // Add a basic starter ship
        _addStarterShip(shipRegistry);
        
        // Add some basic fish species
        _addBasicFish(fishRegistry);
        
        // Add basic bait types
        _addBasicBait(fishRegistry);

        vm.stopBroadcast();

        // 9. Log deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("RisingTidesCurrency:", address(currency));
        console.log("ShipRegistry:", address(shipRegistry));
        console.log("FishRegistry:", address(fishRegistry));
        console.log("GameState:", address(gameState));
        console.log("FishMarket:", address(fishMarket));
        console.log("SeasonPass:", address(seasonPass));
        console.log("\n=== NEXT STEPS ===");
        console.log("1. Verify contracts on block explorer");
        console.log("2. Update frontend with contract addresses");
        console.log("3. Create first season in SeasonPass");
        console.log("4. Add more ships and fish species as needed");
    }

    function _addStarterShip(ShipRegistry shipRegistry) private {
        // Create a basic cargo shape (4x4 grid, all slots available)
        bytes memory cargoShape = new bytes(2); // 16 bits for 4x4 grid
        cargoShape[0] = 0xFF; // First 8 bits
        cargoShape[1] = 0xFF; // Last 8 bits
        
        uint8[] memory engineSlots = new uint8[](2);
        engineSlots[0] = 0; // Top-left corner
        engineSlots[1] = 3; // Top-right corner
        
        uint8[] memory equipmentSlots = new uint8[](4);
        equipmentSlots[0] = 12; // Bottom-left
        equipmentSlots[1] = 13; // Bottom-middle-left
        equipmentSlots[2] = 14; // Bottom-middle-right
        equipmentSlots[3] = 15; // Bottom-right

        shipRegistry.registerShip(
            1, // id
            "Starter Boat", // name
            100, // fuelCapacity
            50, // enginePower
            100, // maxDurability
            4, // cargoWidth
            4, // cargoHeight
            cargoShape,
            engineSlots,
            equipmentSlots,
            0, // purchasePrice (free starter ship)
            10 * 10**18 // repairCostPerPoint (10 RTC per durability point)
        );
        
        console.log("Added starter ship");
    }

    function _addBasicFish(FishRegistry fishRegistry) private {
        // Add common fish species
        
        // 1. Sardine (common, small)
        uint8[] memory sardineBaits = new uint8[](1);
        sardineBaits[0] = 1; // Basic bait
        uint16[] memory sardineProbabilities = new uint16[](1);
        sardineProbabilities[0] = 5000; // 50% chance with basic bait
        
        bytes memory sardineShape = new bytes(1);
        sardineShape[0] = 0x01; // 1x1 shape
        
        fishRegistry.registerFishSpecies(
            1, // id
            "Sardine", // name
            100 * 10**18, // basePrice (100 RTC)
            1, // rarity (common)
            50, // minWeight (50g)
            150, // maxWeight (150g)
            1, // shapeWidth
            1, // shapeHeight
            sardineShape,
            5, // freshnessDecayRate (5% per hour)
            sardineBaits,
            sardineProbabilities
        );

        // 2. Cod (uncommon, medium)
        uint8[] memory codBaits = new uint8[](2);
        codBaits[0] = 1; // Basic bait
        codBaits[1] = 2; // Premium bait
        uint16[] memory codProbabilities = new uint16[](2);
        codProbabilities[0] = 2000; // 20% chance with basic bait
        codProbabilities[1] = 4000; // 40% chance with premium bait
        
        bytes memory codShape = new bytes(1);
        codShape[0] = 0x03; // 2x1 shape (bits: 11)
        
        fishRegistry.registerFishSpecies(
            2, // id
            "Cod", // name
            250 * 10**18, // basePrice (250 RTC)
            3, // rarity (uncommon)
            200, // minWeight (200g)
            800, // maxWeight (800g)
            2, // shapeWidth
            1, // shapeHeight
            codShape,
            3, // freshnessDecayRate (3% per hour)
            codBaits,
            codProbabilities
        );

        // 3. Tuna (rare, large)
        uint8[] memory tunaBaits = new uint8[](2);
        tunaBaits[0] = 2; // Premium bait
        tunaBaits[1] = 3; // Specialized bait
        uint16[] memory tunaProbabilities = new uint16[](2);
        tunaProbabilities[0] = 1000; // 10% chance with premium bait
        tunaProbabilities[1] = 2500; // 25% chance with specialized bait
        
        bytes memory tunaShape = new bytes(1);
        tunaShape[0] = 0x0F; // 2x2 shape (bits: 1111)
        
        fishRegistry.registerFishSpecies(
            3, // id
            "Tuna", // name
            500 * 10**18, // basePrice (500 RTC)
            6, // rarity (rare)
            1000, // minWeight (1kg)
            5000, // maxWeight (5kg)
            2, // shapeWidth
            2, // shapeHeight
            tunaShape,
            2, // freshnessDecayRate (2% per hour)
            tunaBaits,
            tunaProbabilities
        );
        
        console.log("Added basic fish species");
    }

    function _addBasicBait(FishRegistry fishRegistry) private {
        // 1. Basic Bait
        fishRegistry.registerBaitType(
            1, // id
            "Basic Bait", // name
            5 * 10**18 // price (5 RTC)
        );

        // 2. Premium Bait
        fishRegistry.registerBaitType(
            2, // id
            "Premium Bait", // name
            15 * 10**18 // price (15 RTC)
        );

        // 3. Specialized Bait
        fishRegistry.registerBaitType(
            3, // id
            "Specialized Bait", // name
            30 * 10**18 // price (30 RTC)
        );
        
        console.log("Added basic bait types");
    }
}