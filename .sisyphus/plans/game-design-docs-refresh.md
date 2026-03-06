# Game Design Docs Refresh

## TL;DR

> **Quick Summary**: Create a new `docs/game-design.md` as the central game design reference, then update existing docs and AGENTS.md with cross-references and minimal design-context additions. All game design vision lives in game-design.md; technical docs stay accurate to current code.
> 
> **Deliverables**:
> - New `docs/game-design.md` (~200-250 lines) — comprehensive game design reference
> - Updated `docs/INDEX.md` — add game-design.md to reading guide
> - Updated `AGENTS.md` (root) — working title, Quick Reference, Future Work
> - Updated `docs/architecture.md` — glossary updates, design cross-reference
> - Updated `docs/game-loop.md` — design target notes for discovery pipeline
> - Updated `docs/data-model.md` — inventory model design notes
> 
> **Estimated Effort**: Medium
> **Parallel Execution**: YES — 2 waves
> **Critical Path**: Task 1 (game-design.md) → Task 7 (verification)

---

## Context

### Original Request
Refresh all documentation files with game design information captured during an extensive design jam session. The designer established the game's creative vision, core mechanics, visual direction, and progression systems through interactive brainstorming.

### Interview Summary
**Key Discussions** (see `.sisyphus/drafts/game-design-jam.md` for full record):
- Game identity: Working title "EarthNova", cozy nature exploration genre
- Visual style: Top-down watercolour, iOS-clean + PuffPals-cute aesthetic
- 4-tab navigation: Map | Home | Town | Pack
- TCG-style dopamine model with rarity-scaled discovery reveals
- Inventory system: Species as collectible items (not binary flags), stacked in Pack
- Museum (permanent donations, habitat wings, grid display) vs Sanctuary (flexible, grid-based zoo builder)
- NPCs: Full characters discovered on map via milestone + location triggers
- Daily world seed at midnight GMT (Wordle-style shared daily content)
- OSRS-style engagement intensity spectrum (passive → active → high active)
- Treasure maps as the quest system
- 6 collectible categories (Fauna now, Plants/Minerals/Fossils future)
- Sub-collection sets (habitat, taxonomic, continent, rarity, themed, NPC bundles)

### Metis Review
**Key Insight**: Design intent vs implementation reality boundary.
- Technical docs (`architecture.md`, `game-loop.md`, `data-model.md`) must remain accurate to CURRENT CODE
- Design vision goes in `game-design.md` as the single source of truth
- When design context is added to technical docs, it must be clearly marked (separate section, "Design Target:" prefix)
- `game-design.md` should mark decisions as Confirmed / Tentative / Deferred
- AGENTS.md gets minimal updates (working title, Future Work) — not full game design content

---

## Work Objectives

### Core Objective
Create a comprehensive game design reference document and update existing documentation to cross-reference it, so agents working on this project understand both what IS built and what the design INTENDS.

### Concrete Deliverables
- `docs/game-design.md` — new file, ~200-250 lines
- `docs/INDEX.md` — updated with game-design.md entry
- `AGENTS.md` (root) — updated subtitle, Quick Reference, Future Work
- `docs/architecture.md` — updated glossary, design cross-reference
- `docs/game-loop.md` — design target section for discovery
- `docs/data-model.md` — design target section for inventory model

### Definition of Done
- [x] `docs/game-design.md` exists and covers all confirmed design decisions
- [x] All docs cross-reference `game-design.md` where relevant
- [x] Technical docs remain accurate to current code (no aspirational content presented as implemented)
- [x] AGENTS.md Future Work section reflects design jam outcomes
- [x] All files pass consistency check (species count, habitat count, feature list)

### Must Have
- Clear separation between "what IS built" and "what WILL be built"
- Design decisions marked as Confirmed / Tentative / Deferred
- Designer's meta-philosophy captured: "ongoing conversation, not gospel"
- All deferred decisions documented AS deferred (not omitted)

