# Rising Tides New Fishing Mechanics

## Fishing Fulfillment

Players must choose their completion method when initiating fishing (precommitment system):

```solidity
function initiateFishing(uint256 baitId, bool useOffchainCompletion)
```

This prevents players from gaming the system by choosing the completion method after seeing the VRF result.

### Offchain Fulfillment

After the VRF fulfills the randomness request, players who chose offchain completion must call `completeFishingOffchain` with a signed packet from the game server. This enables:

- Interactive minigames
- Enhanced gameplay experiences
- Server-side fishing mechanics

The signed packet uses EIP-712 and contains:

- Success/failure result
- Request ID
- Nonce (replay protection)
- Expiry timestamp

### Onchain Fulfillment

Players who chose onchain completion call `completeFishingOnchain` without needing server interaction. The success rate is determined by:

- VRF-generated random seed
- Configurable failure rate (default: 50%)
- Formula: `success = (randomSeed % 10000) >= onchainFailureRate`

This serves as a fallback ensuring the game remains fully playable even without server availability.

## Fishing Cooldown

### Base Cooldown

- All fishing attempts have a minimum 5-second cooldown to prevent spam
- Applied immediately when completing fishing (success or failure)

### Fish-Specific Cooldown

- Each fish species has minCooldown and maxCooldown attributes
- Actual cooldown is randomly determined within this range
- Larger/rarer fish have longer cooldowns (simulating the struggle to reel them in)
- If fish cooldown > base cooldown, the longer duration is used

## Fish Selection System

### Alias Tables

The game uses alias tables for O(1) fish selection based on:

- Map ID
- Region type
- Bait ID
- Day/night phase (6 AM - 6 PM is day)

### Probability Distribution

- GameMaster configures probability tables for each map-region-bait-dayphase combination
- Fallback hierarchy:
  1. Specific table for exact combination
  2. Default table for the bait type
  3. Global default table

### Fish Rarity

- **Important**: Fish rarity is determined by array index position, NOT fish ID
- GameMaster must sort fishIds arrays by rarity (least rare → most rare)
- Critical hits select the fish with the highest index among all rolls

### Critical Hit System

- Base roll: 1 fish selection
- Critical hit: 2 + critMultiplierBonus selections
- The rarest fish (highest index) among all rolls is caught
