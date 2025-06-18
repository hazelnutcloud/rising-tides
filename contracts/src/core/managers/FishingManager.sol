// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SlotType, ItemType} from "../../types/InventoryTypes.sol";
import "../RisingTidesBase.sol";

/**
 * @title FishingManager
 * @dev Manages fishing mechanics, signature verification, and fish catching
 */
abstract contract FishingManager is RisingTidesBase {
    using ECDSA for bytes32;

    /**
     * @dev Initiate fishing at current position with chosen bait (server will complete the action)
     */
    function initiateFishing(uint256 baitType)
        external
        onlyRegisteredPlayer
        whenNotPaused
        nonReentrant
        returns (uint256 fishingNonce)
    {
        // Validate if a fishing rod is currently equipped
        if (!hasEquippedFishingRod(msg.sender)) revert NoFishingRodEquipped(msg.sender);

        // Validate bait type and check if player has it
        if (!fishRegistry.isValidBait(baitType)) revert InvalidBait(baitType);
        if (playerBait[msg.sender][baitType] == 0) revert InsufficientBait(baitType, 1, 0);

        // Check if player already has a pending fishing request
        if (pendingFishingRequest[msg.sender] != 0) {
            revert PendingFishingRequest(msg.sender, pendingFishingRequest[msg.sender]);
        }

        // Consume one bait
        playerBait[msg.sender][baitType]--;

        // Increment player's fishing nonce
        playerFishingNonce[msg.sender]++;
        fishingNonce = playerFishingNonce[msg.sender];

        // Store pending request info
        pendingFishingRequest[msg.sender] = fishingNonce;
        pendingBaitType[msg.sender] = baitType;

        // Emit event for server to process
        IRisingTides.PlayerState memory player = playerStates[msg.sender];
        emit IRisingTides.FishingInitiated(
            msg.sender, player.shard, player.mapId, player.position.x, player.position.y, baitType, fishingNonce
        );

        return fishingNonce;
    }

    /**
     * @dev Fulfill fishing with server-signed result and fish placement
     */
    function fulfillFishing(FishingResult memory result, bytes memory signature, FishPlacement memory fishPlacement)
        external
        onlyRegisteredPlayer
        whenNotPaused
        nonReentrant
        returns (uint256 instanceId)
    {
        if (result.player != msg.sender) revert InvalidFishingResult("Result not for caller");
        if (pendingFishingRequest[msg.sender] != result.nonce) revert ExpiredFishingRequest(result.nonce);
        if (result.nonce == 0) revert InvalidFishingResult("Invalid nonce");

        // Verify signature timestamp is recent
        if (block.timestamp > result.timestamp + SIGNATURE_TIMEOUT) {
            revert SignatureExpired(block.timestamp, result.timestamp + SIGNATURE_TIMEOUT);
        }
        if (result.timestamp > block.timestamp) revert FutureTimestamp(result.timestamp, block.timestamp);

        // Verify signature hasn't been used before
        bytes32 signatureHash = keccak256(signature);
        if (usedSignatures[signatureHash]) revert SignatureAlreadyUsed(signatureHash);

        // Verify server signature
        bytes32 structHash = keccak256(
            abi.encode(
                FISHING_RESULT_TYPEHASH, result.player, result.nonce, result.species, result.weight, result.timestamp
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address recoveredSigner = hash.recover(signature);
        if (recoveredSigner != serverSigner) revert InvalidSignature(recoveredSigner, serverSigner);

        // Mark signature as used
        usedSignatures[signatureHash] = true;

        // Clear pending request
        delete pendingFishingRequest[msg.sender];
        delete pendingBaitType[msg.sender];

        // If server determined a catch occurred, handle fish placement
        if (result.species > 0) {
            if (!fishRegistry.isValidSpecies(result.species)) revert InvalidSpecies(result.species);

            if (fishPlacement.shouldPlace) {
                // Player wants to place the fish in inventory
                instanceId = inventoryContract.placeFishInInventory(
                    msg.sender, result.species, result.weight, fishPlacement.x, fishPlacement.y, fishPlacement.rotation
                );

                if (instanceId == 0) revert OperationFailed("Failed to place fish in inventory");

                emit IRisingTides.FishCaught(msg.sender, result.species, result.weight);
            }
            // If shouldPlace is false, fish is discarded (no storage, no inventory placement)
        }
    }

    /**
     * @dev Get player's fishing status
     */
    function getPlayerFishingStatus(address player)
        external
        view
        returns (uint256 pendingNonce, uint256 baitTypeUsed, uint256 currentNonce)
    {
        pendingNonce = pendingFishingRequest[player];
        baitTypeUsed = pendingBaitType[player];
        currentNonce = playerFishingNonce[player];
    }

    /**
     * @dev Update server signer address (admin only)
     */
    function updateServerSigner(address newSigner) external onlyRole(ADMIN_ROLE) {
        if (newSigner == address(0)) revert InvalidAddress(newSigner);
        serverSigner = newSigner;
    }

    /**
     * @dev Check if a player has a fishing rod equipped
     */
    function hasEquippedFishingRod(address player) internal view returns (bool) {
        return inventoryContract.hasEquippedFishingRod(player);
    }
}