### Must NOT Have (Guardrails)
- Do NOT change technical doc diagrams (layer diagram, initialization chain, pipeline) to show unbuilt features
- Do NOT present design intent as implemented behavior in technical docs
- Do NOT add full game design content to AGENTS.md (it belongs in game-design.md)
- Do NOT update child AGENTS.md files (out of scope — those describe current code)
- Do NOT update `docs/state.md` or `docs/tech-stack.md` (no design changes affect them)
- Do NOT change code (this is documentation only)

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: N/A (documentation task)
- **Automated tests**: None — this is a docs-only change
- **Framework**: N/A

### QA Policy
Every task includes agent-executed QA scenarios. Evidence saved to `.sisyphus/evidence/task-{N}-*.txt`.

- **Documentation tasks**: Use Bash (wc, grep, cat) to verify file existence, line counts, content presence
- **Cross-reference checks**: Use Grep to verify consistency across files

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately — all independent):
├── Task 1: Create docs/game-design.md [writing]
├── Task 2: Update docs/INDEX.md [quick]
├── Task 3: Update AGENTS.md root [quick]
├── Task 4: Update docs/architecture.md [quick]
├── Task 5: Update docs/game-loop.md [quick]
└── Task 6: Update docs/data-model.md [quick]

Wave FINAL (After ALL tasks — verification):
├── Task F1: Cross-reference consistency check [quick]
└── Task F2: Content accuracy review [deep]

