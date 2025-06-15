# 🌊 Rising Tides

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](https://github.com/your-repo/rising-tides)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Solidity](https://img.shields.io/badge/solidity-^0.8.20-purple.svg)](https://docs.soliditylang.org/)
[![Foundry](https://img.shields.io/badge/foundry-toolkit-red.svg)](https://github.com/foundry-rs/foundry)

An onchain multiplayer fishing game built on the RISE L2 network. Navigate vast oceans, catch rare fish, manage your ship and inventory, and compete in a dynamic player-driven economy.

## 🎮 Game Overview

Rising Tides combines the exploration and resource management of "Dredge" with blockchain technology to create a fully onchain gaming experience. Players explore different maps, catch fish with strategic bait selection, trade in dynamic markets, and climb seasonal leaderboards.

### Core Gameplay Loop
1. **🛒 Preparation** - Buy fuel, bait, and repair equipment
2. **🗺️ Exploration** - Navigate hex-grid oceans across multiple maps  
3. **🎣 Fishing** - Use strategic bait selection to catch rare species
4. **📦 Management** - Organize inventory in Tetris-like cargo system
5. **💰 Trading** - Sell fish in dynamic bonding curve markets
6. **⬆️ Progression** - Upgrade ships and climb leaderboards

## 🏗️ Architecture

### Tech Stack

**Frontend (`app/`)**
- **Framework**: SvelteKit with Svelte 5
- **3D Rendering**: Threlte (Three.js wrapper for Svelte)
- **Styling**: TailwindCSS v4 + bits-ui components
- **Web3**: Viem/Wagmi for blockchain interactions
- **Deployment**: Cloudflare Pages/Workers

**Smart Contracts (`contracts/`)**
- **Framework**: Foundry
- **Language**: Solidity ^0.8.20
- **Network**: RISE L2
- **VRF**: Chainlink VRF for secure randomness

## 📋 Project Structure

```
rising-tides/
├── 📱 app/                    # SvelteKit frontend
│   ├── src/routes/           # Page routes
│   ├── src/lib/              # Shared components & utilities
│   └── static/               # Static assets
├── ⚖️ contracts/              # Smart contracts
│   ├── src/core/             # Core game contracts
│   ├── src/registries/       # Registry contracts
│   ├── src/tokens/           # Token contracts
│   ├── src/interfaces/       # Contract interfaces
│   ├── test/                 # Test files
│   └── script/               # Deployment scripts
├── 📝 memory/                # Game design documents
└── 📄 CLAUDE.md              # Development guidelines
```

## 🚀 Quick Start

### Prerequisites
- **Node.js** 18+ with Bun
- **Foundry** toolkit
- **Git** for version control

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-repo/rising-tides.git
   cd rising-tides
   ```

2. **Install frontend dependencies**
   ```bash
   cd app
   bun install
   ```

3. **Install contract dependencies**
   ```bash
   cd contracts
   forge install
   ```

### Development

**Frontend Development**
```bash
cd app
bun run dev          # Start development server
bun run build        # Build for production
bun run check        # Type checking
bun run lint         # Lint code
```

**Smart Contract Development**
```bash
cd contracts
forge build          # Compile contracts
forge test           # Run tests
forge test -vv       # Run tests with verbose output
forge script script/Deploy.s.sol  # Deploy contracts
```

## 🎯 Game Mechanics

### 🗺️ Map System
- **Multiple Maps**: Explore different ocean regions with unique fish populations
- **Tiered Content**: Higher-tier maps offer rarer fish but cost more to access
- **Terrain**: Navigate around impassable areas and find optimal fishing spots
- **Travel Costs**: Pay currency to fast-travel between maps

### 🎣 Fishing System
- **Bait Selection**: Choose specific bait types for strategic fishing
- **Position-based**: Fish distributions vary by location on each map
- **VRF Randomness**: Chainlink VRF ensures fair and unpredictable catches
- **Free Attempts**: No cost per fishing attempt, only bait consumption

### ⛵ Ship & Movement
- **Hex Grid**: Navigate on a hexagonal grid system (6 directions)
- **Fuel Economy**: Movement costs fuel based on distance and ship efficiency
- **Speed System**: `speed = enginePower / totalWeight`
- **Cooldowns**: Movement speed determines how often you can move

### 📦 Inventory Management
- **2D Grid System**: Tetris-like inventory with item shapes
- **Ship Variants**: Different ships have unique cargo hold shapes
- **Equipment Slots**: Designated areas for engines and fishing gear
- **Weight System**: Total weight affects movement speed

### 💰 Dynamic Economy
- **Bonding Curves**: Fish prices change based on supply and demand
- **Freshness Decay**: Fish lose value over time
- **Weight Factor**: Heavier fish are more valuable
- **Market Formula**: `finalPrice = marketValue × weight × freshness`

### 🏆 Seasonal Competition
- **Leaderboards**: Compete based on currency earned minus spent
- **Season Pass**: Purchase passes with ETH to participate
- **Rewards**: Top players earn valuable in-game items
- **Shards**: Multiplayer optimization without affecting game content

## 📄 Smart Contracts

### Core Contracts

| Contract | Description |
|----------|-------------|
| **GameState** | Main game logic, player registration, movement, fishing |
| **MapRegistry** | Map management, fish distributions, bait shops, terrain |
| **FishMarket** | Trading system with bonding curves |
| **RisingTidesCurrency** | In-game ERC20 token |
| **SeasonPass** | NFT-based seasonal participation |

### Registry Contracts

| Contract | Description |
|----------|-------------|
| **ShipRegistry** | Ship types, stats, and configurations |
| **FishRegistry** | Fish species, bait types, and catch probabilities |

### Key Features
- **Map-based World**: Fish distributions and shops unique per map
- **VRF Integration**: Secure randomness for fishing outcomes  
- **Shard Optimization**: Multiplayer scaling without content fragmentation
- **Upgradeable**: Proxy patterns for future improvements

## 🧪 Testing

**Run All Tests**
```bash
cd contracts
forge test
```

**Run Specific Test**
```bash
forge test --match-test testFishing
```

**Test Coverage**
- ✅ Player registration and state management
- ✅ Map-based movement with terrain collision
- ✅ Bait selection and fishing mechanics  
- ✅ Shop location requirements
- ✅ Fuel and currency systems
- ✅ Inventory and weight calculations

## 🚀 Deployment

### Local Development
```bash
# Start local anvil node
anvil

# Deploy contracts
cd contracts
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --private-key <key> --broadcast
```

### Production Deployment
```bash
# Deploy to RISE L2
forge script script/Deploy.s.sol --rpc-url <RISE_RPC_URL> --private-key <PRIVATE_KEY> --broadcast --verify
```

The deployment script automatically:
- Deploys all core contracts
- Sets up roles and permissions
- Creates starter map with bait shops
- Adds sample fish species and bait types
- Configures fish distributions

## 🎮 Game Design

Detailed game mechanics and design decisions can be found in:
- [`memory/rising-tides.md`](memory/rising-tides.md) - Core game design
- [`memory/technical-implementation.md`](memory/technical-implementation.md) - Technical architecture
- [`CLAUDE.md`](CLAUDE.md) - Development guidelines

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following the guidelines in `CLAUDE.md`
4. Run tests and ensure they pass
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Development Guidelines
- Follow the patterns established in existing contracts
- Add comprehensive tests for new features
- Update documentation for significant changes
- Use the established code style and conventions

## 📊 Gas Optimization

The contracts are optimized for gas efficiency:
- **Packed Structs**: Minimize storage slots
- **Batch Operations**: Combined actions in single transactions
- **Event-driven**: Minimal on-chain storage for temporary data
- **Efficient Algorithms**: Optimized pathfinding and calculations

## 🔐 Security

- **Access Control**: Role-based permissions for admin functions
- **Reentrancy Protection**: Guards on all external functions
- **Input Validation**: Comprehensive parameter checking
- **VRF Security**: Chainlink VRF for tamper-proof randomness
- **Pausable**: Emergency pause functionality

## 📈 Roadmap

### Phase 1: Core Game ✅
- [x] Basic movement and fishing
- [x] Map system with terrain
- [x] Bait selection mechanics
- [x] VRF integration

### Phase 2: Economy & Trading 🚧
- [ ] Fish market implementation
- [ ] Dynamic pricing system
- [ ] Inventory management
- [ ] Ship upgrades

### Phase 3: Social Features 📋
- [ ] Seasonal leaderboards
- [ ] Guild system
- [ ] Multiplayer events
- [ ] Achievement system

### Phase 4: Advanced Features 📋
- [ ] Equipment crafting
- [ ] Weather system
- [ ] Rare events
- [ ] NFT integration

## 📞 Support

- **Issues**: Report bugs on GitHub Issues
- **Discussions**: Join community discussions
- **Documentation**: Check `memory/` folder for detailed guides

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Chainlink** for VRF services
- **OpenZeppelin** for secure contract templates
- **Foundry** for excellent development tools
- **RISE L2** for the blockchain infrastructure
- **"Dredge"** for game design inspiration

---

*Built with ❤️ for the future of onchain gaming*