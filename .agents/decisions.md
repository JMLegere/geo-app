# Decisions

**Role: CURRENT-SCOPED decision registry.** Entries preserve the decision made on their date. A later explicit supersession, `CONTEXT.md`, or an accepted `docs/adr/` controls when old language or architecture conflicts with current authority.

## 2026-05-03 — beta-first trunk deployment
- Keep `main` as the only long-lived branch.
- Deploy `main` to Railway beta first.
- Promote to production with a manual GitHub Actions workflow.
- Use separate Supabase projects for beta and production.
- Inject Supabase frontend config at build time from Railway environment variables.
- Seed beta from production data so backend/schema changes can be validated against realistic data.

## 2026-05-03 — per-cell geometry substrate source of truth
- Missing fog on beta is caused by missing true per-cell geometry, not frontend fog logic.
- Do not use district/admin boundaries as cell polygons; `districts.boundary_json` is not a valid cell geometry source.
- Canonical cell geometry lives in Supabase/PostGIS, starting with `039_cell_geometry_data_model.sql`.
- Use versioned immutable geometry batches:
  - `cell_geometry_versions` stores source/version metadata and validation status.
  - `cell_geometry_cells` stores per-cell PostGIS `MultiPolygon` geometry keyed by `(source_version, cell_id)`.
  - `cell_geometry_active_version` is the atomic active pointer.
  - `cell_geometry_current` resolves the currently active cells for read models/RPCs.
- Use a raw staging table that stores both original payloads and parsed geometry metadata so invalid batches are auditable and reproducible.
- Publish only complete, topology-validated tessellation batches; a publish atomically switches the active source version.
- Geometry versions must include an authoritative `coverage_geom`; gap/overflow validation compares the union of staged cells against this boundary.
- Validation ownership is split:
  - service/import code parses artifacts and writes staging rows
  - DB/PostGIS validates spatial/topology correctness and decides publishability
- Validation uses a full audit log:
  - `cell_geometry_validation_runs` records each run, tolerances, status, and summary
  - `cell_geometry_validation_issues` records each detected batch/cell issue
- Topology policy is semantic zero tolerance: no real overlaps/gaps, with a strict practical `1.0 m²` epsilon for floating-point/sliver noise.
- Publish is DB-owned via `publish_cell_geometry_source_version(source_version, validation_run_id)` in migration `041`.
- Publish requires a passed validation run and rejects staging rows modified after that run finished.
- Publish copies staged geometry into immutable `cell_geometry_cells`, upserts `cell_geometry_active_version`, retires the prior active version, marks the new version active, and appends `cell_geometry_publish_events`.
- Migrations `039`-`041` were validated together against linked beta inside a rollback transaction.
- External import artifact contract is custom JSON, captured in `supabase/cell_geometry_artifact.schema.json`.
- Artifact shape is `{schema_version, source, source_version, coverage, cells:[...]}`.
- Artifact coordinates follow GeoJSON standard `[lng, lat]`; importer converts to PostGIS, and the later RPC converts active geometry to app-facing `{lat,lng}` nested rings.
- First importer runtime is a repo Python script, `scripts/import_cell_geometry_artifact.py`, run manually/CI with service-role DB access. Supabase Edge Function can come later after the artifact/import contract stabilizes.
- Importer includes `--emit-sql` so staging SQL can be validated with `supabase db query --linked` without requiring a local `psql` DB URL.
- Minimal fixture artifact lives at `supabase/fixtures/cell_geometry_artifact_minimal.json`; migrations `039`-`041` plus importer SQL for that fixture were rollback-validated against linked beta.
- For beta-scale real geometry, prefer DB-side staging via `stage_cell_geometry_from_cell_ids` (`042`) because full artifact upload exceeds Supabase Management API request limits.
- Encoded cell IDs use `v_<x>_<y>` with derived center `lat=x/500`, `lng=y/500`.
- Since centers lie on a uniform lattice, bounded point-Voronoi cells are the half-step squares around each center; DB staging uses that geometry directly.
- Rollback validation of `039`-`042` on linked beta proved stage → validate → publish works transactionally with `current_count=7820`.
- Beta geometry integration is live as source version `db-lattice-voronoi-beta-v1`.
- Read model repair is migration `043`: `v3_map_cells_read_model` joins `cell_geometry_current` and `fetch_nearby_cells` returns renderable true per-cell polygons.
- Keep legacy `polygon` in the RPC for current Flutter compatibility while adding `polygons` for the richer long-term transport.

## 2026-05-04 — topology-aware map render projection
- Research confirmed the renderer problem is not failed Voronoi persistence; it is
  treating a tessellation as independent semi-transparent/stroked polygons.
- Keep Supabase/PostGIS Voronoi geometry as source truth and validation authority.
- Client rendering should build a transient topology-aware projection:
  - fills grouped by reveal state
  - same-state internal borders suppressed
  - shared boundaries snapped/canonicalized and drawn once
  - frontier/unknown seams remain hidden
- This is preferred over mutating persisted geometry, adding overlap/gap hacks, or
  continuing to tune independent per-cell strokes.
- Longer-term, a source-owned topology/arc format or native MapLibre vector layer may
  supersede the Flutter projection, but the invariant remains: visual rendering should
  respect shared tessellation edges.

## 2026-05-04 — pin Railway web builds to Flutter 3.41.3
- Railway beta was building the web app from `instrumentisto/flutter:3.41`, which had drifted to a newer patch/runtime than local `mise` and GitHub CI.
- Local/CI were already pinned to Flutter `3.41.3`; beta blank-map behavior reproduced as an environment mismatch, not as a failure of the merged web map-idle signal change.
- Pin the Docker build image to `instrumentisto/flutter:3.41.3` so beta/prod web bundles use the same Flutter toolchain and web engine as local and CI.
- Guard this with a repo test that fails if `Dockerfile` drifts away from the CI Flutter version pin.

## 2026-05-04 — bridge web style readiness from real MapLibre JS load
- After pinning Railway web builds to Flutter `3.41.3`, beta could still stall at the readiness gate with `map created` but without `style_loaded`.
- Do not rely solely on `MapLibreMap.onStyleLoadedCallback` on web.
- Mirror the earlier idle fix: dispatch an app-owned browser event from the underlying MapLibre GL JS `load` event and listen for it in Dart.
- Keep the plugin callback path too, but make style-ready handling idempotent so either source can win without double-logging.

## 2026-05-04 — adopt OpenTelemetry model without adding new telemetry infra
- The goal is to set EarthNova up with OpenTelemetry concepts and conventions, but not to add paid or always-on new infrastructure just to store/query telemetry.
- Terminal agents must be able to query telemetry easily, so Supabase remains the primary telemetry store for now.
- Treat OpenTelemetry as the contract/model:
  - resource fields (`service.name`, `service.version`, `deployment.environment`)
  - trace/span IDs
  - logs vs spans vs metrics separation
  - semantic event/attribute naming
