# Rising Tides

Rising Tides is an onchain multiplayer fishing game built on the RISE L2 network. Players travel the open sea to catch and trade fish, manage and upgrade their boats and fishing equipment, and compete to climb a global leaderboard.

## Table of Contents
- [Core Gameplay](#core-gameplay)
- [Game Mechanics](#game-mechanics)
  - [Movement & Fuel Economy](#movement--fuel-economy)
  - [Inventory Management](#inventory-management)
  - [Fishing Mechanics](#fishing-mechanics)
  - [Market Economy](#market-economy)
- [World Structure](#world-structure)
  - [Maps & Regions](#maps--regions)
  - [Shards](#shards)
- [Tokenomics](#tokenomics)
- [Technical Implementation](#technical-implementation)
  - [Smart Contracts](#smart-contracts)
  - [Data Structures](#data-structures)

## Core Gameplay

The core gameplay of Rising Tides revolves around managing your ship, equipment, inventory, and consumable resources to earn as much in-game currency (Doubloons - $DBL) as possible by catching and trading fish.

### Game Loop
1. **Registration**: New players register, receive starter equipment, and spawn at a port
2. **Preparation**: Buy fuel, bait, and repair equipment using Doubloons
3. **Exploration**: Navigate the hex-grid ocean to find fishing spots
4. **Fishing**: Use bait to catch fish of various species and sizes
5. **Inventory Management**: Organize caught fish in your cargo hold (weight-based)
6. **Trading**: Return to port to sell fish at dynamic market prices
7. **Progression**: Upgrade ships and equipment with earned currency

## Game Mechanics

### Movement & Fuel Economy

Players navigate freely in the open sea using a hexagonal grid coordinate system. Movement consumes fuel based on ship engine power and distance traveled.

#### Movement Mechanics
- **Hex Grid System**: Hexagonal tiles with axial coordinates (q, r) allow for 6-directional movement
- **Fuel Consumption**: `fuelCost = enginePower * distanceMoved * fuelEfficiencyModifier`
- **Distance Calculation**: Uses standard hex distance formula
- **Movement Validation**: Players must have equipped ship with sufficient fuel
- **Range**: Limited by fuel capacity and consumption rate

### Inventory Management

The game uses a weight-based inventory system managed through ERC1155 tokens:

#### Inventory Items
- **Ships**: NFTs with unique stats (engine power, weight capacity, fuel capacity)
- **Fishing Rods**: Equipment with durability that depletes with use
- **Fuel**: Consumable ERC1155 tokens required for movement
- **Bait**: Consumable tokens that determine fish catch probabilities
- **Fish**: Caught fish with weight and freshness attributes

#### Ship Management
- Players can own multiple ships but only equip one at a time
- Ship stats affect movement speed, fuel consumption, and cargo capacity

### Fishing Mechanics

#### Bait System
- Different bait types affect which fish species can be caught
- Bait-region combinations determine probability distributions
- Bait is consumed when fishing

#### Fishing Process
1. Player must be at a valid fishing location
2. Fishing rod durability is checked
3. Bait is consumed
4. Fish is sampled using O(1) alias method with VRF randomness
5. Fish weight is randomly determined
6. Rod durability decreases based on fish size
7. Fish is added to inventory with timestamp for freshness tracking

#### Durability System
- Fishing rods have durability that depletes with each catch
- Larger fish cause more durability damage
- Broken equipment (0 durability) must be repaired with Doubloons

### Market Economy

The game features a dynamic market system with supply and demand mechanics:

#### Fish Trading
- **Bonding Curve**: Fish prices decrease as more are sold, recover over time
- **Price Factors**:
  - Base market value (per species)
  - Fish weight (randomly determined when caught)
  - Freshness (decreases from 100% to 0% over time)
- **Price Formula**: `finalPrice = marketValue * weight * freshness`
- **Market Recovery**: Prices gradually increase when fish aren't being sold

#### Currency Flow
- **Doubloons ($DBL)**: ERC20 token used as in-game currency
- **Emission**: Created when players sell fish to the market
- **Burning**: Destroyed through various game actions:
  - Fuel purchases
  - Bait purchases
  - Equipment repairs
  - Ship upgrades
  - Map travel fees

## World Structure

### Maps & Regions

The game world consists of multiple maps, each divided into hexagonal regions:

#### Map Properties
- **Boundaries**: Min/max coordinates defining map size
- **Travel Cost**: Doubloon fee to travel between maps
- **Level Requirement**: Minimum player level to access
- **Port Regions**: Safe zones for spawning, trading, and map travel

#### Region System
- Each hex coordinate can be assigned a region ID
- Region types determine available actions (currently only ports)
- Regions store fish probability distributions for that area
- Region data is packed efficiently using coordinate hashing

#### Map Travel
- Players must be at a port to travel between maps
- Travel requires payment in Doubloons
- Players must meet level requirements for destination map
- Travel destination must be a port region

### Shards

To optimize multiplayer performance, players are distributed across shards:

#### Shard Mechanics
- Players are automatically assigned to shards on registration
- Assignment uses load balancing (least populated shard)
- Each shard has a maximum player capacity
- Movement events include shard ID for client filtering

#### Client Optimization
- Clients only subscribe to events from their shard
- Reduces network traffic and improves performance
- Admin can manually reassign players for balancing

## Technical Implementation

### Smart Contracts

The game consists of three main smart contracts:

#### 1. RisingTidesWorld
Manages the game world and player movement:
- **Player Management**: Registration, position tracking, level progression
- **Movement System**: Hex-based movement with fuel consumption
- **Map Management**: Multiple maps with boundaries and travel costs
- **Region System**: Efficient coordinate-to-region mapping
- **Shard System**: Player distribution for multiplayer optimization
- **Access Control**: Admin and GameMaster roles

Key Functions:
- `registerPlayer()`: Join game with starting position
- `move()`: Move to new hex coordinate
- `travelToMap()`: Travel between maps at ports
- `setHexRegion()`: Assign regions to coordinates

#### 2. RisingTidesFish
Handles fishing mechanics and fish trading:
- **Fish Storage**: Tracks caught fish with attributes
- **Probability Tables**: Alias method implementation for O(1) sampling
- **Market System**: Dynamic pricing with bonding curves
- **VRF Integration**: Fair random number generation
- **Trading Functions**: Sell fish with freshness calculation

Key Functions:
- `fish()`: Catch fish using bait and VRF
- `sellFish()`: Trade fish for Doubloons
- `setFishingTable()`: Configure probability distributions

#### 3. RisingTidesInventory
Manages player items as ERC1155 tokens:
- **Token Management**: Ships, rods, fuel, bait as NFTs/tokens
- **Equipment System**: Track equipped items per player
- **Durability Tracking**: Monitor equipment condition
- **Starter Kits**: Initial equipment for new players
- **Fuel System**: Purchase and consumption mechanics

Key Functions:
- `equipShip()`: Select active ship
- `purchaseFuel()`: Buy fuel with Doubloons
- `consumeFuel()`: Deduct fuel for movement
- `repairEquipment()`: Fix broken items

### Data Structures

#### Coordinate Packing
```solidity
// Pack two 32-bit coordinates into one 256-bit value
function packCoordinates(int32 q, int32 r) returns (uint256) {
    return (uint256(uint32(q)) << 32) | uint256(uint32(r));
}
```

#### Region Storage
```solidity
// Map + packed coordinates -> region ID
mapping(uint256 => mapping(uint256 => uint256)) hexToRegion;

// Region ID format: [type (8 bits)][custom data (248 bits)]
// Type 1 = Port Region
```

#### Alias Method for Fish Sampling
```solidity
struct AliasTable {
    uint256[] probabilities;  // Fixed-point (1e18 = 1.0)
    uint256[] aliases;       // Fallback indices
    uint256[] fishIds;       // Maps index to fish species
    uint256 n;              // Table size
}

// Composite key: keccak256(baitId, regionId) -> AliasTable
mapping(bytes32 => AliasTable) fishingTables;
```

#### Player Data
```solidity
struct Player {
    int32 q, r;              // Hex coordinates
    uint256 mapId;           // Current map
    uint256 shardId;         // Assigned shard
    uint256 level;           // Player level
    uint256 lastMoveTimestamp;
    bool isRegistered;
}
```

## Leaderboard

Players compete on a global seasonal leaderboard:
- **Ranking Metric**: Total Doubloons earned (not current balance)
- **Season Duration**: Fixed time periods with resets
- **Rewards**: Top players receive valuable in-game items
- **Competition**: Encourages efficient fishing and trading strategies

## Future Enhancements

Potential features for future development:
- Additional region types (deep water, reefs, etc.)
- Weather system affecting fishing probabilities
- Player-to-player trading
- Guilds and cooperative gameplay
- Special events and tournaments
- More equipment types and upgrades
- Achievement system
- Mobile client support
