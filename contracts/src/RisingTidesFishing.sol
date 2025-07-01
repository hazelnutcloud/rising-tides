// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
                                                                               ,----,
                                               ,--.                          ,/   .`|
,-.----.     ,---,  .--.--.      ,---,       ,--.'|  ,----..               ,`   .'  :   ,---,    ,---,        ,---,.  .--.--.
\    /  \ ,`--.' | /  /    '. ,`--.' |   ,--,:  : | /   /   \            ;    ;     /,`--.' |  .'  .' `\    ,'  .' | /  /    '.
;   :    \|   :  :|  :  /`. / |   :  :,`--.'`|  ' :|   :     :         .'___,/    ,' |   :  :,---.'     \ ,---.'   ||  :  /`. /
|   | .\ ::   |  ';  |  |--`  :   |  '|   :  :  | |.   |  ;. /         |    :     |  :   |  '|   |  .`\  ||   |   .';  |  |--`
.   : |: ||   :  ||  :  ;_    |   :  |:   |   \ | :.   ; /--`          ;    |.';  ;  |   :  |:   : |  '  |:   :  |-,|  :  ;_
|   |  \ :'   '  ; \  \    `. '   '  ;|   : '  '; |;   | ;  __         `----'  |  |  '   '  ;|   ' '  ;  ::   |  ;/| \  \    `.
|   : .  /|   |  |  `----.   \|   |  |'   ' ;.    ;|   : |.' .'            '   :  ;  |   |  |'   | ;  .  ||   :   .'  `----.   \
;   | |  \'   :  ;  __ \  \  |'   :  ;|   | | \   |.   | '_.' :            |   |  '  '   :  ;|   | :  |  '|   |  |-,  __ \  \  |
|   | ;\  \   |  ' /  /`--'  /|   |  ''   : |  ; .''   ; : \  |            '   :  |  |   |  ''   : | /  ; '   :  ;/| /  /`--'  /
:   ' | \.'   :  |'--'.     / '   :  ||   | '`--'  '   | '/  .'            ;   |.'   '   :  ||   | '` ,/  |   |    \'--'.     /
:   : :-' ;   |.'   `--'---'  ;   |.' '   : |      |   :    /              '---'     ;   |.' ;   :  .'    |   :   .'  `--'---'
|   |.'   '---'               '---'   ;   |.'       \   \ .'                         '---'   |   ,.'      |   | ,'
`---'                                 '---'          `---`                                   '---'        `----'

                                                $DBL - Doubloons of the Seven Seas
*/

import {IRisingTidesFishing} from "./interfaces/IRisingTidesFishing.sol";
import {IRisingTidesWorld} from "./interfaces/IRisingTidesWorld.sol";
import {IRisingTidesInventory} from "./interfaces/IRisingTidesInventory.sol";
import {IRisingTidesFishingRod} from "./interfaces/IRisingTidesFishingRod.sol";
import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Pausable} from "../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {ECDSA} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";

