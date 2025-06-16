// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./MovementManager.sol";

/**
 * @title FishingManager
 * @dev Manages fishing mechanics, signature verification, and fish catching
 */
abstract contract FishingManager is MovementManager {
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
        // TODO: validate if a fishing rod is currently equipped

        // Validate bait type and check if player has it
        require(fishRegistry.isValidBait(baitType), "Invalid bait type");
        require(playerBait[msg.sender][baitType] > 0, "Insufficient bait");

        // Check if player already has a pending fishing request
        require(pendingFishingRequest[msg.sender] == 0, "Already have pending fishing request");

        // Consume one bait
        playerBait[msg.sender][baitType]--;

        // Increment player's fishing nonce
        playerFishingNonce[msg.sender]++;
        fishingNonce = playerFishingNonce[msg.sender];

        // Store pending request info
        pendingFishingRequest[msg.sender] = fishingNonce;
        pendingBaitType[msg.sender] = baitType;

        // Emit event for server to process
        IGameState.PlayerState memory player = playerStates[msg.sender];
        emit IGameState.FishingInitiated(
            msg.sender, player.shard, player.mapId, player.position.x, player.position.y, baitType, fishingNonce
        );

        return fishingNonce;
    }

    /**
     * @dev Fulfill fishing with server-signed result and optional inventory management
     */
    function fulfillFishing(
        FishingResult memory result,
        bytes memory signature,
        InventoryAction[] memory inventoryActions
    ) external onlyRegisteredPlayer whenNotPaused nonReentrant {
        require(result.player == msg.sender, "Result not for caller");
        require(pendingFishingRequest[msg.sender] == result.nonce, "Invalid or expired fishing request");
        require(result.nonce > 0, "Invalid nonce");

        // Verify signature timestamp is recent
        require(block.timestamp <= result.timestamp + SIGNATURE_TIMEOUT, "Signature expired");
        require(result.timestamp <= block.timestamp, "Future timestamp not allowed");

        // Verify signature hasn't been used before
        bytes32 signatureHash = keccak256(signature);
        require(!usedSignatures[signatureHash], "Signature already used");

        // Verify server signature
        bytes32 structHash = keccak256(
            abi.encode(
                FISHING_RESULT_TYPEHASH, result.player, result.nonce, result.species, result.weight, result.timestamp
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address recoveredSigner = hash.recover(signature);
        require(recoveredSigner == serverSigner, "Invalid signature");

        // Mark signature as used
        usedSignatures[signatureHash] = true;

        // Clear pending request
        delete pendingFishingRequest[msg.sender];
        delete pendingBaitType[msg.sender];

        // If server determined a catch occurred, process inventory actions
        if (result.species > 0) {
            require(fishRegistry.isValidSpecies(result.species), "Invalid species");

            // Process inventory management actions
            _processInventoryActions(msg.sender, inventoryActions);

            // Store caught fish if it was successfully placed in inventory
            uint256 fishId = playerFishCount[msg.sender];
            playerFish[msg.sender][fishId] =
                IGameState.FishCatch({species: result.species, weight: result.weight, caughtAt: block.timestamp});
            playerFishCount[msg.sender]++;

            emit IGameState.FishCaught(msg.sender, result.species, result.weight, fishId);
        } else {
            // Even if no fish caught, player can still manage inventory
            _processInventoryActions(msg.sender, inventoryActions);
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
        require(newSigner != address(0), "Invalid signer address");
        serverSigner = newSigner;
    }

    /**
     * @dev Process array of inventory actions (to be implemented by InventoryManager)
     */
    function _processInventoryActions(address player, InventoryAction[] memory actions) internal virtual;
}
