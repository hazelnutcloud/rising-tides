// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVRFConsumer {
    function rawFulfillRandomNumbers(uint256 requestId, uint256[] memory randomNumbers) external;
}