contract RisingTidesFishing is
    IRisingTidesFishing,
    AccessControl,
    Pausable,
    ReentrancyGuard,
    EIP712
{
    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 private constant GAME_MASTER_ROLE = keccak256("GAME_MASTER_ROLE");
    bytes32 private constant VRF_COORDINATOR_ROLE =
        keccak256("VRF_COORDINATOR_ROLE");

    bytes32 private constant FISHING_RESULT_TYPEHASH =
        keccak256(
            "FishingResult(uint256 requestId,bool success,uint256 nonce,uint256 expiry)"
        );

    uint256 private constant PRECISION = 1e18;
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant DAY_DURATION = 86400; // 24 hours in seconds
    uint256 private constant DAY_START = 21600; // 6 AM in seconds
    uint256 private constant DAY_END = 64800; // 6 PM in seconds

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    // Core contracts
    IRisingTidesWorld public world;
    IRisingTidesInventory public inventory;
    IRisingTidesFishingRod public fishingRod;

    // VRF and offchain
    address public vrfCoordinator;
    address public offchainSigner;
    uint256 public onchainFailureRate = 5000; // 50% in basis points

    // Request tracking
    mapping(address => FishingRequest) public activeFishingRequests;
    mapping(uint256 => address) public requestIdToPlayer;
    uint256 public nextRequestId = 1;

    // Player state
    mapping(address => uint256) public playerCooldowns;
    mapping(address => uint256) public playerNonces;

    // Fish data
    mapping(uint256 => FishSpecies) public fishSpecies;

    // Alias tables for probability distributions
    // Key: keccak256(abi.encodePacked(mapId, regionType, baitId, isDayTime))
    mapping(bytes32 => AliasTable) public fishingTables;

    // Default fallback tables
    mapping(uint256 => AliasTable) public defaultBaitTables; // baitId => table
    AliasTable public globalDefaultTable;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyVRFCoordinator() {
        if (!hasRole(VRF_COORDINATOR_ROLE, msg.sender)) revert Unauthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _world,
        address _inventory,
        address _fishingRod,
        address _vrfCoordinator,
        address _offchainSigner
    ) EIP712("RisingTidesFishing", "1") {
        world = IRisingTidesWorld(_world);
        inventory = IRisingTidesInventory(_inventory);
        fishingRod = IRisingTidesFishingRod(_fishingRod);
        vrfCoordinator = _vrfCoordinator;
        offchainSigner = _offchainSigner;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(GAME_MASTER_ROLE, msg.sender);
        _grantRole(VRF_COORDINATOR_ROLE, _vrfCoordinator);
    }

    /*//////////////////////////////////////////////////////////////
                            FISHING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function initiateFishing(
        uint256 baitId
    ) external whenNotPaused returns (uint256 requestId) {
        // Check if player already has an active request
        if (activeFishingRequests[msg.sender].isPending)
            revert AlreadyFishing();

        // Check cooldown
        if (block.timestamp < playerCooldowns[msg.sender])
            revert StillOnCooldown();

        // Validate player location and state
        (bool canFish, int32 q, int32 r, uint256 regionId) = world
            .validateFishingLocation(msg.sender);
        if (!canFish) revert InvalidFishingLocation();
        if (world.isMoving(msg.sender)) revert CannotFishWhileMoving();

        // Get player info for mapId
        IRisingTidesWorld.Player memory playerInfo = world.getPlayerInfo(
            msg.sender
        );

        // Check fishing rod
        uint256 rodTokenId = inventory.getEquippedRod(msg.sender);
        if (rodTokenId == 0) revert NoFishingRodEquipped();

        // TODO: lots of missing stuff here

        // Validate rod is usable
        (, , , , , bool isUsable) = fishingRod.getAttributes(
            rodTokenId,
            regionId & 0xFF
        );
        if (!isUsable) revert InvalidFishingLocation();

        // Check bait
        if (baitId != 0) {
            uint256 baitAmount = inventory.getBait(msg.sender, baitId);
            if (baitAmount == 0) revert InsufficientBait();
        }

        // Generate request ID
        requestId = nextRequestId++;

        // Store request
        activeFishingRequests[msg.sender] = FishingRequest({
            player: msg.sender,
            requestId: requestId,
            randomSeed: 0, // Will be filled by VRF
            timestamp: block.timestamp,
            rodTokenId: rodTokenId,
            baitId: baitId,
            mapId: playerInfo.mapId,
            regionId: regionId,
            q: q,
            r: r,
            isPending: true,
            isDayTime: isDayTime()
        });

        requestIdToPlayer[requestId] = msg.sender;

        // Request randomness from VRF
        // In a real implementation, this would call the VRF coordinator
        // For now, we'll emit the event
        emit FishingInitiated(
            msg.sender,
            requestId,
            rodTokenId,
            baitId,
            playerInfo.mapId,
            regionId,
            q,
            r,
            isDayTime(),
            block.timestamp
        );
    }

    function completeFishingOffchain(
        uint256 requestId,
        OffchainResult calldata result,
        bytes calldata signature,
        uint256[] calldata fishToDiscard
    ) external whenNotPaused nonReentrant {
        // Validate request
        address player = requestIdToPlayer[requestId];
        if (player != msg.sender) revert Unauthorized();

        FishingRequest storage request = activeFishingRequests[msg.sender];
        if (!request.isPending || request.requestId != requestId)
            revert InvalidRequestId();
        if (request.randomSeed == 0) revert InvalidRequestId(); // VRF not fulfilled yet

        // Validate signature
        if (result.expiry < block.timestamp) revert RequestExpired();
        if (result.nonce != playerNonces[msg.sender]) revert InvalidSignature();

        bytes32 structHash = keccak256(
            abi.encode(
                FISHING_RESULT_TYPEHASH,
                requestId,
                result.success,
                result.nonce,
                result.expiry
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = hash.recover(signature);
        if (signer != offchainSigner) revert InvalidSignature();

        // Increment nonce
        playerNonces[msg.sender]++;

        // Process completion
        _completeFishing(request, result.success, fishToDiscard, true);
    }

    function completeFishingOnchain(
        uint256 requestId,
        uint256[] calldata fishToDiscard
    ) external whenNotPaused nonReentrant {
        // Validate request
        address player = requestIdToPlayer[requestId];
        if (player != msg.sender) revert Unauthorized();

        FishingRequest storage request = activeFishingRequests[msg.sender];
        if (!request.isPending || request.requestId != requestId)
            revert InvalidRequestId();
        if (request.randomSeed == 0) revert InvalidRequestId(); // VRF not fulfilled yet

        // Determine success based on onchain failure rate
        bool success = (request.randomSeed % BASIS_POINTS) >=
            onchainFailureRate;

        // Process completion
        _completeFishing(request, success, fishToDiscard, false);
    }

    /*//////////////////////////////////////////////////////////////
                            VRF CALLBACK
    //////////////////////////////////////////////////////////////*/

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) external onlyVRFCoordinator {
        address player = requestIdToPlayer[requestId];
        if (player == address(0)) revert InvalidRequestId();

        FishingRequest storage request = activeFishingRequests[player];
        if (!request.isPending || request.requestId != requestId)
            revert InvalidRequestId();

        // Store random seed
        request.randomSeed = randomWords[0];
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getActiveFishingRequest(
        address player
    ) external view returns (FishingRequest memory) {
        return activeFishingRequests[player];
    }

    function getFishSpecies(
        uint256 fishId
    ) external view returns (FishSpecies memory) {
        return fishSpecies[fishId];
    }

    function getAliasTable(
        uint256 mapId,
        uint256 regionType,
        uint256 baitId,
        bool _isDayTime
    ) external view returns (AliasTable memory) {
        bytes32 key = keccak256(
            abi.encodePacked(mapId, regionType, baitId, _isDayTime)
        );
        return fishingTables[key];
    }

    function getPlayerCooldown(address player) external view returns (uint256) {
        return playerCooldowns[player];
    }

    function isDayTime() public view returns (bool) {
        uint256 timeOfDay = block.timestamp % DAY_DURATION;
        return timeOfDay >= DAY_START && timeOfDay < DAY_END;
    }

    function getOnchainFailureRate() external view returns (uint256) {
        return onchainFailureRate;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setFishSpecies(
        uint256 fishId,
        FishSpecies calldata species
    ) external onlyRole(GAME_MASTER_ROLE) {
        if (species.minWeight > species.maxWeight) revert InvalidFishSpecies();
        if (species.minCooldown > species.maxCooldown)
            revert InvalidFishSpecies();

        fishSpecies[fishId] = species;

        emit FishSpeciesSet(
            fishId,
            species.name,
            species.minWeight,
            species.maxWeight,
            species.baseValue,
            species.minCooldown,
            species.maxCooldown,
            species.decayRate
        );
    }

    function setAliasTable(
        uint256 mapId,
        uint256 regionType,
        uint256 baitId,
        bool _isDayTime,
        uint256[] calldata probabilities,
        uint256[] calldata aliases,
        uint256[] calldata fishIds
    ) external onlyRole(GAME_MASTER_ROLE) {
        _validateAndSetAliasTable(
            keccak256(abi.encodePacked(mapId, regionType, baitId, _isDayTime)),
            probabilities,
            aliases,
            fishIds
        );

        emit AliasTableSet(
            mapId,
            regionType,
            baitId,
            _isDayTime,
            probabilities,
            aliases,
            fishIds
        );
    }

    function setDefaultBaitTable(
        uint256 baitId,
        uint256[] calldata probabilities,
        uint256[] calldata aliases,
        uint256[] calldata fishIds
    ) external onlyRole(GAME_MASTER_ROLE) {
        _validateAndSetAliasTable(
            bytes32(0), // Temporary key for validation
            probabilities,
            aliases,
            fishIds
        );

        defaultBaitTables[baitId] = AliasTable({
            probabilities: probabilities,
            aliases: aliases,
            fishIds: fishIds,
            totalProbability: _sumArray(probabilities),
            exists: true
        });
    }

    function setGlobalDefaultTable(
        uint256[] calldata probabilities,
        uint256[] calldata aliases,
        uint256[] calldata fishIds
    ) external onlyRole(GAME_MASTER_ROLE) {
        _validateAndSetAliasTable(
            bytes32(0), // Temporary key for validation
            probabilities,
            aliases,
            fishIds
        );

        globalDefaultTable = AliasTable({
            probabilities: probabilities,
            aliases: aliases,
            fishIds: fishIds,
            totalProbability: _sumArray(probabilities),
            exists: true
        });
    }

    function setOnchainFailureRate(
        uint256 rate
    ) external onlyRole(GAME_MASTER_ROLE) {
        if (rate > BASIS_POINTS) revert InvalidFailureRate();
        onchainFailureRate = rate;
        emit OnchainFailureRateSet(rate);
    }

    function setVRFCoordinator(
        address coordinator
    ) external onlyRole(ADMIN_ROLE) {
        _revokeRole(VRF_COORDINATOR_ROLE, vrfCoordinator);
        vrfCoordinator = coordinator;
        _grantRole(VRF_COORDINATOR_ROLE, coordinator);
    }

    function setOffchainSigner(address signer) external onlyRole(ADMIN_ROLE) {
        offchainSigner = signer;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _completeFishing(
        FishingRequest storage request,
        bool success,
        uint256[] calldata fishToDiscard,
        bool isOffchain
    ) internal {
        // Mark request as completed
        request.isPending = false;

        // Process bait consumption
        bool consumeBait = _processBaitConsumption(request);

        if (!success) {
            emit FishingFailed(
                request.player,
                request.requestId,
                "Failed catch",
                consumeBait,
                isOffchain
            );
            return;
        }

        // Discard fish if needed
        if (fishToDiscard.length > 0) {
            _discardFish(request.player, fishToDiscard);
        }

        // Process the actual fishing
        _processFishCatch(request, consumeBait, isOffchain);
    }

    function _processBaitConsumption(
        FishingRequest storage request
    ) internal returns (bool) {
        if (request.baitId == 0) return false;

        uint256 regionType = request.regionId & 0xFF;
        (, , uint256 effectiveEfficiency, , , ) = fishingRod.getAttributes(
            request.rodTokenId,
            regionType
        );

        bool consumeBait = true;
        if (effectiveEfficiency > 0) {
            uint256 efficiencyRoll = uint256(
                keccak256(abi.encode(request.randomSeed, "efficiency"))
            ) % 100;
            if (efficiencyRoll < effectiveEfficiency) {
                consumeBait = false;
            }
        }

        if (consumeBait) {
            inventory.consumeBait(request.player, request.baitId, 1);
            emit BaitConsumed(request.player, request.baitId, 1);
        }

        return consumeBait;
    }

    function _processFishCatch(
        FishingRequest storage request,
        bool consumeBait,
        bool isOffchain
    ) internal {
        uint256 regionType = request.regionId & 0xFF;

        // Get rod attributes
        (
            uint256 effectiveMaxFishWeight,
            uint256 effectiveCritRate,
            ,
            uint256 effectiveCritMultiplierBonus,
            ,

        ) = fishingRod.getAttributes(request.rodTokenId, regionType);

        // Select fish
        uint256 fishId = _selectFishWithCrits(
            request,
            effectiveCritRate,
            effectiveCritMultiplierBonus
        );

        if (fishId == 0 || !fishSpecies[fishId].exists) {
            emit FishingFailed(
                request.player,
                request.requestId,
                "No fish available",
                consumeBait,
                isOffchain
            );
            return;
        }

        // Calculate fish weight
        uint256 weight = _calculateFishWeight(
            fishId,
            request.randomSeed,
            effectiveMaxFishWeight
        );

        // Check if rod can handle the fish
        if (weight > effectiveMaxFishWeight) {
            uint256 catchRoll = uint256(
                keccak256(abi.encode(request.randomSeed, "overweight"))
            ) % 100;
            if (catchRoll >= 10) {
                emit FishingFailed(
                    request.player,
                    request.requestId,
                    "Fish too heavy",
                    consumeBait,
                    isOffchain
                );
                return;
            }
        }

        // Process catch and add to inventory
        _finalizeCatch(
            request,
            fishId,
            weight,
            regionType,
            effectiveMaxFishWeight,
            consumeBait,
            isOffchain
        );
    }

    function _selectFishWithCrits(
        FishingRequest storage request,
        uint256 effectiveCritRate,
        uint256 effectiveCritMultiplierBonus
    ) internal view returns (uint256) {
        // Initial fish selection
        uint256 fishId = _selectFish(
            request.mapId,
            request.regionId & 0xFF,
            request.baitId,
            request.isDayTime,
            request.randomSeed
        );

        // Calculate number of rolls
        uint256 numRolls = 1;
        if (effectiveCritRate > 0) {
            uint256 critRoll = uint256(
                keccak256(abi.encode(request.randomSeed, "crit"))
            ) % BASIS_POINTS;
            if (critRoll < effectiveCritRate) {
                numRolls = 2 + effectiveCritMultiplierBonus;
            }
        }

        // Roll for best fish
        uint256 bestFishId = fishId;
        for (uint256 i = 1; i < numRolls; i++) {
            uint256 rolledFishId = _selectFish(
                request.mapId,
                request.regionId & 0xFF,
                request.baitId,
                request.isDayTime,
                uint256(keccak256(abi.encode(request.randomSeed, "roll", i)))
            );

            if (rolledFishId > bestFishId) {
                bestFishId = rolledFishId;
            }
        }

        return bestFishId;
    }

    function _finalizeCatch(
        FishingRequest storage request,
        uint256 fishId,
        uint256 weight,
        uint256 regionType,
        uint256 effectiveMaxFishWeight,
        bool consumeBait,
        bool isOffchain
    ) internal {
        // Process catch with rod
        IRisingTidesFishingRod.FishModifiers memory modifiers = fishingRod
            .processCatch(
                request.rodTokenId,
                weight,
                regionType,
                request.randomSeed
            );

        // Calculate cooldown
        uint256 cooldownDuration = _calculateCooldown(
            fishId,
            request.randomSeed
        );
        uint256 cooldownUntil = block.timestamp + cooldownDuration;
        playerCooldowns[request.player] = cooldownUntil;

        // Add fish to inventory
        try
            inventory.addFish(
                request.player,
                fishId,
                weight,
                modifiers.isTrophyQuality,
                modifiers.freshnessModifier
            )
        {
            // Handle double catch
            if (modifiers.doubleCatch) {
                _tryAddSecondFish(
                    request,
                    fishId,
                    effectiveMaxFishWeight,
                    modifiers
                );
            }

            emit FishingCompleted(
                request.player,
                request.requestId,
                true,
                fishId,
                weight,
                modifiers.isTrophyQuality,
                modifiers.freshnessModifier,
                cooldownUntil,
                consumeBait,
                modifiers.actualDurabilityLoss,
                modifiers.actualDurabilityLoss == 0,
                isOffchain
            );
        } catch {
            revert InventoryFull();
        }
    }

    function _tryAddSecondFish(
        FishingRequest storage request,
        uint256 fishId,
        uint256 effectiveMaxFishWeight,
        IRisingTidesFishingRod.FishModifiers memory modifiers
    ) internal {
        uint256 secondWeight = _calculateFishWeight(
            fishId,
            uint256(keccak256(abi.encode(request.randomSeed, "double"))),
            effectiveMaxFishWeight
        );

        try
            inventory.addFish(
                request.player,
                fishId,
                secondWeight,
                modifiers.isTrophyQuality,
                modifiers.freshnessModifier
            )
        {} catch {
            // Inventory full for second fish, ignore
        }
    }

    function _selectFish(
        uint256 mapId,
        uint256 regionType,
        uint256 baitId,
        bool _isDayTime,
        uint256 randomSeed
    ) internal view returns (uint256) {
        // Try specific table first
        bytes32 key = keccak256(
            abi.encodePacked(mapId, regionType, baitId, _isDayTime)
        );
        AliasTable storage table = fishingTables[key];

        // Fallback to default bait table
        if (!table.exists && baitId != 0) {
            table = defaultBaitTables[baitId];
        }

        // Fallback to global default
        if (!table.exists) {
            table = globalDefaultTable;
        }

        // No table available
        if (!table.exists || table.fishIds.length == 0) {
            return 0;
        }

        // Alias method sampling
        uint256 n = table.fishIds.length;
        uint256 index = randomSeed % n;
        uint256 prob = (randomSeed >> 128) % table.totalProbability;

        if (prob < table.probabilities[index]) {
            return table.fishIds[index];
        } else {
            return table.fishIds[table.aliases[index]];
        }
    }

    function _calculateFishWeight(
        uint256 fishId,
        uint256 randomSeed,
        uint256 maxWeightBonus
    ) internal view returns (uint256) {
        FishSpecies memory species = fishSpecies[fishId];

        // Apply max weight bonus from rod
        uint256 effectiveMaxWeight = species.maxWeight;
        if (maxWeightBonus > 0) {
            effectiveMaxWeight =
                (species.maxWeight * (100 + maxWeightBonus)) /
                100;
        }

        // Random weight between min and effective max
        uint256 range = effectiveMaxWeight - species.minWeight;
        uint256 randomWeight = (randomSeed % range) + species.minWeight;

        return randomWeight;
    }

    function _calculateCooldown(
        uint256 fishId,
        uint256 randomSeed
    ) internal view returns (uint256) {
        FishSpecies memory species = fishSpecies[fishId];

        // Random cooldown between min and max
        uint256 range = species.maxCooldown - species.minCooldown;
        uint256 randomCooldown = (randomSeed % range) + species.minCooldown;

        return randomCooldown;
    }

    function _discardFish(address player, uint256[] calldata indices) internal {
        // Validate indices are in descending order to avoid index shifting issues
        for (uint256 i = 0; i < indices.length - 1; i++) {
            if (indices[i] <= indices[i + 1]) revert InvalidDiscardIndices();
        }

        // Remove fish from inventory
        for (uint256 i = 0; i < indices.length; i++) {
            inventory.removeFish(player, indices[i]);
        }

        emit FishDiscarded(player, indices);
    }

    function _validateAndSetAliasTable(
        bytes32 key,
        uint256[] calldata probabilities,
        uint256[] calldata aliases,
        uint256[] calldata fishIds
    ) internal {
        uint256 n = fishIds.length;
        if (n == 0 || n != probabilities.length || n != aliases.length) {
            revert InvalidAliasTable();
        }

        // Validate aliases are within bounds
        for (uint256 i = 0; i < n; i++) {
            if (aliases[i] >= n) revert InvalidAliasTable();
        }

        uint256 total = _sumArray(probabilities);
        if (total == 0) revert InvalidAliasTable();

        if (key != bytes32(0)) {
            fishingTables[key] = AliasTable({
                probabilities: probabilities,
                aliases: aliases,
                fishIds: fishIds,
                totalProbability: total,
                exists: true
            });
        }
    }

    function _sumArray(
        uint256[] calldata arr
    ) internal pure returns (uint256 sum) {
        for (uint256 i = 0; i < arr.length; i++) {
            sum += arr[i];
        }
    }
}
