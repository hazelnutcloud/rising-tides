// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRisingTidesInventory} from "./interfaces/IRisingTidesInventory.sol";
import {IRisingTidesWorld} from "./interfaces/IRisingTidesWorld.sol";
import {IRisingTidesFishingRod} from "./interfaces/IRisingTidesFishingRod.sol";
import {IERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Pausable} from "../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";

contract RisingTidesInventory is IRisingTidesInventory, AccessControl, Pausable {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 private constant GAME_MASTER_ROLE = keccak256("GAME_MASTER_ROLE");

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    struct PlayerInventory {
        uint256 equippedShipId;
        uint256 equippedRodTokenId;
        uint256 fuel;
        mapping(uint256 => uint256) bait;
        mapping(uint256 => uint256) materials;
        Fish[] fish;
    }

    mapping(address => PlayerInventory) private inventories;
    mapping(address => uint256) public shipOwnership;
    mapping(uint256 => Ship) public shipTypes;
    mapping(address => bool) public authorizedContracts;

    StarterKit public starterKitConfig;

    address public risingTidesWorld;
    address public risingTidesFishing;
    address public risingTidesPort;
    address public risingTidesFishingRod;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAuthorized() {
        if (!authorizedContracts[msg.sender]) revert Unauthorized();
        _;
    }

    modifier onlyWorld() {
        if (msg.sender != risingTidesWorld) revert OnlyWorld();
        _;
    }

    modifier onlyFishing() {
        if (msg.sender != risingTidesFishing) revert OnlyFishing();
        _;
    }

    modifier onlyPort() {
        if (msg.sender != risingTidesPort) revert OnlyPort();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _admin, address _gameMaster) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(GAME_MASTER_ROLE, _gameMaster);
    }

    /*//////////////////////////////////////////////////////////////
                            SHIP FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function equipShip(address player, uint256 shipId) external onlyPort whenNotPaused {
        // Verify player is at port (Port contract should check this)
        if (!shipTypes[shipId].exists) revert InvalidShipId();
        if ((shipOwnership[player] & (uint256(1) << shipId)) == 0) revert ShipNotOwned();

        uint256 previousShipId = inventories[player].equippedShipId;
        
        // Check if changing ship would exceed cargo capacity
        if (shipId != previousShipId) {
            uint256 cargoWeight = getPlayerCargoWeight(player);
            if (cargoWeight > shipTypes[shipId].weightCapacity) {
                revert CargoExceedsCapacity();
            }
        }

        inventories[player].equippedShipId = shipId;
        emit ShipEquipped(player, shipId, previousShipId);
    }

    function getEquippedShip(address player) external view returns (uint256 shipId) {
        return inventories[player].equippedShipId;
    }

    function getShipStats(uint256 shipId)
        external
        view
        returns (
            uint256 enginePower,
            uint256 weightCapacity,
            uint256 fuelCapacity
        )
    {
        Ship memory ship = shipTypes[shipId];
        return (ship.enginePower, ship.weightCapacity, ship.fuelCapacity);
    }

    function hasShip(address player, uint256 shipId) external view returns (bool) {
        return (shipOwnership[player] & (uint256(1) << shipId)) != 0;
    }

    function grantShip(address player, uint256 shipId) external onlyPort whenNotPaused {
        if (!shipTypes[shipId].exists) revert InvalidShipId();
        shipOwnership[player] |= (uint256(1) << shipId);
        emit ShipGranted(player, shipId);
    }

    function getTotalWeight(address player) external view returns (uint256) {
        uint256 shipId = inventories[player].equippedShipId;
        if (shipId == 0) return 0;

        Ship memory ship = shipTypes[shipId];
        uint256 cargoWeight = getPlayerCargoWeight(player);

        return ship.emptyWeight + cargoWeight;
    }

    /*//////////////////////////////////////////////////////////////
                            RESOURCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getFuel(address player) external view returns (uint256) {
        return inventories[player].fuel;
    }

    function addFuel(address player, uint256 amount) external onlyPort whenNotPaused {
        inventories[player].fuel += amount;
        emit FuelChanged(player, inventories[player].fuel, int256(amount));
    }

    function consumeFuel(address player, uint256 amount) external onlyAuthorized whenNotPaused {
        if (inventories[player].fuel < amount) revert InsufficientFuel();
        inventories[player].fuel -= amount;
        emit FuelChanged(player, inventories[player].fuel, -int256(amount));
    }

    function getBait(address player, uint256 baitId) external view returns (uint256) {
        return inventories[player].bait[baitId];
    }

    function addBait(address player, uint256 baitId, uint256 amount) external onlyPort whenNotPaused {
        inventories[player].bait[baitId] += amount;
        emit BaitChanged(player, baitId, inventories[player].bait[baitId], int256(amount));
    }

    function consumeBait(address player, uint256 baitId, uint256 amount) external onlyFishing whenNotPaused {
        if (inventories[player].bait[baitId] < amount) revert InsufficientBait();
        inventories[player].bait[baitId] -= amount;
        emit BaitChanged(player, baitId, inventories[player].bait[baitId], -int256(amount));
    }

    function getMaterials(address player, uint256 materialId) external view returns (uint256) {
        return inventories[player].materials[materialId];
    }

    function addMaterials(address player, uint256 materialId, uint256 amount) external onlyPort whenNotPaused {
        inventories[player].materials[materialId] += amount;
        emit MaterialsChanged(player, materialId, inventories[player].materials[materialId], int256(amount));
    }

    function consumeMaterials(address player, uint256 materialId, uint256 amount) external onlyPort whenNotPaused {
        if (inventories[player].materials[materialId] < amount) revert InsufficientMaterials();
        inventories[player].materials[materialId] -= amount;
        emit MaterialsChanged(player, materialId, inventories[player].materials[materialId], -int256(amount));
    }

    /*//////////////////////////////////////////////////////////////
                            FISH FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addFish(
        address player,
        uint256 fishId,
        uint256 weight,
        bool isTrophyQuality,
        uint256 freshnessModifier
    ) external onlyFishing whenNotPaused {
        // Check cargo capacity
        uint256 shipId = inventories[player].equippedShipId;
        if (shipId == 0) revert NoShipEquipped();

        uint256 newCargoWeight = getPlayerCargoWeight(player) + weight;
        if (newCargoWeight > shipTypes[shipId].weightCapacity) {
            revert CargoExceedsCapacity();
        }

        inventories[player].fish.push(Fish({
            fishId: fishId,
            weight: weight,
            caughtAt: block.timestamp,
            isTrophyQuality: isTrophyQuality,
            freshnessModifier: freshnessModifier
        }));

        emit FishAdded(player, fishId, weight, isTrophyQuality, freshnessModifier, block.timestamp);
    }

    function removeFish(address player, uint256 index) external onlyPort whenNotPaused returns (Fish memory) {
        Fish[] storage playerFish = inventories[player].fish;
        if (index >= playerFish.length) revert InvalidFishIndex();

        Fish memory removedFish = playerFish[index];

        // Swap with last element and pop
        if (index < playerFish.length - 1) {
            playerFish[index] = playerFish[playerFish.length - 1];
        }
        playerFish.pop();

        emit FishRemoved(player, removedFish.fishId, removedFish.weight, index);
        return removedFish;
    }

    function getFish(address player) external view returns (Fish[] memory) {
        return inventories[player].fish;
    }

    function getPlayerCargoWeight(address player) public view returns (uint256) {
        Fish[] storage playerFish = inventories[player].fish;
        uint256 totalWeight = 0;

        for (uint256 i = 0; i < playerFish.length; i++) {
            totalWeight += playerFish[i].weight;
        }

        return totalWeight;
    }

    /*//////////////////////////////////////////////////////////////
                            ROD FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function equipRod(address player, uint256 tokenId) external onlyPort whenNotPaused {
        if (inventories[player].equippedRodTokenId != 0) revert RodAlreadyEquipped();

        // Verify player owns the rod
        IERC721 rodContract = IERC721(risingTidesFishingRod);
        if (rodContract.ownerOf(tokenId) != player) revert NotRodOwner();

        // Transfer rod to this contract
        rodContract.transferFrom(player, address(this), tokenId);

        inventories[player].equippedRodTokenId = tokenId;
        emit RodEquipped(player, tokenId);
    }

    function unequipRod(address player) external onlyPort whenNotPaused {
        uint256 tokenId = inventories[player].equippedRodTokenId;
        if (tokenId == 0) revert NoRodEquipped();

        // Transfer rod back to player
        IERC721 rodContract = IERC721(risingTidesFishingRod);
        rodContract.transferFrom(address(this), player, tokenId);

        inventories[player].equippedRodTokenId = 0;
        emit RodUnequipped(player, tokenId);
    }

    function getEquippedRod(address player) external view returns (uint256) {
        return inventories[player].equippedRodTokenId;
    }

    /*//////////////////////////////////////////////////////////////
                            STARTER KIT
    //////////////////////////////////////////////////////////////*/

    function mintStarterKit(address player) external onlyAuthorized whenNotPaused {
        // Grant starter ship
        if (starterKitConfig.shipId != 0) {
            shipOwnership[player] |= (uint256(1) << starterKitConfig.shipId);
            inventories[player].equippedShipId = starterKitConfig.shipId;
            emit ShipGranted(player, starterKitConfig.shipId);
            emit ShipEquipped(player, starterKitConfig.shipId, 0);
        }

        // Add starter fuel
        inventories[player].fuel = starterKitConfig.fuel;

        // Add starter bait
        for (uint256 i = 0; i < starterKitConfig.baitIds.length; i++) {
            inventories[player].bait[starterKitConfig.baitIds[i]] = starterKitConfig.baitAmounts[i];
        }

        emit StarterKitMinted(player, starterKitConfig.shipId, starterKitConfig.fuel);
        
        // Emit individual resource events for complete tracking
        if (starterKitConfig.fuel > 0) {
            emit FuelChanged(player, starterKitConfig.fuel, int256(starterKitConfig.fuel));
        }
        
        // Emit bait events
        for (uint256 i = 0; i < starterKitConfig.baitIds.length; i++) {
            if (starterKitConfig.baitAmounts[i] > 0) {
                emit BaitChanged(
                    player, 
                    starterKitConfig.baitIds[i], 
                    starterKitConfig.baitAmounts[i], 
                    int256(starterKitConfig.baitAmounts[i])
                );
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getShipOwnership(address player) external view returns (uint256) {
        return shipOwnership[player];
    }

    function getShipInfo(uint256 shipId) external view returns (Ship memory) {
        return shipTypes[shipId];
    }

    function getStarterKit() external view returns (StarterKit memory) {
        return starterKitConfig;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setContracts(
        address _world,
        address _fishing,
        address _port,
        address _fishingRod
    ) external onlyRole(ADMIN_ROLE) {
        risingTidesWorld = _world;
        risingTidesFishing = _fishing;
        risingTidesPort = _port;
        risingTidesFishingRod = _fishingRod;

        // Automatically authorize these contracts
        authorizedContracts[_world] = true;
        authorizedContracts[_fishing] = true;
        authorizedContracts[_port] = true;
    }

    function setShipType(uint256 shipId, Ship memory ship) external onlyRole(GAME_MASTER_ROLE) {
        ship.exists = true;
        shipTypes[shipId] = ship;
    }

    function setStarterKit(StarterKit memory kit) external onlyRole(GAME_MASTER_ROLE) {
        starterKitConfig = kit;
    }

    function setAuthorizedContract(address contractAddress, bool authorized) external onlyRole(ADMIN_ROLE) {
        authorizedContracts[contractAddress] = authorized;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                            ROLE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function grantAdminRole(address _admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, _admin);
    }

    function grantGameMasterRole(address _gameMaster) external onlyRole(ADMIN_ROLE) {
        grantRole(GAME_MASTER_ROLE, _gameMaster);
    }

    function revokeGameMasterRole(address _gameMaster) external onlyRole(ADMIN_ROLE) {
        revokeRole(GAME_MASTER_ROLE, _gameMaster);
    }
}