- Do not make SigNoz a required runtime dependency for the app. It is optional later for analysis/export, not part of the first-pass production architecture.
- Refactor the current observability path toward OTel-shaped events persisted in Supabase so the team gets future export compatibility without losing simple SQL-based terminal access.
- Big-bang means a true cutover: do not backfill historical `app_logs`, and do not preserve the old logs as an ongoing compatibility surface. Remove the old schema/code path once the new telemetry tables and ingest path are live.
- Canonical first-pass schema is split by signal type:
  - `telemetry_logs` for point-in-time events
  - `telemetry_spans` for timed work / parent-child trace trees
  - SQL views provide terminal-friendly timelines, funnels, readiness inspection, and error queries.
- Canonical ingestion boundary is one Supabase Edge Function, `telemetry-ingest`, used by both app flushes and JS beacon/sendBeacon diagnostics.
- App-facing instrumentation keeps a thin `ObservabilityService` facade, but internally follows the OTel model with logger/tracer roles, `startSpan` / `endSpan`, and explicit trace/span IDs threaded through important flows.

## 2026-05-05 — use lifecycle grammar for agent-debuggable telemetry
- Observability is optimized for terminal agents doing reactive debugging, with secondary batch analysis surfacing suspicious activity from logs.
- Important flows should emit bounded lifecycle attributes: `flow`, `phase`, `dependency`, `previous_state`, `next_state`, and `reason`.
- Canonical phases are `started`, `waiting_on`, `dependency_requested`, `dependency_ready`, `dependency_failed`, `state_changed`, `completed`, `failed`, `timed_out`, and `cancelled`.
- Keep existing domain event names where they are already useful (`map.style_loaded`, `auth.no_session`, etc.), but add lifecycle grammar attributes so SQL can detect missing terminal events and dependency failures without brittle event-name parsing.
- Add terminal-agent query surfaces over the raw OTel-shaped tables: `telemetry_flow_lifecycle_v`, `telemetry_incomplete_flows_v`, and `telemetry_dependency_failures_v`.

## 2026-05-05 — split gameplay marker from camera follow smoothing
- The green map dot is the app-owned gameplay/player marker, not the raw GPS location; MapLibre's native puck remains disabled.
- Raw GPS remains the target for map framing, but camera movement now runs through a separate fast smoothed `cameraFollowProvider`.
- Camera smoothing is intentionally faster than the gameplay marker spline and never affects exploration eligibility, cell visits, or encounter triggering.
- The first camera fix snaps to GPS to avoid panning from `(0,0)` across the globe; later GPS updates ease toward the new target to suppress jitter.

## 2026-05-05 — low-level observability is app-wide, bounded, and short-retained
- Do not instrument platform bugs as one-off whack-a-mole probes. The browser bootstrap owns a shared low-level telemetry surface for the whole app.
- Low-level events use category `low_level` and bounded event names/payloads for pointer, touch, gesture, wheel, keyboard, viewport, network, focus/blur, resource, and clipboard signals.
- Low-level telemetry must be privacy-safe: no raw key characters and no clipboard contents.
- Supabase observability retention is 14 days for `telemetry_logs` and `telemetry_spans`; observability is diagnostic, not permanent product history.

## 2026-05-05 — screen lifecycle is the UI loading contract
- Use **UI lifecycle observability** as the umbrella term; `ui.widget.*` remains lower-level Flutter widget telemetry.
- `navigation.*` now emits `ui.screen.expected` so terminal agents can correlate "we navigated to X" with whether X mounted and became ready.
- `ObservableScreen` is the screen lifecycle boundary and emits `ui.screen.mounted`, `ui.screen.first_build`, `ui.screen.ready`, `ui.screen.disposed`, `ui.screen.load_timeout`, and `ui.screen.disposed_before_ready`.
- A screen load has a terminal outcome: ready, boundary error, timeout, or disposed-before-ready. Coverage tests enforce these event names so missing screen/deload bugs stop being invisible.
- `silentTransition` remains allowed only for high-frequency/non-diagnostic state changes and must carry a nearby `silentTransition:` justification comment.

## 2026-05-05 — observability correlation must use query-stable names and sessions
- `ui.screen.expected` must use the same stable snake_case names emitted by `ObservableScreen` (`map_screen`, `district_screen`, `tab_shell`, etc.); logical names such as `map.district`, `home`, or `pack` are preserved only as raw fields for debugging.
- Browser bootstrap / low-level telemetry and Dart app telemetry must share one active app session ID. Web startup may create a temporary bootstrap session, but queued JS events are rewritten to the Dart app session before beacon flush, with the original stored as `bootstrap_session_id` when different.
- `map.bootstrap` must always reach a terminal lifecycle phase. If steady state is not reached, emit `map.bootstrap.timed_out` with the readiness booleans and `waiting_for` list so `telemetry_incomplete_flows_v` does not become the only diagnosis surface.
- If style and cells are ready but MapLibre idle never reaches Dart, keep the explicit base-map-settled safety fallback and label it `readiness_safety_fallback` so terminal agents can distinguish it from the normal JS idle/plugin paths.

## 2026-05-18 — use World Events for OSRS-style distractions and diversions
- Use **World Events** as the title for OSRS-style distractions/diversions inside the map-world layer, not as a current top-level capability after the capability synthesis.
- Model it after OSRS Distractions and Diversions: sporadic, optional, chance-encountered activities that can redirect a player's current plan without replacing the core loop.
- Use **World Events** instead of Wonders/Diversions/Field Events because it is clearer, system-level, and fits the existing naming style.
- Intended player reward: serendipity — "wait, what's that?" moments that make the real world feel alive.
- First SuperBDD event family is **Wildlife Migration**: temporary movements of fauna/flora through territories that players may notice, inspect, follow, and encounter during normal exploration.

## 2026-05-18 — natural sciences are top-level capabilities
- Treat major natural science disciplines as first-class EarthNova capabilities rather than only item categories.
- Science capabilities should express the player fantasy of studying the natural world through the retained discipline set: Zoology, Botany, Mycology, Geology, Paleontology, and Genetics.
- Keep **Archaeology** as a sibling capability for human traces/artifacts even though it is not strictly a natural science.

## 2026-05-18 — split capability and action product truth
- Keep the SuperBDD spine capability-only until the capability language is settled.
- Store capabilities in `product/capabilities.ts`.
- Store actions separately in `product/actions.ts`; it is intentionally empty until the next cascade layer is designed.
- Keep `product/manifest.ts` as the EAC-compatible re-export facade.