Critical Path: Task 1 → F1/F2
Parallel Speedup: All 6 writing tasks run simultaneously
Max Concurrent: 6 (Wave 1)
```

### Dependency Matrix

| Task | Depends On | Blocks |
|------|-----------|--------|
| 1-6 | None | F1, F2 |
| F1 | 1-6 | — |
| F2 | 1-6 | — |

### Agent Dispatch Summary

- **Wave 1**: **6** — T1 → `writing`, T2-T6 → `quick`
- **FINAL**: **2** — F1 → `quick`, F2 → `deep`

---

## TODOs

- [x] 1. Create docs/game-design.md — Central Game Design Reference

  **What to do**:
  - Create `docs/game-design.md` as a NEW file (~200-250 lines)
  - Read `.sisyphus/drafts/game-design-jam.md` as the PRIMARY source (this contains ALL design decisions)
  - Structure the document with these sections (in order):
    1. **Design Philosophy** — "ongoing conversation, not gospel" + cozy genre identity
    2. **Game Identity** — Working title EarthNova, core fantasy (iNaturalist × Stardew × Pokémon Go), target audience, player identity (shifts by area: explorer/researcher/keeper)
    3. **Visual Direction** — Top-down, watercolour art, iOS-clean + PuffPals-cute, AI art pipeline for now, everything illustrated
    4. **Game Areas & Navigation** — 4-tab bottom bar (Map | Home | Town | Pack), each area's purpose
    5. **Core Loop** — Map (discover) → Pack (manage) → Museum/Sanctuary (place). TCG dopamine model.
    6. **Discovery System** — Rarity-scaled reveals (LC toast → EX full-screen), auto-collect commons, photograph rares, daily world seed (midnight GMT), deterministic first visit + daily rotation
    7. **Engagement Intensity** — OSRS-style spectrum: passive/light active/high active. Cell activities (forage, lure, survey, habitat care, photograph)
    8. **Inventory (Pack)** — Species as items not flags, stacked with preview, unlimited carry, release mechanic
    9. **Museum** — Separate from sanctuary, NPC-run, permanent donations, 7 habitat wings (unlockable), grid display, see silhouettes of missing species
    10. **Sanctuary** — Grid-based (Stardew), Ark Nova appeal system (future), flexible placement, NPCs react
    11. **NPCs** — Full characters with personality, discovered on map (milestone + location), Town tab is summary hub, remember player progress
    12. **Collectible Categories** — Fauna (32k IUCN, organized by habitat, 25 taxonomic classes as metadata), Plants, Minerals, Fossils (future)
    13. **Sub-Collections & Sets** — Habitat, taxonomic, continent, rarity, themed, NPC bundles. Dynamic like Stardew community center. Completion rewards.
    14. **Quest System** — Treasure maps (from NPCs, random drops, curator requests, weekly challenges, milestones). Directed exploration.
    15. **World Systems** — Seasons change visuals, weather affects spawns, daily/weekly challenges
    16. **Mechanics Under Review** — Restoration (designer questions value), economy/shops (not designed)
    17. **Deferred Decisions** — Economy, NPC count, social features, sound/music, monetization, session arc
  - Mark each decision with confidence level: **(confirmed)**, **(tentative)**, or **(deferred)**
  - Use telegraphic style: bullet points, tables, code blocks. Zero narrative fluff. Format for AI agents.
  - Include a "Current vs Target" quick-reference table showing what IS built vs what's planned

  **Must NOT do**:
  - Do NOT copy the draft verbatim — synthesize and organize it
  - Do NOT include implementation details (file paths, provider names) — that's for technical docs
  - Do NOT exceed 280 lines — keep it dense

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: This is a documentation writing task requiring synthesis of design decisions into clear, structured prose
  - **Skills**: []
    - No special skills needed — this is pure markdown writing from a source document

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2-6)
  - **Blocks**: F1, F2
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `docs/architecture.md` — Example of how existing docs are structured (telegraphic, tables, code blocks, ~100 lines)
  - `docs/data-model.md` — Example of dense reference document format

  **Source Document (PRIMARY — read this first)**:
  - `.sisyphus/drafts/game-design-jam.md` — Contains ALL design decisions from the jam session. This is the source of truth.

  **WHY Each Reference Matters**:
  - `game-design-jam.md` is THE source. Every design decision in the new doc must come from this draft.
  - Existing docs show the FORMAT and DENSITY expected. Match their style.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: game-design.md exists and has correct structure
    Tool: Bash
    Preconditions: Task complete
    Steps:
      1. wc -l docs/game-design.md → verify 180-280 lines
      2. grep "Design Philosophy" docs/game-design.md → verify section exists
      3. grep "EarthNova" docs/game-design.md → verify game title present
      4. grep "confirmed" docs/game-design.md → verify confidence labels used
      5. grep "deferred" docs/game-design.md → verify deferred items documented
      6. grep "TCG" docs/game-design.md → verify TCG dopamine model captured
      7. grep "treasure map" docs/game-design.md -i → verify quest system captured
      8. grep "midnight GMT" docs/game-design.md → verify daily seed captured
      9. grep "Pack" docs/game-design.md → verify tab rename captured
    Expected Result: All greps find matches
    Evidence: .sisyphus/evidence/task-1-structure.txt

  Scenario: No design decision from draft was lost
    Tool: Bash
    Preconditions: Task complete
    Steps:
      1. grep "OSRS" docs/game-design.md → engagement model
      2. grep "Ark Nova" docs/game-design.md → sanctuary inspiration
      3. grep "PuffPals" docs/game-design.md → visual reference
      4. grep "watercolour" docs/game-design.md → art style
      5. grep "photograph" docs/game-design.md → rare species mechanic
      6. grep "permanent" docs/game-design.md → museum donation permanence
      7. grep "Stardew" docs/game-design.md → community center bundles
    Expected Result: All greps find matches
    Evidence: .sisyphus/evidence/task-1-completeness.txt
  ```

  **Commit**: YES (groups with all tasks)
  - Message: `📝 docs: create game-design.md and refresh docs with EarthNova design vision`
  - Files: `docs/game-design.md`

