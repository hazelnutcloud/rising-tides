import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  namespace: "risingtides",
  tables: {
    PlayerPosition: {
      schema: {
        address: "address",
        q: "uint32",
        r: "uint32",
      },
      key: ["address"],
    },
  },
});
