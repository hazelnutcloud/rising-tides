## Intro

Rising Tides is an onchain multiplayer fishing game built on the RISE L2 network. Players travel the open sea to catch and trade fish, manage and upgrade their boats and fishing equipments, and compete to climb a global leaderboard.

## Core Gameplay

The core gameplay of Rising Tides is inspired by the indie game "Dredge" and revolves around managing your ship, equipments, inventory, and consumable resources to earn as much in-game currency as possible by catching fish.

### Game Loop
1. **Preparation**: Buy fuel, bait, and repair equipment
2. **Exploration**: Navigate the hex-grid ocean to find fishing spots
3. **Fishing**: Use bait to catch fish of various species and sizes
4. **Inventory Management**: Organize caught fish in your cargo hold
5. **Trading**: Return to port to sell fish at market prices
6. **Progression**: Upgrade ships and equipment with earned currency

## Movement & Fuel Economy

Players are able to move freely in the open sea based on a hex-grid system. Moving costs a certain amount of fuel. Your fuel consumption is primarily determined by your engine power. You need to spend in-game currency in order to top-up your fuel.

### Movement Mechanics
- **Grid System**: Hexagonal tiles allow for 6-directional movement
- **Fuel Consumption**: `fuelCost = enginePower * distanceMoved * fuelEfficiencyModifier`
- **Movement Speed**: `speed = enginePower / totalWeight`
- **Range**: Limited by fuel capacity and consumption rate

## Cargo Management

The game utilizes a 2D tile-based inventory management system to manage your ship's cargo. Each player's ships have a cargo space that holds all their caught fish, their ship's engine and their fishing equipment. These cargo items each have their own unique shape and dimension. The shape and dimension of the cargo space is determined by the player's equipped ship. You may place your caught fish anywhere in the cargo space as long as it fits. However, you may only place your engine and your fishing equipment in designated tiles of your cargo space.

### Inventory System Details
- **Grid-based**: Ships have cargo spaces of various shapes (not just rectangular)
- **Tetris-like Placement**: Items have various shapes that must fit within the grid
- **Designated Slots**: Specific tiles marked for engines and fishing equipment only
- **Item Shapes**: Fish and equipment come in different configurations (1x1, 2x2, L-shapes, etc.)
- **Cargo Shapes**: Different ships offer uniquely shaped cargo holds

## Power, Fuel, Speed, Weight

Power and therefore fuel consumption is determined by the ship's equipped engine. Speed is directly proportional to power and inversely proportional to weight. Players must carefully balance between these different variables to optimize their fishing output.

## Durability

Ships and fishing equipment have a durability value. As they get used, their durability reduces until it reaches zero. At which point, that item is no longer usable and must be repaired using in-game currency.

## Bait

In order to catch fish, users must spend in-game currency to buy bait. Bait will determine the types/species of fish you are able to catch and the probabilities of catching them.

### Bait Types
- **Basic Bait**: Catches common fish, low cost
- **Premium Bait**: Higher chance for rare species
- **Specialized Bait**: Targets specific fish types
- **Bait Consumption**: One bait per fishing attempt

## Open Market

In order to earn in-game currency, players may sell their caught fish in the game's open market. To simulate supply-and-demand, the value of fish follow a bonding curve. As players sell more of a certain species of fish in a span of time, the value of it decreases. This value increases over time (up to a limit) as less players sell it. Fish also have two different attributes that affect its final price: weight and freshness. Weight is determined at the time the player catches the fish. The freshness of the fish decreases over time as the player holds on to it. This means that the final value of a fish is determined by this formula: marketValue * weight * freshness.

### Market Dynamics
- **Bonding Curve**: Price decreases with volume sold, recovers over time
- **Fish Attributes**:
  - **Weight**: Randomly determined when caught (affects value)
  - **Freshness**: Decreases over time (100% → 0% over time period)
- **Price Formula**: `finalPrice = marketValue * weight * freshness`
- **Species Variety**: Different fish species have different base values and demand curves

## Maps

The world of Rising Tides is divided into different spaces called Maps. You are able to pay in-game currency to fast-travel between different maps. Maps with higher tiers of loot will cost more to fast-travel to.

### Map Tiers
- **Tier 1 (Starting Waters)**: Common fish, low travel cost
- **Tier 2 (Deep Ocean)**: Uncommon fish, moderate travel cost
- **Tier 3 (Abyssal Depths)**: Rare fish, high travel cost
- **Special Events**: Temporary maps with unique rewards

## Shards

To optimize the multiplayer experience, players are divided into logical units called Shards. Shards are mostly used in EVM indexed logs so users may only subscribe to logs from players from their shard, i.e, If a player is in Shard 1, they will only listen to movement events from logs coming from Shard 1

## Tokenomics

The in-game currency is emitted primarily when the user sells fish. It is burnt by various in-game actions such as purchasing fuel, purchasing bait, repairing/buying/upgrading new ships and fishing equipment, and more.

### Currency Flow
- **Emission (Currency Created)**:
  - Selling fish at market
  - Completing quests/achievements
  - Season rewards
  
- **Burning (Currency Destroyed)**:
  - Fuel purchases
  - Bait purchases
  - Equipment repairs
  - Ship upgrades
  - Map travel fees
  - Market transaction fees

## Leaderboard

Players compete to climb a global seasonal leaderboard. Their position on the leaderboard is determined by their total currency earned minus total currency spent. At the end of a season, top-ranked players will earn various valuable in-game items as rewards. In order to participate in a season's leaderboard and earn seasonal rewards, players must purchase the season's pass using ETH.