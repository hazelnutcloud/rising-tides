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
- **Active Focus**: Frontend development and smart contract test fixes
- **Current Branch**: main  
- **Recent Progress**: Discovered advanced smart contract implementation (16/19 tests passing)
- **Next Priority**: Fix 3 failing tests, then implement 3D game world frontend

### Memory System
The `./memory/` directory contains project knowledge and development context:
- `rising-tides.md` - Comprehensive game design and mechanics documentation
- `technical-implementation.md` - Architecture, data models, and technical decisions
- `current-tasks.md` - Active tasks and immediate priorities (see memory/current-tasks.md)
- `development-log.md` - Progress tracking and completed milestones (see memory/development-log.md)
- `decisions.md` - Architectural and design decisions log (see memory/decisions.md)

### Implementation Progress

#### Smart Contracts Status (MAJOR UPDATE: Advanced Implementation)
- [x] Core game state management (GameState.sol - fully implemented)
- [x] Player registration and ship management (complete with multi-shard support)
- [x] Movement and fuel system (hex-grid with 6 directions, fuel economy)
- [x] Fishing mechanics and RNG (VRF integration with Chainlink)
- [x] Inventory and cargo management (sophisticated 2D Tetris-like system)
- [x] Fish market with bonding curves (dynamic pricing, freshness decay)
- [x] Season pass and leaderboard (NFT-based system)
- [x] Currency token contract (ERC20 with mint/burn mechanics)
- [x] Registry systems (Ship, Fish, Map management)
- [x] Deployment scripts (complete with sample data)

#### Test Status: 16/19 Passing ⚠️
- [x] Player registration and state management
- [x] Hex-grid movement with collision detection  
- [x] Fuel purchasing and consumption
- [x] Fishing mechanics with VRF
- [x] Bonding curve economics
- ❌ FishMarket freshness calculation (minor discrepancy)
- ❌ Fish selling currency minting (permission issue)
- ❌ Batch fish selling (related permission issue)

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

#### Current Blockers
- 3 failing smart contract tests (easily fixable permission issues)
- Frontend implementation gap (no game-specific components yet)

### Quick Reference
- **Next Actions**: Fix 3 failing contract tests, then implement 3D frontend with Threlte
- **Key Files to Review**: memory/current-tasks.md, contracts/test/*.t.sol, app/src/routes/
- **Testing Strategy**: Fix contract test permissions, add frontend tests with Vitest
- **Critical Discovery**: Smart contracts are production-ready, focus on frontend development

## Development Notes

When implementing features:
1. Check memory/rising-tides.md for detailed game mechanics and design decisions
2. Review memory/technical-implementation.md for data models and architecture
3. Update memory/current-tasks.md when starting new work
4. Log decisions in memory/decisions.md for future reference
5. Frontend components should use Threlte for 3D rendering
6. Smart contracts will need to implement game logic for fishing, trading, and inventory management
7. Consider gas optimization for on-chain game actions
8. Update development progress in memory/development-log.md