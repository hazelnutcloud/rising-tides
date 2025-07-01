# Rising Tides New Fishing Mechanics

## Fishing fullfilment

- There should be two function or ways to fulfill a player's fishing request:

1. Offchain fulfillment
2. Onchain fulfillment

### Offchain fulfillment

After the external VRF contract calls the FishingContract, the completion should actually be put into a queue. Afterwards, the user should call another method `completeFishingOffchain` where they pass a signed packet provided by an offchain server. This method allows the game to implement some fun mechanics around fishing like minigames when the player is trying to catch a fish. The packet should contain the result whether the fishing attempt was succesful or another

### Onchain fulfillment

Alternatively, the user may call a different function `completeFishingOnChain` where they do not need a signed packet from an offchain server. However, the outcome of their fishing now becomes a coin toss where they have a chance to fail determined by the random number generated. This chance of failure is configurable by the master and is by default set to 50/50. This alternative function serves as a fallback in case of server failure and ensure the liveness of the contracts and the fully onchain nature of the game.

## Fishing cooldown

- Each type of fish should have another set of attributes called minCooldown and maxCooldown. This is the time that the player must wait after catching this fish. Larger/rarer fish should have a longer cooldown simulating the struggle to reel in the fish.