## 2026-05-18 — first-pass accepted feature candidates
- Accepted feature candidates under **Fog**: Place Reveal, Persistent Footprint, Frontier Tease, Fog Trust Rules.
- Accepted feature candidates under **Exploration**: Crossing Places, Trusted Marker, Nearby Opportunity, Bad-GPS Pause.
- Accepted feature candidates under **Territories**: District Progress, City Atlas, State/Nation Passport, World Atlas.
- Accepted feature candidates under **World Events**: Wildlife Migration.
- Accepted feature candidates under **Discovery**: First-Visit Finds, Revisit Finds, Rarity Moment, Place-Shaped Finds.
- Accepted feature candidates under **Zoology**: Threatened Species Focus.
- Accepted feature candidates under **Botany**: Growth Stages.
- Accepted feature candidates under **Paleontology**: Deep-Time Timeline.
- Accepted feature candidates under **Genetics**: Trait Variation, Inheritance Patterns.
- Accepted feature candidates under **Field Journal**: Species Pages.
- Accepted feature candidates under **Conservation**: Threat Status Meaning, Stewardship Goals.
- Accepted feature candidates under **Pack**: Owned Find Grid, Mystery Cards, Domain Filters, Find History.
- Accepted feature candidates under **Identification**: Hold-to-Reveal, Reveal Theater, Deterministic Traits.
- Accepted feature candidates under **Collections**: Collection Unlocks, Bundle Slots, Collection Completion Rewards, Cross-Domain Collections.
- Accepted feature candidates under **Sanctuary**: Sanctuary Placement, Sanctuary Growth.
- Accepted feature candidates under **Buddy**: Active Buddy, Buddy Care.
- Accepted feature candidates under **Lineage**: Family Tree, Breeding Pairing, Inherited Traits, Lineage Rarity.
- Accepted feature candidates under **Quests**: Science Quests.
- Accepted feature candidates under **Achievements**: Milestone Achievements, Achievement Diaries.
- Accepted feature candidates under **Recap**: Return Recap.
- Accepted feature candidates under **Community**: Community Progress, Community Events.
- Accepted feature candidates under **Economy**: Duplicate Value, Trading, Market Signals.
- Explicitly not accepted in this pass: World Events Falling Stars/Treasure Trails/Fossil Exposures/Community Sightings/Anomalies; Identification Readiness Mystery; Buddy Bond; Quests Field Quests/Daily Weekly Prompts; Recap Pending Mysteries; Community Nearby Presence; Economy Orbs as Currency/Care Items.
- Current capability gaps needing future synthesis: Mycology, Geology, and Archaeology have no accepted feature candidates yet.

## 2026-05-18 — concrete app sections define SuperBDD features
- Refine the SuperBDD vocabulary: capabilities are broad app/game-system areas; features are concrete sections of a page, app surface, or data model that can be owned independently inside a capability.
- A feature should be an independently designable/buildable part of the larger capability, not just an emotional beat, rule, loop name, or scenario/action.
- The 2026-05-18 feature-candidate list above should be treated as selected experience ingredients and design inputs, not final SuperBDD features.
- Before writing real feature files, synthesize those ingredients into concrete app features such as map overlay sections, territory atlas sections, pack/card sections, journal data models, collection models, buddy state models, and economy/trade surfaces.
- In the feature catalog, break the territory concept into concrete features: Districts, Cities, States, Countries, and World.

## 2026-05-18 — science disciplines remain capabilities while Field Guide is a feature
- Keep high-level science disciplines as first-class capabilities: Zoology, Botany, Mycology, Geology, Paleontology, Genetics, and Archaeology.
- Treat **Field Guide** as a concrete Progression-Permanence feature, not a top-level capability, because it is an app section/knowledge surface that persists learned observations.
- Science discipline feature files are tagged only with their science capability; they are presented through the Field Guide feature rather than owned by a Field Guide capability.
- Progression-Permanence now owns Field Guide and Conservation alongside Collections, Sanctuary, Buddy, and Lineage.

## 2026-05-18 — Map decomposes into concrete map features
- Replace broad map feature buckets such as Fog, Exploration, and World Events with concrete app surfaces/data models.
- Map surfaces: Map Frame, Player Marker + Accuracy Ring, Fog Overlay, Map Cell Detail Sheet, Nearby Opportunity Layer, World Event Cue Layer, Districts, Cities, States, Countries, World, and Territory Navigation.
- Map data models: Exploration Eligibility State, Cell Border Crossing Model, Fog State Model, Territory Progress Model, and World Event Instance Model.
- This decomposition targets the current map jank diagnosis: semantic jank is handled by map cell detail/context features, visual jank by marker/fog/cue layers, and reward jank by explicit border crossing/fog/progress models.

## 2026-05-18 — Map design starts from experience and state
- Design the mapping capability as a game system before designing individual screens.
- Map's experience contract is: the player knows where they are, trusts the gameplay marker, reveals the world by moving, understands map cell entries, sees a soft nearby pull, and accumulates local movement into larger territory progress.
- Use the core loop `open map → orient on self → read fog/frontier → move physically → cross Voronoi map cell border → reveal/update footprint → acknowledge map cell → optionally inspect or follow a cue`.
- Prioritize state-machine clarity before implementation: marker trust, exploration eligibility, cell border crossing, fog relationship, reward handoff, territory progress, and world event instances.
- First implementation slice should stay focused on map frame, marker/ring, cell border crossing, fog state/overlay, and map cell detail sheet before nearby opportunities or territory rollups.

## 2026-05-19 — Map design source aligns to Map boundary
- `docs/map-design.md` now treats map design as Map capability design, not just a screen/rendering spec.
- Map owns movement truth, fog reveal, map cell acknowledgement, territory context, soft opportunity cues, and map-visible event cues.
- Map does **not** own high-intensity species/item/identification/pack rewards; those are downstream Discovery, Identification, Pack, Field Guide, or event-specific systems.
- First-visit map cell entries should be medium-intensity: one cell border crossing event, fog reveal, map cell acknowledgement, and optional downstream handoff. This replaces forced first-visit discovery popup language for the map capability.
- Feedback should follow the reward intensity ladder so the map stays movement-first rather than noisy or chore-like.

## 2026-05-19 — First playable Map slice
- The first playable mapping slice is deliberately narrower than the full Map fantasy.
- Included: Map Frame, Player Marker + Accuracy Ring, Exploration Eligibility State, Cell Border Crossing Model, Fog State Model, Fog Overlay, and Map Cell Detail Sheet.
- Not yet included: full territory dashboard polish, advanced marker personality, rich POI/social place claims, full habitat art direction, and downstream Discovery/Pack/Field Guide reward reveal.
- First-slice success means one walk produces a coherent loop: trusted map open, one Voronoi map cell border crossing, visible fog reveal, map cell acknowledgement, no reward spam on repeat, and no downstream systems required to feel playable.
- GPS-level visual hierarchy should be `marker/ring > current map cell > fog relationship > cell cue > base map detail`.

## 2026-05-19 — First-slice Map contracts
- The first playable map slice now has an implementation-ready moment choreography: map enters, map steadies, trust resolves, player moves, border crosses, first entry/re-entry feedback, detail opened, trust lost, and trust recovered.
- First-slice state contracts are named explicitly: `MapReadiness`, `MarkerTrust`, `ExplorationEligibility`, `CellBorderCrossingEvent`, `FogRelationship`, `CellEntryFeedback`, and `MapCellDetailState`.
- `CellBorderCrossingEvent` is the shared identity for visit recording, fog recompute, map cell acknowledgement, downstream handoff availability, and observability.
- The first-slice map cell detail sheet uses a field-note anatomy: map cell heading, status pill, territory context, visit facts, fog/progress note, then secondary downstream handoffs.

