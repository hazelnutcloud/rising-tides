## Intro

Rising Tides is an onchain multiplayer fishing game built on the RISE L2 network. Players travel the open sea to catch and trade fish, manage and upgrade their boats and fishing equipments, and compete to climb a global leaderboard.

## Core Gameplay

The core gameplay of Rising Tides revolves around managing your ship, equipments, inventory, and consumable resources to earn as much in-game currency as possible by catching fish.

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
- **Continous coodinates**: Grid System: Hexagonal tiles allow for 6-directional movement
- **Fuel Consumption**: `fuelCost = enginePower * distanceMoved * fuelEfficiencyModifier`
- **Movement Speed**: `speed = enginePower / totalWeight`
- **Range**: Limited by fuel capacity and consumption rate

## Cargo Management

The game utilizes a weight-based inventory management system to manage your ship's cargo. You can only carry as much fish as your ship's maximum weight capacity.

## Power, Fuel, Speed, Weight

Power and therefore fuel consumption is determined by the ship. Speed is directly proportional to power and inversely proportional to weight. Players must carefully balance between these different variables to optimize their fishing output.

## Durability

Ships and fishing equipment have a durability value. As they get used, their durability reduces until it reaches zero. At which point, that item is no longer usable and must be repaired using in-game currency.

## Bait

In order to catch fish, users must spend in-game currency to buy bait. Bait will determine the types/species of fish you are able to catch and the probabilities of catching them.

## Fishing period

Your fishing rod contains a durability meter. Once depleted, your fishing rod is considered broken and must be repaired in order to use it again. This durability meter depletes every time you catch a fish. The amount of durability depleted depends on the size of the fish caught.

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

## Shards

To optimize the multiplayer experience, players are divided into logical units called Shards. Shards are mostly used in EVM indexed logs so users may only subscribe to logs from players from their shard, i.e, If a player is in Shard 1, they will only listen to movement events from logs coming from Shard 1

## Tokenomics

The in-game currency is emitted primarily when the user sells fish. It is burnt by various in-game actions such as purchasing fuel, purchasing bait, repairing/buying/upgrading new ships and fishing equipment, and more.

### Currency Flow
- **Emission (Currency Created)**:
  - Selling fish at market

- **Burning (Currency Destroyed)**:
  - Fuel purchases
  - Bait purchases
  - Fishing rod repairs
  - Ship upgrades
  - Map travel fees

## Leaderboard

Players compete to climb a global seasonal leaderboard. Their position on the leaderboard is determined by their total currency earned. At the end of a season, top-ranked players will earn various valuable in-game items as rewards.

## Technical Implementation

### Fish Probability Distribution

The probability distribution of fish is stored onchain using the alias method. This distribution is grouped by areas within a map and bait type into alias tables. Each alias table contains a probabilities array and an aliases array. When sampling a fish from this distribution, the x and y coordinates of the player is taken along with the bait id used to fetch the appropriate alias table. This alias table is then finally used to sample the fish with O(1) complexity.

### Smart Contracts

There are mainly two smart contracts which power Rising Tides.

1. **RisingTidesWorld**
  - Controls player movement and coordinates
  - Store data for all the different maps
  - Store alias tables for fish catching probability distributions
  - Contains functions and logic for catching and sampling fish, integrating with an external VRF provider

2. **RisingTidesInventory**
  - Inherits from ERC1155
  - Stores information about the player's inventory, i.e. Fuel, bait, ships, fishing rods, fish.
  - Also contains fish market data and functions for selling fish

If required due to size constraints, we can split the fish catching and selling mechanics into a separate contract.

### Region Metadata Storage

Information about a region is stored using packed coordinates:

```solidity
contract HexRegionLookup {
    mapping(uint256 => uint256) public hexToRegion;

    function packCoordinates(int32 q, int32 r) public pure returns (uint256) {
        return (uint256(uint32(q)) << 32) | uint256(uint32(r));
    }

    function setHexRegion(int32 q, int32 r, uint256 regionId) external {
        hexToRegion[packCoordinates(q, r)] = regionId;
    }

    function getRegionId(int32 q, int32 r) external view returns (uint256) {
        return hexToRegion[packCoordinates(q, r)];
    }
}
```

This regionId can then be used to lookup further information such as fish probability alias tables, map safe regions, etc.
