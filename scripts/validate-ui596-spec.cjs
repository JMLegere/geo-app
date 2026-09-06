#!/usr/bin/env node
"use strict";
const fs = require("node:fs");
const path = require("node:path");

function validateManifest(manifest, plan, expectedIds) {
  const errors = [];
  const decisions = [...manifest.questions, ...manifest.baseline, ...(manifest.direction ?? [])];
  const seen = new Set();
  const scenarios = new Map();
  for (const scenario of manifest.scenarios) {
    if (scenarios.has(scenario.id)) errors.push("Duplicate scenario " + scenario.id);
    scenarios.set(scenario.id, scenario);
  }
  for (const decision of decisions) {
    if (seen.has(decision.id)) errors.push("Duplicate decision " + decision.id);
    seen.add(decision.id);
    if (!expectedIds.includes(decision.id)) errors.push("Unexpected decision " + decision.id);
    if (typeof decision.answer !== "string" || !decision.answer.trim()) errors.push("Empty answer " + decision.id);
    if (!decision.scenario_ids?.length) errors.push("No scenarios for " + decision.id);
    for (const id of decision.scenario_ids ?? []) {
      if (!scenarios.has(id)) errors.push("Unknown scenario " + id + " for " + decision.id);
    }
  }
  for (const id of expectedIds) if (!seen.has(id)) errors.push("Missing decision " + id);
  const compiled = new Set();
  for (const pickle of plan) {
    const match = pickle.name.match(/^\[(UI596-\d{3})\] (.+)$/);
    if (!match) { errors.push("Missing scenario ID in " + pickle.name); continue; }
    const id = match[1];
    if (compiled.has(id)) errors.push("Duplicate compiled scenario " + id);
    compiled.add(id);
    const declared = scenarios.get(id);
    if (!declared) { errors.push("Uncatalogued scenario " + id); continue; }
    if (declared.title !== match[2]) errors.push("Title mismatch for " + id);
    if (path.normalize(declared.file) !== path.normalize(pickle.uri)) errors.push("Source mismatch for " + id);
  }
  for (const id of scenarios.keys()) if (!compiled.has(id)) errors.push("Scenario " + id + " not compiled");
  return errors;
}

async function main() {
  const { loadSources } = require("@cucumber/cucumber/api");
  const root = path.resolve(__dirname, "..");
  const manifest = JSON.parse(fs.readFileSync(path.join(root, "docs/specifications/ui596/decisions.json"), "utf8"));
  const sources = await loadSources({
    defaultDialect: "en", paths: ["features/ui596/*.feature"],
    names: [], tagExpression: "", order: "defined"
  }, { cwd: root });
  const expected = [
    ...Array.from({ length: 111 }, (_, i) => "Q" + String(i + 1).padStart(3, "0")),
    ...Array.from({ length: 27 }, (_, i) => "A" + String(i + 1).padStart(3, "0")),
    ...Array.from({ length: 12 }, (_, i) => "D" + String(i + 1).padStart(3, "0"))
  ];
  const errors = [
    ...sources.errors.map(e => e.uri + ":" + e.location.line + ": " + e.message),
    ...validateManifest(manifest, sources.plan, expected)
  ];
  // Match traceability tags to actual scenario declarations, not comments elsewhere.
  for (const scenario of manifest.scenarios) {
    const text = fs.readFileSync(path.join(root, scenario.file), "utf8");
    const lines = text.split(/\r?\n/);
    const index = lines.findIndex(line => line.includes("Scenario: [" + scenario.id + "]"));
    if (index < 0) continue; // The compiled-source check reports this.
    const tags = lines[index - 1].trim().split(/\s+/);
    for (const decision of [...manifest.questions, ...manifest.baseline, ...(manifest.direction ?? [])]) {
      if (decision.scenario_ids.includes(scenario.id) && !tags.includes("@" + decision.id)) {
        errors.push("Missing @" + decision.id + " on " + scenario.id);
      }
    }
    if (!tags.includes("@" + scenario.id)) errors.push("Missing scenario tag " + scenario.id);
  }
  if (errors.length) {
    for (const error of errors) console.error(error);
    process.exitCode = 1;
    return;
  }
  console.log("Parsed " + sources.plan.length + " target scenarios; traced 111 questions, 27 baseline records and 12 direction decisions.");
  console.log("Syntax and traceability only. No target UI step definitions or product acceptance tests were executed.");
}
module.exports = { validateManifest };
if (require.main === module) main().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});