- [x] 2. Update docs/INDEX.md — Add Game Design to Reading Guide

  **What to do**:
  - Add `game-design.md` to the "What to Read First" table:
    - Task type: **Game design work** → Read: `game-design.md` + `AGENTS.md` (root) → Then: Relevant feature AGENTS.md
    - Task type: **New feature** → Add `game-design.md` to the "Then" column (for gameplay-related features)
  - Add `game-design.md` to the "File Inventory" table:
    - Lines: ~220, Purpose: Game identity, creative vision, mechanics design, progression systems
    - Staleness Signal: Design decision changed without updating this doc
  - Keep all existing content unchanged

  **Must NOT do**:
  - Do NOT remove or change existing reading guide entries
  - Do NOT change maintenance rules section

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small edit to an existing file, ~10 lines added
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3-6)
  - **Blocks**: F1
  - **Blocked By**: None

  **References**:
  - `docs/INDEX.md` — The file being edited. Read it first to understand current structure.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: INDEX.md has game-design.md entry
    Tool: Bash
    Preconditions: Task complete
    Steps:
      1. grep "game-design.md" docs/INDEX.md → verify entry exists
      2. grep "Game design" docs/INDEX.md -i → verify reading guide row
      3. wc -l docs/INDEX.md → verify reasonable size (35-45 lines)
    Expected Result: All greps match, line count in range
    Evidence: .sisyphus/evidence/task-2-index.txt
  ```

  **Commit**: YES (groups with all tasks)
  - Files: `docs/INDEX.md`

- [x] 3. Update AGENTS.md Root — Working Title, Quick Reference, Future Work

  **What to do**:
  - **Line 1 subtitle**: Update `# Agent Guidance — Fog of World` to `# Agent Guidance — EarthNova (working title)`
  - **Line 3 description**: Update the `>` block to include game identity: add "Working title: EarthNova" and update genre description
  - **Quick Reference table**: Add `| Working Title | EarthNova |` row. Keep all other rows.
  - **Future Work section** (lines 417-425): REPLACE entire section with updated list reflecting design jam:
    - 4-tab navigation (Map | Home | Town | Pack)
    - Inventory system (species as items, Pack tab)
    - Museum system (habitat wings, permanent donations, NPC curator)
    - Sanctuary grid-based builder (Ark Nova appeal system)
    - NPC system (full characters, discoverable on map)
    - TCG-style discovery reveals (rarity-scaled ceremony)
    - Treasure map quest system
    - Daily world seed (midnight GMT rotation)
    - Cell activities (forage, lure, survey, habitat care)
    - Sub-collection sets (habitat, taxonomic, continent, themed, NPC bundles)
    - Weather-based spawns
    - Social features
    - Additional collectible categories (Plants, Minerals, Fossils)
    - Keep existing items: Camera/AI identification, real-time sync, push notifications, particle effects, real tile provider, analytics
  - **Documentation Maintenance Protocol**: Add `game-design.md` to the update triggers table:
    - `game-design.md` | Design decision changed, new mechanic confirmed, deferred item resolved

  **Must NOT do**:
  - Do NOT add full game design content to AGENTS.md body (it belongs in game-design.md)
  - Do NOT change Core Design Decisions section (those are locked without explicit instruction)
  - Do NOT change Scope Ceilings, Forbidden Patterns, API Gotchas, or any other section
  - Do NOT exceed 440 lines total (currently 425 — minimal growth)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Targeted edits to specific sections of an existing file
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1-2, 4-6)
  - **Blocks**: F1
  - **Blocked By**: None

  **References**:
  - `AGENTS.md` (root) — The file being edited. Read lines 1-10 (header), 400-425 (Future Work + Maintenance).
  - `.sisyphus/drafts/game-design-jam.md` — Source for Future Work items.

  **WHY Each Reference Matters**:
  - AGENTS.md header/subtitle sets the tone for every agent that reads it
  - Future Work must reflect design jam outcomes, sourced from the draft

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: AGENTS.md has EarthNova in header
    Tool: Bash
    Preconditions: Task complete
    Steps:
      1. head -5 AGENTS.md → verify "EarthNova" appears in title/subtitle
      2. grep "EarthNova" AGENTS.md → verify working title present
      3. grep "game-design.md" AGENTS.md → verify cross-reference in maintenance protocol
      4. grep "treasure map" AGENTS.md -i → verify new Future Work items
      5. grep "Pack" AGENTS.md → verify Pack tab mentioned in Future Work
      6. wc -l AGENTS.md → verify under 450 lines
    Expected Result: All checks pass
    Evidence: .sisyphus/evidence/task-3-agents.txt

  Scenario: Core Design Decisions unchanged
    Tool: Bash
    Preconditions: Task complete
    Steps:
      1. grep "Computed fog state" AGENTS.md → still present
      2. grep "Deterministic species encounters" AGENTS.md → still present
      3. grep "Voronoi cells" AGENTS.md → still present
      4. grep "IUCN rarity = loot weights" AGENTS.md → still present
      5. grep "Offline-first" AGENTS.md → still present
    Expected Result: All 5 core decisions still present unchanged
    Evidence: .sisyphus/evidence/task-3-preserved.txt
  ```

  **Commit**: YES (groups with all tasks)
  - Files: `AGENTS.md`

- [x] 4. Update docs/architecture.md — Glossary & Design Cross-Reference

  **What to do**:
  - **Glossary table** (lines 87-99): Update existing entries and add new ones:
    - Update "Encounter" to note the design target (rarity-scaled reveals, daily seed rotation)
    - Update "Sanctuary" to note the design target (grid-based zoo builder, Ark Nova appeal)
    - Add: **Museum** — NPC-run donation facility with 7 habitat wings. Permanent donations. (Planned — see `game-design.md`)
    - Add: **Pack** — Player inventory. Species collected as items, stacked by type. (Planned — see `game-design.md`)
    - Add: **Town** — NPC hub tab. Summary of discovered NPCs. (Planned — see `game-design.md`)
    - Add: **Treasure map** — Quest item directing player to a real-world location with a rare species. (Planned — see `game-design.md`)
    - Add: **Daily seed** — Midnight GMT world rotation. Same cell gives same species to all players each day. (Planned — see `game-design.md`)
  - **Top of file**: Add a one-line cross-reference after line 1: `> For game design vision (what WILL be built), see [game-design.md](game-design.md).`
  - Keep ALL other content (layer diagram, dependency rules, feature boundaries, initialization chain) UNCHANGED

  **Must NOT do**:
  - Do NOT change the layer diagram (lines 5-31)
  - Do NOT change feature boundary classification table (lines 42-58)
  - Do NOT change initialization chain (lines 70-85)
  - Do NOT present planned features as currently implemented

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Adding glossary rows and one cross-reference line to an existing file
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: F1
  - **Blocked By**: None

  **References**:
  - `docs/architecture.md` — The file being edited. Read the full file (99 lines).
  - `.sisyphus/drafts/game-design-jam.md` — Source for glossary definitions.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Glossary updated with design terms
    Tool: Bash
    Preconditions: Task complete
    Steps:
      1. grep "Museum" docs/architecture.md → verify new glossary entry
      2. grep "Pack" docs/architecture.md → verify new glossary entry
      3. grep "Town" docs/architecture.md → verify new glossary entry
      4. grep "Treasure map" docs/architecture.md -i → verify new glossary entry
      5. grep "game-design.md" docs/architecture.md → verify cross-reference
      6. grep "ProviderScope" docs/architecture.md → verify layer diagram unchanged
      7. grep "Initialization Chain" docs/architecture.md → verify section unchanged
    Expected Result: All checks pass
    Evidence: .sisyphus/evidence/task-4-architecture.txt
  ```

  **Commit**: YES (groups with all tasks)
  - Files: `docs/architecture.md`

