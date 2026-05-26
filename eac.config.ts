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
  },
  "design": {
    "contracts": [
      "product/design/**/*.atom",
      "product/design/**/*.molecule",
      "product/design/**/*.organism",
      "product/design/**/*.template",
      "product/design/**/*.page"
    ]
  },
  "uiActions": {
    "evidence": [
      "artifacts/eac/ui-actions.json"
    ]
  }
};
