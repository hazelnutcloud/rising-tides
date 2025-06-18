// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../utils/Errors.sol";

/**
 * @title RisingTidesCurrency
 * @dev ERC20 token for the Rising Tides game economy
 * Features minting (when selling fish) and burning (for purchases) mechanics
 */
contract RisingTidesCurrency is ERC20, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18; // 1 billion tokens max supply

    // Tracking stats for tokenomics
    uint256 public totalMinted;
    uint256 public totalBurned;

    mapping(address => uint256) public minted; // Track minted per address
    mapping(address => uint256) public burned; // Track burned per address

    event TokensMinted(address indexed to, uint256 amount, string reason);
    event TokensBurned(address indexed from, uint256 amount, string reason);

    constructor() ERC20("Rising Tides Coin", "RTC") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @dev Mint tokens - typically called when players sell fish
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     * @param reason Reason for minting (for tracking/events)
     */
    function mint(address to, uint256 amount, string calldata reason) external onlyRole(MINTER_ROLE) whenNotPaused {
        if (to == address(0)) revert InvalidAddress(to);
        if (amount == 0) revert InvalidAmount(amount);
        if (totalSupply() + amount > MAX_SUPPLY) {
            revert ExceedsMaxSupply(totalSupply(), amount, MAX_SUPPLY);
        }

        totalMinted += amount;
        minted[to] += amount;

        _mint(to, amount);
        emit TokensMinted(to, amount, reason);
    }

    /**
     * @dev Burn tokens from an address - typically for purchases
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     * @param reason Reason for burning (for tracking/events)
     */
    function burn(address from, uint256 amount, string calldata reason) external onlyRole(BURNER_ROLE) whenNotPaused {
        if (from == address(0)) revert InvalidAddress(from);
        if (amount == 0) revert InvalidAmount(amount);
        if (balanceOf(from) < amount) revert InsufficientBalance(from, amount, balanceOf(from));

        totalBurned += amount;
        burned[from] += amount;

        _burn(from, amount);
        emit TokensBurned(from, amount, reason);
    }

    /**
     * @dev Burn tokens from the caller's address
     * @param amount Amount of tokens to burn
     * @param reason Reason for burning
     */
    function burnFrom(uint256 amount, string calldata reason) external whenNotPaused {
        if (amount == 0) revert InvalidAmount(amount);
        if (balanceOf(msg.sender) < amount) {
            revert InsufficientBalance(msg.sender, amount, balanceOf(msg.sender));
        }

        totalBurned += amount;
        burned[msg.sender] += amount;

        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount, reason);
    }

    /**
     * @dev Get net tokens for an address (minted - burned)
     * @param account Address to check
     * @return Net token amount for the address
     */
    function getNetTokens(address account) external view returns (int256) {
        return int256(minted[account]) - int256(burned[account]);
    }

    /**
     * @dev Get total tokens in circulation (minted - burned)
     * @return Net circulation amount
     */
    function getNetCirculation() external view returns (uint256) {
        return totalMinted - totalBurned;
    }

    /**
     * @dev Pause the contract (emergency use)
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Override transfer to add pause functionality
     */
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from, to, value);
    }
}
