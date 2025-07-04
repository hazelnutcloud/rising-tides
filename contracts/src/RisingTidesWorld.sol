// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
                                                                               ,----,
                                               ,--.                          ,/   .`|
,-.----.     ,---,  .--.--.      ,---,       ,--.'|  ,----..               ,`   .'  :   ,---,    ,---,        ,---,.  .--.--.
\    /  \ ,`--.' | /  /    '. ,`--.' |   ,--,:  : | /   /   \            ;    ;     /,`--.' |  .'  .' `\    ,'  .' | /  /    '.
;   :    \|   :  :|  :  /`. / |   :  :,`--.'`|  ' :|   :     :         .'___,/    ,' |   :  :,---.'     \ ,---.'   ||  :  /`. /
|   | .\ ::   |  ';  |  |--`  :   |  '|   :  :  | |.   |  ;. /         |    :     |  :   |  '|   |  .`\  ||   |   .';  |  |--`
.   : |: ||   :  ||  :  ;_    |   :  |:   |   \ | :.   ; /--`          ;    |.';  ;  |   :  |:   : |  '  |:   :  |-,|  :  ;_
|   |  \ :'   '  ; \  \    `. '   '  ;|   : '  '; |;   | ;  __         `----'  |  |  '   '  ;|   ' '  ;  ::   |  ;/| \  \    `.
|   : .  /|   |  |  `----.   \|   |  |'   ' ;.    ;|   : |.' .'            '   :  ;  |   |  |'   | ;  .  ||   :   .'  `----.   \
;   | |  \'   :  ;  __ \  \  |'   :  ;|   | | \   |.   | '_.' :            |   |  '  '   :  ;|   | :  |  '|   |  |-,  __ \  \  |
|   | ;\  \   |  ' /  /`--'  /|   |  ''   : |  ; .''   ; : \  |            '   :  |  |   |  ''   : | /  ; '   :  ;/| /  /`--'  /
:   ' | \.'   :  |'--'.     / '   :  ||   | '`--'  '   | '/  .'            ;   |.'   '   :  ||   | '` ,/  |   |    \'--'.     /
:   : :-' ;   |.'   `--'---'  ;   |.' '   : |      |   :    /              '---'     ;   |.' ;   :  .'    |   :   .'  `--'---'
|   |.'   '---'               '---'   ;   |.'       \   \ .'                         '---'   |   ,.'      |   | ,'
`---'                                 '---'          `---`                                   '---'        `----'

                                                $DBL - Doubloons of the Seven Seas
*/

import {IERC20} from "../lib/forge-std/src/interfaces/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IRisingTidesInventory} from "./interfaces/IRisingTidesInventory.sol";
import {IRisingTidesFishing} from "./interfaces/IRisingTidesFishing.sol";
import {IRisingTidesWorld} from "./interfaces/IRisingTidesWorld.sol";

