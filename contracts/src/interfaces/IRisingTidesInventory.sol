// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRisingTidesInventory {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Ship {
        uint256 enginePower;
        uint256 weightCapacity;
        uint256 fuelCapacity;
        uint256 emptyWeight;
        uint256 supportedRegionTypes; // Bitfield for region type support
        bool exists;
    }

    struct Fish {
        uint256 fishId;              // Species ID from Fishing contract
        uint256 weight;              // Exact weight passed by Fishing contract
        uint256 caughtAt;            // Timestamp for freshness
        bool isTrophyQuality;        // 1.5x value when selling
        uint256 freshnessModifier;   // Affects freshness decay rate (100 = normal)
    }

    struct StarterKit {
        uint256 shipId;
        uint256 fuel;
        uint256[] baitIds;
        uint256[] baitAmounts;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    // Ship events
    event ShipGranted(address indexed player, uint256 indexed shipId);
    event ShipEquipped(address indexed player, uint256 indexed shipId, uint256 previousShipId);
    
    // Rod events
    event RodEquipped(address indexed player, uint256 indexed tokenId);
    event RodUnequipped(address indexed player, uint256 indexed tokenId);
    
    // Fish events - include all fish data for reconstruction
    event FishAdded(
        address indexed player,
        uint256 indexed fishId,
        uint256 weight,
        bool isTrophyQuality,
        uint256 freshnessModifier,
        uint256 timestamp
    );
    event FishRemoved(
        address indexed player,
        uint256 indexed fishId,
        uint256 weight,
        uint256 fishIndex
    );
    
    // Resource events - separate events for each resource type
    event FuelChanged(address indexed player, uint256 newAmount, int256 delta);
    event BaitChanged(address indexed player, uint256 indexed baitId, uint256 newAmount, int256 delta);
    event MaterialsChanged(address indexed player, uint256 indexed materialId, uint256 newAmount, int256 delta);
    
    // Starter kit event
    event StarterKitMinted(address indexed player, uint256 shipId, uint256 fuel);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error NoShipEquipped();
    error ShipNotOwned();
    error InvalidShipId();
    error CargoExceedsCapacity();
    error InsufficientFuel();
    error InsufficientBait();
    error InsufficientMaterials();
    error InvalidFishIndex();
    error RodAlreadyEquipped();
    error NoRodEquipped();
    error NotRodOwner();
    error MustBeAtPort();
    error OnlyWorld();
    error OnlyFishing();
    error OnlyPort();

    /*//////////////////////////////////////////////////////////////
                            SHIP FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function equipShip(address player, uint256 shipId) external;

    function getEquippedShip(address player) external view returns (uint256 shipId);

    function getShipStats(uint256 shipId)
        external
        view
        returns (
            uint256 enginePower,
            uint256 weightCapacity,
            uint256 fuelCapacity
        );

    function hasShip(address player, uint256 shipId) external view returns (bool);

    function grantShip(address player, uint256 shipId) external;

    function getTotalWeight(address player) external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            RESOURCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getFuel(address player) external view returns (uint256);

    function addFuel(address player, uint256 amount) external;

    function consumeFuel(address player, uint256 amount) external;

    function getBait(address player, uint256 baitId) external view returns (uint256);

    function addBait(address player, uint256 baitId, uint256 amount) external;

    function consumeBait(address player, uint256 baitId, uint256 amount) external;

    function getMaterials(address player, uint256 materialId) external view returns (uint256);

    function addMaterials(address player, uint256 materialId, uint256 amount) external;

    function consumeMaterials(address player, uint256 materialId, uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                            FISH FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addFish(
        address player,
        uint256 fishId,
        uint256 weight,
        bool isTrophyQuality,
        uint256 freshnessModifier
    ) external;

    function removeFish(address player, uint256 index) external returns (Fish memory);

    function getFish(address player) external view returns (Fish[] memory);

    function getPlayerCargoWeight(address player) external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            ROD FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function equipRod(address player, uint256 tokenId) external;

    function unequipRod(address player) external;

    function getEquippedRod(address player) external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            STARTER KIT
    //////////////////////////////////////////////////////////////*/

    function mintStarterKit(address player) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getShipOwnership(address player) external view returns (uint256);

    function getShipInfo(uint256 shipId) external view returns (Ship memory);

    function getStarterKit() external view returns (StarterKit memory);

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setShipType(uint256 shipId, Ship memory ship) external;

    function setStarterKit(StarterKit memory kit) external;

    function setAuthorizedContract(address contractAddress, bool authorized) external;
}