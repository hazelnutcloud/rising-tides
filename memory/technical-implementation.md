# Technical Implementation

## Smart Contract Architecture (Modular Design)

### Core Contract Hierarchy
- **RisingTides**: Main deployed contract inheriting all manager functionality
- **RisingTidesBase**: Shared state, dependencies, modifiers, and constants
- **PlayerManager**: Player registration, shard management, default equipment
- **MovementManager**: Hex-grid movement, fuel consumption, engine power calculation
- **FishingManager**: Server-driven fishing with EIP712 signature verification
- **InventoryManager**: 2D Tetris-like inventory with equipment validation
- **ResourceManager**: Ship changing, bait purchasing, map travel

### Economic & Registry Contracts
- **FishMarket**: Implements bonding curves and trading mechanics
- **SeasonPass**: NFT-based season pass and rewards distribution
- **Currency**: ERC20 token for in-game economy

### Registry System
- **ShipRegistry**: Ship templates with cargo shapes and slot types
- **FishRegistry**: Fish species and bait types with pricing
- **EngineRegistry**: Engine stats (power, efficiency, weight)
- **FishingRodRegistry**: Simplified fishing rod equipment
- **MapRegistry**: Game worlds with travel costs and bait shops

### Modular Architecture Benefits
- **Maintainability**: Each manager focuses on specific functionality (100-250 lines)
- **Testing**: Individual manager contracts can be tested in isolation
- **Gas Optimization**: Smaller contract sizes improve deployment efficiency
- **Development**: Multiple developers can work on different managers simultaneously
- **Upgradeability**: Individual managers can be optimized without affecting others

### Equipment System Design
- **Computed Stats**: Engine power/efficiency calculated from equipped items, not stored in ship templates
- **Default Assignment**: New players start with Engine ID 1 and Fishing Rod ID 1
- **Slot-Based Placement**: Ships define engine slots (type 1) and equipment slots (type 2)
- **Real-Time Calculation**: Movement speed updated dynamically based on equipment changes

## Frontend Architecture

### Tech Stack
- **Rendering**: Threlte/Three.js for 3D ocean and ship visualization
- **State Management**: Svelte stores for game state and player data
- **Web3 Integration**: Viem/Wagmi for blockchain interactions
- **Multiplayer**: Event-based updates via blockchain logs (filtered by shard)

### Key Components
- **GameWorld**: 3D hex-grid ocean renderer
- **InventoryManager**: Drag-and-drop cargo management UI
- **MarketInterface**: Fish trading and price display
- **ShipControls**: Movement and navigation system

## Data Models

### Player State
```typescript
interface Player {
  address: string
  position: { x: number, y: number }
  shard: number
  ship: Ship
  inventory: InventoryGrid
  currency: bigint
  seasonStats: SeasonStats
}
```

### Ship Configuration (Updated)
```typescript
interface Ship {
  id: number
  cargoShape: boolean[][] // 2D grid defining cargo space shape
  slotTypes: number[] // Flat array: 0=normal, 1=engine, 2=equipment
  cargoWidth: number
  cargoHeight: number
  durability: number
  fuelCapacity: number
  currentFuel: number
  // Note: enginePower and fuelEfficiency removed - now computed from equipment
}

interface ShipStats {
  cargoCapacity: number // Computed from cargo dimensions
  durability: number
  // enginePower: REMOVED - computed from equipped engines
  // fuelEfficiency: REMOVED - computed from equipped engines
}
```

### Fish & Equipment (Simplified)
```typescript
interface Fish {
  species: number
  weight: number
  freshness: number // 0-100
  shape: boolean[][] // 2D shape for inventory
  caughtAt: number // timestamp
}

interface Engine {
  id: number
  name: string
  enginePower: number
  fuelEfficiency: number
  weight: number
  shape: boolean[][]
  isActive: boolean
}

interface FishingRod {
  id: number
  name: string
  shapeWidth: number
  shapeHeight: number
  weight: number
  shape: boolean[][]
  isActive: boolean
  // Note: No stats stored - effects computed off-chain
}
```

### Market Data
```typescript
interface MarketState {
  species: number
  currentPrice: bigint
  volume24h: bigint
  lastSaleTime: number
  priceHistory: PricePoint[]
}
```

## On-chain vs Off-chain

### On-chain Data
- Player positions and movements
- Inventory state and item ownership
- Fish catches and trading
- Currency transactions
- Season pass ownership
- Leaderboard scores

### Off-chain Computation
- Pathfinding calculations
- UI animations and transitions
- Temporary game state
- Price chart visualizations

### Hybrid Approach
- **Fish Spawning**: On-chain seed generation, off-chain spawn calculations
- **Movement Validation**: Client-side prediction, on-chain verification
- **Market Updates**: On-chain trades, off-chain price aggregation

## Event System

### Key Events
```solidity
event PlayerMoved(address indexed player, uint8 shard, int32 x, int32 y)
event FishCaught(address indexed player, uint8 species, uint16 weight)
event FishSold(address indexed player, uint8 species, uint256 price)
event FuelPurchased(address indexed player, uint256 amount)
event ShipUpgraded(address indexed player, uint256 newShipId)
```

### Shard-based Filtering
- Players subscribe only to events from their current shard
- Reduces bandwidth and improves performance
- Shard transitions handled specially

## Gas Optimization Strategies

### Batch Operations
- Multiple fish sales in single transaction
- Bulk inventory updates
- Combined movement and action commands

### Storage Optimization
- Packed structs for player data
- Bitmap representations for inventory grids
- Minimal on-chain storage for temporary data

### Calculation Efficiency
- Pre-computed bonding curve values
- Simplified freshness decay formulas
- Optimized pathfinding constraints