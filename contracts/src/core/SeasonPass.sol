// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title SeasonPass
 * @dev NFT-based season pass system for Rising Tides
 * Manages seasonal gameplay, leaderboards, and rewards
 */
contract SeasonPass is ERC721, AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    struct Season {
        uint256 id;
        string name;
        uint256 startTime;
        uint256 endTime;
        uint256 passPrice; // Price in ETH
        bool isActive;
        uint256 totalPasses;
        address[] rewardPool;
        uint256[] rewardAmounts;
    }

    struct PlayerStats {
        uint256 totalEarnings;
        uint256 totalSpent;
        int256 netValue; // earnings - spent
        uint256 lastUpdateTime;
        bool hasPass;
    }

    // Current season
    uint256 public currentSeasonId;
    mapping(uint256 => Season) public seasons;
    
    // Player stats per season
    mapping(uint256 => mapping(address => PlayerStats)) public seasonStats;
    
    // Season pass ownership
    mapping(uint256 => mapping(address => bool)) public hasSeasonPass;
    mapping(uint256 => mapping(address => uint256)) public passTokenIds;
    
    // Leaderboard tracking
    mapping(uint256 => address[]) public leaderboards;
    mapping(uint256 => mapping(address => uint256)) public leaderboardPositions;
    
    // Token ID tracking
    uint256 private nextTokenId = 1;
    mapping(uint256 => uint256) private tokenToSeason; // tokenId => seasonId
    mapping(uint256 => address) private tokenToPlayer; // tokenId => player

    // Reward distribution
    mapping(uint256 => bool) public seasonRewardsDistributed;
    uint256 public constant MAX_LEADERBOARD_SIZE = 1000;
    uint256 public constant TOP_REWARDS_COUNT = 100; // Top 100 players get rewards

    // Events
    event SeasonCreated(uint256 indexed seasonId, string name, uint256 startTime, uint256 endTime, uint256 passPrice);
    event SeasonPassPurchased(address indexed player, uint256 indexed seasonId, uint256 tokenId);
    event PlayerStatsUpdated(address indexed player, uint256 indexed seasonId, int256 netValue);
    event LeaderboardUpdated(address indexed player, uint256 indexed seasonId, uint256 position);
    event SeasonEnded(uint256 indexed seasonId);
    event RewardsDistributed(uint256 indexed seasonId, uint256 totalRewards);

    modifier activeSeason() {
        require(currentSeasonId > 0, "No active season");
        require(seasons[currentSeasonId].isActive, "Season not active");
        require(block.timestamp >= seasons[currentSeasonId].startTime, "Season not started");
        require(block.timestamp <= seasons[currentSeasonId].endTime, "Season ended");
        _;
    }

    modifier validSeason(uint256 seasonId) {
        require(seasonId > 0 && seasonId <= currentSeasonId, "Invalid season ID");
        _;
    }

    constructor() ERC721("Rising Tides Season Pass", "RTSP") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @dev Create a new season
     */
    function createSeason(
        string calldata name,
        uint256 startTime,
        uint256 endTime,
        uint256 passPrice
    ) external onlyRole(ADMIN_ROLE) {
        require(startTime > block.timestamp, "Start time must be in the future");
        require(endTime > startTime, "End time must be after start time");
        require(bytes(name).length > 0, "Season name cannot be empty");

        // End current season if active
        if (currentSeasonId > 0 && seasons[currentSeasonId].isActive) {
            seasons[currentSeasonId].isActive = false;
            emit SeasonEnded(currentSeasonId);
        }

        currentSeasonId++;
        seasons[currentSeasonId] = Season({
            id: currentSeasonId,
            name: name,
            startTime: startTime,
            endTime: endTime,
            passPrice: passPrice,
            isActive: true,
            totalPasses: 0,
            rewardPool: new address[](0),
            rewardAmounts: new uint256[](0)
        });

        emit SeasonCreated(currentSeasonId, name, startTime, endTime, passPrice);
    }

    /**
     * @dev Purchase season pass
     */
    function purchaseSeasonPass() external payable activeSeason whenNotPaused nonReentrant {
        Season storage season = seasons[currentSeasonId];
        require(msg.value >= season.passPrice, "Insufficient payment");
        require(!hasSeasonPass[currentSeasonId][msg.sender], "Already owns season pass");

        // Mint season pass NFT
        uint256 tokenId = nextTokenId++;
        _mint(msg.sender, tokenId);
        
        // Track ownership
        hasSeasonPass[currentSeasonId][msg.sender] = true;
        passTokenIds[currentSeasonId][msg.sender] = tokenId;
        tokenToSeason[tokenId] = currentSeasonId;
        tokenToPlayer[tokenId] = msg.sender;
        
        season.totalPasses++;

        // Initialize player stats
        seasonStats[currentSeasonId][msg.sender] = PlayerStats({
            totalEarnings: 0,
            totalSpent: 0,
            netValue: 0,
            lastUpdateTime: block.timestamp,
            hasPass: true
        });

        // Refund excess payment
        if (msg.value > season.passPrice) {
            payable(msg.sender).transfer(msg.value - season.passPrice);
        }

        emit SeasonPassPurchased(msg.sender, currentSeasonId, tokenId);
    }

    /**
     * @dev Update player statistics (called by game contracts)
     */
    function updatePlayerStats(
        address player,
        uint256 earnings,
        uint256 spent
    ) external onlyRole(ADMIN_ROLE) activeSeason {
        require(hasSeasonPass[currentSeasonId][player], "Player does not have season pass");

        PlayerStats storage stats = seasonStats[currentSeasonId][player];
        stats.totalEarnings += earnings;
        stats.totalSpent += spent;
        stats.netValue = int256(stats.totalEarnings) - int256(stats.totalSpent);
        stats.lastUpdateTime = block.timestamp;

        // Update leaderboard position
        _updateLeaderboard(player, currentSeasonId);

        emit PlayerStatsUpdated(player, currentSeasonId, stats.netValue);
    }

    /**
     * @dev Get leaderboard for a season
     */
    function getLeaderboard(uint256 seasonId, uint256 limit) 
        external 
        view 
        validSeason(seasonId) 
        returns (address[] memory players, int256[] memory scores) 
    {
        address[] memory seasonLeaderboard = leaderboards[seasonId];
        uint256 length = seasonLeaderboard.length > limit ? limit : seasonLeaderboard.length;
        
        players = new address[](length);
        scores = new int256[](length);
        
        for (uint256 i = 0; i < length; i++) {
            players[i] = seasonLeaderboard[i];
            scores[i] = seasonStats[seasonId][seasonLeaderboard[i]].netValue;
        }
        
        return (players, scores);
    }

    /**
     * @dev Get player's season statistics
     */
    function getPlayerStats(address player, uint256 seasonId) 
        external 
        view 
        validSeason(seasonId) 
        returns (PlayerStats memory) 
    {
        return seasonStats[seasonId][player];
    }

    /**
     * @dev Get player's leaderboard position
     */
    function getPlayerPosition(address player, uint256 seasonId) 
        external 
        view 
        validSeason(seasonId) 
        returns (uint256) 
    {
        return leaderboardPositions[seasonId][player];
    }

    /**
     * @dev End current season manually
     */
    function endSeason() external onlyRole(ADMIN_ROLE) {
        require(currentSeasonId > 0, "No season to end");
        require(seasons[currentSeasonId].isActive, "Season already ended");

        seasons[currentSeasonId].isActive = false;
        emit SeasonEnded(currentSeasonId);
    }

    /**
     * @dev Distribute rewards to top players
     */
    function distributeRewards(uint256 seasonId) external onlyRole(ADMIN_ROLE) validSeason(seasonId) {
        require(!seasons[seasonId].isActive, "Season still active");
        require(!seasonRewardsDistributed[seasonId], "Rewards already distributed");

        address[] memory seasonLeaderboard = leaderboards[seasonId];
        uint256 rewardCount = seasonLeaderboard.length > TOP_REWARDS_COUNT ? TOP_REWARDS_COUNT : seasonLeaderboard.length;
        
        // Calculate reward distribution (example: linear decay)
        uint256 totalPool = address(this).balance;
        uint256 distributedAmount = 0;

        for (uint256 i = 0; i < rewardCount; i++) {
            address player = seasonLeaderboard[i];
            // Higher rank gets higher reward (position 1 gets most)
            uint256 reward = (totalPool * (rewardCount - i)) / (rewardCount * (rewardCount + 1) / 2);
            
            if (reward > 0 && distributedAmount + reward <= totalPool) {
                payable(player).transfer(reward);
                distributedAmount += reward;
            }
        }

        seasonRewardsDistributed[seasonId] = true;
        emit RewardsDistributed(seasonId, distributedAmount);
    }

    /**
     * @dev Internal function to update leaderboard position
     */
    function _updateLeaderboard(address player, uint256 seasonId) private {
        address[] storage leaderboard = leaderboards[seasonId];
        uint256 currentPosition = leaderboardPositions[seasonId][player];
        int256 playerScore = seasonStats[seasonId][player].netValue;

        // If player not on leaderboard, add them
        if (currentPosition == 0) {
            leaderboard.push(player);
            currentPosition = leaderboard.length;
            leaderboardPositions[seasonId][player] = currentPosition;
        }

        // Bubble sort to maintain leaderboard order (optimize for small movements)
        uint256 position = currentPosition - 1; // Convert to 0-based index

        // Move up in rankings
        while (position > 0 && seasonStats[seasonId][leaderboard[position - 1]].netValue < playerScore) {
            // Swap positions
            address temp = leaderboard[position - 1];
            leaderboard[position - 1] = leaderboard[position];
            leaderboard[position] = temp;
            
            // Update position mappings
            leaderboardPositions[seasonId][temp] = position + 1;
            leaderboardPositions[seasonId][player] = position;
            
            position--;
        }

        // Move down in rankings
        while (position < leaderboard.length - 1 && seasonStats[seasonId][leaderboard[position + 1]].netValue > playerScore) {
            // Swap positions
            address temp = leaderboard[position + 1];
            leaderboard[position + 1] = leaderboard[position];
            leaderboard[position] = temp;
            
            // Update position mappings
            leaderboardPositions[seasonId][temp] = position + 1;
            leaderboardPositions[seasonId][player] = position + 2;
            
            position++;
        }

        emit LeaderboardUpdated(player, seasonId, leaderboardPositions[seasonId][player]);
    }

    /**
     * @dev Get season information
     */
    function getSeason(uint256 seasonId) external view validSeason(seasonId) returns (Season memory) {
        return seasons[seasonId];
    }

    /**
     * @dev Check if player has season pass
     */
    function playerHasSeasonPass(address player, uint256 seasonId) external view validSeason(seasonId) returns (bool) {
        return hasSeasonPass[seasonId][player];
    }

    /**
     * @dev Withdraw contract balance (admin only)
     */
    function withdraw(address to) external onlyRole(ADMIN_ROLE) {
        require(to != address(0), "Cannot withdraw to zero address");
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        
        payable(to).transfer(balance);
    }

    /**
     * @dev Override tokenURI to provide metadata
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        
        uint256 seasonId = tokenToSeason[tokenId];
        Season memory season = seasons[seasonId];
        
        // Return metadata URL (implement according to your metadata service)
        return string(abi.encodePacked(
            "https://risingtides.game/api/metadata/pass/",
            Strings.toString(seasonId),
            "/",
            Strings.toString(tokenId)
        ));
    }

    /**
     * @dev Pause the contract
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
     * @dev Override supportsInterface to resolve conflict between ERC721 and AccessControl
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Override _update to add pause functionality
     */
    function _update(address to, uint256 tokenId, address auth) internal override whenNotPaused returns (address) {
        return super._update(to, tokenId, auth);
    }
}