## 2026-05-19 — First-slice payload and responsibility boundaries
- First-slice payload shapes are now design contracts, not final Dart APIs: `MapReadiness`, `MarkerTrust`, `ExplorationEligibility`, `CellBorderCrossingEvent`, `FogRelationshipSet`, `CellEntryFeedback`, and `MapCellDetailState`.
- Payloads must stay reward-clean: border crossing/detail/fog payloads do not carry species, item, pack, field-guide, or identification mutation results.
- Component responsibilities are split so the map frame composes readiness/framing, marker/ring displays trust, overlay renders relationships, border crossing coordinator emits one identity, entry feedback handles intensity/copy, detail sheet explains context, and observability provides traceability.
- The first-slice acceptance matrix now covers trusted/bad-GPS cold opens, same-cell movement, first border crossing, jitter suppression, re-entry, detail inspection, trust loss, and trust recovery.

## 2026-05-19 — Map and Voronoi map cell terminology
- Use **Map** as the capability/surface term, not World Board, for first-slice technical design.
- Use **Voronoi map cell** for the generated playable polygon, with **map cell** as shorthand.
- Use **map cell border** for the boundary line between adjacent map cells. The player crosses a border, then enters a map cell; they do not "cross a map cell."
- Reserve **place** for future semantic geography layered above map cells, such as POIs, parks, landmarks, named areas, or social claims.

## 2026-05-19 — First-slice transition invariants
- The first playable Map slice must obey six invariants: no ready-before-ready, no same-cell mutation, no border-crossing replay after paused trust loss, no reward payload leakage, no inspection mutation, and no fake progress while paused.
- `MapReadiness` is the only gate into playable map state; visits, fog, and handoffs must not appear early.
- `CellBorderCrossingEvent` only exists when a real border is crossed under eligible movement; same-cell movement and jitter produce no semantic event.
- `MapCellDetailState` may surface paused context, but it must never imply movement is currently counting unless `ExplorationEligibility` is active again.

## 2026-05-19 — Map Debug Controls are test infrastructure
- `Map Debug Controls` is a Map feature, but it is developer-only infrastructure rather than player-facing gameplay.
- The feature owns on-screen buttons for P↑/P↓/P←/P→ simulated marker movement, GPS resume, and Pinch/Spread/swipe gesture injection.
- Debug movement and gestures must use the same readiness, marker trust, exploration eligibility, border crossing, fog, and reward-clean gates as real input.
- Debug-driven movement must be source-marked (`debug_controls`) and must not grant reward payloads or hidden production privileges directly.

## 2026-05-19 — First-slice Map implementation boundaries
- First-slice Map implementation should be organized by explicit boundaries, not a god-screen: location source, marker trust, map readiness, cell data source, exploration eligibility, cell border crossing coordinator, visit recorder, fog relationship service, entry feedback presenter, map cell detail state builder, and debug controls.
- Existing code anchors can evolve toward these names without churn: `LocationNotifier`, `PlayerMarkerNotifier`, `MapNotifier`, `ExplorationEligibility`, `DetectCellEntry`, `RecordCellVisit`, `VisitQueueProvider`, `FogStateService`, and `DebugGestureOverlay`.
- The build order should preserve TDD and vertical-slice safety: readiness gate → marker trust → eligibility → border crossing identity → visit result → fog recompute → entry feedback/detail → debug harness regression coverage.

## 2026-05-19 — Player actions belong in owning feature files
- Follow the EAC and main-website pattern: `actionCapabilities` is the central action catalog, `productCapabilities.requiredActions` wires actions to capabilities, and `@action.<id>` scenarios live in the concrete feature files that own the behavior.
- Do not model `Player Actions` as its own product feature; it is a cross-cutting manifest/catalog concern, not a player-facing app section or game system.
- A shared generic player-actions feature was removed after review; action scenarios are distributed into Map, science Field Guide, Exploration-Discovery, Progression, Motivation, and Multiplayer feature files.

## 2026-05-19 — Capability action wiring should use typed action ids
- Follow the main-website pattern beyond feature placement: keep a central action-id export (`playerActions`) derived from `actionCapabilities`, then reference those constants from `productCapabilities.requiredActions`.
- This makes action ownership easier to refactor and reduces silent typo risk compared with repeating raw action-id strings across capability definitions.

## 2026-05-19 — SuperBDD workflows model stateful player mutations
- Use `product/workflows.ts` for typed SuperBDD workflow definitions and keep `product/manifest.ts` as the export facade.
- Keep workflow ids centralized with the action catalog (`playerActionWorkflows`) so actions and capability workflow ownership do not repeat raw workflow-id strings.
- Attach workflows to stateful gameplay flows rather than creating workflow-only feature files: Map exploration, Discovery ownership, conservation, collection commitment, sanctuary placement, buddy care, lineage, quest rewards, recap acknowledgement, community contribution, and trade exchange.
- Workflow evidence stays tied to existing owning feature files plus `mise exec -- eac check`; do not invent generic workflow/action feature files just to satisfy the graph.

## 2026-05-19 — Flutter interactibles declare SuperBDD action ids or exemptions
- Mirror the main-website `data-user-action` pattern in Flutter through `ObservableInteraction`: every instrumented interaction must now declare a known `PlayerActions.*` id or an explicit telemetry-only reason.
- Keep `lib/shared/product/player_actions.dart` as a hand-maintained Dart mirror of `product/actions.ts`, guarded by a test that compares Dart constants against the SuperBDD action catalog.
- Use `player_action_id` in interaction telemetry when the UI gesture corresponds to a SuperBDD player action; use `telemetry_only_reason` for auth/account/debug/filter refinements that are real telemetry but not current gameplay actions.
- Static enforcement lives in `test/shared/observability/player_action_interaction_enforcement_test.dart`; it rejects unclassified `ObservableInteraction` calls and raw-string `playerActionId` usage.

## 2026-05-19 — Map progress begins on real border crossings, not idle occupancy
- Align the first playable Map slice to the chosen fantasy of **crossing places**: simply opening the map or regaining trust inside the same map cell should track context, but must not immediately grant a visit, fog clear, encounter, or discovery acknowledgement.
- `ExplorationNotifier` now treats initial occupancy and trusted recovery as `map.cell_tracked` only; visit/fog/discovery mutation requires an eligible transition from one tracked map cell into a different map cell.
- Border-crossing mutations now carry a shared `CellBorderCrossingEvent` identity (`border_crossing_id`, previous/entered cell ids, first-vs-reentry, timestamp, territory ids) so visit recording, fog clear, encounter/discovery triggers, and later detail/feedback can agree on one technical event.
- Explicit exploration eligibility can now gate mutation even when the marker itself is not a ring, covering paused GPS/unavailable states without replaying stale crossings on recovery.


## 2026-05-19 — Explored map cells remain distinct
- Do not implement dedicated border jitter suppression in the first playable Map slice; same-cell movement and untrusted movement are already gated, and eligible border crossings should remain simple.
- Remove `jitter_suppressed` from `CellBorderCrossingEvent` so the border crossing payload stays limited to accepted crossing identity, first/revisit status, timestamp, and territory context.
- Explored Voronoi map cells should not visually dissolve into one continuous explored blob.
- Keep frontier and unknown seams suppressed to avoid a debug-grid fog wall, but keep explored/explored shared edges visible as dark neutral revealed-cell boundaries.
- Revealed mosaic seams should stay thin enough to avoid heavy technical outlines; if the cell structure is readable, prefer thinner dark grey strokes over thicker borders.
- Screenshot review showed the prior "subtle" seam styling was perceptually invisible; explored/explored boundaries must be strong enough to read as a revealed mosaic, not merely present in topology tests.
- Unknown/non-frontier cells should use fully opaque fog so base-map detail does not leak through unexplored territory.
- The map fetch radius must cover wide GPS-level viewports with padding; otherwise already-explored cells can appear hidden behind unknown fog because their geometry was not loaded.

