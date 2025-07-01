# Rising Tides - Units and Precision Reference

This document details the units, data types, and precision used for all calculations in Rising Tides.

## Table of Contents

- [General Precision Standards](#general-precision-standards)
- [Movement & Navigation Units](#movement--navigation-units)
- [Fishing Mechanics Units](#fishing-mechanics-units)
- [Market Economy Units](#market-economy-units)
- [Inventory Management Units](#inventory-management-units)
- [Time Units](#time-units)

## General Precision Standards

### Fixed-Point Arithmetic

- **PRECISION constant**: `1e18` (1,000,000,000,000,000,000)
- **Purpose**: Avoid floating-point math in Solidity
- **Usage**: Multiply by PRECISION for calculations, divide by PRECISION for final result

### Percentage Representations

- **Basis Points**: Used for rates (10,000 = 100%)
- **Percentage**: Direct percentage values (100 = 100%)
- **Fixed-Point Percentage**: Percentage × PRECISION (1e18 = 100%)

## Movement & Navigation Units

### Hex Distance Calculation

```solidity
function calculateHexDistance(int32 q1, int32 r1, int32 q2, int32 r2) returns (uint256)
```

**Units:**

- **Input**: `q1, r1, q2, r2` - Hexagonal coordinates (int32)
  - Range: -2,147,483,648 to 2,147,483,647
- **Output**: Distance in hex tiles (uint256)
  - Precision: Whole numbers only
  - Example: 5 = 5 hex tiles

### Fuel Consumption

```solidity
fuelCost = (enginePower × distance × fuelEfficiencyModifier) / PRECISION
```

**Units:**

- **enginePower**: Power units (uint256)
  - Typical range: 10-1000
  - Precision: Whole numbers
- **distance**: Hex tiles (uint256)
  - Precision: Whole numbers
- **fuelEfficiencyModifier**: Fixed-point multiplier (uint256)
  - Default: 1e18 (represents 1.0)
  - Range: 0.1e18 to 10e18 (0.1x to 10x efficiency)
- **fuelCost**: Fuel units consumed (uint256)
  - Precision: Whole numbers
  - Example: 500 = 500 fuel units

### Movement Speed

```solidity
speed = (enginePower × PRECISION) / totalWeight
```

**Units:**

- **enginePower**: Power units (uint256)
  - Range: 10-1000
- **totalWeight**: Weight units (uint256)
  - Range: 1-100,000
- **speed**: Fixed-point speed value (uint256)
  - Unit: Power per weight with 18 decimal precision
  - Example: 2e17 = 0.2 speed units

### Movement Time

```solidity
movementTime = (baseMovementTime × distance × totalWeight × PRECISION) / (enginePower × PRECISION)
```

**Units:**

- **baseMovementTime**: Seconds (uint256)
  - Default: 10 seconds
  - Range: 1-60 seconds
- **distance**: Hex tiles (uint256)
- **totalWeight**: Weight units (uint256)
- **enginePower**: Power units (uint256)
- **movementTime**: Seconds (uint256)
  - Precision: Whole seconds
  - Example: 150 = 150 seconds (2.5 minutes)

## Fishing Mechanics Units

### Durability System

```solidity
durabilityLoss = fishWeight / (1 + strength/100)
```

**Units:**

- **fishWeight**: Weight units (uint256)
  - Range: 1-10,000
  - Precision: Can include decimals (stored as fixed-point)
  - Example: 250 = 2.5 weight units (if using 2 decimal precision)
- **strength**: Strength points (uint256)
  - Range: 0-100
  - Precision: Whole numbers
- **durabilityLoss**: Durability points (uint256)
  - Precision: Whole numbers (rounded down)
  - Example: 40 = 40 durability points lost

### Rod Durability

**Units:**

- **maxDurability**: Durability points (uint256)
  - Typical range: 100-10,000
  - Precision: Whole numbers
- **currentDurability**: Durability points (uint256)
  - Range: 0 to maxDurability
  - Precision: Whole numbers

### Fish Weight

**Units:**

- **maxFishWeight**: Weight units (uint256)
  - Range: 10-50,000
  - Precision: Depends on implementation
  - If stored with 2 decimal places: 1000 = 10.00 weight units
  - If stored as whole numbers: 1000 = 1000 weight units

### Critical Rate

```solidity
criticalHit = random() < (critRate / 10000)
```

**Units:**

- **critRate**: Basis points (uint256)
  - Range: 0-10,000
  - Precision: 1 basis point = 0.01%
  - Examples:
    - 100 = 1%
    - 500 = 5%
    - 1000 = 10%
    - 10000 = 100%

### Efficiency

```solidity
baitConsumed = random() >= (efficiency / 100)
```

**Units:**

- **efficiency**: Percentage points (uint256)
  - Range: 0-100
  - Precision: Whole percentage points
  - Examples:
    - 25 = 25% chance to save bait
    - 50 = 50% chance to save bait
    - 100 = 100% chance to save bait

## Market Economy Units

### Fish Price Calculation

```solidity
finalPrice = marketValue × weight × freshness
```

**Units:**

- **marketValue**: Doubloons per weight unit (uint256)
  - Precision: 18 decimals (Wei standard)
  - Example: 100e18 = 100 DBL per weight unit
- **weight**: Weight units (uint256)
  - Precision: Depends on fish weight system
  - Example: 250 = 2.5 weight units (with 2 decimal precision)
- **freshness**: Percentage as decimal (uint256)
  - Range: 0-100 (representing 0% to 100%)
  - Applied as: freshness/100
- **finalPrice**: Doubloons (uint256)
  - Precision: 18 decimals (Wei standard)
  - Example: 200e18 = 200 DBL

### Doubloons (DBL)

**Standard**: ERC20 with 18 decimals

- **1 DBL** = 1e18 wei (1,000,000,000,000,000,000 wei)
- **0.1 DBL** = 1e17 wei
- **0.01 DBL** = 1e16 wei

### Freshness Decay

```solidity
freshness = max(0, 100 - (timeSinceCatch / decayRate))
```

**Units:**

- **timeSinceCatch**: Seconds (uint256)
  - Source: block.timestamp difference
- **decayRate**: Seconds per 1% decay (uint256)
  - Example: 72 = 1% decay every 72 seconds
- **freshness**: Percentage (uint256)
  - Range: 0-100
  - Precision: Whole percentage points

## Inventory Management Units

### Weight Capacity

**Units:**

- **shipWeightCapacity**: Weight units (uint256)
  - Typical range: 100-100,000
  - Precision: Same as fish weight system
- **cargoWeight**: Total weight units (uint256)
  - Sum of all fish weights
  - Precision: Same as individual fish weights

### Fuel Capacity

**Units:**

- **fuelCapacity**: Fuel units (uint256)
  - Typical range: 100-10,000
  - Precision: Whole numbers
- **currentFuel**: Fuel units (uint256)
  - Range: 0 to fuelCapacity
  - Precision: Whole numbers

## Time Units

### Block Timestamps

- **Unit**: Seconds since Unix epoch (uint256)
- **Precision**: Whole seconds
- **Usage**: Movement timing, freshness calculations

### Duration Constants

- **baseMovementTime**: Seconds (default: 10)
- **segmentDuration**: Seconds per hex movement
- **decayRate**: Seconds for freshness decay

## Coordinate Systems

### Hexagonal Coordinates

- **Type**: Axial coordinates (q, r)
- **Data Type**: int32 for each coordinate
- **Range**: -2,147,483,648 to 2,147,483,647
- **Packing**: Two int32 values packed into one uint256
  ```solidity
  packed = (uint256(uint32(q)) << 32) | uint256(uint32(r))
  ```

### Map IDs

- **Type**: uint256
- **Range**: 0 to 2^256-1
- **Typical Usage**: Sequential IDs starting from 0

### Region IDs

- **Type**: uint256
- **Format**: [type (8 bits)][custom data (248 bits)]
- **Region Type Extraction**: `regionId & 0xFF`

## Enchantment Bitmasks

### Enchantment Storage

- **Type**: uint256 bitmask
- **Bit Positions**:
  ```solidity
  ENCHANT_LUCKY = 1 << 0      // Bit 0
  ENCHANT_ICY = 1 << 1        // Bit 1
  ENCHANT_DEADLY = 1 << 2     // Bit 2
  ENCHANT_EFFICIENT = 1 << 3  // Bit 3
  ENCHANT_STRONG = 1 << 4     // Bit 4
  ENCHANT_REGION_BONUS = 1 << 5 // Bit 5
  ENCHANT_TASTY = 1 << 6      // Bit 6
  ```

## Random Number Ranges

### VRF Random Numbers

- **Type**: uint256
- **Range**: 0 to 2^256-1
- **Usage**: Modulo operations for specific ranges

  ```solidity
  // For percentage chance (0-99)
  randomPercent = randomNumber % 100

  // For basis points (0-9999)
  randomBasisPoints = randomNumber % 10000
  ```

## Best Practices

1. **Always use fixed-point math** for calculations involving decimals
2. **Store percentages as whole numbers** (0-100) and divide when applying
3. **Use basis points** (0-10,000) for fine-grained percentages
4. **Round down** for player costs, **round up** for player rewards
5. **Validate ranges** before calculations to prevent overflows
6. **Use consistent precision** within each system (e.g., all weights use same decimal places)

## Example Calculations with Units

### Example 1: Fuel Cost for 5 Hex Movement

```
Engine Power: 100 power units
Distance: 5 hex tiles
Fuel Efficiency: 1.0 (1e18)

Fuel Cost = (100 × 5 × 1e18) / 1e18 = 500 fuel units
```

### Example 2: Fish Sale with Freshness

```
Market Value: 50 DBL per weight unit (50e18 wei)
Fish Weight: 3.5 weight units (350 with 2 decimal precision)
Freshness: 75%

Final Price = (50e18 × 350 × 75) / (100 × 100)
           = 1,312,500e18 / 10,000
           = 131.25e18 wei
           = 131.25 DBL
```

### Example 3: Durability Loss Calculation

```
Fish Weight: 8.0 weight units (800 with 2 decimal precision)
Rod Strength: 40 strength points

Durability Loss = 800 / (100 + 40) × 100
                = 800 / 140 × 100
                = 571 (rounded down to 5 durability points)
```
