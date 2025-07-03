# Rising Tides - Units and Precision Reference

This document details the units, data types, and precision used for all calculations in Rising Tides.

## Real-World Units Summary

The game uses real-world units to provide intuitive scale:

- **Engine Power**: Horsepower (HP)
- **Weight**: Kilograms (kg)
- **Fuel**: Liters (L)
- **Currency**: Doubloons (DBL)

All values are stored with 1e18 precision for accurate calculations.

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

- **enginePower**: Horsepower (HP) with 1e18 precision (uint256)
  - Real-world unit: Horsepower (HP)
  - Typical range: 10e18 to 1000e18 (10 HP to 1000 HP)
  - Precision: 1e18 (fixed-point)
  - Example: 100e18 = 100 horsepower
- **distance**: Hex tiles (uint256)
  - Precision: Whole numbers
- **fuelEfficiencyModifier**: Fixed-point multiplier (uint256)
  - Default: 1e17 (represents 0.1)
  - Range: 0.1e18 to 10e18 (0.1x to 10x efficiency)
- **fuelCost**: Liters of fuel consumed with 1e18 precision (uint256)
  - Real-world unit: Liters (L)
  - Precision: 1e18 (fixed-point)
  - Example: 500e18 = 500 liters of fuel

### Movement Time

```solidity
movementTime = (baseMovementTime × distance × totalWeight) / enginePower
```

**Units:**

- **baseMovementTime**: Seconds (uint256)
  - Default: 1 second
  - Range: 1-60 seconds
- **distance**: Hex tiles (uint256)
  - Precision: Whole numbers
- **totalWeight**: Kilograms (kg) with 1e18 precision (uint256)
  - Real-world unit: Kilograms (kg)
  - Range: 1e18 to 100000e18 (1 kg to 100,000 kg)
  - Precision: 1e18 (fixed-point)
  - Example: 500e18 = 500 kilograms
- **enginePower**: Horsepower (HP) with 1e18 precision (uint256)
  - Real-world unit: Horsepower (HP)
  - Range: 10e18 to 1000e18 (10 HP to 1000 HP)
  - Precision: 1e18 (fixed-point)
  - Example: 100e18 = 100 horsepower
- **movementTime**: Seconds with 1e18 precision (uint256)
  - Precision: 1e18 (fixed-point)
  - Example: 150e18 = 150 seconds (2.5 minutes)

## Fishing Mechanics Units

### Durability System

```solidity
durabilityLoss = fishWeight / (1 + strength/100)
```

**Units:**

- **fishWeight**: Kilograms (kg) (uint256)
  - Real-world unit: Kilograms (kg)
  - Range: 1-10,000
  - Precision: Can include decimals (stored as fixed-point)
  - Example: 2.5e18 = 2.5 kg (using 1e18 precision)
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

- **maxFishWeight**: Kilograms (kg) (uint256)
  - Real-world unit: Kilograms (kg)
  - Range: 10e18 to 50000e18 (10 kg to 50,000 kg)
  - Precision: 1e18 (fixed-point)
  - Example: 10e18 = 10 kg
  - Example: 1000e18 = 1,000 kg

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

- **marketValue**: Doubloons per kilogram (uint256)
  - Precision: 18 decimals (Wei standard)
  - Example: 100e18 = 100 DBL per kg
- **weight**: Kilograms (kg) (uint256)
  - Precision: Depends on fish weight system
  - Example: 2.5e18 = 2.5 kg (using 1e18 precision)
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

### Freshness Levels

**Discrete Levels:**

| Level   | Value | Description           |
| ------- | ----- | --------------------- |
| FRESH   | 100%  | Caught recently       |
| STALE   | 66%   | Starting to decay     |
| ROTTING | 33%   | Significantly decayed |
| ROTTEN  | 0%    | Cannot be sold        |

### Dynamic Market Pricing

**Units:**

- **currentPrice**: DBL per kg with PRECISION (uint256)
  - Updates based on supply/demand
  - Cannot drop below 10% of base price
- **priceDropRate**: Multiplier with PRECISION (uint256)
  - How much price drops per DBL sold
  - Example: 0.01e18 = 1% drop per DBL
- **priceRecoveryRate**: DBL per second with PRECISION (uint256)
  - How fast price recovers to base
  - Example: 0.1e18 = 0.1 DBL/kg per second