> **Current-authority note (2026-07-20):** This dated revisit-loop decision is implementation/product evidence only. `CONTEXT.md` now governs Cell Visit → Selector → zero-or-one Encounter semantics; production Encounter rates, weights, and additional Condition kinds remain open.

## 2026-05-19 — Daily map cell revisit loop can use positive FOMO
- Jeremy clarified that FOMO is acceptable for the daily revisit loop; the design target should not over-optimize for anti-FOMO.
- Use **positive FOMO** rather than punitive streak pressure: familiar map cells should feel alive on a daily schedule, making the player want to check them before the GMT day turns over.
- Daily map cell state is global map state: the same Voronoi map cell on the same GMT day resolves to the same active daily state for every player.
- Daily map cell freshness expires on the daily GMT seed refresh; if the player misses a map cell's daily seed, they miss that specific daily opportunity.
- Do not bank missed daily loot, leave weaker traces, or add capped catch-up buildup for the daily layer; the revisit motivation is that today's map cell state exists only today.
- Use the hybrid global-state architecture: deterministic on-demand resolution from global seeds is canonical, while persisted rows are limited to period seeds, resolver versions, player claims, audits, special event instances, and intentional caches/snapshots.
- This architecture must be justified by the SuperBDD scenarios in `features/map-global-map-state-model.feature`, not by implementation preference alone.
- Resolver payload shape must also be derived from BDD consumer scenarios. `GlobalMapCellState` is reward-clean shared state; player-specific fog/visit/claim status wraps it in a separate `PlayerMapCellStateView`.

> **Superseded authority claim (2026-07-20):** SuperBDD and EAC remain executable evidence and traceability checks, but they are not the source of product truth or work authorization. Root `AGENTS.md`, `CONTEXT.md`, and ADRs 0003–0005 govern the current relationship.

## 2026-05-19 — Root repo workflow is SuperBDD-driven
- Root `AGENTS.md` now explicitly instructs EarthNova work to use SuperBDD as the source of truth for product behavior, gameplay rules, UI flows, payload contracts, and state-model changes.
- Relevant `features/*.feature` scenarios and `product/*.ts` catalog entries should be read before coding.
- If player-visible behavior, terminology, ownership boundaries, or product contracts change, SuperBDD should be updated first or in the same change.
- Architecture should fall out of scenarios rather than being invented first and backfilled into BDD later.
- `mise exec -- eac check` is part of verification whenever product truth or feature behavior changes.

## 2026-05-19 — Frontier requires shared revealed border adjacency
- Frontier is a fog relationship for fetched unvisited Voronoi map cells that share a full border with the player's revealed footprint.
- The revealed footprint includes present and explored map cells; present participates because the current cell is visibly revealed even before it becomes historical explored state.
- Fetched unvisited cells that do not share a revealed border are `unknown`, not frontier, and should retain fully opaque fog.
- Corner-only point contact does not count as frontier adjacency.

## 2026-05-19 — Loading animation uses spinning world emoji cycle
- Use the shared loading animation for app, GPS, and map readiness blocking states instead of raw ellipses.
- The animation cycles through `🌍 → 🌎 → 🌏` to imply a spinning Earth and keep waiting states in EarthNova's world/exploration language.

## 2026-05-19 — Map bootstrap failures need pre-map dependency diagnostics
- When the Map screen times out before `map.map_created`, logs must still identify the blocking dependency instead of only saying every readiness flag is false.
- GPS startup now logs each awaited stage (`permission_request`, `current_position_request`) plus watchdog events so hung browser permission/location promises are diagnosable.
- `map.bootstrap.timed_out` includes the current `location_state` and optional `location_error_message`.

## 2026-05-19 — Overlay projection follows actual MapLibre camera state
- The cell/fog overlay must project geometry from the actual MapLibre camera position and zoom currently rendered on screen, not only from the desired smoothed camera-follow target.
- `MapScreen` now updates render projection state from `onCameraMove` / `controller.cameraPosition`, then uses that same render camera for shimmer placeholders, overlay painting, marker placement, and tap hit-testing.
- This keeps Voronoi map cells visually pinned to the base map even if MapLibre lags, rounds, or eases differently than the app's desired camera-follow target.

## 2026-05-19 — Overlay projection uses MapLibre screen coordinates when available
- The fog/cell overlay should prefer `MapLibreMapController.toScreenLocationBatch` for marker, cell vertex, and cell-center projection instead of relying only on an app-side Mercator camera model.
- The app-side Mercator projector remains a temporary synchronous fallback before MapLibre has produced exact screen coordinates.
- Projection requests are coalesced so fast camera changes keep only one in-flight batch plus the latest pending batch; stale batches are discarded rather than applied.
- `map.geometry_rendered` includes `projection_mode` so beta logs can show whether a frame used exact MapLibre coordinates or the fallback.

## 2026-05-19 — Player marker movement uses the marker/geolocation gap
- The visible gameplay marker should not chase geolocation at the old aggressive exponential catch-up rate; that made accurate-but-batched movement look like teleports.
- The first geolocation fix anchors the marker because no player-visible marker exists yet.
- Subsequent movement uses a proportional catch-up rule keyed to the current marker-to-geolocation gap, so nearby GPS updates resolve smoothly while larger gaps still drag visibly toward the fix.
- Low-confidence GPS still drags the marker. Ring state is triggered only when marker-to-geolocation distance exceeds 100m; exploration remains paused while in ring and resumes as the marker converges.

## 2026-05-19 — Marker speed scales with marker-to-geolocation gap
- Trusted marker movement should feel smooth but responsive by moving at roughly `gap_meters` per second.
- This means 100m away moves about 100m/s, 50m away moves about 50m/s, and smaller gaps naturally slow as the marker converges.
- Keep the 100m marker-to-geolocation ring threshold as the playability boundary; low-confidence GPS still drags the marker, but visits/fog/rewards pause once the marker gap exceeds the threshold.

## 2026-05-19 — Mercator fallback must match MapLibre scale
- `map.geometry_rendered` showed projection mode alternating between exact MapLibre screen coordinates and the synchronous Mercator fallback while movement/projection batches were pending.
- The visible cell-size snap came from a scale mismatch: the fallback used a 256px tile world while MapLibre GL's screen projection uses a 512px world scale.
- Keep MapLibre exact screen coordinates as the preferred overlay projection, but calibrate the fallback to the same 512px world scale so frames do not visibly resize while waiting for exact batch results.

## 2026-05-19 — GPS-level map suppresses base-map text labels
- The GPS-level Map should prioritize marker, fog relationship, map-cell mosaic, and cue readability over cartographic labels.
- Hide MapLibre base-map text labels after style load by disabling symbol layers with a `text-field`; preserve legal attribution.
- Do not hide icon-only symbol layers as part of this decision unless they later prove visually noisy.

