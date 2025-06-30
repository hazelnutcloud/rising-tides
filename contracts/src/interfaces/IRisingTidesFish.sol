// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRisingTidesFish {
    function getPlayerCargoWeight(address player) external view returns (uint256);
}