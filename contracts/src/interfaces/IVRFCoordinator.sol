// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVRFCoordinator {
    function requestRandomNumbers(
        uint32 numNumbers,
        uint256 clientSeed
    ) external returns (uint256 requestId);
}
