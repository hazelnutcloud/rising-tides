// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "../interfaces/IGameState.sol";
import "../interfaces/IShipRegistry.sol";
import "../interfaces/IMapRegistry.sol";
import "../tokens/RisingTidesCurrency.sol";
import "../registries/FishRegistry.sol";
import "../libraries/InventoryLib.sol";

/**
 * @title GameState
 * @dev Main contract managing core game mechanics
 * Handles player registration, movement, fishing, and inventory management
 */
contract GameState is IGameState, AccessControl, Pausable, ReentrancyGuard, VRFConsumerBaseV2 {
    using InventoryLib for InventoryLib.InventoryGrid;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SERVER_ROLE = keccak256("SERVER_ROLE");

    // Contract dependencies
    RisingTidesCurrency public currency;
    IShipRegistry public shipRegistry;
    FishRegistry public fishRegistry;
    IMapRegistry public mapRegistry;
    
    // VRF dependencies
    VRFCoordinatorV2Interface public vrfCoordinator;
    uint64 public subscriptionId;
    bytes32 public keyHash;
    uint32 public callbackGasLimit = 100000;
    uint16 public requestConfirmations = 3;
    uint32 public numWords = 1;

    // Game state mappings
    mapping(address => PlayerState) private playerStates;
    mapping(address => InventoryLib.InventoryGrid) private playerInventories;
    mapping(address => bool) private registeredPlayers;
    mapping(address => mapping(uint256 => FishCatch)) private playerFish;
    mapping(address => uint256) private playerFishCount;
    
    // Player bait inventory
    mapping(address => mapping(uint8 => uint256)) private playerBait;
    
    // VRF request tracking
    mapping(uint256 => address) private vrfRequestToPlayer;
    mapping(uint256 => uint8) private vrfRequestToBaitType;

    // Game configuration
    uint256 public constant FUEL_PRICE_PER_UNIT = 10 * 10**18; // 10 RTC per fuel unit
    uint256 public constant MAX_SHARDS = 100;
    uint256 public constant HEX_MOVE_COST = 1; // Base fuel cost per hex
    uint256 public constant BASE_MOVEMENT_SPEED = 1000; // Base movement speed (lower = faster)
    
    // Movement constraints
    int32 public constant MAX_COORDINATE = 1000;
    int32 public constant MIN_COORDINATE = -1000;

    // Hex movement directions (0=NE, 1=E, 2=SE, 3=SW, 4=W, 5=NW)
    int32[6] private hexDirectionsX = [int32(1), int32(1), int32(0), int32(-1), int32(-1), int32(0)];
    int32[6] private hexDirectionsY = [int32(0), int32(-1), int32(-1), int32(0), int32(1), int32(1)];

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
        address _fishRegistry,
        address _mapRegistry,
        address _vrfCoordinator,
        uint64 _subscriptionId,
        bytes32 _keyHash
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        require(_currency != address(0), "Currency address cannot be zero");
        require(_shipRegistry != address(0), "Ship registry address cannot be zero");
        require(_fishRegistry != address(0), "Fish registry address cannot be zero");
        require(_mapRegistry != address(0), "Map registry address cannot be zero");
        require(_vrfCoordinator != address(0), "VRF coordinator address cannot be zero");

        currency = RisingTidesCurrency(_currency);
        shipRegistry = IShipRegistry(_shipRegistry);
        fishRegistry = FishRegistry(_fishRegistry);
        mapRegistry = IMapRegistry(_mapRegistry);
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(SERVER_ROLE, msg.sender);
    }

    /**
     * @dev Register a new player
     */
    function registerPlayer(uint8 shard, uint256 mapId) 
        external 
        validShard(shard) 
        whenNotPaused 
    {
        require(!registeredPlayers[msg.sender], "Player already registered");
        require(mapRegistry.isValidMap(mapId), "Invalid map ID");

        // Initialize player with default ship (ID 1) and calculate initial weight
        IShipRegistry.ShipStats memory shipStats = shipRegistry.getShipStats(1);
        
        // Calculate initial player weight (ship base weight + engine weight)
        uint256 totalWeight = _calculatePlayerWeight(msg.sender, 1);
        
        playerStates[msg.sender] = PlayerState({
            position: Position(0, 0),
            shard: shard,
            mapId: mapId,
            shipId: 1,
            currentFuel: 100, // Starting fuel
            lastMoveTimestamp: block.timestamp,
            nextMoveTime: block.timestamp,
            movementSpeed: _calculateMovementSpeed(shipStats.enginePower, totalWeight),
            totalWeight: totalWeight,
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
     * @dev Move player using array of directions (0=NE, 1=E, 2=SE, 3=SW, 4=W, 5=NW)
     */
    function move(uint8[] calldata directions) 
        external 
        onlyRegisteredPlayer 
        whenNotPaused 
    {
        PlayerState storage player = playerStates[msg.sender];
        require(block.timestamp >= player.nextMoveTime, "Movement still on cooldown");
        require(directions.length > 0, "No directions provided");
        require(directions.length <= 10, "Too many moves at once"); // Limit batch size
        
        // Validate movement path and terrain collision
        (int32 finalX, int32 finalY) = _validateMovementPath(player.mapId, player.position, directions);
        
        // Calculate fuel cost for the entire movement
        uint256 fuelCost = calculateFuelCost(msg.sender, directions);
        require(player.currentFuel >= fuelCost, "Insufficient fuel");
        
        // Update position and fuel
        player.position = Position(finalX, finalY);
        player.currentFuel -= fuelCost;
        player.lastMoveTimestamp = block.timestamp;
        
        // Set next move time based on movement speed
        player.nextMoveTime = block.timestamp + (player.movementSpeed * directions.length);

        emit PlayerMoved(msg.sender, player.shard, player.mapId, finalX, finalY, fuelCost);
    }

    /**
     * @dev Calculate fuel cost for movement directions
     */
    function calculateFuelCost(address player, uint8[] calldata directions) 
        public 
        view 
        returns (uint256) 
    {
        PlayerState memory playerState = playerStates[player];
        
        // Each direction costs base amount
        uint256 distance = directions.length;

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
     * @dev Fish at current position with chosen bait (free attempts, requires bait in inventory)
     */
    function fish(uint8 baitType) 
        external 
        onlyRegisteredPlayer 
        whenNotPaused 
        nonReentrant 
        returns (uint8 species, uint16 weight) 
    {
        // Validate bait type and check if player has it
        require(fishRegistry.isValidBait(baitType), "Invalid bait type");
        require(playerBait[msg.sender][baitType] > 0, "Insufficient bait");
        
        // Consume one bait
        playerBait[msg.sender][baitType]--;
        
        // Request random number from VRF
        uint256 requestId = vrfCoordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        
        // Store request info for callback
        vrfRequestToPlayer[requestId] = msg.sender;
        vrfRequestToBaitType[requestId] = baitType;
        
        return (0, 0); // Actual result will be emitted in VRF callback
    }

    /**
     * @dev Change player's ship
     */
    function changeShip(uint256 newShipId) external onlyRegisteredPlayer whenNotPaused {
        require(shipRegistry.isValidShip(newShipId), "Invalid ship ID");
        
        PlayerState storage player = playerStates[msg.sender];

        // TODO: Add ship ownership/purchase logic
        // For now, allow free ship changes

        player.shipId = newShipId;
        
        // Recalculate weight and movement speed based on new ship
        IShipRegistry.ShipStats memory shipStats = shipRegistry.getShipStats(newShipId);
        uint256 newWeight = _calculatePlayerWeight(msg.sender, newShipId);
        player.totalWeight = newWeight;
        player.movementSpeed = _calculateMovementSpeed(shipStats.enginePower, newWeight);
        
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
     * @dev VRF callback to complete fishing
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        address player = vrfRequestToPlayer[requestId];
        uint8 baitType = vrfRequestToBaitType[requestId];
        
        if (player == address(0)) {
            return; // Invalid request
        }
        
        PlayerState memory playerState = playerStates[player];
        uint256 randomValue = randomWords[0];
        
        // Determine catch result using map and position-based distribution
        (uint8 species, uint16 weight) = _performFishing(playerState.mapId, playerState.position, baitType, randomValue);
        
        if (species > 0) {
            // Store caught fish
            uint256 fishId = playerFishCount[player];
            playerFish[player][fishId] = FishCatch({
                species: species,
                weight: weight,
                caughtAt: block.timestamp
            });
            playerFishCount[player]++;

            emit FishCaught(player, species, weight, fishId);
        }
        
        // Clean up request tracking
        delete vrfRequestToPlayer[requestId];
        delete vrfRequestToBaitType[requestId];
    }
    
    /**
     * @dev Internal function to perform fishing logic with position and VRF
     */
    function _performFishing(uint256 mapId, Position memory position, uint8 baitType, uint256 randomValue) 
        private 
        view 
        returns (uint8 species, uint16 weight) 
    {
        // Get fish distribution at current position on the map
        IMapRegistry.FishDistribution memory distribution = mapRegistry.getFishDistribution(mapId, position.x, position.y);
        
        // If no distribution set, use default from registry
        if (distribution.species.length == 0) {
            return _performDefaultFishing(baitType, randomValue);
        }
        
        // Calculate total probability with bait modifier
        uint256 totalProbability = 0;
        uint16[] memory adjustedProbabilities = new uint16[](distribution.species.length);
        
        for (uint256 i = 0; i < distribution.species.length; i++) {
            uint8 speciesId = distribution.species[i];
            uint16 baseProbability = distribution.baseProbabilities[i];
            uint16 baitModifier = fishRegistry.getCatchProbability(speciesId, baitType);
            
            adjustedProbabilities[i] = (baseProbability * baitModifier) / 100;
            totalProbability += adjustedProbabilities[i];
        }
        
        if (totalProbability == 0) {
            return (0, 0); // No catch
        }
        
        // Select species based on adjusted probabilities
        uint256 targetValue = randomValue % totalProbability;
        uint256 currentProbability = 0;
        
        for (uint256 i = 0; i < distribution.species.length; i++) {
            currentProbability += adjustedProbabilities[i];
            if (targetValue < currentProbability) {
                species = distribution.species[i];
                break;
            }
        }
        
        if (species > 0) {
            // Generate weight using additional randomness
            weight = fishRegistry.getRandomWeight(species, randomValue >> 128);
        }
        
        return (species, weight);
    }
    
    /**
     * @dev Fallback fishing logic when no position distribution is set
     */
    function _performDefaultFishing(uint8 baitType, uint256 randomValue) 
        private 
        view 
        returns (uint8 species, uint16 weight) 
    {
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
            return (0, 0);
        }

        uint256 targetValue = randomValue % totalProbability;
        uint256 currentProbability = 0;

        for (uint256 i = 0; i < compatibleCount; i++) {
            currentProbability += probabilities[i];
            if (targetValue < currentProbability) {
                species = compatibleSpecies[i];
                break;
            }
        }

        if (species > 0) {
            weight = fishRegistry.getRandomWeight(species, randomValue >> 128);
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
     * @dev Travel to a different map
     */
    function travelToMap(uint256 newMapId) 
        external 
        onlyRegisteredPlayer 
        whenNotPaused 
        nonReentrant 
    {
        PlayerState storage player = playerStates[msg.sender];
        require(newMapId != player.mapId, "Already on this map");
        require(mapRegistry.isValidMap(newMapId), "Invalid map ID");
        
        IMapRegistry.Map memory newMap = mapRegistry.getMap(newMapId);
        uint256 travelCost = newMap.travelCost;
        
        require(currency.balanceOf(msg.sender) >= travelCost, "Insufficient currency for travel");
        
        // Burn currency for travel cost
        if (travelCost > 0) {
            currency.burn(msg.sender, travelCost, "Map travel");
        }
        
        uint256 oldMapId = player.mapId;
        player.mapId = newMapId;
        
        // Reset position to map origin (0, 0) - could be customized per map
        player.position = Position(0, 0);
        
        emit MapChanged(msg.sender, oldMapId, newMapId, travelCost);
    }
    
    /**
     * @dev Update player's total weight (used when inventory changes)
     */
    function updatePlayerWeight(address player) external onlyRegisteredPlayer {
        require(player == msg.sender, "Can only update own weight");
        PlayerState storage playerState = playerStates[player];
        
        uint256 newWeight = _calculatePlayerWeight(player, playerState.shipId);
        playerState.totalWeight = newWeight;
        
        // Recalculate movement speed with new weight
        IShipRegistry.ShipStats memory shipStats = shipRegistry.getShipStats(playerState.shipId);
        playerState.movementSpeed = _calculateMovementSpeed(shipStats.enginePower, newWeight);
    }
    
    /**
     * @dev Purchase bait at a bait shop
     */
    function purchaseBait(uint8 baitType, uint256 amount) 
        external 
        onlyRegisteredPlayer 
        whenNotPaused 
        nonReentrant 
    {
        require(amount > 0, "Amount must be greater than zero");
        PlayerState memory player = playerStates[msg.sender];
        
        // Check if player is at a bait shop on current map
        uint256 shopId = _findBaitShopAtPosition(player.mapId, player.position);
        require(shopId < mapRegistry.getBaitShopsCount(player.mapId), "No bait shop at current position");
        
        IMapRegistry.BaitShop memory shop = mapRegistry.getBaitShop(player.mapId, shopId);
        require(shop.isActive, "Bait shop is inactive");
        
        // Check if bait type is available at this shop
        bool baitAvailable = false;
        for (uint256 i = 0; i < shop.availableBait.length; i++) {
            if (shop.availableBait[i] == baitType) {
                baitAvailable = true;
                break;
            }
        }
        require(baitAvailable, "Bait type not available at this shop");
        
        // Calculate cost
        FishRegistry.BaitType memory bait = fishRegistry.getBaitType(baitType);
        uint256 totalCost = bait.price * amount;
        require(currency.balanceOf(msg.sender) >= totalCost, "Insufficient currency");
        
        // Burn currency and add bait to inventory
        currency.burn(msg.sender, totalCost, "Bait purchase");
        playerBait[msg.sender][baitType] += amount;
        
        emit BaitPurchased(msg.sender, baitType, amount, totalCost);
    }
    
    
    /**
     * @dev Get player's bait inventory
     */
    function getPlayerBait(address player, uint8 baitType) external view returns (uint256) {
        return playerBait[player][baitType];
    }
    
    /**
     * @dev Get all available bait types and amounts for a player
     */
    function getPlayerAvailableBait(address player) 
        external 
        view 
        returns (uint8[] memory baitTypes, uint256[] memory amounts) 
    {
        // Count available bait types first
        uint256 availableCount = 0;
        for (uint8 i = 1; i <= 255; i++) {
            if (playerBait[player][i] > 0) {
                availableCount++;
            }
            if (!fishRegistry.isValidBait(i) && i > 10) {
                break; // Stop checking after a reasonable range
            }
        }
        
        // Populate arrays
        baitTypes = new uint8[](availableCount);
        amounts = new uint256[](availableCount);
        
        uint256 index = 0;
        for (uint8 i = 1; i <= 255 && index < availableCount; i++) {
            if (playerBait[player][i] > 0) {
                baitTypes[index] = i;
                amounts[index] = playerBait[player][i];
                index++;
            }
            if (!fishRegistry.isValidBait(i) && i > 10) {
                break;
            }
        }
        
        return (baitTypes, amounts);
    }
    
    /**
     * @dev Calculate player's total weight based on ship and inventory
     */
    function _calculatePlayerWeight(address /* player */, uint256 shipId) private view returns (uint256) {
        // Get base ship weight
        IShipRegistry.Ship memory ship = shipRegistry.getShip(shipId);
        uint256 baseWeight = ship.durability; // Using durability as proxy for ship weight
        
        // TODO: Add inventory weight calculation
        // This would iterate through player's inventory and sum up item weights
        // For now, return base weight
        
        return baseWeight;
    }
    
    /**
     * @dev Calculate movement speed based on engine power and total weight
     */
    function _calculateMovementSpeed(uint256 enginePower, uint256 totalWeight) private pure returns (uint256) {
        if (enginePower == 0 || totalWeight == 0) {
            return BASE_MOVEMENT_SPEED;
        }
        
        // Speed inversely proportional to weight, proportional to engine power
        // Formula: speed = (enginePower * BASE_MOVEMENT_SPEED) / totalWeight
        return (enginePower * BASE_MOVEMENT_SPEED) / totalWeight;
    }
    
    /**
     * @dev Validate movement path and check terrain collisions
     */
    function _validateMovementPath(uint256 mapId, Position memory startPos, uint8[] calldata directions) 
        private 
        view 
        returns (int32 finalX, int32 finalY) 
    {
        finalX = startPos.x;
        finalY = startPos.y;
        
        for (uint256 i = 0; i < directions.length; i++) {
            require(directions[i] < 6, "Invalid direction");
            
            // Calculate next position
            int32 nextX = finalX + hexDirectionsX[directions[i]];
            int32 nextY = finalY + hexDirectionsY[directions[i]];
            
            // Check if position is valid and passable
            require(mapRegistry.isValidPosition(mapId, nextX, nextY), "Position out of map bounds");
            require(mapRegistry.isPassable(mapId, nextX, nextY), "Terrain is not passable");
            
            finalX = nextX;
            finalY = nextY;
        }
        
        return (finalX, finalY);
    }
    
    /**
     * @dev Find bait shop at specific position on a map
     */
    function _findBaitShopAtPosition(uint256 mapId, Position memory position) private view returns (uint256) {
        uint256 shopCount = mapRegistry.getBaitShopsCount(mapId);
        for (uint256 i = 0; i < shopCount; i++) {
            IMapRegistry.BaitShop memory shop = mapRegistry.getBaitShop(mapId, i);
            if (shop.position.x == position.x && 
                shop.position.y == position.y && 
                shop.isActive) {
                return i;
            }
        }
        return type(uint256).max; // Not found
    }
    

    /**
     * @dev Update contract dependencies (admin only)
     */
    function updateDependencies(
        address _currency,
        address _shipRegistry,
        address _fishRegistry,
        address _mapRegistry
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
        if (_mapRegistry != address(0)) {
            mapRegistry = IMapRegistry(_mapRegistry);
        }
    }
    
    /**
     * @dev Update VRF configuration (admin only)
     */
    function updateVRFConfig(
        address _vrfCoordinator,
        uint64 _subscriptionId,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations
    ) external onlyRole(ADMIN_ROLE) {
        if (_vrfCoordinator != address(0)) {
            vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        }
        if (_subscriptionId != 0) {
            subscriptionId = _subscriptionId;
        }
        if (_keyHash != bytes32(0)) {
            keyHash = _keyHash;
        }
        if (_callbackGasLimit != 0) {
            callbackGasLimit = _callbackGasLimit;
        }
        if (_requestConfirmations != 0) {
            requestConfirmations = _requestConfirmations;
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