contract RisingTidesWorld is IRisingTidesWorld, AccessControl, Pausable {
    struct GameConfig {
        uint256 maxPlayersPerShard;
        uint256 fuelEfficiencyModifier;
        uint256 baseMovementTime; // Base time in seconds to move one hex
        uint256 maxStepsPerMove; // Maximum steps allowed in one transaction
    }

    mapping(address => Player) public players;
    mapping(uint256 => Map) public maps;
    mapping(uint256 => mapping(uint256 => uint256)) public hexToRegion;
    mapping(uint256 => uint256) public shardPlayerCount;
    mapping(uint256 => uint256) public levelThresholds;

    uint256 public totalShards;
    uint256 public totalMaps;
    uint256 public maxLevel;

    GameConfig public gameConfig;

    IERC20 public doubloons;
    IRisingTidesInventory public inventory;
    IRisingTidesFishing public fishContract;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant GAME_MASTER_ROLE = keccak256("GAME_MASTER_ROLE");
    bytes32 public constant FISHING_CONTRACT_ROLE = keccak256("FISHING_CONTRACT_ROLE");

    uint256 public constant REGION_TYPE_PORT = 1;
    uint256 public constant REGION_TYPE_TERRAIN = 2;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MIN_ENGINE_POWER = 10e18; // 10 engine power with 1e18 precision
    uint256 public constant MAX_MOVEMENT_QUEUE = 10;

    event PlayerRegistered(address indexed player, uint256 shardId, int32 q, int32 r, uint256 mapId);
    event PlayerMoved(
        address indexed player, uint256 indexed shardId, uint256 indexed mapId, uint256 segmentTime, Coordinate[] path
    );
    event PlayerTraveledMap(address indexed player, uint256 fromMapId, uint256 toMapId, uint256 cost);
    event ShardReassigned(address indexed player, uint256 oldShardId, uint256 newShardId);
    event XPGranted(address indexed player, uint256 amount, uint256 newTotalXP);

    modifier onlyRegistered() {
        if (!players[msg.sender].isRegistered) revert PlayerNotRegistered();
        _;
    }

    constructor(address _doubloons, address _inventory, address _admin, address _gameMaster) {
        doubloons = IERC20(_doubloons);
        inventory = IRisingTidesInventory(_inventory);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(GAME_MASTER_ROLE, _gameMaster);

        gameConfig = GameConfig({
            maxPlayersPerShard: 100,
            fuelEfficiencyModifier: 1e17, // 0.1 fuel per engine power per hex tile
            baseMovementTime: 1, // 1 seconds base movement time
            maxStepsPerMove: 5 // Max 5 steps per transaction
        });

        totalShards = 1;
    }

    /*//////////////////////////////////////////////////////////////
                            COORDINATE HELPERS
    //////////////////////////////////////////////////////////////*/

    function packCoordinates(int32 q, int32 r) public pure returns (uint256) {
        return (uint256(uint32(q)) << 32) | uint256(uint32(r));
    }

    function unpackCoordinates(uint256 packed) public pure returns (int32 q, int32 r) {
        q = int32(uint32(packed >> 32));
        r = int32(uint32(packed));
    }

    /*//////////////////////////////////////////////////////////////
                            REGION MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function setHexRegion(uint256 mapId, uint256 regionId, int32[] calldata qs, int32[] calldata rs)
        external
        onlyRole(GAME_MASTER_ROLE)
    {
        for (uint256 i = 0; i < qs.length; i++) {
            int32 q = qs[i];
            int32 r = rs[i];
            hexToRegion[mapId][packCoordinates(q, r)] = regionId;
        }
    }

    function getRegionId(uint256 mapId, int32 q, int32 r) public view returns (uint256) {
        return hexToRegion[mapId][packCoordinates(q, r)];
    }

    function getRegionType(uint256 mapId, int32 q, int32 r) public view returns (uint256) {
        uint256 regionId = getRegionId(mapId, q, r);
        return regionId & 0xFF;
    }

    function isPortRegion(uint256 mapId, int32 q, int32 r) public view returns (bool) {
        return getRegionType(mapId, q, r) == REGION_TYPE_PORT;
    }

    /*//////////////////////////////////////////////////////////////
                            MAP MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function addMap(uint256 mapId, string memory name, uint256 travelCost, uint256 requiredLevel, int32 radius)
        external
        onlyRole(GAME_MASTER_ROLE)
    {
        if (maps[mapId].exists) revert MapAlreadyExists();
        if (radius <= 0) revert InvalidBoundaries();

        maps[mapId] =
            Map({name: name, travelCost: travelCost, requiredLevel: requiredLevel, radius: radius, exists: true});

        if (mapId >= totalMaps) {
            totalMaps = mapId + 1;
        }
    }

    /*//////////////////////////////////////////////////////////////
                            PLAYER REGISTRATION
    //////////////////////////////////////////////////////////////*/

    function registerPlayer(uint256 mapId, int32 spawnQ, int32 spawnR) external whenNotPaused {
        if (players[msg.sender].isRegistered) revert PlayerAlreadyRegistered();
        if (!maps[mapId].exists) revert InvalidMap();
        if (!isValidPosition(mapId, spawnQ, spawnR)) revert InvalidPosition();
        if (!isPortRegion(mapId, spawnQ, spawnR)) {
            revert MustSpawnInPortRegion();
        }

        uint256 assignedShard = _getOptimalShard();

        Player storage player = players[msg.sender];
        player.mapId = mapId;
        player.shardId = assignedShard;
        player.xp = 0;
        player.moveStartTime = block.timestamp;
        player.segmentDuration = 0;
        player.isRegistered = true;
        player.currentPathIndex = 0;

        // Initialize with spawn position
        player.path.push(Coordinate({q: spawnQ, r: spawnR}));

        shardPlayerCount[assignedShard]++;

        inventory.mintStarterKit(msg.sender);

        emit PlayerRegistered(msg.sender, assignedShard, spawnQ, spawnR, mapId);
    }

    /*//////////////////////////////////////////////////////////////
                            PLAYER MOVEMENT
    //////////////////////////////////////////////////////////////*/

    function move(Direction[] calldata directions) external whenNotPaused onlyRegistered {
        if (directions.length == 0) revert NoDirectionsProvided();
        if (directions.length > gameConfig.maxStepsPerMove) {
            revert TooManySteps();
        }

        Player storage player = players[msg.sender];

        (int32 currentQ, int32 currentR) = getCurrentPosition(msg.sender);

        _clearPath(msg.sender);
        player.path.push(Coordinate({q: currentQ, r: currentR}));

        uint256 shipId = inventory.getEquippedShip(msg.sender);
        if (shipId == 0) revert NoShipEquipped();

        (uint256 enginePower, uint256 weightCapacity,) = inventory.getShipStats(shipId);

        // Get ship's supported region types
        IRisingTidesInventory.Ship memory shipInfo = inventory.getShipInfo(shipId);
        // Engine power is expected to be in 1e18 precision
        if (enginePower < MIN_ENGINE_POWER) revert ShipEngineTooWeak();

        // Get actual cargo weight from Fish contract
        // Both cargoWeight and weightCapacity should be in 1e18 precision
        uint256 cargoWeight = inventory.getPlayerCargoWeight(msg.sender);
        if (cargoWeight > weightCapacity) revert CargoExceedsCapacity();

        // Calculate time per segment
        uint256 segmentTime = calculateMovementTime(
            enginePower,
            cargoWeight,
            1 // Time for one hex
        );

        // Build path and validate positions
        for (uint256 i = 0; i < directions.length; i++) {
            (int32 dq, int32 dr) = getDirectionOffset(directions[i]);
            int32 nextQ = currentQ + dq;
            int32 nextR = currentR + dr;

            if (!isValidPosition(player.mapId, nextQ, nextR)) {
                revert InvalidPosition();
            }

            // Check if ship can navigate to this region type
            uint256 regionType = getRegionType(player.mapId, nextQ, nextR);
            if (regionType != 0 && (shipInfo.supportedRegionTypes & (uint256(1) << regionType)) == 0) {
                revert ShipCannotNavigateRegion();
            }
            if (regionType == 2) revert ShipCannotNavigateRegion();

            // Add to path
            player.path.push(Coordinate({q: nextQ, r: nextR}));

            currentQ = nextQ;
            currentR = nextR;
        }

        uint256 totalFuelCost = calculateFuelCost(enginePower, directions.length);

        uint256 playerFuel = inventory.getFuel(msg.sender);
        if (playerFuel < totalFuelCost) revert InsufficientFuel();

        inventory.consumeFuel(msg.sender, totalFuelCost);

        player.segmentDuration = segmentTime;
        player.moveStartTime = block.timestamp;
        player.currentPathIndex = 0;
        
        emit PlayerMoved(msg.sender, player.shardId, player.mapId, segmentTime, player.path);
    }

    function stopMoving() external onlyRegistered {
        Player storage player = players[msg.sender];
        if (!isMoving(msg.sender)) revert NotCurrentlyMoving();

        // Get current position and update path to only contain that position
        (int32 currentQ, int32 currentR) = getCurrentPosition(msg.sender);

        _clearPath(msg.sender);
        player.path.push(Coordinate({q: currentQ, r: currentR}));
        player.segmentDuration = 0;
        player.currentPathIndex = 0;

        emit PlayerMoved(
            msg.sender,
            player.shardId,
            player.mapId,
            0, // duration 0 indicates stop
            player.path
        );
    }

    function travelToMap(uint256 newMapId, int32 spawnQ, int32 spawnR) external whenNotPaused onlyRegistered {
        Player storage player = players[msg.sender];

        if (isMoving(msg.sender)) revert CannotTravelWhileMoving();

        // Get current position
        (int32 currentQ, int32 currentR) = getCurrentPosition(msg.sender);

        if (!maps[newMapId].exists) revert InvalidMap();
        if (newMapId == player.mapId) revert AlreadyOnThisMap();
        if (!isPortRegion(player.mapId, currentQ, currentR)) {
            revert MustBeAtPortToTravel();
        }
        if (!isPortRegion(newMapId, spawnQ, spawnR)) {
            revert MustTravelToPortRegion();
        }
        if (!isValidPosition(newMapId, spawnQ, spawnR)) {
            revert InvalidPosition();
        }
        if (getPlayerLevel(msg.sender) < maps[newMapId].requiredLevel) {
            revert InsufficientLevel();
        }

        // Check if ship can navigate to the destination port
        uint256 shipId = inventory.getEquippedShip(msg.sender);
        if (shipId == 0) revert NoShipEquipped();

        IRisingTidesInventory.Ship memory shipInfo = inventory.getShipInfo(shipId);
        uint256 destinationRegionType = getRegionType(newMapId, spawnQ, spawnR);
        if (destinationRegionType != 0 && (shipInfo.supportedRegionTypes & (uint256(1) << destinationRegionType)) == 0)
        {
            revert ShipCannotNavigateRegion();
        }

        uint256 travelCost = maps[newMapId].travelCost;
        if (doubloons.balanceOf(msg.sender) < travelCost) {
            revert InsufficientDoubloons();
        }

        doubloons.transferFrom(msg.sender, address(this), travelCost);

        emit PlayerTraveledMap(msg.sender, player.mapId, newMapId, travelCost);

        // Update to new map and position
        player.mapId = newMapId;
        _clearPath(msg.sender);
        player.path.push(Coordinate({q: spawnQ, r: spawnR}));
        player.segmentDuration = 0;
        player.currentPathIndex = 0;
    }

    /*//////////////////////////////////////////////////////////////
                            XP MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function grantXP(address player, uint256 amount) external onlyRole(FISHING_CONTRACT_ROLE) {
        if (!players[player].isRegistered) revert PlayerNotRegistered();
        
        players[player].xp += amount;
        
        emit XPGranted(player, amount, players[player].xp);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function reassignPlayerShard(address playerAddress, uint256 newShardId) external onlyRole(ADMIN_ROLE) {
        if (!players[playerAddress].isRegistered) revert PlayerNotRegistered();
        if (newShardId == 0 || newShardId > totalShards) revert InvalidShard();

        Player storage player = players[playerAddress];
        uint256 oldShardId = player.shardId;

        if (oldShardId != newShardId) {
            shardPlayerCount[oldShardId]--;
            shardPlayerCount[newShardId]++;
            player.shardId = newShardId;

            emit ShardReassigned(playerAddress, oldShardId, newShardId);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            CALCULATION HELPERS
    //////////////////////////////////////////////////////////////*/

    function calculateHexDistance(int32 q1, int32 r1, int32 q2, int32 r2) public pure returns (uint256) {
        int32 dq = q2 - q1;
        int32 dr = r2 - r1;
        int32 ds = -dq - dr;

        uint32 absQ = dq >= 0 ? uint32(dq) : uint32(-dq);
        uint32 absR = dr >= 0 ? uint32(dr) : uint32(-dr);
        uint32 absS = ds >= 0 ? uint32(ds) : uint32(-ds);

        return uint256((absQ + absR + absS) / 2);
    }

    function calculateFuelCost(uint256 enginePower, uint256 distance) public view returns (uint256) {
        // enginePower is in 1e18 precision
        // distance is in whole hex units
        // fuelEfficiencyModifier is in 1e18 precision
        // Result: fuel units in 1e18 precision
        return (enginePower * distance * gameConfig.fuelEfficiencyModifier) / PRECISION;
    }

    function isValidPosition(uint256 mapId, int32 q, int32 r) public view returns (bool) {
        Map memory map = maps[mapId];
        if (!map.exists) return false;

        // For hexagonal map with axial coordinates:
        // Valid positions satisfy: |q| <= radius, |r| <= radius, |q + r| <= radius
        int32 s = -q - r; // The third axial coordinate

        // Use absolute values for comparison
        uint32 absQ = q >= 0 ? uint32(q) : uint32(-q);
        uint32 absR = r >= 0 ? uint32(r) : uint32(-r);
        uint32 absS = s >= 0 ? uint32(s) : uint32(-s);

        return absQ <= uint32(map.radius) && absR <= uint32(map.radius) && absS <= uint32(map.radius);
    }

    function getDirectionOffset(Direction dir) public pure returns (int32 dq, int32 dr) {
        if (dir == Direction.EAST) return (1, 0);
        if (dir == Direction.NORTHEAST) return (1, -1);
        if (dir == Direction.NORTHWEST) return (0, -1);
        if (dir == Direction.WEST) return (-1, 0);
        if (dir == Direction.SOUTHWEST) return (-1, 1);
        if (dir == Direction.SOUTHEAST) return (0, 1);
    }

    function calculateMovementTime(uint256 enginePower, uint256 totalWeight, uint256 distance)
        public
        view
        returns (uint256)
    {
        // enginePower is in 1e18 precision
        // totalWeight is in 1e18 precision
        // distance is in whole hex units
        // Result: time in seconds with 1e18 precision
        return (gameConfig.baseMovementTime * distance * totalWeight * PRECISION) / enginePower;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    function getPlayerLevel(address playerAddress) public view returns (uint256 level) {
        uint256 xp = players[playerAddress].xp;
        
        // Binary search for the appropriate level
        uint256 left = 1;
        uint256 right = maxLevel;
        uint256 result = 1;
        
        while (left <= right) {
            uint256 mid = (left + right) / 2;
            
            if (xp >= levelThresholds[mid]) {
                // Player has enough XP for this level
                result = mid;
                left = mid + 1; // Search for potentially higher levels
            } else {
                // Player doesn't have enough XP for this level
                right = mid - 1; // Search in lower levels
            }
        }
        
        return result;
    }

    function getCurrentPosition(address playerAddress) public view returns (int32 q, int32 r) {
        Player storage player = players[playerAddress];

        if (player.path.length == 0) {
            return (0, 0); // No path set
        }

        if (player.path.length == 1) {
            return (player.path[0].q, player.path[0].r);
        }

        uint256 elapsedTime = block.timestamp - player.moveStartTime;
        uint256 totalSegments = player.path.length - 1;
        // segmentDuration is in 1e18 precision, so totalDuration will be too
        uint256 totalDuration = player.segmentDuration * totalSegments;

        // Convert elapsedTime to 1e18 precision for comparison
        if (elapsedTime * PRECISION >= totalDuration) {
            // Movement complete, return last position
            uint256 lastIndex = player.path.length - 1;
            return (player.path[lastIndex].q, player.path[lastIndex].r);
        }

        // Calculate which segment we're on
        // Convert elapsedTime to 1e18 precision for division
        uint256 currentSegment = (elapsedTime * PRECISION) / player.segmentDuration;

        // Check if we're in the middle of a segment
        uint256 segmentProgress = (elapsedTime * PRECISION) % player.segmentDuration;

        // If we have any progress into the current segment, round up to the next position
        if (segmentProgress > 0 && currentSegment < totalSegments) {
            currentSegment = currentSegment + 1;
        }

        // Ensure we don't exceed the path length
        if (currentSegment >= player.path.length) {
            currentSegment = player.path.length - 1;
        }

        return (player.path[currentSegment].q, player.path[currentSegment].r);
    }

    function isMoving(address playerAddress) public view returns (bool) {
        Player storage player = players[playerAddress];
        if (player.path.length <= 1) return false;

        uint256 elapsedTime = block.timestamp - player.moveStartTime;
        // segmentDuration is in 1e18 precision
        uint256 totalDuration = player.segmentDuration * (player.path.length - 1);

        // Convert elapsedTime to 1e18 precision for comparison
        return elapsedTime * PRECISION < totalDuration;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _clearPath(address playerAddress) private {
        Player storage player = players[playerAddress];
        delete player.path;
        player.currentPathIndex = 0;
    }

    function _getOptimalShard() private view returns (uint256) {
        uint256 minPlayers = type(uint256).max;
        uint256 optimalShard = 1;

        for (uint256 i = 1; i <= totalShards; i++) {
            if (shardPlayerCount[i] < minPlayers && shardPlayerCount[i] < gameConfig.maxPlayersPerShard) {
                minPlayers = shardPlayerCount[i];
                optimalShard = i;
            }
        }

        return optimalShard;
    }

    function setGameConfig(
        uint256 maxPlayersPerShard,
        uint256 fuelEfficiencyModifier,
        uint256 baseMovementTime,
        uint256 maxStepsPerMove
    ) external onlyRole(ADMIN_ROLE) {
        gameConfig.maxPlayersPerShard = maxPlayersPerShard;
        gameConfig.fuelEfficiencyModifier = fuelEfficiencyModifier;
        gameConfig.baseMovementTime = baseMovementTime;
        gameConfig.maxStepsPerMove = maxStepsPerMove;
    }

    function setTotalShards(uint256 _totalShards) external onlyRole(ADMIN_ROLE) {
        if (_totalShards == 0) revert MustHaveAtLeastOneShard();
        totalShards = _totalShards;
    }

    function pauseGame() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpauseGame() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function setContracts(address _inventory, address _fish) external onlyRole(ADMIN_ROLE) {
        inventory = IRisingTidesInventory(_inventory);
        fishContract = IRisingTidesFishing(_fish);
    }

    function setLevelThresholds(uint256[] calldata levels, uint256[] calldata thresholds) external onlyRole(ADMIN_ROLE) {
        require(levels.length == thresholds.length, "Arrays must have same length");
        require(levels.length > 0, "Must provide at least one level");
        
        uint256 previousThreshold = 0;
        for (uint256 i = 0; i < levels.length; i++) {
            require(levels[i] > 0, "Level must be greater than 0");
            require(thresholds[i] > previousThreshold, "Thresholds must be increasing");
            levelThresholds[levels[i]] = thresholds[i];
            if (levels[i] > maxLevel) {
                maxLevel = levels[i];
            }
            previousThreshold = thresholds[i];
        }
    }

    /*//////////////////////////////////////////////////////////////
                            ROLE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function grantAdminRole(address _admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, _admin);
    }

    function grantGameMasterRole(address _gameMaster) external onlyRole(ADMIN_ROLE) {
        grantRole(GAME_MASTER_ROLE, _gameMaster);
    }

    function revokeGameMasterRole(address _gameMaster) external onlyRole(ADMIN_ROLE) {
        revokeRole(GAME_MASTER_ROLE, _gameMaster);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getPlayerLocation(address player) external view returns (int32 q, int32 r, uint256 mapId) {
        (q, r) = getCurrentPosition(player);
        mapId = players[player].mapId;
    }

    function getPlayerInfo(address player) external view returns (Player memory) {
        return players[player];
    }

    function validateFishingLocation(address player)
        external
        view
        returns (bool canFish, int32 q, int32 r, uint256 regionId, uint256 mapId)
    {
        if (!players[player].isRegistered) revert PlayerNotRegistered();

        // Get current position
        (q, r) = getCurrentPosition(player);

        // Check if player is moving
        if (isMoving(player)) {
            return (false, q, r, 0, 0);
        }

        // Get region ID for current position
        regionId = getRegionId(players[player].mapId, q, r);

        // For now, players can fish anywhere except ports
        // This can be extended to check for specific fishing regions
        canFish = !isPortRegion(players[player].mapId, q, r);

        mapId = players[player].mapId;
    }
}
