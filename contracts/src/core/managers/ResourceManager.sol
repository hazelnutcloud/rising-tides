// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../RisingTidesBase.sol";

/**
 * @title ResourceManager
 * @dev Manages bait, travel, ship changes, and other resource-related operations
 */
abstract contract ResourceManager is RisingTidesBase {
    /**
     * @dev Purchase bait at a bait shop
     */
    function purchaseBait(uint256 baitType, uint256 amount) external onlyRegisteredPlayer whenNotPaused nonReentrant {
        if (amount == 0) revert InvalidAmount(amount);
        IRisingTides.PlayerState memory player = playerStates[msg.sender];

        // Check if player is at a bait shop on current map
        uint256 shopId = _findBaitShopAtPosition(player.mapId, player.position);
        if (shopId >= mapRegistry.getBaitShopsCount(player.mapId)) {
            revert ShopDoesNotExist(player.mapId, shopId);
        }

        IMapRegistry.BaitShop memory shop = mapRegistry.getBaitShop(player.mapId, shopId);
        if (!shop.isActive) revert ShopInactive(shopId);

        // Check if bait type is available at this shop
        bool baitAvailable = false;
        for (uint256 i = 0; i < shop.availableBait.length; i++) {
            if (shop.availableBait[i] == baitType) {
                baitAvailable = true;
                break;
            }
        }
        if (!baitAvailable) revert BaitNotAvailable(shopId, baitType);

        // Calculate cost
        FishRegistry.BaitType memory bait = fishRegistry.getBaitType(baitType);
        uint256 totalCost = bait.price * amount;
        if (currency.balanceOf(msg.sender) < totalCost) {
            revert InsufficientBalance(msg.sender, totalCost, currency.balanceOf(msg.sender));
        }

        // Burn currency and add bait to inventory
        currency.burn(msg.sender, totalCost, "Bait purchase");
        playerBait[msg.sender][baitType] += amount;

        emit IRisingTides.BaitPurchased(msg.sender, baitType, amount, totalCost);
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
        IRisingTides.PlayerState storage player = playerStates[msg.sender];
        if (newMapId == player.mapId) revert AlreadyOnMap(newMapId);
        if (!mapRegistry.isValidMap(newMapId)) revert InvalidMap(newMapId);

        IMapRegistry.Map memory newMap = mapRegistry.getMap(newMapId);
        uint256 travelCost = newMap.travelCost;

        if (currency.balanceOf(msg.sender) < travelCost) {
            revert InsufficientBalance(msg.sender, travelCost, currency.balanceOf(msg.sender));
        }

        // Burn currency for travel cost
        if (travelCost > 0) {
            currency.burn(msg.sender, travelCost, "Map travel");
        }

        uint256 oldMapId = player.mapId;
        player.mapId = newMapId;

        // Reset position to map origin (0, 0) - could be customized per map
        player.position = IRisingTides.Position(0, 0);

        emit IRisingTides.MapChanged(msg.sender, oldMapId, newMapId, travelCost);
    }

    /**
     * @dev Change player's ship
     */
    function changeShip(uint256 newShipId) external onlyRegisteredPlayer whenNotPaused {
        if (!shipRegistry.isValidShip(newShipId)) revert InvalidShip(newShipId);

        IRisingTides.PlayerState storage player = playerStates[msg.sender];

        // TODO: Add ship ownership/purchase logic
        // For now, allow free ship changes

        player.shipId = newShipId;

        // Recalculate weight and movement speed based on new ship
        // uint256 newWeight = _calculatePlayerWeight(msg.sender, newShipId);
        // player.totalWeight = newWeight;

        // Use equipped engine power or fallback to ship default
        // uint256 enginePower = _calculateTotalEnginePower(msg.sender, newShipId);
        // player.movementSpeed = _calculateMovementSpeed(enginePower, newWeight);

        // Reinitialize inventory for new ship
        IShipRegistry.Ship memory ship = shipRegistry.getShip(newShipId);
        inventoryContract.initializeInventory(msg.sender, newShipId, ship.cargoWidth, ship.cargoHeight, ship.slotTypes);

        emit IRisingTides.ShipChanged(msg.sender, newShipId);
    }

    /**
     * @dev Find bait shop at specific position on a map
     */
    function _findBaitShopAtPosition(uint256 mapId, IRisingTides.Position memory position)
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
