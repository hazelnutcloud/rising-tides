// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRisingTidesInventory {
    function getEquippedShip(
        address player
    ) external view returns (uint256 shipId);

    function getShipStats(
        uint256 shipId
    )
        external
        view
        returns (
            uint256 enginePower,
            uint256 weightCapacity,
            uint256 fuelCapacity
        );

    function getFuel(address player) external view returns (uint256);

    function consumeFuel(address player, uint256 amount) external;

    function mintStarterKit(address player) external;

    function getPlayerCargoWeight(
        address player
    ) external view returns (uint256);
}
