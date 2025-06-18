// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../RisingTidesBase.sol";

/**
 * @title ResourceManager
 * @dev Manages travel, ship changes, and other resource-related operations
 */
abstract contract ResourceManager is RisingTidesBase {

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
     * @dev Purchase a ship at a harbor
     */
    function purchaseShip(uint256 shipId) external onlyRegisteredPlayer whenNotPaused nonReentrant {
        if (!shipRegistry.isValidShip(shipId)) revert InvalidShip(shipId);
        
        // Require player to be at a harbor
        _requireHarbor(msg.sender);

        IShipRegistry.Ship memory ship = shipRegistry.getShip(shipId);
        uint256 cost = ship.purchasePrice;
        
        if (currency.balanceOf(msg.sender) < cost) {
            revert InsufficientBalance(msg.sender, cost, currency.balanceOf(msg.sender));
        }

        // Burn currency for purchase
        currency.burn(msg.sender, cost, "Ship purchase");

        // TODO: Add ship to player's ship roster

        emit IRisingTides.ShipPurchased(msg.sender, shipId, cost);
        emit IRisingTides.ShipChanged(msg.sender, shipId);
    }

    /**
     * @dev Purchase an engine at a harbor
     */
    function purchaseEngine(uint256 engineId) external onlyRegisteredPlayer whenNotPaused nonReentrant {
        if (!engineRegistry.isValidEngine(engineId)) revert InvalidEngine(engineId);
        
        // Require player to be at a harbor
        _requireHarbor(msg.sender);

        IEngineRegistry.Engine memory engine = engineRegistry.getEngine(engineId);
        uint256 cost = engine.purchasePrice;
        
        if (currency.balanceOf(msg.sender) < cost) {
            revert InsufficientBalance(msg.sender, cost, currency.balanceOf(msg.sender));
        }

        // Burn currency for purchase
        currency.burn(msg.sender, cost, "Engine purchase");

        // TODO: Add engine to player's inventory or storage
        // For now, just emit the purchase event
        
        emit IRisingTides.EnginePurchased(msg.sender, engineId, cost);
    }

    /**
     * @dev Purchase a fishing rod at a harbor
     */
    function purchaseFishingRod(uint256 rodId) external onlyRegisteredPlayer whenNotPaused nonReentrant {
        if (!fishingRodRegistry.isValidFishingRod(rodId)) revert InvalidFishingRod(rodId);
        
        // Require player to be at a harbor
        _requireHarbor(msg.sender);

        IFishingRodRegistry.FishingRod memory rod = fishingRodRegistry.getFishingRod(rodId);
        uint256 cost = rod.purchasePrice;
        
        if (currency.balanceOf(msg.sender) < cost) {
            revert InsufficientBalance(msg.sender, cost, currency.balanceOf(msg.sender));
        }

        // Burn currency for purchase
        currency.burn(msg.sender, cost, "Fishing rod purchase");

        // TODO: Add fishing rod to player's inventory or storage
        // For now, just emit the purchase event
        
        emit IRisingTides.FishingRodPurchased(msg.sender, rodId, cost);
    }

}
