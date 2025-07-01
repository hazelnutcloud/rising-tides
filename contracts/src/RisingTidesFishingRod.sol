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

import {ERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Pausable} from "../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {IRisingTidesFishingRod} from "./interfaces/IRisingTidesFishingRod.sol";

contract RisingTidesFishingRod is
    IRisingTidesFishingRod,
    ERC721,
    AccessControl,
    Pausable
{
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 private constant GAME_MASTER_ROLE = keccak256("GAME_MASTER_ROLE");

    uint256 private constant PERCENT = 100;
    uint256 private constant BASIS_POINTS = 10000;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => RodType) private _rodTypes;
    mapping(uint256 => RodInstance) private _rodInstances;

    mapping(uint256 => Bonus) private _enchantmentBonuses;
    mapping(uint256 => string) private _enchantmentNames;
    uint256 private _nextEnchantmentId;

    mapping(uint256 => Bonus) private _titleBonuses;
    uint256[] private _titleThresholds;
    string[] private _titleNames;

    uint256 private _nextTokenId;
    string private _baseTokenURI;
    
    uint256 public baseEnchantmentChance; // Basis points (10000 = 100%)
    mapping(uint256 => uint256) public enchantmentWeights; // enchantmentId => weight

    address public risingTidesPort;
    address public risingTidesFishing;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event RodTypeAdded(
        uint256 indexed rodId,
        uint256 minDurability,
        uint256 maxDurability
    );

    event EnchantmentAdded(uint256 indexed enchantmentId, string name);
    
    event EnchantmentWeightUpdated(
        uint256 indexed enchantmentId,
        uint256 weight
    );
    
    event BaseEnchantmentChanceUpdated(uint256 chance);

    event TitleSystemUpdated(uint256 titleCount);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidDurabilityRange();
    error InvalidAttributeRange();
    error RodTypeAlreadyExists();
    error InvalidEnchantmentId();
    error InvalidTitleIndex();
    error InvalidEnchantmentChance();

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyPort() {
        if (msg.sender != risingTidesPort) revert OnlyPort();
        _;
    }

    modifier onlyFishing() {
        if (msg.sender != risingTidesFishing) revert OnlyFishing();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _admin,
        address _gameMaster,
        string memory __baseURI
    ) ERC721("Rising Tides Fishing Rod", "RTFR") {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(GAME_MASTER_ROLE, _gameMaster);

        _baseTokenURI = __baseURI;
        _nextTokenId = 1;
    }

    /*//////////////////////////////////////////////////////////////
                                MINTING
    //////////////////////////////////////////////////////////////*/

    function mint(
        address to,
        uint256 rodId,
        uint256 randomSeed
    ) external onlyPort whenNotPaused returns (uint256 tokenId) {
        RodType memory rodType = _rodTypes[rodId];
        if (!rodType.exists) revert InvalidRodType();

        tokenId = _nextTokenId++;

        // Generate random attributes within rod type ranges
        RodInstance storage rod = _rodInstances[tokenId];
        rod.rodId = rodId;

        // Use different parts of the random seed for each attribute
        rod.maxDurability = _randomInRange(
            rodType.minDurability,
            rodType.maxDurability,
            randomSeed
        );
        rod.currentDurability = rod.maxDurability;

        rod.maxFishWeight = _randomInRange(
            rodType.minMaxFishWeight,
            rodType.maxMaxFishWeight,
            randomSeed >> 32
        );

        rod.critRate = _randomInRange(
            rodType.minCritRate,
            rodType.maxCritRate,
            randomSeed >> 64
        );

        rod.strength = _randomInRange(
            rodType.minStrength,
            rodType.maxStrength,
            randomSeed >> 96
        );

        rod.efficiency = _randomInRange(
            rodType.minEfficiency,
            rodType.maxEfficiency,
            randomSeed >> 128
        );

        rod.totalCatches = 0;

        // Apply enchantments based on random seed
        rod.enchantmentMask = _generateEnchantments(randomSeed >> 160);

        _safeMint(to, tokenId);

        emit RodMinted(tokenId, to, rodId, rod.enchantmentMask);
    }

    /*//////////////////////////////////////////////////////////////
                            FISHING INTEGRATION
    //////////////////////////////////////////////////////////////*/

    function getAttributes(
        uint256 tokenId,
        uint256 regionType
    )
        external
        view
        returns (
            uint256 effectiveMaxFishWeight,
            uint256 effectiveCritRate,
            uint256 effectiveEfficiency,
            uint256 compatibleBaitMask,
            bool isUsable
        )
    {
        if (_ownerOf(tokenId) == address(0)) revert InvalidTokenId();

        RodInstance memory rod = _rodInstances[tokenId];
        RodType memory rodType = _rodTypes[rod.rodId];

        isUsable = rod.currentDurability > 0;

        Bonus memory totalBonus = _calculateTotalBonus(rod, regionType);

        effectiveMaxFishWeight =
            rod.maxFishWeight +
            ((rod.maxFishWeight * totalBonus.maxWeightBonus) / PERCENT);
        effectiveCritRate = rod.critRate + totalBonus.critRateBonus;
        effectiveEfficiency = rod.efficiency + totalBonus.efficiencyBonus;

        compatibleBaitMask = rodType.compatibleBaitMask;
    }

    function processCatch(
        uint256 tokenId,
        uint256 fishWeight,
        uint256 regionType,
        uint256 randomSeed
    ) external onlyFishing returns (FishModifiers memory modifiers) {
        if (_ownerOf(tokenId) == address(0)) revert InvalidTokenId();

        RodInstance storage rod = _rodInstances[tokenId];
        if (rod.currentDurability == 0) revert RodNotUsable();

        Bonus memory totalBonus = _calculateTotalBonus(rod, regionType);

        // Check for perfect catch (5% chance at title 18+)
        bool perfectCatch = false;
        if (totalBonus.hasPerfectCatch) {
            perfectCatch = (randomSeed % 100) < 5;
        }

        // Calculate durability loss
        if (!perfectCatch) {
            uint256 effectiveStrength = rod.strength +
                ((rod.strength * totalBonus.strengthBonus) / PERCENT);
            uint256 durabilityLoss = (fishWeight * PERCENT) /
                (PERCENT + effectiveStrength);

            if (durabilityLoss >= rod.currentDurability) {
                rod.currentDurability = 0;
            } else {
                rod.currentDurability -= durabilityLoss;
            }

            modifiers.actualDurabilityLoss = durabilityLoss;
        }

        // Check trophy quality (10% chance at title 19+)
        if (totalBonus.hasTrophyQuality) {
            modifiers.isTrophyQuality = ((randomSeed >> 8) % 100) < 10;
        }

        // Check double catch (20% chance with Lucky enchantment)
        if (totalBonus.hasDoubleCatch) {
            modifiers.doubleCatch = ((randomSeed >> 16) % 100) < 20;
        }

        // Set freshness modifier
        modifiers.freshnessModifier = totalBonus.freshnessModifier;

        // Increment catches
        rod.totalCatches++;

        emit CatchProcessed(
            tokenId,
            modifiers.actualDurabilityLoss,
            rod.totalCatches,
            perfectCatch
        );
    }

    /*//////////////////////////////////////////////////////////////
                                REPAIRS
    //////////////////////////////////////////////////////////////*/

    function repair(
        uint256 tokenId,
        uint256 durabilityToAdd
    ) external onlyPort {
        if (_ownerOf(tokenId) == address(0)) revert InvalidTokenId();

        RodInstance storage rod = _rodInstances[tokenId];

        uint256 newDurability = rod.currentDurability + durabilityToAdd;
        if (newDurability > rod.maxDurability) {
            newDurability = rod.maxDurability;
        }

        rod.currentDurability = newDurability;

        emit RodRepaired(tokenId, durabilityToAdd, newDurability);
    }

    /*//////////////////////////////////////////////////////////////
                            TITLE SYSTEM
    //////////////////////////////////////////////////////////////*/

    function getCurrentTitleIndex(
        uint256 totalCatches
    ) public view returns (uint256) {
        uint256 left = 0;
        uint256 right = _titleThresholds.length - 1;
        uint256 result = 0;

        while (left <= right) {
            uint256 mid = (left + right) / 2;
            if (_titleThresholds[mid] <= totalCatches) {
                result = mid;
                left = mid + 1;
            } else {
                if (mid > 0) {
                    right = mid - 1;
                } else {
                    break;
                }
            }
        }

        return result;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _calculateTotalBonus(
        RodInstance memory rod,
        uint256 regionType
    ) private view returns (Bonus memory totalBonus) {
        // Start with title bonus
        uint256 titleIndex = getCurrentTitleIndex(rod.totalCatches);
        if (titleIndex < _titleThresholds.length) {
            totalBonus = _titleBonuses[titleIndex];
        }

        // Add enchantment bonuses that apply to this region
        uint256 enchantmentMask = rod.enchantmentMask;
        for (uint256 i = 0; i < _nextEnchantmentId; i++) {
            if ((enchantmentMask & (uint256(1) << i)) != 0) {
                Bonus memory enchBonus = _enchantmentBonuses[i];
                // Check if enchantment applies to current region
                if ((enchBonus.regionMask & (uint256(1) << regionType)) != 0) {
                    // Combine bonuses
                    totalBonus.durabilityBonus += enchBonus.durabilityBonus;
                    totalBonus.efficiencyBonus += enchBonus.efficiencyBonus;
                    totalBonus.critRateBonus += enchBonus.critRateBonus;
                    totalBonus.maxWeightBonus += enchBonus.maxWeightBonus;
                    totalBonus.strengthBonus += enchBonus.strengthBonus;

                    // For modifiers, take the maximum
                    if (
                        enchBonus.freshnessModifier >
                        totalBonus.freshnessModifier
                    ) {
                        totalBonus.freshnessModifier = enchBonus
                            .freshnessModifier;
                    }

                    // OR the boolean flags
                    totalBonus.hasPerfectCatch =
                        totalBonus.hasPerfectCatch ||
                        enchBonus.hasPerfectCatch;
                    totalBonus.hasTrophyQuality =
                        totalBonus.hasTrophyQuality ||
                        enchBonus.hasTrophyQuality;
                    totalBonus.hasDoubleCatch =
                        totalBonus.hasDoubleCatch ||
                        enchBonus.hasDoubleCatch;
                }
            }
        }

        // Ensure freshness modifier has a default value
        if (totalBonus.freshnessModifier == 0) {
            totalBonus.freshnessModifier = 100; // Default: no modification
        }

        return totalBonus;
    }

    function _randomInRange(
        uint256 min,
        uint256 max,
        uint256 seed
    ) private pure returns (uint256) {
        if (min >= max) return min;
        return min + (seed % (max - min + 1));
    }

    function _generateEnchantments(
        uint256 seed
    ) private view returns (uint256 mask) {
        // Check if rod gets any enchantments based on base chance
        if (baseEnchantmentChance == 0 || (seed % BASIS_POINTS) >= baseEnchantmentChance) {
            return 0;
        }
        
        // Calculate total weight of all enchantments
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < _nextEnchantmentId; i++) {
            totalWeight += enchantmentWeights[i];
        }
        
        if (totalWeight == 0) {
            return 0;
        }
        
        // Select an enchantment based on weighted random
        uint256 randomValue = (seed >> 32) % totalWeight;
        uint256 cumulativeWeight = 0;
        
        for (uint256 i = 0; i < _nextEnchantmentId; i++) {
            cumulativeWeight += enchantmentWeights[i];
            if (randomValue < cumulativeWeight) {
                // Set the bit for this enchantment
                mask = uint256(1) << i;
                break;
            }
        }
        
        // Small chance for a second enchantment (1% if first enchantment succeeded)
        if ((seed >> 64) % 100 < 1) {
            uint256 secondRandom = (seed >> 96) % totalWeight;
            cumulativeWeight = 0;
            
            for (uint256 i = 0; i < _nextEnchantmentId; i++) {
                cumulativeWeight += enchantmentWeights[i];
                if (secondRandom < cumulativeWeight && (mask & (uint256(1) << i)) == 0) {
                    // Add second enchantment if it's different from the first
                    mask |= uint256(1) << i;
                    break;
                }
            }
        }
        
        return mask;
    }

    /*//////////////////////////////////////////////////////////////
                            GAME MASTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addRodType(
        uint256 rodId,
        RodType memory rodType
    ) external onlyRole(GAME_MASTER_ROLE) {
        if (_rodTypes[rodId].exists) revert RodTypeAlreadyExists();
        if (rodType.minDurability > rodType.maxDurability)
            revert InvalidDurabilityRange();
        if (rodType.minMaxFishWeight > rodType.maxMaxFishWeight)
            revert InvalidAttributeRange();
        if (rodType.minCritRate > rodType.maxCritRate)
            revert InvalidAttributeRange();
        if (rodType.minStrength > rodType.maxStrength)
            revert InvalidAttributeRange();
        if (rodType.minEfficiency > rodType.maxEfficiency)
            revert InvalidAttributeRange();

        rodType.exists = true;
        _rodTypes[rodId] = rodType;

        emit RodTypeAdded(rodId, rodType.minDurability, rodType.maxDurability);
    }

    function updateRodType(
        uint256 rodId,
        RodType memory rodType
    ) external onlyRole(GAME_MASTER_ROLE) {
        if (!_rodTypes[rodId].exists) revert InvalidRodType();
        if (rodType.minDurability > rodType.maxDurability)
            revert InvalidDurabilityRange();
        if (rodType.minMaxFishWeight > rodType.maxMaxFishWeight)
            revert InvalidAttributeRange();
        if (rodType.minCritRate > rodType.maxCritRate)
            revert InvalidAttributeRange();
        if (rodType.minStrength > rodType.maxStrength)
            revert InvalidAttributeRange();
        if (rodType.minEfficiency > rodType.maxEfficiency)
            revert InvalidAttributeRange();

        rodType.exists = true;
        _rodTypes[rodId] = rodType;
    }

    function addEnchantment(
        string memory name,
        Bonus memory bonus,
        uint256 weight
    ) external onlyRole(GAME_MASTER_ROLE) returns (uint256 enchantmentId) {
        enchantmentId = _nextEnchantmentId++;
        _enchantmentNames[enchantmentId] = name;
        _enchantmentBonuses[enchantmentId] = bonus;
        enchantmentWeights[enchantmentId] = weight;
        
        emit EnchantmentAdded(enchantmentId, name);
        emit EnchantmentWeightUpdated(enchantmentId, weight);
    }

    function updateEnchantment(
        uint256 enchantmentId,
        Bonus memory bonus
    ) external onlyRole(GAME_MASTER_ROLE) {
        if (enchantmentId >= _nextEnchantmentId) revert InvalidEnchantmentId();
        _enchantmentBonuses[enchantmentId] = bonus;
    }

    function setEnchantmentWeight(
        uint256 enchantmentId,
        uint256 weight
    ) external onlyRole(GAME_MASTER_ROLE) {
        if (enchantmentId >= _nextEnchantmentId) revert InvalidEnchantmentId();
        enchantmentWeights[enchantmentId] = weight;
        emit EnchantmentWeightUpdated(enchantmentId, weight);
    }

    function setBaseEnchantmentChance(
        uint256 chance
    ) external onlyRole(GAME_MASTER_ROLE) {
        if (chance > BASIS_POINTS) revert InvalidEnchantmentChance();
        baseEnchantmentChance = chance;
        emit BaseEnchantmentChanceUpdated(chance);
    }

    function initializeTitles() external onlyRole(GAME_MASTER_ROLE) {
        // Set thresholds
        _titleThresholds = [
            0,
            10,
            25,
            45,
            70,
            100,
            135,
            175,
            230,
            300,
            375,
            460,
            560,
            675,
            850,
            1000,
            1500,
            2500,
            5000,
            8500
        ];

        // Set names
        _titleNames = [
            "Strange",
            "Unremarkable",
            "Barely Wet",
            "Mildly Effective",
            "Somewhat Reliable",
            "Uncharitable",
            "Notably Capable",
            "Sufficiently Proven",
            "Truly Feared",
            "Spectacularly Efficient",
            "Scale-Covered",
            "Wicked Nasty",
            "Positively Merciless",
            "Totally Ordinary",
            "Reef-Clearing",
            "Rage-Inducing",
            "Server-Clearing",
            "Australian",
            "Poseidon's Own",
            "Absolutely Seaworthy"
        ];

        // Initialize all title bonuses to default
        for (uint256 i = 0; i < _titleThresholds.length; i++) {
            _titleBonuses[i] = Bonus({
                durabilityBonus: 0,
                efficiencyBonus: 0,
                critRateBonus: 0,
                maxWeightBonus: 0,
                strengthBonus: 0,
                freshnessModifier: 100,
                hasPerfectCatch: false,
                hasTrophyQuality: false,
                hasDoubleCatch: false,
                regionMask: type(uint256).max
            });
        }

        // Set specific title bonuses
        // Title 5: Uncharitable (100 catches) - +5% durability
        _titleBonuses[5].durabilityBonus = 5;

        // Title 9: Spectacularly Efficient (300 catches) - +10% efficiency
        _titleBonuses[9].efficiencyBonus = 10;

        // Title 13: Totally Ordinary (675 catches) - +5% crit rate
        _titleBonuses[13].critRateBonus = 500; // 5% in basis points

        // Title 16: Server-Clearing (1500 catches) - +10% max fish weight
        _titleBonuses[16].maxWeightBonus = 10;

        // Title 18: Poseidon's Own (5000 catches) - Perfect Catch
        _titleBonuses[18].hasPerfectCatch = true;

        // Title 19: Absolutely Seaworthy (8500 catches) - Trophy Quality
        _titleBonuses[19].hasTrophyQuality = true;

        emit TitleSystemUpdated(_titleThresholds.length);
    }

    function updateTitleBonus(
        uint256 titleIndex,
        Bonus memory bonus
    ) external onlyRole(GAME_MASTER_ROLE) {
        if (titleIndex >= _titleThresholds.length) revert InvalidTitleIndex();
        _titleBonuses[titleIndex] = bonus;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setContracts(
        address _port,
        address _fishing
    ) external onlyRole(ADMIN_ROLE) {
        risingTidesPort = _port;
        risingTidesFishing = _fishing;
    }

    function setBaseURI(string memory baseURI) external onlyRole(ADMIN_ROLE) {
        _baseTokenURI = baseURI;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getRodInfo(
        uint256 tokenId
    )
        external
        view
        returns (
            RodInstance memory rod,
            string memory currentTitle,
            uint256 titleIndex
        )
    {
        if (_ownerOf(tokenId) == address(0)) revert InvalidTokenId();

        rod = _rodInstances[tokenId];
        titleIndex = getCurrentTitleIndex(rod.totalCatches);

        if (titleIndex < _titleNames.length) {
            currentTitle = _titleNames[titleIndex];
        }
    }

    function getEnchantmentInfo(
        uint256 enchantmentId
    ) external view returns (string memory name, Bonus memory bonus) {
        if (enchantmentId >= _nextEnchantmentId) revert InvalidEnchantmentId();
        name = _enchantmentNames[enchantmentId];
        bonus = _enchantmentBonuses[enchantmentId];
    }

    function getTitleInfo(
        uint256 titleIndex
    )
        external
        view
        returns (string memory name, uint256 threshold, Bonus memory bonus)
    {
        if (titleIndex >= _titleThresholds.length) revert InvalidTitleIndex();
        name = _titleNames[titleIndex];
        threshold = _titleThresholds[titleIndex];
        bonus = _titleBonuses[titleIndex];
    }

    /*//////////////////////////////////////////////////////////////
                            METADATA
    //////////////////////////////////////////////////////////////*/

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721) returns (string memory) {
        _requireOwned(tokenId);

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, _toString(tokenId)))
                : "";
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /*//////////////////////////////////////////////////////////////
                            OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            ROLE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function grantAdminRole(
        address _admin
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, _admin);
    }

    function grantGameMasterRole(
        address _gameMaster
    ) external onlyRole(ADMIN_ROLE) {
        grantRole(GAME_MASTER_ROLE, _gameMaster);
    }

    function revokeGameMasterRole(
        address _gameMaster
    ) external onlyRole(ADMIN_ROLE) {
        revokeRole(GAME_MASTER_ROLE, _gameMaster);
    }
}
