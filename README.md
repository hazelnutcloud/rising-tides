# Rising Tides


![Rising Tides Banner](rising-tides-banner.png)

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

The game uses a weight-based inventory system:

#### Inventory Items

- **Ships**: Equippable transport with unique stats (engine power, weight capacity, fuel capacity, region compatibility)
- **Fishing Rods**: Equipment with durability that depletes with use
- **Fuel**: Consumable resource required for movement
- **Bait**: Consumable resource that determine fish catch probabilities
- **Fish**: Caught fish with weight and freshness attributes

#### Ship Management

- Players can own multiple ships but only equip one at a time
- Ship ownership is tracked using a bitfield (max 256 ship types, one of each type per player)
- Ships can only be equipped while at a port region
- Ship stats affect movement speed, fuel consumption, and cargo capacity
- Total weight for movement = ship empty weight + cargo weight
- **Supported Regions**: Each ship has a list of region types it can navigate
  - Basic ships may only access ports and open water
  - Advanced ships can navigate deep water and storm regions
  - Specialized ships required for restricted zones
  - Ships cannot move to unsupported region types
  - This creates progression incentive to upgrade ships

### Fishing Mechanics

#### Fishing Rod System

Fishing rods are ERC721 NFTs with unique attributes that affect fishing performance:

**Rod Attributes:**

- **Max Durability**: Reduces with each catch based on fish weight
- **Max Fish Weight**: Catching fish outside this range has 90% chance to fail
- **Crit Rate**: Chance to roll twice and take the rarer item
- **Strength**: Modifier to durability loss (higher strength = lower durability loss)
- **Efficiency**: Chance to not consume bait
- **Compatible Bait Types**: Each rod type has a bitfield defining compatible bait types

**Rod Enchantments:**

Enchantments are configurable by the GameMaster and can provide various bonuses:

- Stat bonuses (durability, efficiency, crit rate, max weight, strength)
- Special effects (double catch chance, slower freshness decay)
- Region-specific bonuses that only apply in certain areas
- Title-like bonuses (perfect catch chance, trophy quality fish)

**Rod Progression:**

