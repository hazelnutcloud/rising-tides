// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IFishMarket.sol";
import "../tokens/RisingTidesCurrency.sol";
import "../registries/FishRegistry.sol";

/**
 * @title FishMarket
 * @dev Market contract implementing bonding curves for dynamic fish pricing
 * Handles fish trading with supply/demand mechanics and freshness decay
 */
contract FishMarket is IFishMarket, AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Contract dependencies
    RisingTidesCurrency public currency;
    FishRegistry public fishRegistry;

    // Market state for each fish species
    mapping(uint256 => MarketData) private marketData;
    mapping(uint256 => uint256[]) private priceHistory; // Last 24 price points
    mapping(uint256 => uint256) private lastPriceUpdate;

    // Bonding curve parameters
    uint256 public constant PRICE_DECAY_FACTOR = 9900; // 99% (1% decay per sale)
    uint256 public constant PRICE_RECOVERY_RATE = 100; // 1% recovery per hour
    uint256 public constant MIN_PRICE_MULTIPLIER = 5000; // 50% of base price minimum
    uint256 public constant MAX_PRICE_MULTIPLIER = 20000; // 200% of base price maximum
    uint256 public constant PRICE_PRECISION = 10000; // 1 = 0.01%

    // Freshness parameters
    uint256 public constant MAX_FRESHNESS = 100;
    uint256 public constant FRESHNESS_DECAY_PERIOD = 1 hours;

    // Market fee
    uint256 public marketFee = 300; // 3% market fee
    address public feeCollector;

    // Volume tracking for 24h rolling window
    mapping(uint256 => mapping(uint256 => uint256)) private hourlyVolume; // species => hour => volume
    uint256 public constant VOLUME_WINDOW = 24 hours;

    modifier validSpecies(uint256 species) {
        require(fishRegistry.isValidSpecies(species), "Invalid fish species");
        _;
    }

    constructor(address _currency, address _fishRegistry, address _feeCollector) {
        require(_currency != address(0), "Currency address cannot be zero");
        require(_fishRegistry != address(0), "Fish registry address cannot be zero");
        require(_feeCollector != address(0), "Fee collector address cannot be zero");

        currency = RisingTidesCurrency(_currency);
        fishRegistry = FishRegistry(_fishRegistry);
        feeCollector = _feeCollector;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @dev Sell a single fish
     */
    function sellFish(uint256 species, uint16 weight, uint256 caughtAt)
        external
        validSpecies(species)
        whenNotPaused
        nonReentrant
        returns (uint256 earnings)
    {
        require(weight > 0, "Weight must be greater than zero");
        require(caughtAt <= block.timestamp, "Invalid caught timestamp");

        // Calculate fish value including freshness
        (uint256 fishValue, uint8 freshness) = calculateFishValue(species, weight, caughtAt);
        require(freshness > 0, "Fish is no longer fresh");

        // Apply market fee
        uint256 fee = (fishValue * marketFee) / PRICE_PRECISION;
        earnings = fishValue - fee;

        // Update market data
        _updateMarketData(species, fishValue);

        // Mint currency to seller
        currency.mint(msg.sender, earnings, "Fish sale");

        // Mint fee to collector if fee > 0
        if (fee > 0) {
            currency.mint(feeCollector, fee, "Market fee");
        }

        emit FishSold(msg.sender, species, weight, freshness, getCurrentPrice(species), fishValue);

        return earnings;
    }

    /**
     * @dev Sell multiple fish in a single transaction
     */
    function sellMultipleFish(
        uint256[] calldata species,
        uint16[] calldata weights,
        uint256[] calldata caughtTimestamps
    ) external whenNotPaused nonReentrant returns (uint256 totalEarnings) {
        require(species.length == weights.length, "Array length mismatch");
        require(species.length == caughtTimestamps.length, "Array length mismatch");
        require(species.length > 0, "No fish to sell");
        require(species.length <= 50, "Too many fish in single transaction");

        totalEarnings = 0;

        for (uint256 i = 0; i < species.length; i++) {
            require(fishRegistry.isValidSpecies(species[i]), "Invalid fish species");
            require(weights[i] > 0, "Weight must be greater than zero");
            require(caughtTimestamps[i] <= block.timestamp, "Invalid caught timestamp");

            // Calculate fish value including freshness
            (uint256 fishValue, uint8 freshness) = calculateFishValue(species[i], weights[i], caughtTimestamps[i]);

            if (freshness > 0) {
                // Apply market fee
                uint256 fee = (fishValue * marketFee) / PRICE_PRECISION;
                uint256 earnings = fishValue - fee;
                totalEarnings += earnings;

                // Update market data
                _updateMarketData(species[i], fishValue);

                // Mint fee to collector if fee > 0
                if (fee > 0) {
                    currency.mint(feeCollector, fee, "Market fee");
                }

                emit FishSold(msg.sender, species[i], weights[i], freshness, getCurrentPrice(species[i]), fishValue);
            }
        }

        // Mint total earnings to seller
        if (totalEarnings > 0) {
            currency.mint(msg.sender, totalEarnings, "Bulk fish sale");
        }

        return totalEarnings;
    }

    /**
     * @dev Get current market price for a species
     */
    function getCurrentPrice(uint256 species) public view validSpecies(species) returns (uint256) {
        MarketData memory data = marketData[species];

        if (data.currentPrice == 0) {
            // Initialize with base price if no trades yet
            FishRegistry.FishSpecies memory fishSpec = fishRegistry.getFishSpecies(species);
            return fishSpec.basePrice;
        }

        // Apply price recovery based on time elapsed
        uint256 timeElapsed = block.timestamp - data.lastSaleTime;
        uint256 hoursElapsed = timeElapsed / 1 hours;

        if (hoursElapsed > 0) {
            uint256 recoveryAmount = (data.currentPrice * PRICE_RECOVERY_RATE * hoursElapsed) / PRICE_PRECISION;
            uint256 recoveredPrice = data.currentPrice + recoveryAmount;

            // Cap at maximum price
            FishRegistry.FishSpecies memory fishSpec = fishRegistry.getFishSpecies(species);
            uint256 maxPrice = (fishSpec.basePrice * MAX_PRICE_MULTIPLIER) / PRICE_PRECISION;

            return recoveredPrice > maxPrice ? maxPrice : recoveredPrice;
        }

        return data.currentPrice;
    }

    /**
     * @dev Calculate fish value including weight and freshness
     */
    function calculateFishValue(uint256 species, uint16 weight, uint256 caughtAt)
        public
        view
        validSpecies(species)
        returns (uint256 value, uint8 freshness)
    {
        freshness = calculateFreshness(caughtAt);

        if (freshness == 0) {
            return (0, 0);
        }

        uint256 currentPrice = getCurrentPrice(species);

        // Value = currentPrice * weight * freshness
        // Weight is treated as a multiplier (in grams, so divide by 1000 for kg)
        value = (currentPrice * uint256(weight) * uint256(freshness)) / (1000 * MAX_FRESHNESS);

        return (value, freshness);
    }

    /**
     * @dev Calculate freshness based on time elapsed since caught
     */
    function calculateFreshness(uint256 caughtAt) public view returns (uint8) {
        if (caughtAt > block.timestamp) {
            return uint8(MAX_FRESHNESS);
        }

        uint256 timeElapsed = block.timestamp - caughtAt;
        uint256 hoursElapsed = timeElapsed / FRESHNESS_DECAY_PERIOD;

        // Freshness decays at 5% per hour (completely spoiled after 20 hours)
        uint256 freshnessLoss = hoursElapsed * 5;

        if (freshnessLoss >= MAX_FRESHNESS) {
            return 0;
        }

        return uint8(MAX_FRESHNESS - freshnessLoss);
    }

    /**
     * @dev Get market data for a species
     */
    function getMarketData(uint256 species) external view validSpecies(species) returns (MarketData memory) {
        MarketData memory data = marketData[species];

        // Update current price with recovery if needed
        data.currentPrice = getCurrentPrice(species);

        // Calculate 24h volume
        data.volume24h = _calculate24hVolume(species);

        return data;
    }

    /**
     * @dev Internal function to update market data after a sale
     */
    function _updateMarketData(uint256 species, uint256 saleValue) private {
        MarketData storage data = marketData[species];

        // Initialize if first sale
        if (data.currentPrice == 0) {
            FishRegistry.FishSpecies memory fishSpec = fishRegistry.getFishSpecies(species);
            data.basePrice = fishSpec.basePrice;
            data.currentPrice = fishSpec.basePrice;
        }

        // Apply bonding curve (price decreases with each sale)
        uint256 newPrice = (data.currentPrice * PRICE_DECAY_FACTOR) / PRICE_PRECISION;

        // Ensure minimum price
        uint256 minPrice = (data.basePrice * MIN_PRICE_MULTIPLIER) / PRICE_PRECISION;
        if (newPrice < minPrice) {
            newPrice = minPrice;
        }

        data.currentPrice = newPrice;
        data.lastSaleTime = block.timestamp;

        // Update hourly volume
        uint256 currentHour = block.timestamp / 1 hours;
        hourlyVolume[species][currentHour] += saleValue;

        // Add to price history (keep last 24 points)
        priceHistory[species].push(newPrice);
        if (priceHistory[species].length > 24) {
            // Remove oldest entry
            for (uint256 i = 0; i < priceHistory[species].length - 1; i++) {
                priceHistory[species][i] = priceHistory[species][i + 1];
            }
            priceHistory[species].pop();
        }

        emit MarketPriceUpdated(species, newPrice);
    }

    /**
     * @dev Calculate 24-hour trading volume for a species
     */
    function _calculate24hVolume(uint256 species) private view returns (uint256) {
        uint256 currentHour = block.timestamp / 1 hours;
        uint256 totalVolume = 0;

        for (uint256 i = 0; i < 24; i++) {
            if (currentHour >= i) {
                uint256 hour = currentHour - i;
                totalVolume += hourlyVolume[species][hour];
            }
        }

        return totalVolume;
    }

    /**
     * @dev Get price history for a species
     */
    function getPriceHistory(uint256 species) external view validSpecies(species) returns (uint256[] memory) {
        return priceHistory[species];
    }

    /**
     * @dev Update market fee (admin only)
     */
    function updateMarketFee(uint256 newFee) external onlyRole(ADMIN_ROLE) {
        require(newFee <= 1000, "Fee cannot exceed 10%"); // Max 10% fee
        marketFee = newFee;
    }

    /**
     * @dev Update fee collector address (admin only)
     */
    function updateFeeCollector(address newFeeCollector) external onlyRole(ADMIN_ROLE) {
        require(newFeeCollector != address(0), "Fee collector cannot be zero address");
        feeCollector = newFeeCollector;
    }

    /**
     * @dev Initialize market data for a species (admin only)
     */
    function initializeMarketData(uint256 species) external onlyRole(ADMIN_ROLE) validSpecies(species) {
        if (marketData[species].basePrice == 0) {
            FishRegistry.FishSpecies memory fishSpec = fishRegistry.getFishSpecies(species);
            marketData[species] = MarketData({
                currentPrice: fishSpec.basePrice,
                volume24h: 0,
                lastSaleTime: block.timestamp,
                basePrice: fishSpec.basePrice
            });
        }
    }

    /**
     * @dev Update contract dependencies (admin only)
     */
    function updateDependencies(address _currency, address _fishRegistry) external onlyRole(ADMIN_ROLE) {
        if (_currency != address(0)) {
            currency = RisingTidesCurrency(_currency);
        }
        if (_fishRegistry != address(0)) {
            fishRegistry = FishRegistry(_fishRegistry);
        }
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
