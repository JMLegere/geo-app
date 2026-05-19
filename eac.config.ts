export default {
  "adapters": [
    "product/superbdd"
  ],
  "waivers": [],
  "product": {
    "manifest": "product/manifest.ts",
    "requireBddForAllActions": true,
    "requireUnitForMutations": true
  },
  "cucumber": {
    "features": [
      "features/**/*.feature"
    ],
    "enforceFeatureInventory": true
  }
};
