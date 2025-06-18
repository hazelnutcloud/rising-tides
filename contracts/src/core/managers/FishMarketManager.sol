// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../RisingTidesBase.sol";

abstract contract FishMarketManager is RisingTidesBase {

    function sellFish(uint256 instanceId) external onlyRegisteredPlayer whenNotPaused returns (uint256 salePrice) {
        // Require player to be at a harbor
        _requireHarbor(msg.sender);

        // Get fish data from inventory contract and remove it
        IRisingTides.FishCatch memory fishData = inventoryContract.removeFishFromInventory(msg.sender, instanceId);

        if (fishData.species == 0) revert InvalidSpecies(0);

        // Store fish data in memory
        uint256 species = fishData.species;
        uint16 weight = fishData.weight;
        uint256 caughtAt = fishData.caughtTimestamp;

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
        IRisingTides.FishCatch memory fishData = inventoryContract.getFishData(player, instanceId);

        if (fishData.species == 0) revert InvalidSpecies(0);

        uint256 freshness = _calculateFishFreshness(fishData.caughtTimestamp);
        uint256 currentMarketPrice = _getMarketPrice(fishData.species);

        return currentMarketPrice * fishData.weight * freshness / 100;
    }

    function getFishFreshness(uint256 instanceId) external view returns (uint256 freshness) {
        address player = msg.sender;
        IRisingTides.FishCatch memory fishData = inventoryContract.getFishData(player, instanceId);

        if (fishData.species == 0) revert InvalidSpecies(0);

        return _calculateFishFreshness(fishData.caughtTimestamp);
    }

    /**
     * @dev Admin function to set fish market data for testing
     */
    function setFishMarketData(uint256 species, uint256 marketValue, uint256 lastSoldTimestamp)
        external
        onlyRole(ADMIN_ROLE)
    {
        if (!fishRegistry.isValidSpecies(species)) revert InvalidSpecies(species);

        fishMarketData[species] = FishMarketData({value: marketValue, lastSoldTimestamp: lastSoldTimestamp});

        emit FishMarketUpdated(species, marketValue, lastSoldTimestamp);
    }
}
