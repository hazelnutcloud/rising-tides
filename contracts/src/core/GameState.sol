// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IGameState.sol";
import "../interfaces/IShipRegistry.sol";
import "../tokens/RisingTidesCurrency.sol";
import "../registries/FishRegistry.sol";
import "../libraries/InventoryLib.sol";

/**
 * @title GameState
 * @dev Main contract managing core game mechanics
 * Handles player registration, movement, fishing, and inventory management
 */
contract GameState is IGameState, AccessControl, Pausable, ReentrancyGuard {
    using InventoryLib for InventoryLib.InventoryGrid;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Contract dependencies
    RisingTidesCurrency public currency;
    IShipRegistry public shipRegistry;
    FishRegistry public fishRegistry;

    // Game state mappings
    mapping(address => PlayerState) private playerStates;
    mapping(address => InventoryLib.InventoryGrid) private playerInventories;
    mapping(address => bool) private registeredPlayers;
    mapping(address => mapping(uint256 => FishCatch)) private playerFish;
    mapping(address => uint256) private playerFishCount;

    // Game configuration
    uint256 public constant FUEL_PRICE_PER_UNIT = 10 * 10**18; // 10 RTC per fuel unit
    uint256 public constant BASE_FISHING_COST = 5 * 10**18; // 5 RTC per fishing attempt
    uint256 public constant MAX_SHARDS = 100;
    uint256 public constant HEX_MOVE_COST = 1; // Base fuel cost per hex
    
    // Movement constraints
    int32 public constant MAX_COORDINATE = 1000;
    int32 public constant MIN_COORDINATE = -1000;

    // Random seed for fishing
    uint256 private fishingSeed;

    modifier onlyRegisteredPlayer() {
        require(registeredPlayers[msg.sender], "Player not registered");
        _;
    }

    modifier validCoordinates(int32 x, int32 y) {
        require(x >= MIN_COORDINATE && x <= MAX_COORDINATE, "X coordinate out of bounds");
        require(y >= MIN_COORDINATE && y <= MAX_COORDINATE, "Y coordinate out of bounds");
        _;
    }

    modifier validShard(uint8 shard) {
        require(shard < MAX_SHARDS, "Invalid shard ID");
        _;
    }

    constructor(
        address _currency,
        address _shipRegistry,
        address _fishRegistry
    ) {
        require(_currency != address(0), "Currency address cannot be zero");
        require(_shipRegistry != address(0), "Ship registry address cannot be zero");
        require(_fishRegistry != address(0), "Fish registry address cannot be zero");

        currency = RisingTidesCurrency(_currency);
        shipRegistry = IShipRegistry(_shipRegistry);
        fishRegistry = FishRegistry(_fishRegistry);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);

        fishingSeed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao)));
    }

    /**
     * @dev Register a new player
     */
    function registerPlayer(uint8 shard) external validShard(shard) whenNotPaused {
        require(!registeredPlayers[msg.sender], "Player already registered");

        // Initialize player with default ship (ID 1)
        playerStates[msg.sender] = PlayerState({
            position: Position(0, 0),
            shard: shard,
            shipId: 1,
            currentFuel: 100, // Starting fuel
            lastMoveTimestamp: block.timestamp,
            isActive: true
        });

        // Initialize inventory grid based on default ship
        _initializeInventory(msg.sender, 1);

        registeredPlayers[msg.sender] = true;

        emit PlayerRegistered(msg.sender, shard);
    }

    /**
     * @dev Get player state
     */
    function getPlayerState(address player) external view returns (PlayerState memory) {
        return playerStates[player];
    }

    /**
     * @dev Check if player is registered
     */
    function isPlayerRegistered(address player) external view returns (bool) {
        return registeredPlayers[player];
    }

    /**
     * @dev Move player to new coordinates
     */
    function move(int32 newX, int32 newY) 
        external 
        onlyRegisteredPlayer 
        validCoordinates(newX, newY) 
        whenNotPaused 
    {
        PlayerState storage player = playerStates[msg.sender];
        
        // Calculate fuel cost
        uint256 fuelCost = calculateFuelCost(msg.sender, newX, newY);
        require(player.currentFuel >= fuelCost, "Insufficient fuel");

        // Update position and fuel
        player.position = Position(newX, newY);
        player.currentFuel -= fuelCost;
        player.lastMoveTimestamp = block.timestamp;

        emit PlayerMoved(msg.sender, player.shard, newX, newY, fuelCost);
    }

    /**
     * @dev Calculate fuel cost for movement
     */
    function calculateFuelCost(address player, int32 targetX, int32 targetY) 
        public 
        view 
        returns (uint256) 
    {
        PlayerState memory playerState = playerStates[player];
        
        // Calculate distance (Manhattan distance for hex grid)
        int32 deltaX = targetX - playerState.position.x;
        int32 deltaY = targetY - playerState.position.y;
        uint256 distance = uint256(int256(abs(deltaX)) + int256(abs(deltaY)));

        // Get ship stats to calculate fuel efficiency
        IShipRegistry.ShipStats memory shipStats = shipRegistry.getShipStats(playerState.shipId);
        
        // Fuel cost = distance * base_cost * fuel_efficiency_modifier
        return distance * HEX_MOVE_COST * shipStats.fuelEfficiency / 100;
    }

    /**
     * @dev Purchase fuel
     */
    function purchaseFuel(uint256 amount) external onlyRegisteredPlayer whenNotPaused nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        
        uint256 totalCost = amount * FUEL_PRICE_PER_UNIT;
        require(currency.balanceOf(msg.sender) >= totalCost, "Insufficient currency");

        // Burn currency and add fuel
        currency.burn(msg.sender, totalCost, "Fuel purchase");
        playerStates[msg.sender].currentFuel += amount;

        emit FuelPurchased(msg.sender, amount, totalCost);
    }

    /**
     * @dev Get current fuel for player
     */
    function getCurrentFuel(address player) external view returns (uint256) {
        return playerStates[player].currentFuel;
    }

    /**
     * @dev Fish with bait
     */
    function fish(uint8 baitType) 
        external 
        onlyRegisteredPlayer 
        whenNotPaused 
        nonReentrant 
        returns (uint8 species, uint16 weight) 
    {
        require(fishRegistry.isValidBait(baitType), "Invalid bait type");
        
        // Check if player has enough currency for bait
        FishRegistry.BaitType memory bait = fishRegistry.getBaitType(baitType);
        require(currency.balanceOf(msg.sender) >= bait.price, "Insufficient currency for bait");

        // Burn currency for bait cost
        currency.burn(msg.sender, bait.price, "Bait purchase");

        // Determine catch result
        (species, weight) = _performFishing(baitType);

        if (species > 0) {
            // Store caught fish
            uint256 fishId = playerFishCount[msg.sender];
            playerFish[msg.sender][fishId] = FishCatch({
                species: species,
                weight: weight,
                caughtAt: block.timestamp
            });
            playerFishCount[msg.sender]++;

            emit FishCaught(msg.sender, species, weight, fishId);
        }

        return (species, weight);
    }

    /**
     * @dev Change player's ship
     */
    function changeShip(uint256 newShipId) external onlyRegisteredPlayer whenNotPaused {
        require(shipRegistry.isValidShip(newShipId), "Invalid ship ID");
        
        PlayerState storage player = playerStates[msg.sender];
        uint256 oldShipId = player.shipId;

        // TODO: Add ship ownership/purchase logic
        // For now, allow free ship changes

        player.shipId = newShipId;
        
        // Reinitialize inventory for new ship
        _initializeInventory(msg.sender, newShipId);

        emit ShipChanged(msg.sender, newShipId);
    }

    /**
     * @dev Change player's shard
     */
    function changeShard(uint8 newShard) external onlyRegisteredPlayer validShard(newShard) whenNotPaused {
        PlayerState storage player = playerStates[msg.sender];
        uint8 oldShard = player.shard;
        
        require(newShard != oldShard, "Already in this shard");
        
        // TODO: Add shard change cost logic
        
        player.shard = newShard;

        emit ShardChanged(msg.sender, oldShard, newShard);
    }

    /**
     * @dev Get player's fish by ID
     */
    function getPlayerFish(address player, uint256 fishId) external view returns (FishCatch memory) {
        require(fishId < playerFishCount[player], "Invalid fish ID");
        return playerFish[player][fishId];
    }

    /**
     * @dev Get player's total fish count
     */
    function getPlayerFishCount(address player) external view returns (uint256) {
        return playerFishCount[player];
    }

    /**
     * @dev Internal function to perform fishing logic
     */
    function _performFishing(uint8 baitType) private returns (uint8 species, uint16 weight) {
        // Get all fish species and check compatibility with bait
        uint8 speciesCount = fishRegistry.getSpeciesCount();
        uint256 totalProbability = 0;
        uint8[] memory compatibleSpecies = new uint8[](speciesCount);
        uint16[] memory probabilities = new uint16[](speciesCount);
        uint256 compatibleCount = 0;

        for (uint8 i = 1; i <= speciesCount; i++) {
            if (fishRegistry.isValidSpecies(i)) {
                uint16 probability = fishRegistry.getCatchProbability(i, baitType);
                if (probability > 0) {
                    compatibleSpecies[compatibleCount] = i;
                    probabilities[compatibleCount] = probability;
                    totalProbability += probability;
                    compatibleCount++;
                }
            }
        }

        if (totalProbability == 0) {
            return (0, 0); // No catch
        }

        // Generate random number for species selection
        fishingSeed = uint256(keccak256(abi.encodePacked(
            fishingSeed,
            msg.sender,
            block.timestamp,
            block.prevrandao
        )));

        uint256 randomValue = fishingSeed % totalProbability;
        uint256 currentProbability = 0;

        // Select species based on probability
        for (uint256 i = 0; i < compatibleCount; i++) {
            currentProbability += probabilities[i];
            if (randomValue < currentProbability) {
                species = compatibleSpecies[i];
                break;
            }
        }

        if (species > 0) {
            // Generate random weight for the species
            weight = fishRegistry.getRandomWeight(species, fishingSeed);
        }

        return (species, weight);
    }

    /**
     * @dev Initialize player inventory based on ship
     */
    function _initializeInventory(address player, uint256 shipId) private {
        IShipRegistry.Ship memory ship = shipRegistry.getShip(shipId);
        
        InventoryLib.InventoryGrid storage inventory = playerInventories[player];
        inventory.width = ship.cargoWidth;
        inventory.height = ship.cargoHeight;
        inventory.engineSlots = ship.engineSlots;
        inventory.equipmentSlots = ship.equipmentSlots;
    }

    /**
     * @dev Absolute value function for int32
     */
    function abs(int32 x) private pure returns (int32) {
        return x >= 0 ? x : -x;
    }

    /**
     * @dev Update contract dependencies (admin only)
     */
    function updateDependencies(
        address _currency,
        address _shipRegistry,
        address _fishRegistry
    ) external onlyRole(ADMIN_ROLE) {
        if (_currency != address(0)) {
            currency = RisingTidesCurrency(_currency);
        }
        if (_shipRegistry != address(0)) {
            shipRegistry = IShipRegistry(_shipRegistry);
        }
        if (_fishRegistry != address(0)) {
            fishRegistry = FishRegistry(_fishRegistry);
        }
    }

    /**
     * @dev Pause the contract
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}