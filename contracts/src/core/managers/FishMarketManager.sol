// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../RisingTidesBase.sol";

abstract contract FishMarketManager is RisingTidesBase {
    using InventoryLib for InventoryLib.InventoryGrid;

    function sellFish(uint256 instanceId) external onlyRegisteredPlayer whenNotPaused returns (uint256 salePrice) {
        InventoryLib.InventoryGrid storage inventory = playerInventories[msg.sender];

        (InventoryLib.GridItem memory item, uint8 x, uint8 y) = inventory.getItemByInstanceId(instanceId);

        require(item.itemType == ItemType.Fish, "Not a fish");

        InventoryLib.ItemShape memory fishShape = _getItemShape(ItemType.Fish, item.itemId);

        inventory.removeItem(fishShape, x, y, item.rotation, item.instanceId);

        FishCatch storage fishData = playerFish[msg.sender][instanceId];

        require(fishData.species > 0, "Invalid fish");

        // Store fish data in memory before deletion
        uint256 species = fishData.species;
        uint16 weight = fishData.weight;
        uint256 caughtAt = fishData.caughtAt;

        delete playerFish[msg.sender][instanceId];

        uint256 freshness = _calculateFishFreshness(caughtAt);

        salePrice = _updateFishMarketData(species, weight, freshness);

        currency.mint(msg.sender, salePrice, "Fish sold");

        emit FishSold(species, weight, freshness, salePrice);
    }

    function _updateFishMarketData(uint256 species, uint16 weight, uint256 freshness)
        internal
        returns (uint256 salePrice)
    {
        FishMarketData storage marketData = fishMarketData[species];

        FishRegistry.FishSpecies memory fish = fishRegistry.getFishSpecies(species);

        if (marketData.lastSoldTimestamp == 0) {
            salePrice = fish.basePrice * weight * freshness / 100;
            marketData.value = fish.basePrice - (fish.basePrice * PRICE_DECAY_RATE / 100);
        } else {
            uint256 secondsElapsed = block.timestamp - marketData.lastSoldTimestamp;
            uint256 marketValue = marketData.value + (fish.basePrice * PRICE_RECOVERY_RATE * secondsElapsed / 1e7);
            if (marketValue > fish.basePrice) {
              marketValue = fish.basePrice;
            }
            salePrice = marketValue * weight * freshness / 100;
            marketData.value = marketValue - (marketValue * PRICE_DECAY_RATE / 100);
        }

        marketData.lastSoldTimestamp = block.timestamp;

        emit FishMarketUpdated(fish.id, marketData.value, marketData.lastSoldTimestamp);
    }

    function _calculateFishFreshness(uint256 caughtAt) internal view returns (uint256 freshness) {
        uint256 secondsElapsed = block.timestamp - caughtAt;
        uint256 decayPeriods = secondsElapsed / FRESHNESS_DECAY_PERIOD;
        uint256 freshnessDecayed = (decayPeriods * FRESHNESS_DECAY_RATE);

        if (freshnessDecayed > 100) return 0;

        return 100 - freshnessDecayed;
    }

    function getMarketPrice(uint256 species) external view returns (uint256 currentPrice) {
        return _getMarketPrice(species);
    }

    function _getMarketPrice(uint256 species) internal view returns (uint256 currentPrice) {
        FishMarketData storage marketData = fishMarketData[species];
        FishRegistry.FishSpecies memory fish = fishRegistry.getFishSpecies(species);

        if (marketData.lastSoldTimestamp == 0) {
            return fish.basePrice;
        }

        uint256 secondsElapsed = block.timestamp - marketData.lastSoldTimestamp;
        uint256 marketValue = marketData.value + (fish.basePrice * PRICE_RECOVERY_RATE * secondsElapsed / 1e7);
        
        if (marketValue > fish.basePrice) {
            marketValue = fish.basePrice;
        }

        return marketValue;
    }

    function estimateSalePrice(uint256 instanceId) external view returns (uint256 estimatedPrice) {
        address player = msg.sender;
        FishCatch storage fishData = playerFish[player][instanceId];
        
        require(fishData.species > 0, "Invalid fish");

        uint256 freshness = _calculateFishFreshness(fishData.caughtAt);
        uint256 currentMarketPrice = _getMarketPrice(fishData.species);
        
        return currentMarketPrice * fishData.weight * freshness / 100;
    }

    function getFishFreshness(uint256 instanceId) external view returns (uint256 freshness) {
        address player = msg.sender;
        FishCatch storage fishData = playerFish[player][instanceId];
        
        require(fishData.species > 0, "Invalid fish");
        
        return _calculateFishFreshness(fishData.caughtAt);
    }

    /**
     * @dev Admin function to set fish market data for testing
     */
    function setFishMarketData(uint256 species, uint256 marketValue, uint256 lastSoldTimestamp) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(fishRegistry.isValidSpecies(species), "Invalid species");
        
        fishMarketData[species] = FishMarketData({
            value: marketValue,
            lastSoldTimestamp: lastSoldTimestamp
        });
        
        emit FishMarketUpdated(species, marketValue, lastSoldTimestamp);
    }

}