## 2026-05-19 — Frontier cells inherit the revealed mosaic edge
- Frontier cells should show the same thin dark neutral edge language as the revealed mosaic wherever tease meets reveal or unknown.
- Keep frontier/frontier internal seams suppressed so the fog does not become a full debug grid.
- Unknown territory remains borderless and opaque; the visible frontier outline exists to make teaser cells legible, not to fully expose unexplored structure.

## 2026-05-22 — cell habitats require provenance and explicit urban normalization
- Do not treat legacy `cell_properties.habitats` rows as self-authenticating terrain facts.
- Add backend habitat provenance on `cell_properties` (`habitat_source`, `habitat_source_version`, `habitat_confidence`, `habitat_provenance`, `habitat_updated_at`) so the app and operators can distinguish legacy fallback labels from real classified terrain.
- Keep the player-facing map taxonomy compact, but expand it to include **Urban** as an explicit built-up terrain class instead of overloading **Plains**.
- Normalize richer source labels into the map taxonomy:
  - `grassland` / `cropland` / `meadow` → `plains`
  - `wetland` → `swamp`
  - `coastal` → `ocean`
  - built-up tags such as `urban` / `residential` / `commercial` / `industrial` → `urban`
- Implement a source-agnostic artifact pipeline:
  - normalize OSM / land-cover GeoJSON into `cell-habitat-artifact/v1`
  - import source features into PostGIS with immutable `source_version`
  - aggregate feature coverage against canonical `cell_geometry_cells`
  - audit each classification run in `cell_habitat_classification_runs` / `cell_habitat_classification_results`
- The client may hide unverified single-`Plains` legacy rows as `Terrain unclassified`, but once `habitat_confidence` is `classified` or `partial`, real `Plains` and `Urban` labels should render normally.

## 2026-05-23 — Frontend design library uses main-website enforcement shape

- EarthNova now has a canonical Flutter design library at `lib/shared/design/`, modeled after the `main-website` repo's enforced `src/design/` structure.
- Use taxonomy folders: `foundations`, `primitives`, `composites`, and `patterns`; screens consume the public `package:earth_nova/shared/design.dart` API, not internal taxonomy paths.
- `lib/shared/design/registry.dart` is the component inventory and must record each exported design widget's category, status, purpose, and direct screen-usage policy.
- Current first-pass canonical widgets are `EarthActionButton`, `EarthMetaText`, `EarthTag`, `EarthNotice`, `EarthPanel`, `EarthFieldRow`, `EarthStatGrid`, and the catalog-only `DesignLibraryExample`.
- Enforcement lives in `test/shared/design/`: contract structure/import checks, registry parity, catalog render smoke, and action touch-target coverage.
- Existing older feature widgets can migrate opportunistically; do not churn stable screens solely for architecture, but new reusable frontend UI should enter through the design library first.

## 2026-05-24 — High-level app chrome must use design-library icons

- `LoadingDots`, bottom navigation, and map status chrome should consume a canonical `EarthIcon` / `EarthGlyph` primitive from `package:earth_nova/shared/design.dart`, not raw `Icons.*`, emoji spinners, or legacy `AppIcons` strings.
- Keep this enforcement narrow but real: app chrome is the first place users notice inconsistency, so `test/shared/design/design_contract_test.dart` now fails if those shared surfaces bypass the design icon primitive.
- Feature/domain icon migrations can continue opportunistically, but any new reusable icon-bearing chrome should enter through the design library first.

## 2026-05-24 — Web basemap must not depend on OpenFreeMap planet TileJSON

- Railway web runs proved `https://tiles.openfreemap.org/planet` can fail from real browser context even when the style JSON, sprites, and glyphs load, leaving the readiness gate stuck on `style_loaded`.
- Keep native/mobile on the existing OpenFreeMap Liberty vector style for now, but serve web from a repo-owned `web/base-map-style.json` raster style that uses direct browser-safe tiles and no label-heavy vector source bootstrap.
- Preserve the existing JS/Dart style-load bridge, but add a MapLibre JS style-ready poll (`map.isStyleLoaded()` / `map.getStyle()`) so style readiness can advance even if the JS `load` event never arrives because remote source fetches fail later in startup.

> **Domain-language supersession (2026-07-20):** The dated rationale below remains historical evidence. Current canonical terms and relationships are Venue, Villager, Service, Venue Visit, Town projection, Home, Pack, Index, Item, and Discovery as defined in `CONTEXT.md`. Old NPC, Place, Feature, Field Guide, Sanctuary, rarity, and Orb-crafting assertions do not authorize or define current implementation.

## 2026-05-24 — NPCs introduce major game features

- Major game features should be introduced through NPCs rather than appearing as unexplained menu systems.
- NPCs act as diegetic unlock/guide surfaces: e.g. a botanist introduces plant features, a museum or curator NPC introduces geology collections.
- NPC identity/details should be dynamically generated within product constraints, not hand-authored as a fully fixed cast from the start.
- Keep the first implementation simple: NPCs should unlock/explain feature capabilities and attach flavor/context, not become open-ended chat, simulation, factions, or heavy relationship systems by default.
## 2026-05-24 — NPC generation is location-first and function-authored

- NPCs should not be generated as free-floating characters first; the player should discover them on the Map as persistent world presences tied to a concrete cell + POI/building.
- Each relevant cell can host a permanent NPC building or venue anchored to a POI, so meeting an NPC feels like discovering a place in the world rather than opening a menu.
- NPC function is authored, not AI-generated: the game decides "this is a botanist", "this is a museum curator", or "this is a trader/questgiver for collections" first.
- Generation should apply only to flavor and identity details within that authored function: name, portrait seed, presentation, affiliation, voice/tone, intro copy, personal quirks, and other cosmetic/worldbuilding details.
- This keeps NPCs legible and roadmap-driven while still allowing world variety and replayable flavor.
## 2026-05-24 — NPC venue placement rules

- One NPC type per city: e.g. one botanist, one museum curator, one ranger per city.
- One NPC venue maximum per cell: a cell can have zero or one NPC, never more.
- NPC venue is placed at the most popular POI within the chosen cell — popularity is determined from POI data (e.g. OSM popularity/foot traffic signals).
- "City" means the city-level location node in the existing location hierarchy, not arbitrary geographic grouping.
- This means NPC venues are sparse, legible, and tied to real-world prominence signals rather than random placement or dense per-cell NPC spam.

## 2026-05-24 — Town menu exposes unlocked NPC-led features

- Add a top-level `Town` menu/surface that shows discovered character-owned local places.
- Town entries are place-first, not feature-first: e.g. `[Character]'s Wildlife Rehab Center` contains the `Release to Wild` service.
- Opening an unlocked Town service should bind the UI to the nearest eligible NPC/place of that feature/type relative to the player's current location.
- This makes features feel local and character-led without turning Town into a generic feature registry or task board.
- Eligibility should respect the placement rules: one NPC type per city, one NPC max per cell, and venue anchored to the chosen cell's most popular POI.

## 2026-05-24 — Sanctuary becomes Home

- Rename the player-facing `Sanctuary` concept to `Home`.
- Home should be the player's personal place/base in the Town-style model, while NPC-led services live under `Town`.
- Existing implementation identifiers can migrate deliberately later; the product language should move toward `Home` for player-facing capability/feature naming.

