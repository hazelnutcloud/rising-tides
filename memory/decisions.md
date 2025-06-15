# Architectural & Design Decisions

*Document key decisions made during development for future reference*

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