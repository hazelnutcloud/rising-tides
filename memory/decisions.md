# Architectural & Design Decisions

*Document key decisions made during development for future reference*

## Server-Driven Game Mechanics (2025-06-16)

### Decision: Replace VRF with Server-Based Fishing System
**Context**: Need to reduce gas costs and increase flexibility in fishing mechanics

**Options Considered**:
1. Keep Chainlink VRF for full on-chain randomness
2. Hybrid approach with some server computation
3. Full server-driven system with callback pattern
4. Commit-reveal scheme for user-generated randomness

**Decision**: Full server-driven system with callback pattern

**Rationale**:
- **Gas Efficiency**: Eliminates expensive VRF calls (saves ~200k gas per fishing attempt)
- **Flexibility**: Server can implement complex fish distribution algorithms
- **Performance**: Instant fishing responses vs waiting for VRF fulfillment
- **Scalability**: Server can handle complex calculations off-chain
- **Anti-cheat**: Nonce-based system prevents manipulation while maintaining security

**Implementation**:
```solidity
// New fishing pattern
function initiateFishing(uint256 baitType) external returns (uint256 fishingNonce)
function completeServerFishing(address player, uint256 nonce, uint256 species, uint16 weight) external
```

**Security Measures**:
- Pending request guard prevents multiple simultaneous fishing
- Nonce tracking ensures proper request/response pairing
- Server authority limited to fishing results only
- All economic transactions remain on-chain

### Decision: Expand Species/Bait ID Data Types
**Context**: Original uint8 limits game to 256 species/bait types

**Decision**: Upgrade all species and bait IDs from uint8 to uint256

**Rationale**:
- **Scalability**: Support unlimited species and bait varieties
- **Future-proofing**: No artificial limits on game content
- **Minimal Gas Impact**: IDs are used sparingly in transactions
- **Ecosystem Growth**: Enables extensive content without contract upgrades

**Impact**: Updated all contracts, tests, and deployment scripts

### Decision: Optimize FishSpecies Data Structure
**Context**: FishSpecies struct contained unused fields consuming storage

**Decision**: Remove unused fields: name, minWeight, maxWeight

**Rationale**:
- **Gas Optimization**: Reduces storage costs for species registration
- **Simplicity**: Eliminates unused `getRandomWeight()` function
- **Clean Architecture**: Focuses struct on essential game mechanics only
- **Server Flexibility**: Weight ranges can be handled by server logic

**Before/After**:
```solidity
// Before: 7 fields
struct FishSpecies {
    uint256 id;
    string name;           // ❌ Removed
    uint256 basePrice;
    uint8 rarity;
    uint16 minWeight;      // ❌ Removed  
    uint16 maxWeight;      // ❌ Removed
    uint8 shapeWidth;
    uint8 shapeHeight;
    bytes shapeData;
    uint256 freshnessDecayRate;
}

// After: 6 fields, more focused
struct FishSpecies {
    uint256 id;
    uint256 basePrice;
    uint8 rarity;
    uint8 shapeWidth;
    uint8 shapeHeight;
    bytes shapeData;
    uint256 freshnessDecayRate;
}
```

## Development Context System (2025-06-15)

### Decision: Implement Memory-Based Development Tracking
**Context**: Need better development context and progress tracking across sessions

**Options Considered**:
1. Simple todo comments in code
2. External project management tools
3. Memory directory with structured markdown files
4. Database-driven tracking system

**Decision**: Memory directory with structured markdown files

**Rationale**:
- Keeps context close to codebase
- Version controlled with project
- Easily readable and maintainable
- Provides Claude with persistent context
- Minimal setup overhead

**Files Created**:
- `memory/current-tasks.md` - Active task tracking
- `memory/development-log.md` - Progress history
- `memory/decisions.md` - This file for decision tracking

## Smart Contract Architecture (Previous)

### Decision: Multi-Contract Architecture
**Context**: Game requires complex state management across multiple systems

**Decision**: Separate contracts for different game systems
- GameState: Core player and world state
- FishMarket: Trading and bonding curves
- SeasonPass: NFT-based seasons and rewards
- Currency: ERC20 for in-game economy

**Rationale**:
- Separation of concerns
- Easier testing and deployment
- Gas optimization through specialized contracts
- Modularity for future updates

### Decision: Hex-Grid Movement System
**Context**: Need structured movement system for fair gameplay

**Decision**: Hexagonal grid with 6-directional movement

**Rationale**:
- More natural movement than square grid
- Fair distance calculations
- Easier pathfinding algorithms
- Better visual representation

### Decision: On-Chain Inventory State
**Context**: Inventory management could be on-chain or off-chain with verification

**Decision**: Full on-chain inventory state with bitmap optimization

**Rationale**:
- Prevents cheating and manipulation
- Enables trustless trading
- Supports complex cargo shapes
- Gas costs manageable with optimization

## Frontend Architecture (Previous)

### Decision: Threlte for 3D Rendering
**Context**: Need 3D ocean visualization and ship movement

**Decision**: Use Threlte (Three.js wrapper for Svelte)

**Rationale**:
- Excellent Svelte integration
- Powerful 3D capabilities
- Good performance for game rendering
- Active community and documentation

### Decision: Event-Based Multiplayer
**Context**: Real-time multiplayer requires state synchronization

**Decision**: Blockchain events with shard-based filtering

**Rationale**:
- Leverages existing blockchain infrastructure
- Naturally trustless
- Shard filtering reduces bandwidth
- Event history provides audit trail

## Pending Decisions

### Gas Optimization Strategy
- Need to decide on specific optimization techniques
- Batch operations vs individual transactions
- Storage packing strategies

### Testing Strategy
- Unit test coverage requirements
- Integration testing approach
- Gas limit testing methodology