- [x] 5. Update docs/game-loop.md — Design Target Notes for Discovery

  **What to do**:
  - **Top of file**: Add cross-reference after line 1: `> For the design target (how discovery WILL work), see [game-design.md](game-design.md).`
  - **After Species Discovery section** (after line 52): Add a clearly marked section:
    ```
    ### Design Target: Discovery System
    > These describe the INTENDED design, not current implementation. See `game-design.md`.
    
    - Rarity-scaled discovery reveals (LC = small toast → EX = full-screen ceremony)
    - Auto-collect for common species (LC, NT), tap-to-photograph for rare (VU+)
    - Daily world seed (midnight GMT): cells rotate species daily, deterministic per day
    - First visit: permanent species seeded by cell ID. Repeat visits: daily rotation pool
    - Inventory model: species go to Pack as stacked items, not binary collected flags
    - Cell activities (forage, lure, survey, habitat care) for active players = more drops
    ```
  - Keep ALL pipeline descriptions, tick rates, fog state machine, streak rules UNCHANGED

  **Must NOT do**:
  - Do NOT change the GPS → Render pipeline (lines 6-37)
  - Do NOT change tick rates table (lines 77-87)
  - Do NOT change fog state machine (lines 89-103)
  - Do NOT remove or modify any current behavior descriptions

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Adding one section and one cross-reference line to an existing file
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: F1
  - **Blocked By**: None

  **References**:
  - `docs/game-loop.md` — The file being edited. Read the full file (103 lines).
  - `.sisyphus/drafts/game-design-jam.md` — Source for design target details.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Design target section added without breaking existing content
    Tool: Bash
    Preconditions: Task complete
    Steps:
      1. grep "Design Target" docs/game-loop.md → verify new section exists
      2. grep "midnight GMT" docs/game-loop.md → verify daily seed captured
      3. grep "rarity-scaled" docs/game-loop.md -i → verify rarity reveals captured
      4. grep "game-design.md" docs/game-loop.md → verify cross-reference
      5. grep "_onLocationUpdate" docs/game-loop.md → verify pipeline unchanged
      6. grep "Fog State Machine" docs/game-loop.md → verify section unchanged
      7. grep "Streak rules" docs/game-loop.md → verify section unchanged
    Expected Result: All checks pass
    Evidence: .sisyphus/evidence/task-5-gameloop.txt
  ```

  **Commit**: YES (groups with all tasks)
  - Files: `docs/game-loop.md`

- [x] 6. Update docs/data-model.md — Design Target Notes for Inventory Model

  **What to do**:
  - **Top of file**: Add cross-reference after line 1: `> For the design target (inventory model, museum, collectibles), see [game-design.md](game-design.md).`
  - **After Database Schema section** (after line 128, before Game Constants): Add a clearly marked section:
    ```
    ### Design Target: Inventory Model
    > These describe the INTENDED design, not current implementation. See `game-design.md`.
    
    Current model: `CollectedSpecies` is a binary flag (collected or not, unique per user+species+cell).
    Target model: Species as inventory items with quantity tracking.
    
    Key changes planned:
    - Species stacked in Pack (inventory): "Mallard ×3" not just "Mallard: collected"
    - Museum donations consume from inventory (permanent — cannot retrieve)
    - Sanctuary placements consume from inventory (flexible — can rearrange)
    - Release mechanic: return unwanted species to the wild
    - Daily world seed: cells offer different species each day (midnight GMT rotation)
    - Multiple collectible categories planned: Fauna (now), Plants, Minerals, Fossils (future)
    
    Museum structure:
    - 7 habitat-based wings (Forest, Plains, Freshwater, Saltwater, Swamp, Mountain, Desert)
    - Wings are unlockable via donation milestones
    - Species appear in ONE wing only — duplicates needed for multiple wings
    - Grid display with empty/filled slots
    ```
  - Keep ALL current schema descriptions, model definitions, repository docs, ESA mapping, constants UNCHANGED

  **Must NOT do**:
  - Do NOT change Domain Models table (lines 6-25)
  - Do NOT change Database Schema tables (lines 65-107)
  - Do NOT change Repository descriptions (lines 109-117)
  - Do NOT change Game Constants table (lines 131-144)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Adding one section and one cross-reference line to an existing file
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: F1
  - **Blocked By**: None

  **References**:
  - `docs/data-model.md` — The file being edited. Read the full file (144 lines).
  - `.sisyphus/drafts/game-design-jam.md` — Source for inventory model design.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Design target section added without breaking existing content
    Tool: Bash
    Preconditions: Task complete
    Steps:
      1. grep "Design Target" docs/data-model.md → verify new section exists
      2. grep "inventory" docs/data-model.md -i → verify inventory model captured
      3. grep "habitat-based wings" docs/data-model.md → verify museum structure
      4. grep "game-design.md" docs/data-model.md → verify cross-reference
      5. grep "LocalCellProgressTable" docs/data-model.md → verify schema unchanged
      6. grep "LocalCollectedSpeciesTable" docs/data-model.md → verify schema unchanged
      7. grep "SpeciesRecord" docs/data-model.md → verify model unchanged
    Expected Result: All checks pass
    Evidence: .sisyphus/evidence/task-6-datamodel.txt
  ```

  **Commit**: YES (groups with all tasks)
  - Files: `docs/data-model.md`

