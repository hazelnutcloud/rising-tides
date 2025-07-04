// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVRFCoordinator} from "./interfaces/IVRFCoordinator.sol";
import {IVRFConsumer} from "./interfaces/IVRFConsumer.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract MockVRFCoordinator is IVRFCoordinator, AccessControl {
    bytes32 public constant FULFILLER_ROLE = keccak256("FULFILLER_ROLE");

    uint256 private nextRequestId = 1;

    struct RandomRequest {
        address requester;
        uint32 numNumbers;
        uint256 clientSeed;
        bool fulfilled;
    }

    mapping(uint256 => RandomRequest) public requests;

    event RandomNumbersRequested(
        uint256 indexed requestId, address indexed requester, uint32 numNumbers, uint256 clientSeed
    );

    event RandomNumbersFulfilled(uint256 indexed requestId, uint256[] randomNumbers);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(FULFILLER_ROLE, admin);
    }

    function requestRandomNumbers(uint32 numNumbers, uint256 clientSeed) external returns (uint256 requestId) {
        requestId = nextRequestId++;

        requests[requestId] =
            RandomRequest({requester: msg.sender, numNumbers: numNumbers, clientSeed: clientSeed, fulfilled: false});

        emit RandomNumbersRequested(requestId, msg.sender, numNumbers, clientSeed);

        return requestId;
    }

    function fulfillRandomNumbers(uint256 requestId, uint256[] memory randomNumbers)
        external
        onlyRole(FULFILLER_ROLE)
    {
        RandomRequest storage request = requests[requestId];
        require(request.requester != address(0), "Invalid request ID");
        require(!request.fulfilled, "Request already fulfilled");
        require(randomNumbers.length == request.numNumbers, "Invalid number count");

        request.fulfilled = true;

        // Call the consumer's callback
        IVRFConsumer(request.requester).rawFulfillRandomNumbers(requestId, randomNumbers);

        emit RandomNumbersFulfilled(requestId, randomNumbers);
    }

    // Helper function for testing - generates pseudo-random numbers
    function fulfillRandomNumbersWithSeed(uint256 requestId, uint256 seed) external onlyRole(FULFILLER_ROLE) {
        RandomRequest storage request = requests[requestId];
        require(request.requester != address(0), "Invalid request ID");
        require(!request.fulfilled, "Request already fulfilled");

        uint256[] memory randomNumbers = new uint256[](request.numNumbers);

        // Generate pseudo-random numbers using the seed
        for (uint32 i = 0; i < request.numNumbers; i++) {
            randomNumbers[i] = uint256(keccak256(abi.encodePacked(seed, requestId, i)));
        }

        request.fulfilled = true;

        // Call the consumer's callback
        IVRFConsumer(request.requester).rawFulfillRandomNumbers(requestId, randomNumbers);

        emit RandomNumbersFulfilled(requestId, randomNumbers);
    }

    // View functions
    function getRequest(uint256 requestId)
        external
        view
        returns (address requester, uint32 numNumbers, uint256 clientSeed, bool fulfilled)
    {
        RandomRequest memory request = requests[requestId];
        return (request.requester, request.numNumbers, request.clientSeed, request.fulfilled);
    }
}