## 2026-05-24 — Navigation language should be clear and boring

- Prefer clear, literal, non-sensational player-facing navigation labels.
- The excitement should come from accurate conservation/science roleplay and earned systems, not fantasy branding or poetic shell labels.
- Rename `Pack` directionally toward a broader `Player` surface, because it should contain inventory/pack, buddy selection, player profile, stats, and personal settings.
- Use `Player` as the top-level label: broad, boring, game-native, and clearer than `Profile` for mixed personal/inventory/progression state.
- Avoid cute labels like `Me`, overly romantic labels like `Explorer`, narrow labels like `Pack`, and account-shaped labels like `Profile` for the top-level personal surface.

## 2026-05-24 — First Town/NPC slice remains unresolved; Naturalist/Field Survey rejected

- Keep `Living World` as the capability that owns NPC venue discovery, Town entries, local feature binding, and authored NPC functions.
- Do not lock `field-naturalist` / Naturalist Field Station as the first concrete NPC slice.
- Do not default the first NPC loop to Field Survey, service-vendor, task-board, or MMO daily-request framing.
- The first concrete NPC and interaction loop must be selected through additional design work, then captured in SuperBDD before implementation.
- Town remains part of the SuperBDD action catalog via `open-town`; map-cell venue discovery and Town feature binding remain captured as `discover-npc-venue` and `open-npc-led-feature`.

## 2026-05-24 — First Town/NPC slice is Wildlife Rehabilitation Center → Release to Wild

- First venue type: `wildlife-rehabilitation-center`.
- First NPC role: `Wildlife Rehabilitator`.
- First NPC-led Town feature: `Release to Wild`.
- Base one-off release is always available; optional local programs add bonus slot-filling asks.
- First/default program style is generated "look for this trait" requests over local map/cell/species metadata — habitats, animal type/group, ecological tags, and existing authored traits — not vulnerable-fauna or conservation-status buckets.
- The loop should feel like durable conservation programs / community-center-style contribution, not Field Survey, service-vendor, task-board, or MMO daily-request loops.
- Release is an irreversible item-instance commitment: the animal leaves active Pack, appears in the center's release ledger/history, Field Guide knowledge remains, and the default reward is a flat Orb item-stack amount.
- No durable Rehab Trust/reputation track exists in v1; Orbs are PoE-style consumable crafting item stacks, not wallet currency.
- Program slot matching is strict; UI may suggest nearby/missing matches, but one animal fills exactly one chosen slot.
- Release storage uses append-only release events as canonical history plus current slot occupancy projections for fast UI and one-to-one enforcement.
- First implementation slice is backend/domain-first: schema/RPC/tests with minimal UI.
- Release eligibility floor: active identified fauna owned by the player, not already released, and not currently serving as a buddy, placed at Home, or committed elsewhere unless those states are cleared first.

## 2026-05-24 — Town visual model is character-owned places

- Town should feel like a directory of discovered character-owned places, not a service catalog or feature backlog.
- Map markers should identify the place and character, not advertise unbuilt feature status.
- Unavailable services should use diegetic copy such as `Opening soon` / `Not yet accepting releases`, not implementation copy such as `Feature not built yet`.
- The first concrete place shape is `[Character]'s Wildlife Rehab Center`, currently represented in the thin slice as `Rowan's Wildlife Rehab Center`.

## 2026-05-24 — Design validation requires app UI surface inventory

- The design system is no longer limited to reusable component registry checks.
- Every Flutter UI implementation outside `lib/shared/design/` must be listed in `designSurfaceInventory` with category, status, purpose, and design-system notes.
- There is no separate legacy exception path: app-specific UI is either part of the documented surface inventory or it fails validation.
- This intentionally closes the old migration gap where feature-local screens/widgets could carry undocumented local styling; any new UI file now shows up as a design-system validation event.

## 2026-07-20 — Encounter state creation and Outcome application use two transactional RPC boundaries

- `v3_cell_visits` remains the exact append-only event that begins Encounter entry resolution.
- The first RPC owns immutable Cell Visit resolution plus zero-or-one Encounter occurrence creation:
  - derive ownership from `auth.uid()` and lock the owned Cell Visit
  - accept the selected active Selector candidate and the exact Encounter Version the app planned
  - verify the candidate belongs to the Selector and matches its result
  - lock the selected Encounter Definition and reject a stale expected Version rather than silently rebinding it
  - persist explicit None without an Encounter, or persist the resolution and exact-version-bound pending Encounter together
  - make retries idempotent through the one-resolution-per-Cell-Visit constraints and reject changed retry inputs
- The second RPC owns Option selection plus ordered Outcome application:
  - lock the pending Encounter and return an already-resolved result idempotently
  - derive the single implicit Option for automatic Encounter Versions; manual selection remains explicit
  - validate and plan every ordered Outcome before mutation
  - bind each generated Item to the Base Item's current published Version while holding the relevant content lock
  - commit the Encounter transition, Items, and immutable Outcome results in one transaction
  - use a nested PostgreSQL exception block so a failed Outcome commit rolls back every partial mutation before durable failure evidence is written
- Add a unique generated-Item reference to Generate Item Outcome results so the mutation is reconstructable end to end.
- Terminal Encounter states are immutable: only `pending → resolved` or `pending → failed` transitions are valid.
- Runtime tables stay read-only under RLS; authenticated mutation is available only through security-definer RPCs that set `search_path`, check `auth.uid()`, and receive explicit execute grants.
- Reveal Venue remains a recognized Outcome kind but cannot mutate player state until the living-world schema provides a durable player-known Venue projection. The first RPC implementation must fail it explicitly without partial results; the later living-world slice extends the same transaction boundary rather than adding a client-side write.
- The current compatibility Selector candidate is app-resolved because the legacy loot input is not durable server context. This is a beta compatibility boundary, not a general authorization model; new Condition inputs must become server-verifiable before they authorize valuable outcomes.
- Evidence: migrations `077`–`080`, `docs/adr/0006-bind-definition-versions-at-state-creation.md`, and the existing `041_cell_geometry_publish_function.sql` lock/validate/commit pattern.

## 2026-07-20 — Cell Visit recording is an idempotent authenticated command

- Record new Cell Visits only through `record_v3_cell_visit(cell_id, client_event_id)`.
- The command derives the Player from `auth.uid()`, server-stamps `visited_at`, and returns the exact persisted row.
- One canonical client event identity is unique per Player; a same-event/same-Cell retry returns the original identity and timestamp, while reusing that event for another Cell fails closed.
- Existing Cell Visits keep nullable client event identity. New ids must be nonblank, bounded, and already trimmed.
- Direct authenticated Cell Visit inserts and all Cell Visit updates/deletes are closed.
- The command authenticates ownership and timing only. Client-reported Cell identity is not physical-presence or anti-cheat proof.

## 2026-07-20 — Preserve legacy Index continuity with explicit Discovery provenance

- Backfill one Discovery for each existing identified `(Player, stable Base Item)` pair so the new Index does not erase knowledge already visible through identified Items.
- Select the first provenance Item deterministically by `identified_at`, then `acquired_at`, then Item id.
- Preserve that Item's exact bound Base Item Version and label the row `legacy_backfill`.
- Do not invent Property Values, Identification events, Discipline XP, or progression for legacy rows.
- New transactional Identification will distinguish `explicit_identification` from `automatic_identification`.

