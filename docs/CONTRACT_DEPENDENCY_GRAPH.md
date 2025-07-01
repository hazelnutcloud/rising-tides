# Rising Tides Smart Contract Dependency Graph

## Visual Representation

```mermaid
graph TD
    %% Contract nodes
    World[RisingTidesWorld<br/>- Player positions<br/>- Movement<br/>- Maps & regions<br/>- Shards]
    Fishing[RisingTidesFishing<br/>- Probability tables<br/>- Fishing logic<br/>- VRF integration]
    Inventory[RisingTidesInventory<br/>- Ship & resource storage<br/>- Rod NFT custody<br/>- Weight management]
    Port[RisingTidesPort<br/>- Market interface<br/>- Shop functions<br/>- Crafting station]
    Rod[RisingTidesFishingRod<br/>- ERC721 NFTs<br/>- Rod attributes<br/>- Enchantments]

    %% External dependencies
    VRF[VRF Contract<br/><i>External</i>]
    DBL[Doubloons ERC20<br/><i>$DBL Token</i>]

    %% Dependencies
    Fishing --> World
    Fishing --> Inventory
    Fishing --> Rod
    Fishing -.-> VRF

    Port --> Inventory
    Port --> World
    Port --> Rod
    Port --> DBL
    Port --> Fishing

    Inventory --> World
    Inventory <--> Rod

    World --> DBL

    %% Styling
    classDef contract fill:#4a90e2,stroke:#2e5c8a,stroke-width:2px,color:#fff
    classDef external fill:#e74c3c,stroke:#c0392b,stroke-width:2px,color:#fff
    classDef token fill:#27ae60,stroke:#1e8449,stroke-width:2px,color:#fff

    class World,Fishing,Inventory,Port,Rod contract
    class VRF external
    class DBL token
```

## Dependency Details

### RisingTidesWorld

**Dependencies:**

- `Doubloons (DBL)` - For map travel fees

**Used by:**

- `RisingTidesFishing` - Validates player position for fishing
- `RisingTidesInventory` - Validates player exists and location
- `RisingTidesPort` - Checks if player is at port for trading

### RisingTidesFishing

**Dependencies:**

- `RisingTidesWorld` - Get player position and region type
- `RisingTidesInventory` - Check/consume bait, add caught fish
- `RisingTidesFishingRod` - Get rod attributes for fishing calculations
- `VRF Contract` - External randomness for fair fish generation

**Used by:**

- `RisingTidesPort` - May need fishing data for market analytics

### RisingTidesInventory

**Dependencies:**

- `RisingTidesWorld` - Validate player registration
- `RisingTidesFishingRod` - Custody of equipped rod NFTs (bidirectional)
- `IERC721` - Interface for rod NFT transfers

**Used by:**

- `RisingTidesFishing` - Consume bait, add caught fish
- `RisingTidesPort` - All inventory modifications
- `RisingTidesWorld` - Check fuel and ship stats for movement

### RisingTidesPort

**Dependencies:**

- `RisingTidesInventory` - Modify player inventories
- `RisingTidesWorld` - Verify player at port
- `RisingTidesFishingRod` - Create/repair rods
- `RisingTidesFishing` - Access fish probability data
- `Doubloons (DBL)` - Handle all currency transactions

**Used by:**

- None (top-level user interface contract)

### RisingTidesFishingRod

**Dependencies:**

- None (standalone ERC721)

**Used by:**

- `RisingTidesFishing` - Read rod attributes
- `RisingTidesInventory` - Track equipped rods
- `RisingTidesPort` - Mint/repair rods

## Key Observations

1. **RisingTidesPort** is the main entry point for most player actions
2. **RisingTidesWorld** is the foundational contract that others depend on
3. **RisingTidesFishingRod** is the most independent (pure ERC721)
4. **RisingTidesFishing** bridges gameplay mechanics with inventory
5. The system has clear separation of concerns with minimal circular dependencies

## Deployment Order

Based on dependencies, the recommended deployment order is:

1. `Doubloons (DBL)` - Token contract
2. `RisingTidesFishingRod` - No dependencies
3. `RisingTidesWorld` - Only depends on DBL
4. `RisingTidesInventory` - Depends on World and Rod
5. `RisingTidesFishing` - Depends on World, Inventory, and Rod
6. `RisingTidesPort` - Depends on all others
