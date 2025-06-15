# Technical Implementation

## Smart Contract Architecture

### Core Contracts
- **GameState**: Main contract managing player positions, inventories, and game state
- **FishMarket**: Implements bonding curves and trading mechanics
- **SeasonPass**: NFT-based season pass and rewards distribution
- **Currency**: ERC20 token for in-game economy

### Supporting Contracts
- **ShipRegistry**: Manages ship types and configurations
- **FishRegistry**: Defines fish species and their properties
- **MapRegistry**: Handles map configurations and travel costs

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

### Ship Configuration
```typescript
interface Ship {
  id: number
  cargoShape: boolean[][] // 2D grid defining cargo space shape
  engineSlots: Position[]  // Designated engine positions
  equipmentSlots: Position[] // Designated equipment positions
  durability: number
  fuelCapacity: number
  currentFuel: number
}
```

### Fish & Items
```typescript
interface Fish {
  species: number
  weight: number
  freshness: number // 0-100
  shape: boolean[][] // 2D shape for inventory
  caughtAt: number // timestamp
}

interface Equipment {
  type: 'engine' | 'rod' | 'net'
  id: number
  shape: boolean[][]
  durability: number
  stats: EquipmentStats
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