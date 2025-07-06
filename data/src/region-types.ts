export const regionTypes = [
  {
    id: 1,
    name: "port",
    debugColor: "#8B4513",
  },
  {
    id: 2,
    name: "terrain",
    debugColor: "#228B22",
  },
  {
    id: 3,
    name: "coastal",
    debugColor: "#F4A460",
  },
  {
    id: 4,
    name: "shallow",
    debugColor: "#87CEEB",
  },
  {
    id: 5,
    name: "oceanic",
    debugColor: "#4682B4",
  },
  {
    id: 6,
    name: "abyssal",
    debugColor: "#191970",
  },
  {
    id: 7,
    name: "hadal",
    debugColor: "#000080",
  },
  {
    id: 8,
    name: "volcanic",
    debugColor: "#DC143C",
  },
  {
    id: 9,
    name: "mangrove",
    debugColor: "#556B2F",
  },
  {
    id: 10,
    name: "icy",
    debugColor: "#B0E0E6",
  },
  {
    id: 11,
    name: "reef",
    debugColor: "#FF7F50",
  },
] as const;

export type RegionType = (typeof regionTypes)[number];
