// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

// Import all contracts
import {Doubloons} from "../src/Doubloons.sol";
import {MockVRFCoordinator} from "../src/MockVRFCoordinator.sol";
import {RisingTidesFishingRod} from "../src/RisingTidesFishingRod.sol";
import {RisingTidesInventory} from "../src/RisingTidesInventory.sol";
import {RisingTidesWorld} from "../src/RisingTidesWorld.sol";
import {RisingTidesFishing} from "../src/RisingTidesFishing.sol";
import {RisingTidesPort} from "../src/RisingTidesPort.sol";

contract DeployAndSaveScript is Script {
    // Contract instances
    Doubloons public doubloons;
    MockVRFCoordinator public vrfCoordinator;
    RisingTidesFishingRod public fishingRod;
    RisingTidesInventory public inventory;
    RisingTidesWorld public world;
    RisingTidesFishing public fishing;
    RisingTidesPort public port;

    function run() public {
        // Get deployer address
        address deployer = vm.envOr("DEPLOYER_ADDRESS", vm.getWallets()[0]);

        console.log("Deploying contracts with deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployer);

        // 1. Deploy Doubloons (no dependencies)
        console.log("Deploying Doubloons...");
        doubloons = new Doubloons(deployer);
        console.log("Doubloons deployed at:", address(doubloons));

        // 2. Deploy MockVRFCoordinator (no dependencies)
        console.log("Deploying MockVRFCoordinator...");
        vrfCoordinator = new MockVRFCoordinator(deployer);
        console.log("MockVRFCoordinator deployed at:", address(vrfCoordinator));

        // 3. Deploy RisingTidesFishingRod (no dependencies)
        console.log("Deploying RisingTidesFishingRod...");
        string memory baseURI = "https://api.risingtides.fun/metadata/rod/";
        fishingRod = new RisingTidesFishingRod(deployer, deployer, baseURI);
        console.log("RisingTidesFishingRod deployed at:", address(fishingRod));

        // 4. Deploy RisingTidesInventory (needs to be linked later)
        console.log("Deploying RisingTidesInventory...");
        inventory = new RisingTidesInventory(deployer, deployer);
        console.log("RisingTidesInventory deployed at:", address(inventory));

        // 5. Deploy RisingTidesWorld (needs Doubloons and Inventory)
        console.log("Deploying RisingTidesWorld...");
        world = new RisingTidesWorld(
            address(doubloons),
            address(inventory),
            deployer,
            deployer
        );
        console.log("RisingTidesWorld deployed at:", address(world));

        // 6. Deploy RisingTidesFishing (needs World, Inventory, Rod, VRF)
        console.log("Deploying RisingTidesFishing...");
        fishing = new RisingTidesFishing(
            address(world),
            address(inventory),
            address(fishingRod),
            deployer, // offchain signer (can be changed later)
            address(vrfCoordinator)
        );
        console.log("RisingTidesFishing deployed at:", address(fishing));

        // 7. Deploy RisingTidesPort (needs all contracts)
        console.log("Deploying RisingTidesPort...");
        port = new RisingTidesPort(
            address(world),
            address(inventory),
            address(fishing),
            address(fishingRod),
            address(doubloons),
            deployer,
            deployer,
            address(vrfCoordinator)
        );
        console.log("RisingTidesPort deployed at:", address(port));

        // Post-deployment setup
        console.log("\nSetting up contract connections...");

        // Set contract addresses in Inventory (also authorizes them)
        inventory.setContracts(
            address(world),
            address(fishing),
            address(port),
            address(fishingRod)
        );

        // Set contract addresses in World
        world.setContracts(address(inventory), address(fishing));

        // Set contract addresses in FishingRod
        fishingRod.setContracts(address(port), address(fishing));

        // Grant roles on Doubloons
        bytes32 MINTER_ROLE = doubloons.MINTER_ROLE();
        bytes32 BURNER_ROLE = doubloons.BURNER_ROLE();

        doubloons.grantRole(MINTER_ROLE, address(port));
        doubloons.grantRole(BURNER_ROLE, address(world));
        doubloons.grantRole(BURNER_ROLE, address(port));

        vm.stopBroadcast();

        // Save deployment addresses
        _saveDeployment();

        console.log("\nDeployment complete!");
        console.log("All contracts deployed and configured successfully.");
    }

    function _saveDeployment() internal {
        string memory deploymentDir = "deployments/";
        string memory chainDir = string.concat(
            deploymentDir,
            vm.toString(block.chainid),
            "/"
        );

        // Create directories if they don't exist
        vm.createDir(deploymentDir, true);
        vm.createDir(chainDir, true);

        // Create deployment JSON
        string memory json = "deployment";
        vm.serializeAddress(json, "doubloons", address(doubloons));
        vm.serializeAddress(json, "vrfCoordinator", address(vrfCoordinator));
        vm.serializeAddress(json, "fishingRod", address(fishingRod));
        vm.serializeAddress(json, "inventory", address(inventory));
        vm.serializeAddress(json, "world", address(world));
        vm.serializeAddress(json, "fishing", address(fishing));
        vm.serializeAddress(json, "port", address(port));
        vm.serializeUint(json, "chainId", block.chainid);
        vm.serializeUint(json, "blockNumber", block.number);
        string memory finalJson = vm.serializeUint(
            json,
            "timestamp",
            block.timestamp
        );

        // Write to file
        string memory filename = string.concat(chainDir, "latest.json");
        vm.writeJson(finalJson, filename);

        // Also save with timestamp
        string memory timestampFilename = string.concat(
            chainDir,
            vm.toString(block.timestamp),
            ".json"
        );
        vm.writeJson(finalJson, timestampFilename);

        console.log("Deployment saved to:", filename);
    }
}