### Port Shop Pricing

**Units:**

- **price**: DBL with 18 decimals (uint256)
  - Fixed prices for items
  - Example: 5e18 = 5 DBL
- **requiredLevel**: Player level (uint256)
  - Minimum level to purchase
  - Example: 10 = Level 10 required

### Rod Repair Cost

**Units:**

- **repairCostPerDurability**: DBL per durability point (uint256)
  - Default: 1e18 (1 DBL per point)
  - Configurable by game master
- **durabilityToAdd**: Durability points (uint256)
  - Direct specification of repair amount

## Inventory Management Units

### Unified Item System

**Item Types:**

```solidity
enum ItemType {
    FUEL,     // 0: Fuel for ships
    BAIT,     // 1: Bait for fishing
    MATERIAL, // 2: Materials for crafting/repair
    SHIP      // 3: Ships
}
```

**Units:**

- **Item Amounts**: Quantity (uint256)
  - Fuel: Liters with 1e18 precision
  - Bait: Individual units
  - Materials: Individual units
  - Ships: Always 1 (binary ownership)

### Weight Capacity

**Units:**

- **shipWeightCapacity**: Kilograms (kg) with 1e18 precision (uint256)
  - Real-world unit: Kilograms (kg)
  - Typical range: 100e18 to 100000e18 (100 kg to 100,000 kg)
  - Precision: 1e18 (fixed-point)
  - Example: 5000e18 = 5,000 kg weight capacity
- **cargoWeight**: Total kilograms (kg) with 1e18 precision (uint256)
  - Real-world unit: Kilograms (kg)
  - Sum of all fish weights
  - Precision: 1e18 (fixed-point)
  - Example: 2500e18 = 2,500 kg total cargo weight

### Fuel Capacity

**Units:**

- **fuelCapacity**: Liters (L) with 1e18 precision (uint256)
  - Real-world unit: Liters (L)
  - Typical range: 100e18 to 10000e18 (100 L to 10,000 L)
  - Precision: 1e18 (fixed-point)
  - Example: 1000e18 = 1,000 liters fuel capacity
- **currentFuel**: Liters (L) with 1e18 precision (uint256)
  - Real-world unit: Liters (L)
  - Range: 0 to fuelCapacity
  - Precision: 1e18 (fixed-point)
  - Example: 750e18 = 750 liters of fuel

## Time Units

### Block Timestamps

- **Unit**: Seconds since Unix epoch (uint256)
- **Precision**: Whole seconds
- **Usage**: Movement timing, freshness calculations

### Duration Constants

- **baseMovementTime**: Seconds (default: 1)
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
6. **Use consistent precision** within each system (e.g., all weights use 1e18 precision)

## Example Calculations with Units

### Example 1: Fuel Cost for 5 Hex Movement

```
Engine Power: 100e18 (100 horsepower with 1e18 precision)
Distance: 5 hex tiles
Fuel Efficiency: 1.0 (1e18)

Fuel Cost = (100e18 × 5 × 1e18) / 1e18 = 500e18 (500 liters of fuel)
```

### Example 2: Fish Sale with Freshness

```
Market Value: 50 DBL per kg (50e18 wei)
Fish Weight: 3.5 kg (3.5e18 with 1e18 precision)
Freshness: 75%

Final Price = (50e18 × 3.5e18 × 75) / (1e18 × 100)
           = 13.125e39 / 1e20
           = 131.25e18 wei
           = 131.25 DBL
```

### Example 3: Movement Time Calculation

```
Engine Power: 150e18 (150 horsepower with 1e18 precision)
Total Weight: 3000e18 (3,000 kg with 1e18 precision)
Distance: 4 hex tiles
Base Movement Time: 10 seconds

Movement Time = (10 × 4 × 3000e18 × 1e18) / 150e18
              = 120000e36 / 150e18
              = 800e18 (800 seconds with 1e18 precision)
```

### Example 4: Durability Loss Calculation

```
Fish Weight: 8.0 kg (8e18 with 1e18 precision)
Rod Strength: 40 strength points

Durability Loss = 8e18 / (1e18 + 40e16)
                = 8e18 / 1.4e18
                = 5.71e18 (rounded down to 5e18 durability points)
```