---

## Final Verification Wave

- [x] F1. **Cross-Reference Consistency Check** — `quick`
  Read ALL 7 modified files. Verify:
  - Species count consistent (32,752) across all files that mention it
  - Habitat count consistent (7) across all files
  - Season count consistent (2)
  - Feature names match (Pack not Journal, EarthNova not Fog of World where appropriate)
  - Every file that mentions game design links to `docs/game-design.md`
  - `docs/INDEX.md` includes game-design.md in reading guide
  - AGENTS.md Future Work reflects design jam outcomes
  Output: `Consistent [YES/NO] | Mismatches: [list]`
  Evidence: `.sisyphus/evidence/task-F1-consistency.txt`

- [x] F2. **Content Accuracy Review** — `deep`
  Read `docs/game-design.md` end-to-end. Compare EVERY design decision against `.sisyphus/drafts/game-design-jam.md`. Verify:
  - No design decisions were lost or misrepresented
  - Confirmed/Tentative/Deferred labels are accurate
  - Deferred items are documented as deferred (not omitted)
  - Technical docs have NOT been changed to describe unbuilt features as implemented
  - architecture.md layer diagram and initialization chain are UNCHANGED
  - game-loop.md pipeline descriptions are UNCHANGED
  - data-model.md schema descriptions are UNCHANGED
  Output: `Decisions [N/N captured] | Technical accuracy [PASS/FAIL] | VERDICT`
  Evidence: `.sisyphus/evidence/task-F2-accuracy.txt`

---

## Commit Strategy

- **Single commit**: `📝 docs: create game-design.md and refresh docs with EarthNova design vision`
  - Files: `docs/game-design.md`, `docs/INDEX.md`, `docs/architecture.md`, `docs/game-loop.md`, `docs/data-model.md`, `AGENTS.md`
  - Pre-commit: `wc -l docs/game-design.md` (verify substantial content)

---

## Success Criteria

### Verification Commands
```bash
wc -l docs/game-design.md  # Expected: 180-280 lines
grep "EarthNova" AGENTS.md  # Expected: appears in subtitle/Quick Reference
grep "game-design.md" docs/INDEX.md  # Expected: appears in reading guide
grep "game-design.md" docs/architecture.md  # Expected: cross-reference exists
grep "Design Target" docs/game-loop.md  # Expected: design section exists
grep "Design Target" docs/data-model.md  # Expected: design section exists
```

### Final Checklist
- [x] `docs/game-design.md` comprehensive and well-structured
- [x] All "Must Have" present
- [x] All "Must NOT Have" absent
- [x] Cross-references consistent
- [x] Technical docs still accurately describe current code
