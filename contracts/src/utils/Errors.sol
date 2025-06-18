// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Errors
 * @notice Centralized custom errors for the Rising Tides game
 * @dev Custom errors are more gas-efficient than require statements with strings
 */

// ============ Validation Errors ============

/// @notice Thrown when an invalid address (e.g., zero address) is provided
/// @param provided The invalid address that was provided
error InvalidAddress(address provided);

/// @notice Thrown when an invalid amount (e.g., zero) is provided
/// @param provided The invalid amount that was provided
error InvalidAmount(uint256 provided);

/// @notice Thrown when an invalid ID is provided
/// @param provided The invalid ID that was provided
error InvalidId(uint256 provided);

/// @notice Thrown when an empty string is provided where a non-empty string is required
error EmptyString();

/// @notice Thrown when invalid dimensions are provided
/// @param width The invalid width provided
/// @param height The invalid height provided
error InvalidDimensions(uint256 width, uint256 height);

/// @notice Thrown when an invalid rotation value is provided
/// @param provided The invalid rotation value
error InvalidRotation(uint256 provided);

/// @notice Thrown when an array length mismatch occurs
/// @param expected The expected array length
/// @param actual The actual array length
error ArrayLengthMismatch(uint256 expected, uint256 actual);

/// @notice Thrown when shape data is too small
/// @param expected The expected minimum size
/// @param actual The actual size provided
error ShapeDataTooSmall(uint256 expected, uint256 actual);

// ============ State Errors ============

/// @notice Thrown when a player is not registered
/// @param player The address of the unregistered player
error PlayerNotRegistered(address player);

/// @notice Thrown when a player is already registered
/// @param player The address of the already registered player
error PlayerAlreadyRegistered(address player);

/// @notice Thrown when a shard is full
/// @param shard The shard ID that is full
/// @param currentPlayers The current number of players in the shard
/// @param maxPlayers The maximum allowed players in the shard
error ShardFull(uint256 shard, uint256 currentPlayers, uint256 maxPlayers);

/// @notice Thrown when a player is already in the target shard
/// @param player The player address
/// @param shard The shard they're already in
error AlreadyInShard(address player, uint256 shard);

/// @notice Thrown when an invalid shard ID is provided
/// @param provided The invalid shard ID
/// @param maxShards The maximum number of shards
error InvalidShardId(uint256 provided, uint256 maxShards);

// ============ Resource Errors ============

/// @notice Thrown when there's insufficient balance
/// @param account The account with insufficient balance
/// @param required The required balance
/// @param available The available balance
error InsufficientBalance(address account, uint256 required, uint256 available);

/// @notice Thrown when there's insufficient fuel
/// @param required The required fuel amount
/// @param available The available fuel amount
error InsufficientFuel(uint256 required, uint256 available);

/// @notice Thrown when there's insufficient bait
/// @param baitType The type of bait
/// @param required The required amount
/// @param available The available amount
error InsufficientBait(uint256 baitType, uint256 required, uint256 available);

/// @notice Thrown when an operation would exceed max supply
/// @param currentSupply The current supply
/// @param additionalAmount The amount to be added
/// @param maxSupply The maximum allowed supply
error ExceedsMaxSupply(uint256 currentSupply, uint256 additionalAmount, uint256 maxSupply);

// ============ Access Errors ============

/// @notice Thrown when an unauthorized access attempt is made
/// @param caller The unauthorized caller
error Unauthorized(address caller);

/// @notice Thrown when only a registered player can perform the action
/// @param caller The unregistered caller
error OnlyRegisteredPlayer(address caller);

/// @notice Thrown when a player tries to update another player's data
/// @param caller The calling player
/// @param target The target player
error CannotUpdateOthersData(address caller, address target);

// ============ Game Logic Errors ============

/// @notice Thrown when an item is not found at the specified position
/// @param x The x coordinate
/// @param y The y coordinate
error ItemNotFound(uint256 x, uint256 y);

/// @notice Thrown when trying to place an item at an occupied position
/// @param x The x coordinate
/// @param y The y coordinate
error PositionOccupied(uint256 x, uint256 y);

