// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title IDoubloons
 * @notice Interface for the Doubloons token contract
 * @dev Extends IERC20 with game-specific minting and burning functions
 */
interface IDoubloons is IERC20 {
    /**
     * @notice Mint new Doubloons
     * @dev Only callable by addresses with MINTER_ROLE
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint (with 18 decimals)
     */
    function mint(address to, uint256 amount) external;

    /**
     * @notice Burn Doubloons from an address
     * @dev Only callable by addresses with BURNER_ROLE
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn (with 18 decimals)
     */
    function burn(address from, uint256 amount) external;

    /**
     * @notice Get the MINTER_ROLE identifier
     * @return The bytes32 identifier for the minter role
     */
    function MINTER_ROLE() external view returns (bytes32);

    /**
     * @notice Get the BURNER_ROLE identifier
     * @return The bytes32 identifier for the burner role
     */
    function BURNER_ROLE() external view returns (bytes32);
}