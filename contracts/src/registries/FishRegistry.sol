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
        uint256 id;
        uint256 basePrice; // Base market price
        uint8 shapeWidth; // Item shape width
        uint8 shapeHeight; // Item shape height
        bytes shapeData; // Packed bitmap of item shape
    }

    struct BaitType {
        uint256 id;
        string name;
        uint256 price;
        bool isActive;
    }

    mapping(uint256 => FishSpecies) private fishSpecies;
    mapping(uint256 => BaitType) private baitTypes;
    uint256 private speciesCount;
    uint256 private baitTypeCount;
    uint256[] private speciesIds;
    uint256[] private baitIds;

    // Events
    event FishSpeciesRegistered(uint256 indexed speciesId, uint256 basePrice);
    event BaitTypeRegistered(uint256 indexed baitId, string name, uint256 price);
    event FishSpeciesUpdated(uint256 indexed speciesId, uint256 newBasePrice);
    event BaitTypeUpdated(uint256 indexed baitId, uint256 newPrice, bool isActive);

    modifier validSpeciesId(uint256 speciesId) {
        require(isValidSpecies(speciesId), "Invalid species ID");
        _;
    }

    modifier validBaitId(uint256 baitId) {
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
        uint256 id,
        uint256 basePrice,
        uint8 shapeWidth,
        uint8 shapeHeight,
        bytes calldata shapeData
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        require(id > 0, "Species ID must be greater than 0");
        require(!isValidSpecies(id), "Species ID already exists");
        require(basePrice > 0, "Base price must be greater than 0");
        require(shapeWidth > 0 && shapeHeight > 0, "Shape dimensions must be greater than 0");

        // Validate shape data size
        uint256 expectedShapeSize = (uint256(shapeWidth) * uint256(shapeHeight) + 7) / 8;
        require(shapeData.length >= expectedShapeSize, "Shape data too small");

        fishSpecies[id] = FishSpecies({
            id: id,
            basePrice: basePrice,
            shapeWidth: shapeWidth,
            shapeHeight: shapeHeight,
            shapeData: shapeData
        });

        speciesIds.push(id);
        speciesCount++;

        emit FishSpeciesRegistered(id, basePrice);
    }

    /**
     * @dev Register a new bait type
     */
    function registerBaitType(uint256 id, string calldata name, uint256 price)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        require(id > 0, "Bait ID must be greater than 0");
        require(!isValidBait(id), "Bait ID already exists");
        require(bytes(name).length > 0, "Bait name cannot be empty");
        require(price > 0, "Bait price must be greater than 0");

        baitTypes[id] = BaitType({id: id, name: name, price: price, isActive: true});

        baitIds.push(id);
        baitTypeCount++;

        emit BaitTypeRegistered(id, name, price);
    }

    /**
     * @dev Get fish species data
     */
    function getFishSpecies(uint256 speciesId) external view validSpeciesId(speciesId) returns (FishSpecies memory) {
        return fishSpecies[speciesId];
    }

    /**
     * @dev Get bait type data
     */
    function getBaitType(uint256 baitId) external view validBaitId(baitId) returns (BaitType memory) {
        return baitTypes[baitId];
    }

    /**
     * @dev Check if a species ID is valid
     */
    function isValidSpecies(uint256 speciesId) public view returns (bool) {
        return fishSpecies[speciesId].id == speciesId && fishSpecies[speciesId].id > 0;
    }

    /**
     * @dev Check if a bait ID is valid
     */
    function isValidBait(uint256 baitId) public view returns (bool) {
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
     * @dev Update fish species base price
     */
    function updateFishPrice(uint256 speciesId, uint256 newBasePrice)
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
    function updateBaitType(uint256 baitId, uint256 newPrice, bool isActive)
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
    function getSpeciesCount() external view returns (uint256) {
        return speciesCount;
    }

    /**
     * @dev Get bait type count
     */
    function getBaitTypeCount() external view returns (uint256) {
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