/// @notice Thrown when an invalid direction is provided
/// @param provided The invalid direction
error InvalidDirection(uint256 provided);

/// @notice Thrown when terrain is not passable
/// @param mapId The map ID
/// @param x The x coordinate
/// @param y The y coordinate
error TerrainNotPassable(uint256 mapId, uint256 x, uint256 y);

/// @notice Thrown when a position is out of map bounds
/// @param mapId The map ID
/// @param x The x coordinate
/// @param y The y coordinate
error PositionOutOfBounds(uint256 mapId, uint256 x, uint256 y);

/// @notice Thrown when no fishing rod is equipped
/// @param player The player without a fishing rod
error NoFishingRodEquipped(address player);

/// @notice Thrown when a player already has a pending fishing request
/// @param player The player with pending request
/// @param nonce The pending request nonce
error PendingFishingRequest(address player, uint256 nonce);

/// @notice Thrown when trying to sell an item that's not a fish
/// @param itemType The actual item type
error NotAFish(uint8 itemType);

/// @notice Thrown when an operation fails
/// @param operation Description of the failed operation
error OperationFailed(string operation);

// ============ Timing Errors ============

/// @notice Thrown when an action is still on cooldown
/// @param currentTime The current timestamp
/// @param cooldownEndTime When the cooldown ends
error OnCooldown(uint256 currentTime, uint256 cooldownEndTime);

/// @notice Thrown when a signature has expired
/// @param currentTime The current timestamp
/// @param expirationTime When the signature expired
error SignatureExpired(uint256 currentTime, uint256 expirationTime);

/// @notice Thrown when a future timestamp is not allowed
/// @param provided The future timestamp provided
/// @param currentTime The current timestamp
error FutureTimestamp(uint256 provided, uint256 currentTime);

/// @notice Thrown when there's no active season
error NoActiveSeason();

/// @notice Thrown when a season is not active
/// @param seasonId The inactive season ID
error SeasonNotActive(uint256 seasonId);

/// @notice Thrown when a season has not started yet
/// @param seasonId The season ID
/// @param startTime When the season starts
/// @param currentTime The current timestamp
error SeasonNotStarted(uint256 seasonId, uint256 startTime, uint256 currentTime);

/// @notice Thrown when a season has ended
/// @param seasonId The season ID
/// @param endTime When the season ended
/// @param currentTime The current timestamp
error SeasonHasEnded(uint256 seasonId, uint256 endTime, uint256 currentTime);

/// @notice Thrown when trying to end a season that's already ended
/// @param seasonId The season ID
error SeasonAlreadyEnded(uint256 seasonId);

/// @notice Thrown when rewards have already been distributed
/// @param seasonId The season ID
error RewardsAlreadyDistributed(uint256 seasonId);

// ============ Registry Errors ============

/// @notice Thrown when an item already exists in a registry
/// @param registryType The type of registry (e.g., "Ship", "Engine")
/// @param id The ID that already exists
error AlreadyExists(string registryType, uint256 id);

/// @notice Thrown when an item doesn't exist in a registry
/// @param registryType The type of registry
/// @param id The ID that doesn't exist
error DoesNotExist(string registryType, uint256 id);

/// @notice Thrown when an invalid species is provided
/// @param speciesId The invalid species ID
error InvalidSpecies(uint256 speciesId);

/// @notice Thrown when an invalid engine is provided
/// @param engineId The invalid engine ID
error InvalidEngine(uint256 engineId);

/// @notice Thrown when an invalid fishing rod is provided
/// @param fishingRodId The invalid fishing rod ID
error InvalidFishingRod(uint256 fishingRodId);

/// @notice Thrown when an invalid map is provided
/// @param mapId The invalid map ID
error InvalidMap(uint256 mapId);

/// @notice Thrown when an invalid ship is provided
/// @param shipId The invalid ship ID
error InvalidShip(uint256 shipId);

/// @notice Thrown when an invalid bait type is provided
/// @param baitId The invalid bait ID
error InvalidBait(uint256 baitId);

