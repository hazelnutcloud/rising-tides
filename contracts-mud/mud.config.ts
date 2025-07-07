import { defineWorld } from "@latticexyz/world";
import { encodeAbiParameters, stringToHex } from "viem";

const erc721ModuleArgs = encodeAbiParameters(
  [
    { type: "bytes14" },
    {
      type: "tuple",
      components: [{ type: "string" }, { type: "string" }, { type: "string" }],
    },
  ],
  [
    stringToHex("fishingrod", { size: 14 }),
    ["Rising Tides Fishing Rod", "RTFR", "http://api.risingtides.fun/rod/v1/"],
  ],
);

export default defineWorld({
  namespaces: {
    game: {
      tables: {
        // Player
        Player: "bool",
        Position: {
          id: "bytes32",
          x: "uint256",
          y: "uint256",
        },
        Moving: {
          id: "bytes32",
          moveStartTime: "uint256",
          moveDuration: "uint256",
          targetX: "uint256",
          targetY: "uint256",
        },
        InMap: "bytes32",
        Xp: "uint256",
        // Purchaseable
        Purchaseable: {
          id: "bytes32",
          cost: "uint256",
          minXp: "uint256",
        },
        // Map Config
        Map: "bool",
        MapConfig: {
          id: "bytes32",
          width: "uint32",
          height: "uint32",
          regionTypeMap: "bytes", // 1d array of map index to region type
          regionIdMap: "bytes", // 1d array of map index to region id (used for alias tables)
        },
        // General Counter Table
        Counter: "uint256",
        // Fishing Rod Configs
        FishingRodConfig: "bool",
        RodConfigStats: {
          id: "bytes32",
          minDurability: "uint256",
          maxDurability: "uint256",
          minMaxFishWeight: "uint256",
          maxMaxFishWeight: "uint256",
          minMulticatchRate: "uint256",
          maxMulticatchRate: "uint256",
          minMulticatchBonus: "uint256",
          maxMulticatchBonus: "uint256",
          minStrength: "uint256",
          maxStrength: "uint256",
          minEfficiency: "uint256",
          maxEfficiency: "uint256",
          compatibleBaitMask: "uint256",
        },
        // Fishing Rod Instances
        FishingRod: "bytes32",
        RodStats: {
          id: "bytes32",
          maxDurability: "uint256",
          currentDurability: "uint256",
          maxFishWeight: "uint256",
          multicatchRate: "uint256",
          multicatchBonus: "uint256",
          strength: "uint256",
          efficiency: "uint256",
          totalCatches: "uint256",
          bonuses: "bytes32[]",
          isStrange: "bool", // Whether this rod can gain titles
        },
        // Fishing Rod Bonuses i.e, enchantments, etc.
        BonusConfig: "bool",
        BonusConfigStats: {
          id: "bytes32",
          durabilityBonus: "uint256",
          efficiencyBonus: "uint256",
          critRateBonus: "uint256",
          maxWeightBonus: "uint256",
          strengthBonus: "uint256",
          freshnessModifier: "uint256",
          critMultiplierBonus: "uint256",
          regionMask: "uint256",
        },
        // Ship
        ShipConfig: "bool",
        ShipConfigStats: {
          id: "bytes32",
          enginePower: "uint256",
          weightCapacity: "uint256",
          fuelCapacity: "uint256",
          emptyWeight: "uint256",
          supportedRegionTypes: "uint256", // Bitfield for region type support
        },
        ShipEquipped: "bytes32",
        ShipOwned: "bool",
        // Fish
        FishSpecies: "bool",
        FishSpeciesStats: {
          id: "bytes32",
          minWeight: "uint256", // in kg with 1e18 precision
          maxWeight: "uint256", // in kg with 1e18 precision
          baseValue: "uint256", // in DBL per kg
          minCooldown: "uint256", // in seconds
          maxCooldown: "uint256", // in seconds
          decayRate: "uint256", // seconds for 100% freshness decay
          xpPerWeight: "uint256", // XP per kg with 1e18 precision
        },
        Fish: "bool",
        FishStats: {
          id: "bytes32",
          fishSpeciesId: "bytes32",
          weight: "uint256", // Exact weight passed by Fishing contract
          caughtAt: "uint256", // Timestamp for freshness
          valueModifier: "uint256",
          freshnessModifier: "uint256", // Affects freshness decay rate (100 = normal)
        },
        // Starter Kit
        StarterKit: {
          schema: {
            shipId: "bytes32",
            fuel: "uint256",
            baitId: "bytes32",
            baitAmount: "uint256",
          },
          key: [],
        },
      },
    },
  },
  modules: [
    {
      artifactPath:
        "@latticexyz/world-modules/out/PuppetModule.sol/PuppetModule.json",
      root: false,
      args: [],
    },
    {
      artifactPath:
        "@latticexyz/world-modules/out/ERC721Module.sol/ERC721Module.json",
      root: false,
      args: [
        {
          type: "bytes",
          value: erc721ModuleArgs,
        },
      ],
    },
  ],
});
