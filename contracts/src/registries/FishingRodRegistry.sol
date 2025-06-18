// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IFishingRodRegistry.sol";
import "../utils/Errors.sol";

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
        if (id == 0) revert InvalidId(id);
        if (fishingRods[id].isActive) revert AlreadyExists("FishingRod", id);
        if (bytes(name).length == 0) revert EmptyString();
        if (shapeWidth == 0 || shapeHeight == 0) revert InvalidDimensions(shapeWidth, shapeHeight);
        if (shapeData.length == 0) revert ShapeDataTooSmall(1, 0);

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

    function updateFishingRod(uint256 id, uint256 purchasePrice, uint256 weight) external override onlyOwner {
        if (!isValidFishingRod(id)) revert InvalidFishingRod(id);

        fishingRods[id].purchasePrice = purchasePrice;
        fishingRods[id].weight = weight;

        emit FishingRodUpdated(id, purchasePrice, weight);
    }

    function setFishingRodStatus(uint256 id, bool isActive) external override onlyOwner {
        if (fishingRods[id].id == 0) revert DoesNotExist("FishingRod", id);

        fishingRods[id].isActive = isActive;
        emit FishingRodStatusChanged(id, isActive);
    }

    function getFishingRod(uint256 id) external view override returns (FishingRod memory) {
        if (fishingRods[id].id == 0) revert InvalidFishingRod(id);
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

    function calculateCombinedWeight(uint256[] memory _fishingRodIds) external view override returns (uint256) {
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < _fishingRodIds.length; i++) {
            if (isValidFishingRod(_fishingRodIds[i])) {
                totalWeight += fishingRods[_fishingRodIds[i]].weight;
            }
        }
        return totalWeight;
    }
}
