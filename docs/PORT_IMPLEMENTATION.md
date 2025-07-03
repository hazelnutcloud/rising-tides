# Rising Tides Port Implementation

This document describes the RisingTidesPort contract implementation and its key features.

## Overview

RisingTidesPort serves as the main economic hub where players interact with the game's marketplace and crafting systems. It provides a unified interface for all economic activities at port locations.

## Key Features

### 1. Dynamic Fish Market

The fish market implements a supply and demand system:

- **Price Drops**: When players sell fish, the market price decreases based on the amount of DBL earned
- **Price Recovery**: Prices gradually recover to their base value over time
- **Price Floor**: Fish cannot be sold below 10% of their base price
- **Freshness System**: Fish value decreases over time in discrete levels (Fresh → Stale → Rotting → Rotten)

### 2. Unified Item Shop

All items are purchased through a single `buyItem` function:

```solidity
buyItem(ItemType itemType, uint256 itemId, uint256 amount)
```

**Item Types:**

- `FUEL` (0): Ship fuel in liters
- `BAIT` (1): Fishing bait
- `MATERIAL` (2): Crafting materials
- `SHIP` (3): Ships (amount must be 1)

**Features:**

- Per-map inventory (different items available at different ports)
- Level requirements for items
- Consistent pricing in DBL

### 3. Rod Crafting System

- Recipes define required materials and DBL cost
- 10% chance for "Strange" quality (can gain titles)
- Map restrictions using bitfield (recipes can be limited to specific locations)
- VRF integration for true randomness

### 4. Simplified Rod Repair

- Direct DBL payment (no materials required)
- Cost: 1 DBL per durability point (configurable)
- Players specify exact durability to restore

## Implementation Details

### Access Control

- `ADMIN_ROLE`: System administration
- `GAME_MASTER_ROLE`: Economic balancing and configuration
- `VRF_COORDINATOR_ROLE`: Randomness for crafting

### Location Validation

All port functions require the player to be at a port location:

```solidity
modifier onlyAtPort() {
    (int32 q, int32 r, uint256 mapId) = world.getPlayerLocation(msg.sender);
    if (!world.isPortRegion(mapId, q, r)) revert NotAtPort();
    _;
}
```

### Error Handling

Uses custom errors instead of require statements for gas efficiency:

- `NotAtPort`
- `InsufficientLevel`
- `InsufficientDoubloons`
- `ItemNotAvailable`
- `InvalidAmount`
- etc.

## Economic Configuration

### Configurable Parameters

1. **Market Data** (per fish species):
   - Base price
   - Price drop rate
   - Price recovery rate

2. **Shop Items** (per map):
   - Price
   - Required level
   - Availability

3. **Crafting Recipes**:
   - Material requirements
   - DBL cost
   - Level requirement
   - Allowed maps (bitfield)

4. **Repair Cost**:
   - DBL per durability point

### Example Configuration

```solidity
// Set tuna market data
setMarketData(TUNA_ID, MarketData({
    currentPrice: 50e18,      // 50 DBL/kg
    basePrice: 50e18,         // 50 DBL/kg base
    priceDropRate: 0.02e18,   // 2% drop per DBL sold
    priceRecoveryRate: 0.1e18, // 0.1 DBL/kg per second
    lastUpdateTime: block.timestamp,
    exists: true
}));

// Set fuel price at map 0
setShopItem(0, ItemType.FUEL, 0, ShopItem({
    price: 0.1e18,      // 0.1 DBL per liter
    requiredLevel: 0,   // No level requirement
    available: true
}));
```

## Gas Optimizations

1. **Bitfield for map restrictions** instead of arrays
2. **Custom errors** instead of require strings
3. **Unified functions** reduce code duplication
4. **Efficient storage patterns** for market data

## Security Considerations

1. **ReentrancyGuard** on all state-changing functions
2. **Pausable** for emergency stops
3. **Role-based access control**
4. **Input validation** on all parameters
5. **Overflow protection** with Solidity 0.8+

## Integration Points

The Port contract integrates with:

- **World**: Location validation
- **Inventory**: Item management
- **Fishing**: Fish species data
- **FishingRod**: Rod minting and repair
- **Doubloons**: All payments

## Future Enhancements

Potential additions that the current architecture supports:

- Port-specific bonuses (e.g., trading ports with better fish prices)
- Auction house for player-to-player trading
- Bulk operations for efficiency
- Special events with temporary price modifiers
- Port reputation system
