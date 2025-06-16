// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFishingRodRegistry {
    struct FishingRod {
        uint256 id;
        string name;
        uint8 shapeWidth;
        uint8 shapeHeight;
        bytes shapeData;
        uint256 purchasePrice;
        uint256 weight;
        bool isActive;
    }

    function registerFishingRod(
        uint256 id,
        string memory name,
        uint8 shapeWidth,
        uint8 shapeHeight,
        bytes memory shapeData,
        uint256 purchasePrice,
        uint256 weight
    ) external;

    function updateFishingRod(
        uint256 id,
        uint256 purchasePrice,
        uint256 weight
    ) external;

    function setFishingRodStatus(uint256 id, bool isActive) external;

    function getFishingRod(
        uint256 id
    ) external view returns (FishingRod memory);
    function getFishingRodCount() external view returns (uint256);
    function getAllFishingRods() external view returns (FishingRod[] memory);
    function isValidFishingRod(uint256 id) external view returns (bool);
    function calculateCombinedWeight(
        uint256[] memory fishingRodIds
    ) external view returns (uint256);
}
