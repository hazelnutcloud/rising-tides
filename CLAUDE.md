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

## Development Notes

When implementing features:
1. Check memory/rising-tides.md for detailed game mechanics and design decisions
2. Review memory/technical-implementation.md for data models and architecture
3. Frontend components should use Threlte for 3D rendering
4. Smart contracts will need to implement game logic for fishing, trading, and inventory management
5. Consider gas optimization for on-chain game actions