// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IFishingRodRegistry.sol";

contract FishingRodRegistry is IFishingRodRegistry, Ownable {
    mapping(uint256 => FishingRod) private fishingRods;
    uint256[] private fishingRodIds;

    event FishingRodRegistered(uint256 indexed id, string name);
    event FishingRodUpdated(uint256 indexed id, uint256 purchasePrice, uint256 weight);
    event FishingRodStatusChanged(uint256 indexed id, bool isActive);

    constructor() Ownable(msg.sender) {}

    function registerFishingRod(
        uint256 id,
        string memory name,
        uint8 shapeWidth,
        uint8 shapeHeight,
        bytes memory shapeData,
        uint256 purchasePrice,
        uint256 weight
    ) external override onlyOwner {
        require(id > 0, "Invalid ID");
        require(!fishingRods[id].isActive, "Fishing rod already exists");
        require(bytes(name).length > 0, "Name cannot be empty");
        require(shapeWidth > 0 && shapeHeight > 0, "Invalid dimensions");
        require(shapeData.length > 0, "Shape data cannot be empty");

        fishingRods[id] = FishingRod({
            id: id,
            name: name,
            shapeWidth: shapeWidth,
            shapeHeight: shapeHeight,
            shapeData: shapeData,
            purchasePrice: purchasePrice,
            weight: weight,
            isActive: true
        });

        fishingRodIds.push(id);
        emit FishingRodRegistered(id, name);
    }

    function updateFishingRod(
        uint256 id,
        uint256 purchasePrice,
        uint256 weight
    ) external override onlyOwner {
        require(isValidFishingRod(id), "Invalid fishing rod ID");
        
        fishingRods[id].purchasePrice = purchasePrice;
        fishingRods[id].weight = weight;
        
        emit FishingRodUpdated(id, purchasePrice, weight);
    }

    function setFishingRodStatus(uint256 id, bool isActive) external override onlyOwner {
        require(fishingRods[id].id > 0, "Fishing rod does not exist");
        
        fishingRods[id].isActive = isActive;
        emit FishingRodStatusChanged(id, isActive);
    }

    function getFishingRod(uint256 id) external view override returns (FishingRod memory) {
        require(fishingRods[id].id > 0, "Invalid fishing rod ID");
        return fishingRods[id];
    }

    function getFishingRodCount() external view override returns (uint256) {
        return fishingRodIds.length;
    }

    function getAllFishingRods() external view override returns (FishingRod[] memory) {
        FishingRod[] memory allRods = new FishingRod[](fishingRodIds.length);
        for (uint256 i = 0; i < fishingRodIds.length; i++) {
            allRods[i] = fishingRods[fishingRodIds[i]];
        }
        return allRods;
    }

    function isValidFishingRod(uint256 id) public view override returns (bool) {
        return fishingRods[id].id > 0 && fishingRods[id].isActive;
    }

    function calculateCombinedWeight(uint256[] memory _fishingRodIds) 
        external 
        view 
        override 
        returns (uint256) 
    {
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < _fishingRodIds.length; i++) {
            if (isValidFishingRod(_fishingRodIds[i])) {
                totalWeight += fishingRods[_fishingRodIds[i]].weight;
            }
        }
        return totalWeight;
    }
}