// ============ Market Errors ============

/// @notice Thrown when a shop doesn't exist at the position
/// @param mapId The map ID
/// @param shopId The invalid shop ID
error ShopDoesNotExist(uint256 mapId, uint256 shopId);

/// @notice Thrown when a shop is inactive
/// @param shopId The inactive shop ID
error ShopInactive(uint256 shopId);

/// @notice Thrown when bait is not available at a shop
/// @param shopId The shop ID
/// @param baitType The unavailable bait type
error BaitNotAvailable(uint256 shopId, uint256 baitType);

/// @notice Thrown when already on the target map
/// @param mapId The map the player is already on
error AlreadyOnMap(uint256 mapId);

// ============ Validation Errors ============

/// @notice Thrown when an invalid fishing result is provided
/// @param reason The reason for invalidity
error InvalidFishingResult(string reason);

/// @notice Thrown when an invalid signature is provided
/// @param signer The recovered signer
/// @param expected The expected signer
error InvalidSignature(address signer, address expected);

/// @notice Thrown when a signature has already been used
/// @param signatureHash The hash of the used signature
error SignatureAlreadyUsed(bytes32 signatureHash);

/// @notice Thrown when trying to process an expired fishing request
/// @param nonce The request nonce
error ExpiredFishingRequest(uint256 nonce);

/// @notice Thrown when a player already owns a season pass
/// @param seasonId The season ID
/// @param player The player who already owns it
error AlreadyOwnsSeasonPass(uint256 seasonId, address player);

/// @notice Thrown when a player doesn't have a season pass
/// @param seasonId The season ID
/// @param player The player without a pass
error NoSeasonPass(uint256 seasonId, address player);

/// @notice Thrown when insufficient payment is provided
/// @param required The required payment
/// @param provided The payment provided
error InsufficientPayment(uint256 required, uint256 provided);

/// @notice Thrown when there's no balance to withdraw
error NoBalance();

/// @notice Thrown when a token doesn't exist
/// @param tokenId The non-existent token ID
error TokenDoesNotExist(uint256 tokenId);

/// @notice Thrown when limit is out of bounds
/// @param provided The provided limit
/// @param min The minimum allowed
/// @param max The maximum allowed
error LimitOutOfBounds(uint256 provided, uint256 min, uint256 max);

/// @notice Thrown when too many moves are requested at once
/// @param requested The number of moves requested
/// @param maxAllowed The maximum allowed moves
error TooManyMoves(uint256 requested, uint256 maxAllowed);

/// @notice Thrown when no directions are provided for movement
error NoDirectionsProvided();

/// @notice Thrown when an item can't be placed at destination
/// @param reason The reason for the placement failure
error CannotPlaceItem(string reason);

/// @notice Thrown when an invalid item type is provided
/// @param itemType The invalid item type
error InvalidItemType(uint8 itemType);

/// @notice Thrown when boundaries are invalid
/// @param minX Minimum X coordinate
/// @param maxX Maximum X coordinate
/// @param minY Minimum Y coordinate
/// @param maxY Maximum Y coordinate
error InvalidBoundaries(int256 minX, int256 maxX, int256 minY, int256 maxY);

/// @notice Thrown when no bait types are specified
error NoBaitTypesSpecified();

/// @notice Thrown when a distribution is empty
error EmptyDistribution();

/// @notice Thrown when start time is not in the future
/// @param provided The provided start time
/// @param currentTime The current time
error StartTimeNotInFuture(uint256 provided, uint256 currentTime);

/// @notice Thrown when end time is not after start time
/// @param startTime The start time
/// @param endTime The end time
error InvalidTimeRange(uint256 startTime, uint256 endTime);

/// @notice Thrown when arrays have mismatched lengths
error InvalidArrayLength();

/// @notice Thrown when player is not at a harbor location
/// @param mapId The map ID
/// @param x The x coordinate
/// @param y The y coordinate
error NotAtHarbor(uint256 mapId, int32 x, int32 y);