## 2026-07-20 — Item creation is command-owned before Identification cutover

- Legacy/shadow compatibility acquisition uses `acquire_v3_legacy_discovery_item`; authoritative Generate Item Outcomes remain owned by the Encounter outcome command.
- Neither command accepts caller-owned user, stable Base Item, or Base Item Version identity. Both derive ownership and bind the server's exact current published Version when creating an Item.
- Direct authenticated Item INSERT and DELETE are revoked, and Item identity/acquisition/content binding plus hidden Identification source evidence are immutable.
- Existing own-row UPDATE is temporarily restricted to the seven visible Identification projection fields needed by the current reveal path.
- The later transactional Identification command must revoke that remaining direct UPDATE compatibility path; it is not a permanent client-authoritative mutation model.

## 2026-07-20 — Variable Property resolution is deterministic and server-authoritative

- Keep normalized `v3_variable_properties`, exact-Version assignments, Selectors, and Property Values as the only canonical authored/runtime model; do not duplicate effective properties inside authored JSON.
- Derive one weighted roll from SHA-256 of `Item id + U+001F + Variable Property id`, using the first 32 bits divided by `2^32` and candidate ordinal order.
- The client may prepare and retain the plan for presentation/retry, but the Identification command recomputes the expected candidate and rejects a mismatch.
- Explicit None is a real candidate/result and is persisted as such.
- Until a server Condition evaluator and trusted context exist, publishing an assigned Variable Property whose candidate carries a Condition fails closed.

## 2026-07-20 — Identification is one atomic command and Item generation derives its lifecycle

- Identification commits Discovery, every exact-Version Property Value, the visible Item projection, and an immutable explicit receipt in one transaction.
- First Identification creates one Discovery keyed by Player and stable Base Item. Later Identifications never replace its first exact Item/Version provenance.
- Every future command-created Item derives its state using one rule: Identification is required iff its stable Base Item is not Discovered or its exact bound Version has any Variable Properties.
- A repeated no-property Item for a discovered stable Base Item is automatically identified at insert and receives an automatic receipt; it creates no duplicate Discovery and no Property Values.
- Discipline XP, levels, thresholds, unlocks, and events remain inactive until separately tuned.
- After the Flutter Pack runtime uses prepare/commit, authenticated direct Item UPDATE is revoked; the old pending-field copy path is mock-only compatibility.

## 2026-07-20 — Pack and Index are separate read models

- Pack owns the Player's active Item-instance collection, filters, screen, and cards; it may show instance Identification and Property state.
- Index owns one player-facing entry per Discovered stable Base Item, retaining the first exact Version snapshot/provenance.
- Index never derives from Pack multiplicity, never exposes Item Property Values, and never resolves an old Discovery through the current published Version.
- The shared Item identity remains in core for cross-context use; feature behavior/repositories no longer live in the shared core or one mixed Identification read boundary.

## 2026-07-21 — Reveal Venue and Town use exact durable knowledge

- A `reveal_venue` Outcome binds the stable Venue and exact published Venue Version into the immutable Encounter Outcome result.
- The same Encounter outcome transaction inserts first-known Venue provenance; repeat reveals retain the original known row while each ordered Outcome keeps its own result evidence.
- Town is a projection, not a mutable aggregate table. It exposes only Player-known Venues and globally known Villagers at visited Venues' current published rosters, plus current Services.
- Town presents current authored names/roles/Services while retaining each Venue/Villager's immutable first-known Version and Outcome/Visit provenance.
- Unrevealed Living World authored tables and Reveal Outcome target payloads are not directly enumerable by authenticated clients.
- The Rowan compatibility seed creates authored Venue/Villager/Service content only; it does not seed player knowledge.

## 2026-07-21 — Venue Visit is exact, idempotent, and physically gated

- `record_v3_venue_visit(cell_visit_id, venue_id, expected_venue_version_id)` is the only Venue Visit mutation boundary.
- The command derives ownership, requires an owned exact Cell Visit at the Venue anchor Cell, and binds the current exact Venue Version for a new Visit.
- Retrying the same Cell Visit/Venue requires the originally persisted Version, returns that historical Version, introduces nobody, and never repurposes an old Visit after authored content changes.
- A later Cell Visit can introduce only Villagers on the current Venue roster whom the Player does not already know.
- Physical-presence trust and the client trigger remain deliberately unresolved. Map, Town, GPS, and screen-open paths do not invoke the command.

## 2026-07-21 — Home is identity-only and category completeness remains behavior-free

- Every `v3_profiles` Player has exactly one immutable UUID Home, created automatically for new profiles and backfilled for existing profiles.
- Home is read-only at this boundary. No Home Module kind, placement, capacity, upgrade, lifecycle, or Item-placement model is authorized.
- The canonical Food Base Items are exactly Veg, Fruit, Critter, Fish, Grub, and Nectar; a validated stable-ID whitelist prevents a seventh Food type.
- `orb:orb_type` / `Orb Type` is explicit authored Base Item identity only. Orb use, crafting, stacking, currency, consumption, and lifecycle behavior remain absent.
- Player-facing navigation and copy use Home. The legacy `open-sanctuary` identifier remains only as EAC/telemetry compatibility evidence until a separately authorized identifier migration.

## 2026-07-21 — Item identity is opaque until command-owned Identification

- `acquire_v3_legacy_discovery_item` accepts only compatibility discovery identity/provenance, derives canonical Base Item and exact published Version evidence server-side, and retains idempotent retry semantics.
- Authenticated clients cannot directly select `v3_items`. The owner-bound Pack projection is the only active collection read boundary.
- Before Identification, an Item exposes only its opaque instance ID, generic display, category, acquisition provenance, and lifecycle state. It never exposes canonical definition/Base Item/Version IDs, taxonomy, habitat, continent, or identified fields.
- Identification is the sole player-facing reveal boundary. Its prepare, deterministic plan, and commit share one trace ID; only identified Pack projections expose canonical identity.
- Encounter outcome storage retains exact Item/Base Item/Version evidence server-side, while authenticated aggregate responses redact Generate Item canonical identity until that Item is identified.

## 2026-07-21 — Encounter actions preserve every reward and one root trace

- An Encounter action creates one root trace before Cell Visit persistence. That trace correlates Cell Visit, selector/version binding, transaction/retry, repository terminal events, and user-facing completion/failure logs.
- Trace context is observability-only and does not change existing authenticated RPC parameter shapes or persist a client-controlled trace into game evidence.
- Generated Item Outcomes are plural and ordered. The runtime validates, registers, and presents every committed generated Item rather than selecting a first reward.
- Supabase Encounter providers must inject the active Encounter observability logger; repository telemetry is a production composition requirement, not a test-only adapter option.

## 2026-07-21 — Repository boundaries sanitize outward failures

- Map Cell, Map Hierarchy, Auth, and Encounter version-binding adapters emit stable non-secret terminal diagnostics internally, then expose only safe domain failures to use cases.
- Raw transport bodies, SQL errors, parser payloads, and credentials may not cross into `ObservableUseCase` summaries or terminal telemetry.
