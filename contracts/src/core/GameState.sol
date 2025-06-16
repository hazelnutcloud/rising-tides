// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
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
contract GameState is IGameState, AccessControl, Pausable, ReentrancyGuard {
    using InventoryLib for InventoryLib.InventoryGrid;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SERVER_ROLE = keccak256("SERVER_ROLE");

    // Contract dependencies
    RisingTidesCurrency public currency;
    IShipRegistry public shipRegistry;
    FishRegistry public fishRegistry;
    IMapRegistry public mapRegistry;
    
    // Fishing system
    mapping(address => uint256) private playerFishingNonce;

    // Game state mappings
    mapping(address => PlayerState) private playerStates;
    mapping(address => InventoryLib.InventoryGrid) private playerInventories;
    mapping(address => bool) private registeredPlayers;
    mapping(address => mapping(uint256 => FishCatch)) private playerFish;
    mapping(address => uint256) private playerFishCount;
    
    // Player bait inventory
    mapping(address => mapping(uint256 => uint256)) private playerBait;
    
    // Fishing request tracking
    mapping(address => uint256) private pendingFishingRequest;
    mapping(address => uint256) private pendingBaitType;

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
        address _mapRegistry
    ) {
        require(_currency != address(0), "Currency address cannot be zero");
        require(_shipRegistry != address(0), "Ship registry address cannot be zero");
        require(_fishRegistry != address(0), "Fish registry address cannot be zero");
        require(_mapRegistry != address(0), "Map registry address cannot be zero");

        currency = RisingTidesCurrency(_currency);
        shipRegistry = IShipRegistry(_shipRegistry);
        fishRegistry = FishRegistry(_fishRegistry);
        mapRegistry = IMapRegistry(_mapRegistry);

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
     * @dev Initiate fishing at current position with chosen bait (server will complete the action)
     */
    function initiateFishing(uint256 baitType) 
        external 
        onlyRegisteredPlayer 
        whenNotPaused 
        nonReentrant 
        returns (uint256 fishingNonce) 
    {
        // Validate bait type and check if player has it
        require(fishRegistry.isValidBait(baitType), "Invalid bait type");
        require(playerBait[msg.sender][baitType] > 0, "Insufficient bait");
        
        // Check if player already has a pending fishing request
        require(pendingFishingRequest[msg.sender] == 0, "Already have pending fishing request");
        
        // Consume one bait
        playerBait[msg.sender][baitType]--;
        
        // Increment player's fishing nonce
        playerFishingNonce[msg.sender]++;
        fishingNonce = playerFishingNonce[msg.sender];
        
        // Store pending request info
        pendingFishingRequest[msg.sender] = fishingNonce;
        pendingBaitType[msg.sender] = baitType;
        
        // Emit event for server to process
        emit FishingInitiated(msg.sender, playerStates[msg.sender].shard, playerStates[msg.sender].mapId, 
                             playerStates[msg.sender].position.x, playerStates[msg.sender].position.y, 
                             baitType, fishingNonce);
        
        return fishingNonce;
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
     * @dev Server callback to complete fishing (called by authorized server)
     */
    function completeServerFishing(address player, uint256 nonce, uint256 species, uint16 weight) 
        external 
        onlyRole(SERVER_ROLE) 
        whenNotPaused 
        nonReentrant 
    {
        require(registeredPlayers[player], "Player not registered");
        require(pendingFishingRequest[player] == nonce, "Invalid or expired fishing request");
        require(nonce > 0, "Invalid nonce");
        
        // Clear pending request
        delete pendingFishingRequest[player];
        delete pendingBaitType[player];
        
        // If server determined a catch occurred
        if (species > 0) {
            require(fishRegistry.isValidSpecies(species), "Invalid species");
            
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
    function purchaseBait(uint256 baitType, uint256 amount) 
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
    function getPlayerBait(address player, uint256 baitType) external view returns (uint256) {
        return playerBait[player][baitType];
    }
    
    /**
     * @dev Get all available bait types and amounts for a player
     */
    function getPlayerAvailableBait(address player) 
        external 
        view 
        returns (uint256[] memory baitTypes, uint256[] memory amounts) 
    {
        // Count available bait types first
        uint256 availableCount = 0;
        for (uint256 i = 1; i <= 1000; i++) { // Increased from 255 to 1000 for more species
            if (playerBait[player][i] > 0) {
                availableCount++;
            }
            if (!fishRegistry.isValidBait(i) && i > 50) {
                break; // Stop checking after a reasonable range
            }
        }
        
        // Populate arrays
        baitTypes = new uint256[](availableCount);
        amounts = new uint256[](availableCount);
        
        uint256 index = 0;
        for (uint256 i = 1; i <= 1000 && index < availableCount; i++) {
            if (playerBait[player][i] > 0) {
                baitTypes[index] = i;
                amounts[index] = playerBait[player][i];
                index++;
            }
            if (!fishRegistry.isValidBait(i) && i > 50) {
                break;
            }
        }
        
        return (baitTypes, amounts);
    }
    
    /**
     * @dev Get player's fishing status
     */
    function getPlayerFishingStatus(address player) 
        external 
        view 
        returns (
            uint256 pendingNonce, 
            uint256 baitTypeUsed, 
            uint256 currentNonce
        ) 
    {
        pendingNonce = pendingFishingRequest[player];
        baitTypeUsed = pendingBaitType[player];
        currentNonce = playerFishingNonce[player];
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