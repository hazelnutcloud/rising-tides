import type { regionTypes } from "./region-types";

export type Map = {
  id: number;
  name: string;
  radius: number;
  travelCost: number;
  requiredLevel: 0;
  regions: Region[];
};

export type Region = {
  type: RegionType;
  availableFishIds: {
    day: number[];
    night: number[];
  };
  coordinates: Coordinate[];
};

export type Coordinate = {
  q: number;
  r: number;
};

export type RegionType = (typeof regionTypes)[number];

export type FishSpecies = {
  id: number;
  name: string;
  minWeight: number;
  maxWeight: number;
  baseValue: number;
  minCooldown: number;
  maxCooldown: number;
  decayRate: number;
  xpPerWeight: number;
};

export type ShopItem = {
  dblCost: number;
  requiredLevel: number;
  shopMapId: number;
};

export type Ship = {
  id: number;
  name: string;
  enginePower: number;
  weightCapacity: number;
  fuelCapacity: number;
  emptyWeight: number;
  supportedRegionTypes: RegionType[];
} & ShopItem;

export type FishInstance = {
  id: number;
  weight: number;
  caughtAt: number;
  isTrophyQuality: boolean;
  freshnessModifier: number;
};

export type CraftingMaterial = {
  id: number;
  name: string;
} & ShopItem;

export type FishingRod = {
  id: number;
  name: string;
  minStats: FishingRodStat;
  maxStats: FishingRodStat;
  compatibleBaitIds: number[];
};

export type Bait = {
  id: number;
  name: string;
  compatibleFishIds: number[];
} & ShopItem;

export type FishingRodInstance = {
  id: number;
  rodId: number;
  maxDurability: number;
  currentDurability: number;
  totalCatches: number;
  enchantments: EnchantmentType[];
} & Omit<FishingRodStat, "durability" | "freshnessModifier">;

export enum EnchantmentType {
  Lucky = 0,
  Icy = 1,
  Deadly = 2,
  Efficient = 3,
  Strong = 4,
  Tasty = 6,
}

export type FishingRodStat = {
  durability: number;
  efficiency: number;
  critRate: number;
  maxWeight: number;
  strength: number;
  freshnessModifier: number;
  critMultiplier: number;
};

export type Enchantment = {
  type: EnchantmentType;
  bonuses: FishingRodStat;
  regionRestrictions: RegionType[];
};

export type StrangeRodTitle = {
  name: string;
  threshold: number;
  bonuses: FishingRodStat;
  perfectCatch?: boolean;
  trophyQuality?: boolean;
  doubleCatch?: boolean;
};