- Rods track total fish caught and gain titles at milestones (similar to TF2's strange items)
- 20 title levels from "Strange" to "Absolutely Seaworthy"
- Titles provide specific bonuses:
  - Level 5 (100 catches): +5% durability
  - Level 9 (300 catches): +10% bait efficiency
  - Level 13 (675 catches): +5% crit rate
  - Level 16 (1500 catches): +10% max fish weight
  - Level 18 (5000 catches): 10% chance for "Perfect Catch" (no durability loss)
  - Level 19 (8500 catches): 10% chance for "Trophy Quality" fish (1.5x value)

#### Bait System

- Different bait types affect which fish species can be caught
- Bait-region combinations determine probability distributions
- Bait is consumed when fishing (unless rod efficiency triggers)
- Each fishing rod type has a bitfield defining compatible bait types

#### Fishing Process

1. Player must be at a valid fishing location
2. Fishing rod durability and bait compatibility are checked
3. Bait is consumed (efficiency check may prevent consumption)
4. Fish is sampled using O(1) alias method with VRF randomness
5. Crit rate may trigger double roll for rarer fish
6. Fish weight is randomly determined (affected by rod's max fish weight)
7. Weight check: 90% fail chance if fish exceeds rod's max weight
8. Rod durability decreases based on fish size and strength modifier
9. Fish is added to inventory with timestamp for freshness tracking
10. Lucky enchantment may grant additional fish

#### Crafting & Repair System

- **Material Harvesting**: Fish can be harvested for crafting materials (rarer fish yield rarer materials)
- **Rod Crafting**: Use materials to craft new fishing rods with small chance of enchantment
- **Attributes variance**: Each type of fishing rod has a base range of different attributes. Upon crafting, a number within that range for an attribute is assigned to the rod.
- **Repairs**: Require crafting materials and Doubloons (typically same materials used in crafting)

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
- Region types determine available actions and characteristics
- Regions store fish probability distributions for that area
- Region data is packed efficiently using coordinate hashing

#### Region Types

Maps can contain different types of regions, each with unique properties:

- **Port Regions**: Safe zones for spawning, trading, and map travel
- **Open Water**: Standard fishing areas with normal conditions
- **Deep Water**: Areas with rare fish but higher equipment wear
- **Reef Zones**: Protected areas with unique fish species
- **Storm Regions**: Dangerous areas with enhanced rewards but movement penalties
- **Restricted Zones**: Areas that require specific ship types to access

Region types reuse the port region functionality, with the type encoded in the region ID format.

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

For detailed calculations and formulas, see:

- [Calculations Guide](docs/CALCULATIONS.md) - All game mechanics formulas
- [Units & Precision](docs/CALCULATIONS_UNITS_PRECISION.md) - Data types and precision details
- [Fishing Rod Progression](docs/FISHING_ROD_PROGRESSION.md) - Complete title system details

### Smart Contracts

The game consists of five main smart contracts (see [contract dependency graph](docs/CONTRACT_DEPENDENCY_GRAPH.md)):

#### 1. RisingTidesWorld

Manages the game world, player positions, and navigation:

- **Player Registration**: New player onboarding and spawn management
- **Position Tracking**: Real-time player coordinates on hex grid
- **Movement System**: Hex-based movement validation and execution
- **Map Management**: Multiple maps with boundaries and travel requirements
- **Region System**: Coordinate-to-region mapping with type definitions
- **Shard System**: Player distribution for multiplayer optimization
- **Access Control**: Admin and GameMaster role management

Key Functions:

- `registerPlayer()`: Join game with starting position
- `move()`: Move to new hex coordinate with region validation
- `travelToMap()`: Travel between maps at port regions
- `setHexRegion()`: Assign region types to coordinates
- `getPlayerPosition()`: Query player location and shard

#### 2. RisingTidesFishing

Handles fishing mechanics and probability systems:

- **Probability Tables**: Alias method implementation for O(1) fish sampling
- **Fishing Logic**: Core fishing mechanics and validation
- **VRF Integration**: External VRF contract interface for randomness
- **Bait-Region Tables**: Probability distributions per bait/region combo
- **Catch Validation**: Weight limits and success rate calculations

Key Functions:

- `initiateFishing()`: Start fishing with bait and rod validation
- `completeFishing()`: Process VRF result and determine catch
- `setFishingTable()`: Configure probability distributions
- `calculateCatch()`: Determine fish species and weight

#### 3. RisingTidesInventory

Manages player inventory state:

- **Ship Management**: Bitfield-based ownership tracking (max 256 ship types)
- **Resource Storage**: Track fuel, bait, and crafting materials
- **Fish Management**: Store caught fish with weight, timestamps, and modifiers
- **Equipment Tracking**: Custody system for equipped fishing rod NFTs
- **Capacity Management**: Enforce weight limits based on ship capacity
- **Starter Kit**: Configurable initial items for new players

Key Functions:

- `equipShip()`: Equip owned ship (only at ports)
- `grantShip()`: Grant ship ownership to player
- `addFuel()/consumeFuel()`: Manage fuel resources
- `addBait()/consumeBait()`: Manage bait inventory
- `addMaterials()/consumeMaterials()`: Manage crafting materials
- `addFish()`: Add caught fish with trophy/freshness modifiers
- `removeFish()`: Remove fish using efficient array swap
- `equipRod()/unequipRod()`: NFT custody for fishing rods
- `mintStarterKit()`: Grant initial items to new players
- `getPlayerCargoWeight()`: Calculate total fish weight

#### 4. RisingTidesPort

Main player interface for economy and crafting:

- **Fish Market**: Dynamic pricing with bonding curves
- **Ship Dealership**: Purchase new ships with different capabilities
- **Fuel Station**: Buy fuel with Doubloons
- **Bait Shop**: Purchase various bait types
- **Crafting Station**: Create and repair fishing rods
- **Market Data**: Track supply/demand for price calculations
- **Currency Management**: Handle Doubloon transactions

Key Functions:

- `sellFish()`: Trade fish for Doubloons with freshness calculation
- `purchaseShip()`: Buy new ships with region capabilities
- `purchaseFuel()`: Buy fuel for movement
- `purchaseBait()`: Buy bait for fishing
- `craftFishingRod()`: Create rods from materials
- `repairEquipment()`: Fix damaged items

#### 5. RisingTidesFishingRod

Manages fishing rods as ERC721 NFTs:

- **NFT Management**: Each rod is a unique NFT with attributes
- **Attribute System**: Max durability, weight limits, crit rate, strength, efficiency
- **Enchantment System**: Configurable enchantments with region-specific bonuses
- **Title Progression**: 20 titles with specific bonuses at milestones
- **Compatibility**: Bitfield-based bait compatibility (up to 256 bait types)
- **Metadata Storage**: On-chain attributes and off-chain visuals

Key Functions:

- `mint()`: Create new fishing rod NFT, passing in attributes and any enchantments (can only be called by RisingTidesPort)
- `getAttributes()`: Get effective rod stats including bonuses for fishing
- `processCatch()`: Process catch results and apply durability loss
- `repair()`: Restore rod durability (can only be called by RisingTidesPort)

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
// Region Types:
// Type 1 = Port Region
// Type 2 = Open Water
// Type 3 = Deep Water
// Type 4 = Reef Zone
// Type 5 = Storm Region
// Type 6 = Restricted Zone
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

#### Fishing Rod Data

```solidity
struct RodInstance {
    uint256 rodId;               // Type of rod
    uint256 maxDurability;
    uint256 currentDurability;
    uint256 maxFishWeight;
    uint256 critRate;            // Basis points (10000 = 100%)
    uint256 strength;            // Durability loss modifier
    uint256 efficiency;          // Bait save chance (percentage)
    uint256 totalCatches;        // For title progression
    uint256 enchantmentMask;     // Bitfield for enchantments
}

// Enchantments are now configurable by GameMaster
// Each enchantment can have region-specific bonuses
```

#### Ship Data

```solidity
struct Ship {
    uint256 enginePower;
    uint256 weightCapacity;
    uint256 fuelCapacity;
    uint256 emptyWeight;
    uint256 supportedRegionTypes;  // Bitfield for region type support
    bool exists;
}
```

#### Fish Data

```solidity
struct Fish {
    uint256 fishId;              // Species ID
    uint256 weight;              // Individual fish weight
    uint256 caughtAt;            // Timestamp for freshness
    bool isTrophyQuality;        // 1.5x value when selling
    uint256 freshnessModifier;   // Affects freshness decay rate (100 = normal)
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
