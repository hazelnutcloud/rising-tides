# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rising Tides is an onchain multiplayer fishing game built on the RISE L2 network. It combines a SvelteKit web application with Solidity smart contracts to create a Web3 gaming experience inspired by the indie game "Dredge".

## Tech Stack

**Frontend (app/):**
- Framework: SvelteKit with Svelte 5
- Deployment: Cloudflare Pages/Workers  
- 3D Graphics: Threlte (Three.js wrapper)
- Styling: TailwindCSS v4 + bits-ui
- Build Tool: Vite
- Package Manager: Bun
- Language: TypeScript

**Smart Contracts (contracts/):**
- Framework: Foundry
- Language: Solidity

## Commands

### Frontend Development (app/)

```bash
# Install dependencies
bun install

# Development server
bun run dev

# Build for production
bun run build

# Preview production build
bun run preview

# Type checking
bun run check
bun run check:watch

# Linting and formatting
bun run lint
bun run format
```

### Smart Contract Development (contracts/)

```bash
# Build contracts
forge build

# Run tests
forge test

# Run specific test
forge test --match-test testName

# Format Solidity code
forge fmt

# Gas snapshots
forge snapshot

# Deploy
forge script script/Counter.s.sol:CounterScript --rpc-url <RPC_URL> --private-key <PRIVATE_KEY>
```

## Architecture

### Game Mechanics
- **Movement**: Hex-grid based system with fuel consumption
- **Inventory**: 2D tile-based cargo management system
- **Economy**: Dynamic pricing with bonding curves for fish trading
- **Durability**: Ships and equipment degrade over time
- **Maps/Shards**: Multiple game worlds for scalability

### Key Implementation Areas
1. **Frontend**: Game rendering, Web3 wallet integration, state management
2. **Smart Contracts**: Game logic, token economics, marketplace mechanics
3. **Indexing**: Event processing with Ponder.sh (planned)

### Current Status
- Frontend has SvelteKit boilerplate setup
- Contracts contain only the Foundry starter template (Counter.sol)
- Game design is documented in memory/rising-tides.md
- Technical implementation details in memory/technical-implementation.md

## Development Context & Progress Tracking

### Current Development Status
- **Active Focus**: Frontend development (smart contracts complete)
- **Current Branch**: main  
- **Recent Progress**: Achieved 100% test coverage, optimized architecture, clean codebase
- **Next Priority**: Implement 3D game world frontend with Threlte and Web3 integration

### Memory System
The `./memory/` directory contains project knowledge and development context:
- `rising-tides.md` - Comprehensive game design and mechanics documentation
- `technical-implementation.md` - Architecture, data models, and technical decisions
- `current-tasks.md` - Active tasks and immediate priorities (see memory/current-tasks.md)
- `development-log.md` - Progress tracking and completed milestones (see memory/development-log.md)
- `decisions.md` - Architectural and design decisions log (see memory/decisions.md)

### Implementation Progress

#### Smart Contracts Status (PRODUCTION-READY: Complete Modular Implementation)
- [x] Modular architecture (GameState broken into 7 focused manager contracts)
- [x] Core game state management (RisingTides with all managers)
- [x] Player registration with default equipment assignment
- [x] Shard management system with configurable limits and admin controls
- [x] Movement and fuel system (hex-grid with 6 directions, fuel economy)
- [x] Fishing mechanics (server-driven with EIP712 signature verification)
- [x] Inventory and cargo management (sophisticated 2D Tetris-like system)
- [x] Fish market with bonding curves (dynamic pricing, freshness decay)
- [x] Season pass and leaderboard (NFT-based system)
- [x] Currency token contract (ERC20 with mint/burn mechanics)
- [x] Registry systems (Ship, Fish, Engine, FishingRod, Map - complete)
- [x] Equipment system (computed stats from equipped items)
- [x] Deployment scripts (complete with sample data)

#### Test Status: 57/57 Passing ✅
- [x] Player registration with default equipment assignment
- [x] Hex-grid movement with collision detection  
- [x] Fuel purchasing and consumption
- [x] Fishing mechanics with server-driven randomness and signature verification
- [x] Bonding curve economics and market operations
- [x] FishMarket freshness calculation and batch selling
- [x] Engine registry management and stats calculation
- [x] FishingRod registry operations and validation
- [x] Inventory management with equipment placement
- [x] Shard management and admin controls
- [x] Equipment validation and slot-based placement
- [x] All compilation warnings resolved

#### Frontend Status
- [x] SvelteKit boilerplate setup (Svelte 5, TailwindCSS v4)
- [x] Threlte dependencies configured (ready for 3D)
- [x] bits-ui components available
- [ ] 3D ocean world implementation
- [ ] Hex-grid movement visualization
- [ ] Inventory management UI (2D grid system)  
- [ ] Market trading interface
- [ ] Web3 wallet integration (Viem/Wagmi)
- [ ] Game state synchronization with contracts

#### Current Status
- ✅ All smart contract tests passing (57/57)
- ✅ Clean, warning-free codebase ready for production
- ✅ Modular architecture with focused manager contracts
- ✅ Equipment system with computed stats and default assignment
- ✅ Comprehensive shard management with admin controls
- ⏳ Frontend implementation ready to begin

### Quick Reference
- **Next Actions**: Implement 3D frontend with Threlte, Web3 integration, game UI
- **Key Files to Review**: memory/current-tasks.md, app/src/routes/, contracts are complete
- **Testing Strategy**: Contract tests complete, add frontend tests with Vitest
- **Major Achievement**: Production-ready modular smart contracts with 100% test coverage (57/57)
- **Architecture Highlights**: Modular managers, computed equipment stats, shard scaling, default equipment

## Development Notes

When implementing features:
1. Check memory/rising-tides.md for detailed game mechanics and design decisions
2. Review memory/technical-implementation.md for data models and architecture
3. Update memory/current-tasks.md when starting new work
4. Log decisions in memory/decisions.md for future reference
5. Frontend components should use Threlte for 3D rendering
6. Smart contracts are complete - focus on frontend implementation and Web3 integration
7. Equipment stats are computed from equipped items, not stored in ship templates
8. Default equipment ensures new players can immediately play
9. Shard system provides scalability for multiplayer
10. Update development progress in memory/development-log.md

## Memory

- Do not try to maintain backward compatibility in smart contracts as long as we have not yet deployed them