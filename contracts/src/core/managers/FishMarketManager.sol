// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../RisingTidesBase.sol";

abstract contract FishMarketManager is RisingTidesBase {
  function sellFish(uint8 x, uint8 y) external onlyRegisteredPlayer whenNotPaused {}
}