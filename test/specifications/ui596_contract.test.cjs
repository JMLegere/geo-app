const test = require("node:test");
const assert = require("node:assert/strict");
const { validateManifest } = require("../../scripts/validate-ui596-spec.cjs");

function fixture() {
  return {
    manifest: {
      questions: [{ id: "Q001", answer: "Preserve the selected view", scenario_ids: ["UI596-001"] }],
      baseline: [{ id: "A001", answer: "Five columns", scenario_ids: ["UI596-001"] }],
      scenarios: [{ id: "UI596-001", file: "features/ui596/a.feature", title: "A visible outcome" }]
    },
    plan: [{ name: "[UI596-001] A visible outcome", uri: "features/ui596/a.feature" }],
    expected: ["Q001", "A001"]
  };
}
test("accepts complete question and baseline traceability", () => {
  const f = fixture();
  assert.deepEqual(validateManifest(f.manifest, f.plan, f.expected), []);
});
test("includes later solution direction in exact traceability", () => {
  const f = fixture();
  f.manifest.direction = [{ id: "D001", answer: "Original art", scenario_ids: ["UI596-001"] }];
  f.expected.push("D001");
  assert.deepEqual(validateManifest(f.manifest, f.plan, f.expected), []);
  f.manifest.direction[0].answer = "";
  assert.match(validateManifest(f.manifest, f.plan, f.expected).join("\n"), /Empty answer D001/);
});
test("rejects an omitted source decision", () => {
  const f = fixture(); f.manifest.questions = [];
  assert.match(validateManifest(f.manifest, f.plan, f.expected).join("\n"), /Missing decision Q001/);
});
test("rejects duplicate decision identities", () => {
  const f = fixture(); f.manifest.questions.push(f.manifest.questions[0]);
  assert.match(validateManifest(f.manifest, f.plan, f.expected).join("\n"), /Duplicate decision Q001/);
});
test("rejects a reference to a nonexistent scenario", () => {
  const f = fixture(); f.manifest.questions[0].scenario_ids = ["UI596-999"];
  assert.match(validateManifest(f.manifest, f.plan, f.expected).join("\n"), /Unknown scenario UI596-999/);
});
test("rejects a scenario declaration absent from compiled Gherkin", () => {
  const f = fixture(); f.plan = [];
  assert.match(validateManifest(f.manifest, f.plan, f.expected).join("\n"), /not compiled/);
});
test("rejects a compiled scenario that was not catalogued", () => {
  const f = fixture(); f.plan.push({ name: "[UI596-002] Untracked", uri: "features/ui596/a.feature" });
  assert.match(validateManifest(f.manifest, f.plan, f.expected).join("\n"), /Uncatalogued scenario UI596-002/);
});
test("rejects a blank answer or untraceable requirement", () => {
  const f = fixture(); f.manifest.questions[0].answer = " "; f.manifest.questions[0].scenario_ids = [];
  assert.match(validateManifest(f.manifest, f.plan, f.expected).join("\n"), /Empty answer Q001/);
  assert.match(validateManifest(f.manifest, f.plan, f.expected).join("\n"), /No scenarios for Q001/);
});
test("rejects a scenario pointing to the wrong source file", () => {
  const f = fixture(); f.manifest.scenarios[0].file = "features/ui596/wrong.feature";
  assert.match(validateManifest(f.manifest, f.plan, f.expected).join("\n"), /Source mismatch/);
});
