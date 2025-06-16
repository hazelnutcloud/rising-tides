// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "../src/tokens/RisingTidesCurrency.sol";
import "../src/registries/ShipRegistry.sol";
import "../src/registries/FishRegistry.sol";
import "../src/registries/EngineRegistry.sol";
import "../src/registries/FishingRodRegistry.sol";
import "../src/interfaces/IFishingRodRegistry.sol";
import "../src/registries/MapRegistry.sol";
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

        // 4. Deploy Engine Registry
        console.log("\n=== Deploying EngineRegistry ===");
        EngineRegistry engineRegistry = new EngineRegistry();
        console.log("EngineRegistry deployed to:", address(engineRegistry));

        // 5. Deploy Fishing Rod Registry
        console.log("\n=== Deploying FishingRodRegistry ===");
        FishingRodRegistry fishingRodRegistry = new FishingRodRegistry();
        console.log("FishingRodRegistry deployed to:", address(fishingRodRegistry));

        // 6. Deploy Map Registry
        console.log("\n=== Deploying MapRegistry ===");
        MapRegistry mapRegistry = new MapRegistry();
        console.log("MapRegistry deployed to:", address(mapRegistry));

        // 7. Deploy Game State
        console.log("\n=== Deploying GameState ===");
        // Note: Using deployer address as initial server signer (should be changed after deployment)
        GameState gameState = new GameState(
            address(currency), 
            address(shipRegistry), 
            address(fishRegistry), 
            address(engineRegistry),
            address(fishingRodRegistry),
            address(mapRegistry), 
            deployerAddress
        );
        console.log("GameState deployed to:", address(gameState));

        // 8. Deploy Fish Market
        console.log("\n=== Deploying FishMarket ===");
        FishMarket fishMarket = new FishMarket(
            address(currency),
            address(fishRegistry),
            deployerAddress // Fee collector
        );
        console.log("FishMarket deployed to:", address(fishMarket));

        // 9. Deploy Season Pass
        console.log("\n=== Deploying SeasonPass ===");
        SeasonPass seasonPass = new SeasonPass();
        console.log("SeasonPass deployed to:", address(seasonPass));

        // 10. Setup Roles and Permissions
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

        // 11. Initialize with sample data
        console.log("\n=== Initializing sample data ===");

        // Add a basic starter ship
        _addStarterShip(shipRegistry);

        // Add basic engines
        _addBasicEngines(engineRegistry);

        // Add basic equipment
        _addBasicFishingRods(fishingRodRegistry);

        // Add some basic fish species
        _addBasicFish(fishRegistry);

        // Add basic bait types
        _addBasicBait(fishRegistry);

        // Add starter map
        _addStarterMap(mapRegistry);

        vm.stopBroadcast();

        // 12. Log deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("RisingTidesCurrency:", address(currency));
        console.log("ShipRegistry:", address(shipRegistry));
        console.log("FishRegistry:", address(fishRegistry));
        console.log("EngineRegistry:", address(engineRegistry));
        console.log("FishingRodRegistry:", address(fishingRodRegistry));
        console.log("MapRegistry:", address(mapRegistry));
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

        // Create slot types array (16 slots for 4x4 grid)
        // 0=normal, 1=engine, 2=equipment
        uint8[] memory slotTypes = new uint8[](16);
        // Initialize all as normal cargo slots
        for (uint256 i = 0; i < 16; i++) {
            slotTypes[i] = 0; // normal slot
        }
        // Set engine slots
        slotTypes[0] = 1; // Top-left corner
        slotTypes[3] = 1; // Top-right corner
        // Set equipment slots
        slotTypes[12] = 2; // Bottom-left
        slotTypes[13] = 2; // Bottom-middle-left
        slotTypes[14] = 2; // Bottom-middle-right
        slotTypes[15] = 2; // Bottom-right

        shipRegistry.registerShip(
            1, // id
            "Starter Boat", // name
            100, // fuelCapacity
            100, // maxDurability
            4, // cargoWidth
            4, // cargoHeight
            cargoShape,
            slotTypes,
            0, // purchasePrice (free starter ship)
            10 * 10 ** 18 // repairCostPerPoint (10 RTC per durability point)
        );

        console.log("Added starter ship");
    }

    function _addBasicFish(FishRegistry fishRegistry) private {
        // Add common fish species

        // 1. Sardine (common, small)
        bytes memory sardineShape = new bytes(1);
        sardineShape[0] = 0x01; // 1x1 shape

        fishRegistry.registerFishSpecies(
            1, // id
            100 * 10 ** 18, // basePrice (100 RTC)
            1, // rarity (common)
            1, // shapeWidth
            1, // shapeHeight
            sardineShape,
            5 // freshnessDecayRate (5% per hour)
        );

        // 2. Cod (uncommon, medium)
        bytes memory codShape = new bytes(1);
        codShape[0] = 0x03; // 2x1 shape (bits: 11)

        fishRegistry.registerFishSpecies(
            2, // id
            250 * 10 ** 18, // basePrice (250 RTC)
            3, // rarity (uncommon)
            2, // shapeWidth
            1, // shapeHeight
            codShape,
            3 // freshnessDecayRate (3% per hour)
        );

        // 3. Tuna (rare, large)
        bytes memory tunaShape = new bytes(1);
        tunaShape[0] = 0x0F; // 2x2 shape (bits: 1111)

        fishRegistry.registerFishSpecies(
            3, // id
            500 * 10 ** 18, // basePrice (500 RTC)
            6, // rarity (rare)
            2, // shapeWidth
            2, // shapeHeight
            tunaShape,
            2 // freshnessDecayRate (2% per hour)
        );

        console.log("Added basic fish species");
    }

    function _addBasicBait(FishRegistry fishRegistry) private {
        // 1. Basic Bait
        fishRegistry.registerBaitType(
            1, // id
            "Basic Bait", // name
            5 * 10 ** 18 // price (5 RTC)
        );

        // 2. Premium Bait
        fishRegistry.registerBaitType(
            2, // id
            "Premium Bait", // name
            15 * 10 ** 18 // price (15 RTC)
        );

        // 3. Specialized Bait
        fishRegistry.registerBaitType(
            3, // id
            "Specialized Bait", // name
            30 * 10 ** 18 // price (30 RTC)
        );

        console.log("Added basic bait types");
    }

    function _addStarterMap(MapRegistry mapRegistry) private {
        // Register the starting ocean map
        mapRegistry.registerMap(
            1, // id
            "Starting Waters", // name
            1, // tier
            0, // travel cost (free starting map)
            -100, // minX
            100, // maxX
            -100, // minY
            100 // maxY
        );

        // Add a bait shop at the origin (0,0)
        uint256[] memory availableBait = new uint256[](3);
        availableBait[0] = 1; // Basic bait
        availableBait[1] = 2; // Premium bait
        availableBait[2] = 3; // Specialized bait

        mapRegistry.addBaitShop(1, 0, 0, availableBait);

        // Add some fish distributions for testing
        uint256[] memory fishSpecies = new uint256[](2);
        fishSpecies[0] = 1; // Sardine
        fishSpecies[1] = 2; // Cod

        // Add fish distribution at a few locations
        mapRegistry.updateFishDistribution(1, 5, 5, fishSpecies);
        mapRegistry.updateFishDistribution(1, -10, 10, fishSpecies);
        mapRegistry.updateFishDistribution(1, 15, -5, fishSpecies);

        console.log("Added starter map with bait shop and fish distributions");
    }

    function _addBasicEngines(EngineRegistry engineRegistry) private {
        // 1. Small Engine (1x1)
        bytes memory smallEngineShape = new bytes(1);
        smallEngineShape[0] = 0x01; // 1x1 shape

        engineRegistry.registerEngine(
            1, // id
            "Small Engine", // name
            30, // enginePower
            90, // fuelEfficiency (90% of base)
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
            60, // enginePower
            110, // fuelEfficiency (110% of base - less efficient but more power)
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
            100, // enginePower
            130, // fuelEfficiency (130% of base - least efficient but most power)
            2, // shapeWidth
            2, // shapeHeight
            largeEngineShape,
            500 * 10 ** 18, // purchasePrice (500 RTC)
            120 // weight
        );

        console.log("Added basic engines");
    }

    function _addBasicFishingRods(FishingRodRegistry fishingRodRegistry) private {
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

        console.log("Added basic fishing rods");
    }
}
