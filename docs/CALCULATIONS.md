# Rising Tides - Master Calculations Document

This document details all the calculations used in the Rising Tides game mechanics. Refer to [CALCULATIONS_UNITS_PRECISION](docs/CALCULATIONS_UNITS_PRECISION.md) for detailed units and precision info.

## Table of Contents

- [Movement & Navigation](#movement--navigation)
  - [Hex Distance Calculation](#hex-distance-calculation)
  - [Fuel Consumption](#fuel-consumption)
  - [Movement Time](#movement-time)
- [Fishing Mechanics](#fishing-mechanics)
  - [Durability Loss](#durability-loss)
  - [Fish Weight Validation](#fish-weight-validation)
  - [Critical Hit Mechanics](#critical-hit-mechanics)
  - [Bait Efficiency](#bait-efficiency)
  - [Lucky Enchantment](#lucky-enchantment)
- [Market Economy](#market-economy)
  - [Fish Price Calculation](#fish-price-calculation)
  - [Freshness Decay](#freshness-decay)
  - [Market Recovery](#market-recovery)
- [Inventory Management](#inventory-management)
  - [Weight Capacity](#weight-capacity)
  - [Cargo Weight Calculation](#cargo-weight-calculation)
- [Progression Systems](#progression-systems)
  - [Fishing Rod Titles](#fishing-rod-titles)
  - [Title Bonuses](#title-bonuses)

## Movement & Navigation

### Hex Distance Calculation

Calculates the distance between two hexagonal coordinates using axial coordinates (q, r).

```solidity
function calculateHexDistance(int32 q1, int32 r1, int32 q2, int32 r2) returns (uint256)
```

**Formula:**

```
dq = q2 - q1
dr = r2 - r1
ds = -dq - dr

distance = (|dq| + |dr| + |ds|) / 2
```

**Example:**

- From (0, 0) to (2, -1): distance = (|2| + |-1| + |-1|) / 2 = 2

### Fuel Consumption

Calculates fuel required for movement based on engine power and distance.

```solidity
function calculateFuelCost(uint256 enginePower, uint256 distance) returns (uint256)
```

**Formula:**

```
fuelCost = (enginePower × distance × fuelEfficiencyModifier) / PRECISION
```

**Constants:**

- `PRECISION = 1e18`
- `fuelEfficiencyModifier = 1e17` (default, can be adjusted)

**Example:**

- Engine Power: 100e18 (100 engine power with 1e18 precision)
- Distance: 5 hexes
- Fuel Cost = (100e18 × 5 × 1e18) / 1e18 = 500e18 fuel units

### Movement Time

Calculates time required to move a certain distance.

```solidity
function calculateMovementTime(uint256 enginePower, uint256 totalWeight, uint256 distance) returns (uint256)
```

**Formula:**

```
movementTime = (baseMovementTime × distance × totalWeight × PRECISION) / enginePower
```

**Constants:**

- `baseMovementTime = 1` seconds (default)
- `PRECISION = 1e18`

**Example:**

- Base Time: 1 seconds
- Distance: 3 hexes
- Total Weight: 500e18 (500 weight units with 1e18 precision)
- Engine Power: 100e18 (100 engine power with 1e18 precision)
- Movement Time = (1 × 3 × 500e18 × 1e18) / 100e18 = 150e18 (15 seconds with 1e18 precision)

## Fishing Mechanics

### Durability Loss

Calculates durability loss when catching a fish.

**Formula:**

```
durabilityLoss = fishWeight / (1 + strength/100)
```

**Factors:**

- Fish weight (randomly determined within species range)
- Rod strength attribute (higher strength = less durability loss)

**Example:**

- Fish Weight: 50
- Rod Strength: 25
- Durability Loss = 50 / (1 + 25/100) = 50 / 1.25 = 40

### Fish Weight Validation

Determines if a catch succeeds based on rod's max fish weight.

**Formula:**

```
if (fishWeight > rodMaxWeight) {
    successChance = 10%  // 90% fail chance
} else {
    successChance = 100%
}
```

### Critical Hit Mechanics

Determines if player gets bonus rolls for rarer fish.

**Critical Hit Check:**

```
criticalHit = random() < (critRate / 10000)
```

**Note:** critRate is stored in basis points (10000 = 100%)

**Number of Rolls on Critical Hit:**

```
totalRolls = 1 + 1 + critMultiplierBonus
```

Where:

- First 1 = base roll (always happens)
- Second 1 = standard critical hit bonus
- critMultiplierBonus = additional rolls from enchantments/titles (default 0)

**Examples:**

- No crit: 1 roll
- Normal crit (no bonus): 2 rolls (1 base + 1 crit)
- Crit with +1 multiplier bonus: 3 rolls (1 base + 1 crit + 1 bonus)
- Crit with +2 multiplier bonus: 4 rolls (1 base + 1 crit + 2 bonus)

### Bait Efficiency

Determines if bait is consumed when fishing.

**Formula:**

```
baitConsumed = random() >= (efficiency / 100)
```

### Lucky Enchantment

Determines if player catches two fish in one attempt.

**Formula:**

```
if (hasLuckyEnchantment) {
    doubleCatch = random() < 0.20  // 20% chance
}
```

## Market Economy

### Fish Price Calculation

Calculates the final selling price of a fish.

**Formula:**

```
finalPrice = marketValue × weight × freshness
```

**Components:**

- `marketValue`: Base price per species (affected by supply/demand)
- `weight`: Individual fish weight
- `freshness`: Percentage from 0% to 100%

**Example:**

- Market Value: 100 DBL
- Fish Weight: 2.5
- Freshness: 80%
- Final Price = 100 × 2.5 × 0.80 = 200 DBL

### Freshness Decay

Calculates fish freshness based on time since catch.

**Formula:**

```
freshness = max(0, 100 - (timeSinceCatch / decayRate))
```

**Factors:**

- Time since catch (in seconds)
- Decay rate (species-specific)
- Icy enchantment: 50% slower decay

**Example:**

- Time Since Catch: 3600 seconds (1 hour)
- Decay Rate: 7200 seconds (2 hours for 100% decay)
- Freshness = 100 - (3600 / 7200) × 100 = 50%

### Market Recovery

Market prices recover when fish aren't being sold.

**Formula:**

```
newPrice = currentPrice + (basePrice - currentPrice) × recoveryRate × timeSinceLastSale
```

**Factors:**

- Recovery rate per second
- Time since last sale
- Base price (equilibrium price)

## Inventory Management

### Weight Capacity

Validates if cargo weight exceeds ship capacity.

**Check:**

```
if (cargoWeight > shipWeightCapacity) {
    revert CargoExceedsCapacity()
}
```

### Cargo Weight Calculation

Total weight of all fish in inventory.

**Formula:**

```
cargoWeight = Σ(fishWeight[i]) for all fish in inventory
```

### Total Weight Calculation

Total weight used for movement calculations, including ship's empty weight.

**Formula:**

```
totalWeight = ship.emptyWeight + cargoWeight
```

**Example:**

- Ship Empty Weight: 30e18 (30 kilos)
- Cargo Weight: 8e18 (8 kilos of fish)
- Total Weight = 30e18 + 8e18 = 38e18

## Progression Systems

### Strange Quality Assignment

Determines if a newly crafted rod receives the Strange quality.

**Formula:**

```
isStrange = (randomSeed >> 192) % 100 < STRANGE_CHANCE
```

Where:

- `STRANGE_CHANCE = 10` (10% probability)
- Only Strange rods can track catches and gain titles

### Fishing Rod Titles

Titles unlock at specific catch milestones with associated bonuses. **Only available for Strange quality rods.**

| Title                   | Catches Required | Bonus                                                    |
| ----------------------- | ---------------- | -------------------------------------------------------- |
| Strange                 | 0                | None                                                     |
| Unremarkable            | 10               | None                                                     |
| Barely Wet              | 25               | None                                                     |
| Mildly Effective        | 45               | None                                                     |
| Somewhat Reliable       | 70               | None                                                     |
| Uncharitable            | 100              | +5% durability                                           |
| Notably Capable         | 135              | None                                                     |
| Sufficiently Proven     | 175              | None                                                     |
| Truly Feared            | 230              | None                                                     |
| Spectacularly Efficient | 300              | +10% bait efficiency                                     |
| Scale-Covered           | 375              | None                                                     |
| Wicked Nasty            | 460              | None                                                     |
| Positively Merciless    | 560              | None                                                     |
| Totally Ordinary        | 675              | +5% crit rate                                            |
| Reef-Clearing           | 850              | None                                                     |
| Rage-Inducing           | 1000             | None                                                     |
| Server-Clearing         | 1500             | +10% max fish weight range                               |
| Australian              | 2500             | None                                                     |
| Poseidon's Own          | 5000             | 5% chance for "Perfect Catch" (no durability loss)       |
| Absolutely Seaworthy    | 8500             | Fish have 10% chance to be "Trophy Quality" (1.5x value) |

### Title Bonuses

Title bonuses are applied as modifiers to base rod stats. **Note: Title bonuses only apply to Strange quality rods.**

**Title Bonus Check:**

```
if (rod.isStrange) {
    // Apply title bonuses based on totalCatches
} else {
    // No title bonuses applied
}
```

**Durability Bonus:**

```
effectiveDurability = baseDurability × (1 + titleDurabilityBonus/100)
```

**Efficiency Bonus:**

```
effectiveEfficiency = baseEfficiency + titleEfficiencyBonus
```

**Crit Rate Bonus:**

```
effectiveCritRate = baseCritRate + titleCritRateBonus
```

**Crit Multiplier Bonus:**

```
effectiveCritMultiplierBonus = titleCritMultiplierBonus + enchantmentCritMultiplierBonus
```

**Max Weight Range Bonus:**

```
effectiveMaxWeight = baseMaxWeight × (1 + titleWeightBonus/100)
```

## Additional Calculations

### Ship Region Compatibility

Ships can only navigate to regions they support:

```
canNavigate = shipSupportedRegions.includes(regionType)
```

### Shard Assignment

New players are assigned to the least populated shard:

```
optimalShard = shard with min(playerCount) where playerCount < maxPlayersPerShard
```

### Map Travel Cost

Traveling between maps requires payment:

```
cost = destinationMap.travelCost
```

### Level Requirements

Maps have minimum level requirements:

```
canAccess = playerLevel >= map.requiredLevel
```

## Constants Reference

| Constant               | Value      | Description                                                 |
| ---------------------- | ---------- | ----------------------------------------------------------- |
| PRECISION              | 1e18       | Fixed-point precision for calculations                      |
| MIN_ENGINE_POWER       | 10e18      | Minimum engine power required to move (with 1e18 precision) |
| MAX_MOVEMENT_QUEUE     | 10         | Maximum movement steps per transaction                      |
| baseMovementTime       | 10 seconds | Base time to move one hex                                   |
| maxPlayersPerShard     | 100        | Maximum players per shard                                   |
| fuelEfficiencyModifier | 1e18       | Fuel consumption modifier                                   |

## Notes

- All calculations use Solidity's integer math to avoid floating-point issues
- Randomness is provided by external VRF (Verifiable Random Function) contract
- Prices and values are denominated in Doubloons (DBL) with 18 decimal places
- Time-based calculations use block.timestamp for on-chain verification
