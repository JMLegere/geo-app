export default {
  paths: [
    "features/exploration-discovery-*.feature",
    "features/map-desktop-traversal.feature",
  ],
  require: ["test/superbdd/steps/**/*.cjs"],
  format: ["progress"],
  strict: true
};
