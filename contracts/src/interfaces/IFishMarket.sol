// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFishMarket {
    struct FishListing {
        uint8 species;
        uint16 weight;
        uint8 freshness; // 0-100
        uint256 caughtAt;
    }

    struct MarketData {
        uint256 currentPrice;
        uint256 volume24h;
        uint256 lastSaleTime;
        uint256 basePrice;
    }

    // Events
    event FishSold(
        address indexed seller,
        uint8 indexed species,
        uint16 weight,
        uint8 freshness,
        uint256 price,
        uint256 totalValue
    );
    event MarketPriceUpdated(uint8 indexed species, uint256 newPrice);

    // Market Operations
    function sellFish(uint8 species, uint16 weight, uint256 caughtAt) external returns (uint256 earnings);
    function sellMultipleFish(
        uint8[] calldata species,
        uint16[] calldata weights,
        uint256[] calldata caughtTimestamps
    ) external returns (uint256 totalEarnings);

    // Price Queries
    function getCurrentPrice(uint8 species) external view returns (uint256);
    function calculateFishValue(
        uint8 species,
        uint16 weight,
        uint256 caughtAt
    ) external view returns (uint256 value, uint8 freshness);
    function getMarketData(uint8 species) external view returns (MarketData memory);

    // Freshness Calculation
    function calculateFreshness(uint256 caughtAt) external view returns (uint8);
}