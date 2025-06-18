// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../GameStateBase.sol";

/**
 * @title ResourceManager
 * @dev Manages bait, travel, ship changes, and other resource-related operations
 */
abstract contract ResourceManager is GameStateBase {
    /**
     * @dev Purchase bait at a bait shop
     */
    function purchaseBait(uint256 baitType, uint256 amount) external onlyRegisteredPlayer whenNotPaused nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        IGameState.PlayerState memory player = playerStates[msg.sender];

        // Check if player is at a bait shop on current map
        uint256 shopId = _findBaitShopAtPosition(player.mapId, player.position);
        require(shopId < mapRegistry.getBaitShopsCount(player.mapId), "No bait shop at current position");

        IMapRegistry.BaitShop memory shop = mapRegistry.getBaitShop(player.mapId, shopId);
        require(shop.isActive, "Bait shop is inactive");

        // Check if bait type is available at this shop
        bool baitAvailable = false;
        for (uint256 i = 0; i < shop.availableBait.length; i++) {
            if (shop.availableBait[i] == baitType) {
                baitAvailable = true;
                break;
            }
        }
        require(baitAvailable, "Bait type not available at this shop");

        // Calculate cost
        FishRegistry.BaitType memory bait = fishRegistry.getBaitType(baitType);
        uint256 totalCost = bait.price * amount;
        require(currency.balanceOf(msg.sender) >= totalCost, "Insufficient currency");

        // Burn currency and add bait to inventory
        currency.burn(msg.sender, totalCost, "Bait purchase");
        playerBait[msg.sender][baitType] += amount;

        emit IGameState.BaitPurchased(msg.sender, baitType, amount, totalCost);
    }

    /**
     * @dev Get player's bait inventory
     */
    function getPlayerBait(address player, uint256 baitType) external view returns (uint256) {
        return playerBait[player][baitType];
    }

    /**
     * @dev Get all available bait types and amounts for a player
     */
    function getPlayerAvailableBait(address player)
        external
        view
        returns (uint256[] memory baitTypes, uint256[] memory amounts)
    {
        // Count available bait types first
        uint256 availableCount = 0;
        for (uint256 i = 1; i <= 1000; i++) {
            if (playerBait[player][i] > 0) {
                availableCount++;
            }
            if (!fishRegistry.isValidBait(i) && i > 50) {
                break; // Stop checking after a reasonable range
            }
        }

        // Populate arrays
        baitTypes = new uint256[](availableCount);
        amounts = new uint256[](availableCount);

        uint256 index = 0;
        for (uint256 i = 1; i <= 1000 && index < availableCount; i++) {
            if (playerBait[player][i] > 0) {
                baitTypes[index] = i;
                amounts[index] = playerBait[player][i];
                index++;
            }
            if (!fishRegistry.isValidBait(i) && i > 50) {
                break;
            }
        }

        return (baitTypes, amounts);
    }

    /**
     * @dev Travel to a different map
     */
    function travelToMap(uint256 newMapId) external onlyRegisteredPlayer whenNotPaused nonReentrant {
        IGameState.PlayerState storage player = playerStates[msg.sender];
        require(newMapId != player.mapId, "Already on this map");
        require(mapRegistry.isValidMap(newMapId), "Invalid map ID");

        IMapRegistry.Map memory newMap = mapRegistry.getMap(newMapId);
        uint256 travelCost = newMap.travelCost;

        require(currency.balanceOf(msg.sender) >= travelCost, "Insufficient currency for travel");

        // Burn currency for travel cost
        if (travelCost > 0) {
            currency.burn(msg.sender, travelCost, "Map travel");
        }

        uint256 oldMapId = player.mapId;
        player.mapId = newMapId;

        // Reset position to map origin (0, 0) - could be customized per map
        player.position = IGameState.Position(0, 0);

        emit IGameState.MapChanged(msg.sender, oldMapId, newMapId, travelCost);
    }

    /**
     * @dev Change player's ship
     */
    function changeShip(uint256 newShipId) external onlyRegisteredPlayer whenNotPaused {
        require(shipRegistry.isValidShip(newShipId), "Invalid ship ID");

        IGameState.PlayerState storage player = playerStates[msg.sender];

        // TODO: Add ship ownership/purchase logic
        // For now, allow free ship changes

        player.shipId = newShipId;

        // Recalculate weight and movement speed based on new ship
        uint256 newWeight = _calculatePlayerWeight(msg.sender, newShipId);
        player.totalWeight = newWeight;

        // Use equipped engine power or fallback to ship default
        uint256 enginePower = _calculateTotalEnginePower(msg.sender, newShipId);
        player.movementSpeed = _calculateMovementSpeed(enginePower, newWeight);

        // Reinitialize inventory for new ship
        _initializeInventory(msg.sender, newShipId);

        emit IGameState.ShipChanged(msg.sender, newShipId);
    }

    /**
     * @dev Check if a slot is blocked for a specific ship
     */
    function isBlockedSlot(uint256 shipId, uint8 position) external view returns (bool) {
        return shipRegistry.isBlockedSlot(shipId, position);
    }

    /**
     * @dev Find bait shop at specific position on a map
     */
    function _findBaitShopAtPosition(uint256 mapId, IGameState.Position memory position)
        private
        view
        returns (uint256)
    {
        uint256 shopCount = mapRegistry.getBaitShopsCount(mapId);
        for (uint256 i = 0; i < shopCount; i++) {
            IMapRegistry.BaitShop memory shop = mapRegistry.getBaitShop(mapId, i);
            if (shop.position.x == position.x && shop.position.y == position.y && shop.isActive) {
                return i;
            }
        }
        return type(uint256).max; // Not found
    }
}
