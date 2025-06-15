// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title FishRegistry
 * @dev Registry contract for managing fish species and their properties
 * Defines fish species, their base values, and catch mechanics
 */
contract FishRegistry is AccessControl, Pausable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    struct FishSpecies {
        uint8 id;
        string name;
        uint256 basePrice; // Base market price
        uint8 rarity; // 1-10 scale (1 = common, 10 = legendary)
        uint16 minWeight; // Minimum weight in grams
        uint16 maxWeight; // Maximum weight in grams
        uint8 shapeWidth; // Item shape width
        uint8 shapeHeight; // Item shape height
        bytes shapeData; // Packed bitmap of item shape
        uint256 freshnessDecayRate; // How fast freshness decreases (per hour)
        uint8[] compatibleBaits; // Bait types that can catch this fish
        uint16[] catchProbabilities; // Catch probability per bait type (out of 10000)
    }

    struct BaitType {
        uint8 id;
        string name;
        uint256 price;
        bool isActive;
    }

    mapping(uint8 => FishSpecies) private fishSpecies;
    mapping(uint8 => BaitType) private baitTypes;
    uint8 private speciesCount;
    uint8 private baitTypeCount;
    uint8[] private speciesIds;
    uint8[] private baitIds;

    // Freshness decay constants
    uint256 public constant FRESHNESS_DECAY_PERIOD = 1 hours;
    uint256 public constant MAX_FRESHNESS = 100;

    // Events
    event FishSpeciesRegistered(uint8 indexed speciesId, string name, uint256 basePrice);
    event BaitTypeRegistered(uint8 indexed baitId, string name, uint256 price);
    event FishSpeciesUpdated(uint8 indexed speciesId, uint256 newBasePrice);
    event BaitTypeUpdated(uint8 indexed baitId, uint256 newPrice, bool isActive);

    modifier validSpeciesId(uint8 speciesId) {
        require(isValidSpecies(speciesId), "Invalid species ID");
        _;
    }

    modifier validBaitId(uint8 baitId) {
        require(isValidBait(baitId), "Invalid bait ID");
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @dev Register a new fish species
     */
    function registerFishSpecies(
        uint8 id,
        string calldata name,
        uint256 basePrice,
        uint8 rarity,
        uint16 minWeight,
        uint16 maxWeight,
        uint8 shapeWidth,
        uint8 shapeHeight,
        bytes calldata shapeData,
        uint256 freshnessDecayRate,
        uint8[] calldata compatibleBaits,
        uint16[] calldata catchProbabilities
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        require(id > 0, "Species ID must be greater than 0");
        require(!isValidSpecies(id), "Species ID already exists");
        require(bytes(name).length > 0, "Species name cannot be empty");
        require(basePrice > 0, "Base price must be greater than 0");
        require(rarity >= 1 && rarity <= 10, "Rarity must be between 1 and 10");
        require(minWeight > 0 && maxWeight >= minWeight, "Invalid weight range");
        require(shapeWidth > 0 && shapeHeight > 0, "Shape dimensions must be greater than 0");
        require(compatibleBaits.length == catchProbabilities.length, "Bait and probability arrays must match");

        // Validate shape data size
        uint256 expectedShapeSize = (uint256(shapeWidth) * uint256(shapeHeight) + 7) / 8;
        require(shapeData.length >= expectedShapeSize, "Shape data too small");

        fishSpecies[id] = FishSpecies({
            id: id,
            name: name,
            basePrice: basePrice,
            rarity: rarity,
            minWeight: minWeight,
            maxWeight: maxWeight,
            shapeWidth: shapeWidth,
            shapeHeight: shapeHeight,
            shapeData: shapeData,
            freshnessDecayRate: freshnessDecayRate,
            compatibleBaits: compatibleBaits,
            catchProbabilities: catchProbabilities
        });

        speciesIds.push(id);
        speciesCount++;

        emit FishSpeciesRegistered(id, name, basePrice);
    }

    /**
     * @dev Register a new bait type
     */
    function registerBaitType(
        uint8 id,
        string calldata name,
        uint256 price
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        require(id > 0, "Bait ID must be greater than 0");
        require(!isValidBait(id), "Bait ID already exists");
        require(bytes(name).length > 0, "Bait name cannot be empty");
        require(price > 0, "Bait price must be greater than 0");

        baitTypes[id] = BaitType({
            id: id,
            name: name,
            price: price,
            isActive: true
        });

        baitIds.push(id);
        baitTypeCount++;

        emit BaitTypeRegistered(id, name, price);
    }

    /**
     * @dev Get fish species data
     */
    function getFishSpecies(uint8 speciesId) external view validSpeciesId(speciesId) returns (FishSpecies memory) {
        return fishSpecies[speciesId];
    }

    /**
     * @dev Get bait type data
     */
    function getBaitType(uint8 baitId) external view validBaitId(baitId) returns (BaitType memory) {
        return baitTypes[baitId];
    }

    /**
     * @dev Check if a species ID is valid
     */
    function isValidSpecies(uint8 speciesId) public view returns (bool) {
        return fishSpecies[speciesId].id == speciesId && fishSpecies[speciesId].id > 0;
    }

    /**
     * @dev Check if a bait ID is valid
     */
    function isValidBait(uint8 baitId) public view returns (bool) {
        return baitTypes[baitId].id == baitId && baitTypes[baitId].id > 0;
    }

    /**
     * @dev Get all fish species
     */
    function getAllSpecies() external view returns (FishSpecies[] memory) {
        FishSpecies[] memory allSpecies = new FishSpecies[](speciesCount);
        
        for (uint256 i = 0; i < speciesIds.length; i++) {
            allSpecies[i] = fishSpecies[speciesIds[i]];
        }
        
        return allSpecies;
    }

    /**
     * @dev Get all bait types
     */
    function getAllBaitTypes() external view returns (BaitType[] memory) {
        BaitType[] memory allBaits = new BaitType[](baitTypeCount);
        
        for (uint256 i = 0; i < baitIds.length; i++) {
            allBaits[i] = baitTypes[baitIds[i]];
        }
        
        return allBaits;
    }

    /**
     * @dev Calculate catch probability for a bait-species combination
     */
    function getCatchProbability(uint8 speciesId, uint8 baitId) 
        external 
        view 
        validSpeciesId(speciesId) 
        validBaitId(baitId) 
        returns (uint16) 
    {
        FishSpecies memory species = fishSpecies[speciesId];
        
        for (uint256 i = 0; i < species.compatibleBaits.length; i++) {
            if (species.compatibleBaits[i] == baitId) {
                return species.catchProbabilities[i];
            }
        }
        
        return 0; // Bait not compatible with species
    }

    /**
     * @dev Get random weight for a fish species
     */
    function getRandomWeight(uint8 speciesId, uint256 seed) 
        external 
        view 
        validSpeciesId(speciesId) 
        returns (uint16) 
    {
        FishSpecies memory species = fishSpecies[speciesId];
        
        if (species.minWeight == species.maxWeight) {
            return species.minWeight;
        }
        
        uint256 range = uint256(species.maxWeight - species.minWeight);
        uint256 randomValue = uint256(keccak256(abi.encodePacked(seed, speciesId, block.timestamp))) % range;
        
        return species.minWeight + uint16(randomValue);
    }

    /**
     * @dev Calculate freshness based on time elapsed
     */
    function calculateFreshness(uint8 speciesId, uint256 caughtAt) 
        external 
        view 
        validSpeciesId(speciesId) 
        returns (uint8) 
    {
        if (caughtAt > block.timestamp) {
            return uint8(MAX_FRESHNESS);
        }

        FishSpecies memory species = fishSpecies[speciesId];
        uint256 timeElapsed = block.timestamp - caughtAt;
        uint256 hoursElapsed = timeElapsed / FRESHNESS_DECAY_PERIOD;
        
        uint256 freshnessLoss = hoursElapsed * species.freshnessDecayRate;
        
        if (freshnessLoss >= MAX_FRESHNESS) {
            return 0;
        }
        
        return uint8(MAX_FRESHNESS - freshnessLoss);
    }

    /**
     * @dev Update fish species base price
     */
    function updateFishPrice(uint8 speciesId, uint256 newBasePrice) 
        external 
        onlyRole(ADMIN_ROLE) 
        validSpeciesId(speciesId) 
        whenNotPaused 
    {
        require(newBasePrice > 0, "Base price must be greater than 0");
        
        fishSpecies[speciesId].basePrice = newBasePrice;
        emit FishSpeciesUpdated(speciesId, newBasePrice);
    }

    /**
     * @dev Update bait type price and status
     */
    function updateBaitType(uint8 baitId, uint256 newPrice, bool isActive) 
        external 
        onlyRole(ADMIN_ROLE) 
        validBaitId(baitId) 
        whenNotPaused 
    {
        require(newPrice > 0, "Bait price must be greater than 0");
        
        baitTypes[baitId].price = newPrice;
        baitTypes[baitId].isActive = isActive;
        
        emit BaitTypeUpdated(baitId, newPrice, isActive);
    }

    /**
     * @dev Get species count
     */
    function getSpeciesCount() external view returns (uint8) {
        return speciesCount;
    }

    /**
     * @dev Get bait type count
     */
    function getBaitTypeCount() external view returns (uint8) {
        return baitTypeCount;
    }

    /**
     * @dev Pause the contract
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}