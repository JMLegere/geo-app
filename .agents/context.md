# Current Session Context

## Completed 2026-05-03 — deployment foundation
- Set up Railway `beta` environment in project `fog-of-world`.
- Created beta Supabase project `ggkvcpgvxqaqzwxehlns`.
- Seeded beta Supabase from production data and recreated beta auth users.
- Repaired beta Supabase migration history (`001`-`038`) so `supabase db push --linked` is clean in GitHub Actions.
- Refactored Dockerfile to require environment-provided `SUPABASE_URL` / `SUPABASE_ANON_KEY`.
- Added GitHub Actions workflows for beta deploy and manual production promotion.
- Merged deployment work through PR #476 and Railway API token fix through PR #477.
- GitHub Actions `Deploy Beta` passed on main commit `7da8fa3`.
- Railway beta deployment `78b1bc7f-3706-454d-8aa4-7515bc16d26d` reached `SUCCESS`.
- Browser verification confirmed beta bundle contains beta Supabase ref and not production ref.

## Completed 2026-05-03 — backlog discovery audit
- Normalized `2026-04-03-work.md` so it no longer presents Pack MVP as the next unfinished slice.
- Reworked `2026-04-03-backlog.md` into priority bands.
- Set the explicit next recommendation to **Map & Exploration foundation**.
- Surfaced blocked/under-specified systems in `.agents/questions.md`, especially discovery encounter count, identification/enrichment blockers, sanctuary/economy questions, and operations risks.
- Clarified that `docs/prd-game-systems.md` is aspirational design intent unless blockers from `docs/prd-game-systems-review.md` are resolved.

## Completed 2026-05-03 — Slice 1 map data + fog correctness pass
- Added clean-architecture data ports: `CellQueryPort` for geometry and `CellVisitPort` for visit history.
- Added Supabase adapters for the split ports and kept `SupabaseCellRepository` as a temporary bridge for existing providers/use cases.
- Wired production cell fetch semantics to the `fetch_nearby_cells` RPC via `SupabaseCellQueryAdapter`.
- Fixed cell DTO contract coverage so real polygons and hierarchy IDs survive into domain `Cell` objects; empty-polygon cells are filtered before domain state.
- Added pure `FogStateService` for present/explored/nearby computation from current marker cell plus persisted/optimistic visits.
- Updated `MapScreen` to use `FogStateService`, so the current marker cell can render as `present`.
- Removed the `IgnorePointer` block that prevented cell overlay taps from reaching the `GestureDetector`.
- Verification: focused map tests passed with `flutter test --no-pub ...`; `flutter analyze --no-pub` passed with no issues.

## Current State
- Beta Railway URL: `https://geo-app-beta.up.railway.app`
- Production Railway URL: `https://geo-app-production-47b0.up.railway.app`
- Beta Supabase auth sign-in verified for test phone `+15551234567` against beta project.
- Beta Railway environment variables point at beta Supabase.
- Production Railway environment variables explicitly point at production Supabase.
- GitHub secrets configured: `RAILWAY_API_TOKEN`, `SUPABASE_ACCESS_TOKEN`, `SUPABASE_BETA_PROJECT_REF`, `SUPABASE_BETA_DB_PASSWORD`, `SUPABASE_PRODUCTION_PROJECT_REF`.
- Roadmap source order for next work: `AGENTS.md` → `docs/design.md` → `docs/map-design.md` → `2026-04-03-backlog.md`.

## In Progress 2026-05-03 — fog geometry RCA + substrate repair
- Beta QA showed `map.cells_fetch_complete` with `cells_with_polygon: 0` and `cells_without_polygon: 1000`.
- RCA: frontend fog/rendering path preserves polygons correctly; backend read model is wrong because `v3_map_cells_read_model` sources `polygon` from `districts.boundary_json`.
- Beta data has no district boundaries, and district boundaries would still be conceptually wrong because many cells share one district.
- Repo archaeology found no existing true per-cell Voronoi geometry storage/generation pipeline.
- Added data-model foundation migration `supabase/migrations/039_cell_geometry_data_model.sql`:
  - enables PostGIS
  - adds versioned immutable geometry batches
  - adds raw staging with raw payload + parsed geometry metadata
  - adds active-version pointer and `cell_geometry_current` view
- Added validation model migration `supabase/migrations/040_cell_geometry_validation_model.sql`:
  - split ownership: service imports/parses; DB/PostGIS owns spatial/topology validation
  - appends validation runs/issues instead of overwriting audit history
  - enforces semantic zero topology tolerance with `1.0 m²` overlap/gap epsilon for numeric noise
  - validates staged cell coverage against `cell_geometry_versions.coverage_geom`
  - initially validated 039+040 against linked beta inside `BEGIN`/`ROLLBACK`
- Added publish model migration `supabase/migrations/041_cell_geometry_publish_function.sql`:
  - appends `cell_geometry_publish_events`
  - publishes only a passed validation run
  - rejects staging modified after validation finished
  - copies staged rows into immutable `cell_geometry_cells`
  - atomically switches `cell_geometry_active_version`
  - retires prior active version and marks new version active
  - validated 039+040+041 against linked beta inside `BEGIN`/`ROLLBACK`
- Added external artifact schema `supabase/cell_geometry_artifact.schema.json`:
  - custom JSON bundle: `{schema_version, source, source_version, coverage, cells:[...]}`
  - coverage is authoritative generation boundary
  - each cell has `cell_id` plus GeoJSON Polygon/MultiPolygon geometry
  - coordinates are GeoJSON-standard `[lng, lat]`
- Added repo importer script `scripts/import_cell_geometry_artifact.py`:
  - reads the custom JSON artifact and computes SHA-256
  - writes `cell_geometry_versions` with PostGIS coverage geometry
  - replaces staging rows only for non-active/non-canonical source versions
  - writes `cell_geometry_staging` with raw payload, raw geometry, raw properties, parsed MultiPolygon, point-on-surface centroid, bbox, and area
  - supports `--dry-run`, `--emit-sql`, and `--db-url`
  - verified with Python bytecode compile and `--help`
- Added fixture artifact `supabase/fixtures/cell_geometry_artifact_minimal.json`.
- Validated migrations `039`-`041` plus emitted importer SQL for the fixture against linked beta inside one rollback transaction:
  - result: `source_version=fixture-minimal-v1`, `staged_cell_count=2`
- Full custom artifact generation succeeded, but Management API import validation hit HTTP 413 due payload size.
- Added DB-side beta-scale staging migration `supabase/migrations/042_stage_cell_geometry_from_cell_ids.sql`:
  - derives centers from encoded `v_<x>_<y>` IDs as `lat=x/500`, `lng=y/500`
  - stages bounded uniform-lattice Voronoi squares directly inside PostGIS
  - avoids huge artifact upload while preserving validation/publish traceability
  - rollback-validated `039`-`042` against linked beta:
    - stage count: `7820`
    - full stage → validate → publish path: `cell_geometry_current` count `7820`
- Integrated geometry substrate into beta:
  - pushed migrations `039`-`042`
  - staged `db-lattice-voronoi-beta-v1` from encoded beta cell IDs: `7820` rows
  - validated source version: `error_count=0`, gaps/overflow/overlap all `0`
  - published source version: `ef1021ad-b9dc-4e77-8069-3a5567ecdd03`
  - active geometry verification: `cell_geometry_current=7820`, canonical rows `7820`, one publish event, one passed validation run
- Added and pushed read-model migration `043_map_cells_read_model_cell_geometry.sql`:
  - `v3_map_cells_read_model` now inner joins `cell_geometry_current`
  - emits legacy `polygon` plus richer `polygons` JSON
  - `fetch_nearby_cells(45.99,-66.65,2000)` returns `357` cells, all renderable and all with `polygons`
- Saved QA report `.agents/qa/2026-05-03-geometry-substrate-beta-integration.md`.
- Browser visual QA is blocked by a separate app bootstrap/canvas issue:
  - pageerror: `Cannot read properties of null (reading 'appendChild')`
  - app health buffer: `canvas element missing`
  - no fresh `map.cells_fetch_complete` emitted from browser session
  - direct DB/RPC geometry verification passed
- Manual browser login with fake phone `5551234567` succeeded and reached the live map shell.
- Map tiles rendered after geolocation override to Fredericton, but no visible fog/polygon overlay appeared.
- Browser network showed direct REST reads to `cell_properties` / `v3_cell_visits` and no `fetch_nearby_cells` RPC traffic, implying the deployed beta frontend still uses the older fetch path.
- After PR #478 deployed, post-deploy manual QA passed:
  - browser network now calls `/rest/v1/rpc/fetch_nearby_cells`
  - visible fog/cell overlay appears on the beta map
  - `map.cells_fetch_complete`: `total_cells=357`, `cells_with_polygon=357`, `cells_without_polygon=0`
  - screenshot: `artifacts/beta-post-deploy-rpc-map.png`

## Added 2026-05-03 — engineering constraints
- Codified repo rules in `.agents/constraints.md`:
  - TDD for behavior changes
  - full traceability from user action through data/audit records
  - explicit audit logs for import, validation, publish, enrichment, and gameplay-significant mutations
## Next Recommended Work
- PR #479 upgraded map domain/rendering from legacy flat `polygon` to canonical `polygons -> rings -> points` and deployed to beta.
- Post-deploy QA passed on beta:
  - `fetch_nearby_cells` RPC returned HTTP `200`
  - `map.cells_fetch_complete`: `total_cells=357`, `cells_with_polygon=357`, `cells_without_polygon=0`, `visited_count=3`
  - visible fog/cell overlay present in `artifacts/beta-nested-polygons-post-deploy-map.png`
- Next recommended work: refine visual fog correctness/current-cell highlighting/tap behavior now that full nested geometry is live.


## In Progress 2026-05-04 — organic map geometry + visual polish
- PR #481 deployed `c512a488` and fixed the duplicate marker plus bottom snackbar/attribution collision, but beta QA still showed square geometry, hard top fog cutoff, strong grid seams, top attribution crowding, and hash-like encounter names.
- Added/pushed migration `044_stage_cell_geometry_from_organic_centroids.sql`:
  - preserves existing `v_<x>_<y>` cell IDs and beta visit history
  - creates deterministic jittered organic centroids from each cell ID
  - generates true `ST_VoronoiPolygons` geometry in PostGIS
  - clips Voronoi cells to the existing beta coverage footprint
  - records `centroid_dataset_version`, `generation_mode`, and `geometry_contract` metadata
- Added/pushed migration `045_cell_geometry_validation_timeout.sql` so beta-scale organic topology validation can complete under Supabase statement timeout limits.
- Published beta source version `organic-voronoi-beta-v1`:
  - validation run `4eef13d6-0750-407b-b18b-2be54ef2bf81`
  - previous source `db-lattice-voronoi-beta-v1`
  - `cell_geometry_current=7820`
  - `fetch_nearby_cells(45.99,-66.65,2000)` now returns `geometry_source_version=organic-voronoi-beta-v1`, `361` nearby cells, first-ring point range `4–13`.
- Frontend branch `fix-map-organic-geometry-polish` adds:
  - frontier/unknown seam suppression to avoid debug-grid fog
  - top fog feather under the status area
  - MapLibre attribution margin increased to avoid status crowding
  - `EncounterPresenter` for deterministic friendly names instead of raw hash labels
- Focused tests for migration contract, fog renderer, map screen structure, and encounter presenter pass locally.
## Remaining Risks / Manual Items
- `SUPABASE_PRODUCTION_DB_PASSWORD` is not configured, so production workflow will skip database migrations until that secret is added.
- Legacy Railway service `geo-app beta` still exists as an unused sibling service. Direct API deletion with the available token returned 403; remove manually in Railway dashboard if desired.
- Local `.hive/sessions.json` has an unrelated uncommitted modification and was intentionally not committed.

## Completed 2026-05-04 — map readiness + topology-aware render hardening
- PR #486 merged to `main` as commit `a2ef0391819becfff5379409d648b0527f84d628`.
- `Deploy Beta` passed for the same commit.
- Added migration `046_cell_geometry_visual_quality_and_provenance.sql`:
  - surfaces `geometry_generation_mode`, `centroid_dataset_version`,
    `geometry_contract`, and `geometry_visual_quality` through
    `v3_map_cells_read_model` / `fetch_nearby_cells`
  - stores advisory visual-quality summary under `validation_summary.visual_quality`
- Added steady-state map readiness gate in `MapScreen`:
  - startup now remains covered until map created, style loaded, base map settled,
    cells fetched, and overlay frame painted
  - beta logs showed `map.base_map_settled` came from the style-load fallback path
    during web QA
- Added topology-aware Flutter render projection:
  - grouped fills by reveal state
  - shared edges snapped/canonicalized and drawn once
  - same-state internal borders suppressed
  - present/explored seams softened
- Post-merge beta QA passed:
  - startup screenshots confirmed no raw fog-free map exposure before steady state
  - `fetch_nearby_cells(...)` returned provenance + non-null
    `geometry_visual_quality`
  - `map.readiness_waiting` and `map.steady_state_ready` logs were present
  - no `category='error'` rows for retest session

## Completed 2026-05-04 — OpenTelemetry-shaped observability replacement
- Replaced the old `app_logs` source of truth with OTel-shaped Supabase telemetry:
  - migration `047_otel_observability.sql` creates `telemetry_logs`, `telemetry_spans`, query indexes, and terminal-friendly views (`telemetry_session_timeline_v`, `telemetry_recent_errors_v`, `telemetry_startup_funnel_v`, `telemetry_map_readiness_v`)
  - migration drops the old `app_logs` / `app_events` compatibility surface with no historical backfill
- Added canonical `telemetry-ingest` Edge Function:
  - accepts one envelope with `resource`, `logs`, and `spans`
  - inserts via service role into `telemetry_logs` / `telemetry_spans`
  - configured `verify_jwt = false` so JS `navigator.sendBeacon()` diagnostics can reach it
- Removed the retired `beacon-events` function path and updated pipeline health to query `telemetry_recent_errors_v`.
- Reworked `ObservabilityService` into a thin OTel-shaped facade with logger/tracer ports, `TraceContext` 32-hex trace IDs, 16-hex span IDs, and `startSpan` / `endSpan`.
- Startup and map readiness flows now attach trace/span IDs:
  - `app.startup` span links `app.cold_start` and Supabase init logs
  - `map.bootstrap` span links map readiness logs and ends on `map.steady_state_ready`
- Web bootstrap JS now posts OTel-shaped log envelopes to environment-aware `telemetry-ingest` URLs instead of the old production-only beacon endpoint.
- Docs/runbook now query `telemetry_logs`, `telemetry_spans`, and telemetry views.
- Verification passed:
  - `flutter analyze --no-pub`
  - `flutter test --no-pub --reporter=compact`
  - `git diff --check`

## Completed 2026-05-04 — beta OTel trace validation
- PR #490 merged as `5823d02` and beta deploy passed; `telemetry_logs`, `telemetry_spans`, and `telemetry-ingest` are live on beta.
- Querying recent beta sessions confirmed Dart-side startup telemetry is flowing:
  - `app.cold_start`
  - `supabase.init_success`
  - `auth.session_restore_started`
  - `auth.no_session`
  - `navigation.screen_changed` to login
- Browser screenshot validation showed beta reaches the login screen normally after the OTel cutover; the app is not stuck before first frame.
- The earlier `Cannot read properties of null (reading 'appendChild')` trace was a false lead from the browser harness itself:
  - CDP `Debugger.getScriptSource` for the failing script id resolved to the harness's injected stealth script
  - the failing line was `document.head.appendChild(iframe)` inside the tool's own anti-detection prelude
  - this was reported via `report_tool_issue(browser, ...)`
- Remaining observability gap:
  - JS bootstrap/beacon telemetry uses persistent `earthnova_session_id` from localStorage
  - Dart/app telemetry generates a fresh per-load UUID in `main.dart`
  - cross-layer startup traces therefore require timestamp correlation instead of a shared session/trace id

## In Progress 2026-05-05 — lifecycle grammar for terminal-agent debugging
- Added a lifecycle grammar on top of OTel-shaped telemetry for reactive debugging by terminal agents.
- Canonical lifecycle attributes: `flow`, `phase`, `dependency`, `previous_state`, `next_state`, `reason`.
- Canonical phases: `started`, `waiting_on`, `dependency_requested`, `dependency_ready`, `dependency_failed`, `state_changed`, `completed`, `failed`, `timed_out`, `cancelled`.
- Instrumented startup, use-case, JS bootstrap, map bootstrap/readiness, GPS, and cell fetch telemetry with lifecycle attributes while preserving existing event names where useful.
- Added migration `048_telemetry_lifecycle_views.sql` with:
  - `telemetry_flow_lifecycle_v`
  - `telemetry_incomplete_flows_v`
  - `telemetry_dependency_failures_v`
- Local verification passed:
  - focused lifecycle telemetry tests
  - `flutter analyze --no-pub`
  - `flutter test --no-pub --reporter=compact`
  - `git diff --check`

## Completed 2026-05-08 — debug map movement controls
- Developer/debug overlay now includes player movement controls (`P↑`, `P↓`, `P←`, `P→`) plus a `GPS` resume control.
- Pressing a debug movement control switches `LocationNotifier` into simulated-location mode, cancels the active GPS stream subscription, and emits `map.debug_location_updated` with `geo_location_enabled=false`.
- Simulated movement starts from the current active location when available, otherwise from the Fredericton beta fixture coordinate (`45.9636,-66.6431`) so local/web QA fetches real beta map cells.
- `GPS` exits simulated mode, emits `map.debug_location_disabled`, and restarts the normal GPS permission/current-position/stream flow.
- Verification passed:
  - `flutter test --no-pub test/features/map/presentation/providers/location_provider_test.dart test/shared/debug/debug_gesture_overlay_test.dart`
  - `flutter test --no-pub test/shared/widgets/tab_shell_test.dart`
  - `flutter analyze --no-pub`
  - `flutter test --no-pub --reporter=compact`
- Beta QA immediately after PR #538 found the simulated movement buttons were present and emitted `map.debug_location_updated`, but web fallback GPS had already activated at the old San Francisco mock coordinate (`37.7749,-122.4194`), causing `fetch_nearby_cells` to return `0` renderable cells. Follow-up fix changes the default fallback mock location to the Fredericton beta coverage coordinate.
- Final beta QA after PR #539 / commit `99630a6` passed: beta bundle showed `β 2026-05-08-1942-99630a6`; fallback GPS selected Fredericton (`45.9636,-66.6431`); `fetch_nearby_cells` returned `480` cells with polygons; `map.steady_state_ready` emitted; debug east movement emitted `map.debug_location_updated` and then `map.cell_entered` / `map.cell_visited` for `v_22982_-33321`. Screenshot saved at `artifacts/beta-debug-simulated-movement-99630a6.png`.

## In Progress 2026-05-18 — exploration experience discovery
- Jeremy preferred the old map exploration experience but explicitly does **not** want the old renderer brought back.
- Use the old pre-nuke map as a reference for desired feel only; current discovery should define the intended movement/reveal/cell-crossing experience before further implementation.
- User identified the primary current failures as **semantic jank**, **visual jank**, and **reward jank** — not primarily movement jank.
- Target exploration fantasies selected: **revealing fog** and **crossing places**.

## Completed 2026-05-18 — EAC SuperBDD installation
- Installed released EAC through `mise.toml` using `github:JMLegere/eac = "1.2.1"`; `mise exec -- eac --version` resolves to `1.2.1`.
- Ran `eac add product/superbdd`, creating `eac.config.ts` with the `product/superbdd` adapter and default product/cucumber options.
- Authored real starter SuperBDD truth for EarthNova map exploration instead of generated placeholders:
  - `product/manifest.ts`
  - `features/map-exploration.feature`
- Released EAC `v1.2.1` on GitHub with SuperBDD doctor guidance; forced geo-app mise reinstall downloaded the release asset.
- Verification passed: `mise exec -- eac doctor` shows the SuperBDD model guide, `mise exec -- eac check`, `mise exec -- flutter analyze --no-pub`, `git diff --check`, and `mise exec -- flutter test --no-pub --reporter=compact`.

## Completed 2026-05-18 — map SuperBDD experience refocus
- Rewrote `product/manifest.ts` and `features/map-exploration.feature` around the chosen experience: revealing fog by crossing into meaningful places.
- Product capability shifted from generic map mechanics to **map place discovery**.
- Required map actions now emphasize the player-facing loop:
  - open steady board
  - hint nearby unrevealed places
  - cross into place
  - acknowledge place discovery
  - persist explored footprint
  - inspect place details
- Verification passed: `mise exec -- eac doctor` and `mise exec -- eac check`.

## Completed 2026-05-18 — World Events SuperBDD seed
- Jeremy chose **World Events** as the capability title for OSRS-style distractions/diversions.
- World Events are sporadic, optional, time-sensitive happenings that can interrupt or redirect exploration without replacing the core loop.
- Chose **Wildlife Migration** as the first World Events feature.
- Added SuperBDD coverage for Wildlife Migration in:
  - `product/manifest.ts`
  - `features/world-events-wildlife-migration.feature`

## In Progress 2026-05-18 — capability-level science synthesis
- Jeremy wants a focused natural-science capability pillar, not a broad STEM taxonomy or simple discoverable item categories.
- Removed Physics, Chemistry, Ecology, Microbiology, Meteorology, Hydrology, Oceanography, and Astronomy from the current capability set.
- Current science capability set: Zoology, Botany, Mycology, Geology, Paleontology, and Genetics, with Archaeology as a sibling human-history capability.

## Completed 2026-05-18 — capability-only SuperBDD spine
- Implemented a capability-only SuperBDD spine and deferred actions.
- Split product truth into separate files:
  - `product/capabilities.ts` owns the top-level capability catalog.
  - `product/actions.ts` is intentionally empty for now.
  - `product/manifest.ts` re-exports both for EAC compatibility.
- Replaced action-level feature files with `features/capability-spine.feature`.
- Verification passed: `mise exec -- eac check` and `mise exec -- eac doctor`.
- Added Field Journal, Conservation, Buddy, and Lineage to the spine; renamed Breeding to Lineage.
- Added Genetics as a top-level field-science capability for inherited traits, variation, and generation-to-generation life changes.

## Completed 2026-05-18 — first-pass feature candidate selection
- Used the interactive question tool to select candidate features under each top-level capability.
- Accepted broad world features: Fog all four; Exploration all four; Territories all four; World Events Wildlife Migration only.
- Accepted lifecycle/progression highlights: Discovery all four, Pack all four, Collections all four, Lineage all four, Identification without Readiness Mystery.
- Added feature selections to `.agents/decisions.md`.
- Open synthesis gaps: Mycology, Geology, and Archaeology still need accepted feature candidates.

## Completed 2026-05-18 — feature semantics correction
- Jeremy clarified that capabilities are broad app/game-system areas.
- Features should be concrete app features: large sections of a page, app surface, or data model that can be independently owned inside a capability.
- Prior selected "feature candidates" are now treated as experience ingredients/design inputs, not final feature definitions.
- Created `product/features.ts` as a separate feature catalog, while leaving EAC actions empty.
- Collapsed product truth away from Field Guide as a capability: Field Guide is now a Progression-Permanence feature/knowledge surface.
- High-level sciences remain top-level capabilities: Zoology, Botany, Mycology, Geology, Paleontology, Genetics, and Archaeology.
- Science capability files are tagged only with their science capability and are described as discipline sections surfaced through the Field Guide feature.
- Map has been decomposed from broad Fog/Exploration/World Events buckets into concrete map surfaces and data models: map frame, marker/ring, fog overlay/state, map cell detail/border crossing, nearby opportunity, territory scale/progress, and event cues/instances.
- Wrote stub `.feature` files for the detailed app features and verified with `mise exec -- eac check` and `mise exec -- eac doctor`.

## Completed 2026-05-18 — Map design cascade
- Authored SuperBDD scenarios for the mapping capability as a game system rather than a screen-only design.
- Captured the Map experience contract: orientation, marker trust, movement-driven reveal, technical map cell entry, nearby pull, and territory-scale accumulation.
- Captured the core loop: open map, orient on self, read fog/frontier, move physically, cross a Voronoi map cell border, reveal/update footprint, acknowledge map cell, optionally inspect/follow cues.
- Added state-machine scenarios across Map feature files for marker/ring trust, exploration eligibility, cell border crossing, fog state, fog overlay, map cell detail, nearby opportunities, territory navigation/progress, and world event cues/instances.
- Verification passed with `mise exec -- eac check` and `git diff --check`.

## Completed 2026-05-19 — map design source alignment
- Updated `docs/map-design.md` with the Map capability contract, GPS-level interaction stack, state-machine table, and reward intensity ladder.
- Clarified the Discovery handoff boundary: Map owns cell border crossing, fog reveal, map cell acknowledgement, cues, and territory context; high-intensity species/item/identification/pack rewards are downstream.
- Replaced the old forced first-visit TCG popup language in the map doc with a medium-intensity first-entry map cell event plus optional downstream handoff.
- Updated map observability events to include cell border crossing, exploration eligibility, cell entry acknowledgement, and discovery handoff availability.
- Verification passed with `mise exec -- eac check` and `git diff --check`.

## Completed 2026-05-19 — first playable map slice design
- Added the first playable Map slice to `docs/map-design.md`.
- First slice includes: Map Frame, Player Marker + Accuracy Ring, Exploration Eligibility State, Cell Border Crossing Model, Fog State Model, Fog Overlay, and Map Cell Detail Sheet.
- Deferred broader/full-fantasy pieces from the first slice: territory dashboard polish, advanced marker personality/skins, rich POI or social place claims, full habitat art direction, and downstream Discovery/Pack/Field Guide reward reveal.
- Added GPS-level visual grammar and hierarchy: marker/ring first, then current map cell, fog relationship, cell cue, and base map detail.
- Strengthened SuperBDD scenarios for first-slice focus, one border crossing identity, visual hierarchy, and cell-before-reward detail.
- Verification passed with `mise exec -- eac check` and `git diff --check`.

## Completed 2026-05-19 — first-slice map contract design
- Added first-slice moment choreography to `docs/map-design.md`: map enters, map steadies, trust resolves, movement, border crossing, first entry/re-entry, detail opened, trust lost, trust recovered.
- Added first-slice state contracts: `MapReadiness`, `MarkerTrust`, `ExplorationEligibility`, `CellBorderCrossingEvent`, `FogRelationship`, `CellEntryFeedback`, and `MapCellDetailState`.
- Defined the first-slice map cell detail sheet as a dismissible field-note card with heading, status pill, territory context, visit facts, fog/progress note, and secondary handoffs.
- Extended SuperBDD scenarios for readiness contracts, ring browse-only behavior, eligibility gating, border crossing identity fields, fog consistency, and sheet anatomy.
- Verification passed with `mise exec -- eac check` and `git diff --check`.

## Completed 2026-05-19 — first-slice payload and acceptance design
- Added first-slice payload shapes to `docs/map-design.md`: `MapReadiness`, `MarkerTrust`, `ExplorationEligibility`, `CellBorderCrossingEvent`, `FogRelationshipSet`, `CellEntryFeedback`, and `MapCellDetailState`.
- Added component responsibility boundaries for map frame, marker/ring layer, cell/fog overlay, border crossing coordinator, entry feedback presenter, map cell detail sheet, and observability hooks.
- Added a first-slice acceptance matrix for cold open trusted/bad GPS, same-cell movement, first border crossing, jitter, re-entry, detail inspection, trust loss, and trust recovery.
- Extended SuperBDD scenarios for same-cell quiet movement, reward-clean border crossing payloads, and non-mutating detail inspection.
- Verification passed with `mise exec -- eac check` and `git diff --check`.

## Completed 2026-05-19 — map terminology correction
- Jeremy clarified that this level of design should use technical terms rather than emotionally nice names.
- Renamed the capability from World Board to Map across product capability tags and feature inventory.
- Standardized first-slice spatial unit terminology: generated polygon = Voronoi map cell, shorthand = map cell, boundary = map cell border.
- Corrected the movement language: the player crosses a map cell border and enters a map cell; they do not "cross a map cell."
- Renamed the crossing model to Cell Border Crossing Model and the shared payload to `CellBorderCrossingEvent`; entry feedback is `CellEntryFeedback`; detail state is `MapCellDetailState`.
- Verification passed with `mise exec -- eac check` and `git diff --check`.

## Completed 2026-05-19 — first-slice transition and invariant design
- Added first-slice transition rules to `docs/map-design.md` for `MapReadiness`, `MarkerTrust`, `ExplorationEligibility`, `CellBorderCrossingEvent`, and `CellEntryFeedback`.
- Added a mutation matrix clarifying exactly which triggers may mutate marker state, visit rows, fog state, detail state, handoff availability, and observability.
- Added first-slice invariants: no ready-before-ready, no same-cell mutation, no border-crossing replay, no reward payload leakage, no inspection mutation, and no fake progress while paused.
- Extended SuperBDD scenarios for dependency-gated steady state, recovery without replay, no border event on same-cell movement, and paused detail inspection.
- Verification passed with `mise exec -- eac check` and `git diff --check`.

## Completed 2026-05-19 — map debug controls SuperBDD feature
- Added `Map Debug Controls` as a Map feature in `product/features.ts` and included `features/map-debug-controls.feature` in the Map capability inventory.
- Authored SuperBDD scenarios for developer-mode visibility, P↑/P↓/P←/P→ simulated marker movement, GPS resume, gesture buttons, debug source telemetry, and no gameplay gate bypass.
- Extended `docs/map-design.md` with `MapDebugControlState`, field schemas, debug mutation matrix rows, debug invariants, component ownership, acceptance cases, interaction-stack/state-machine rows, and debug observability events.
- Verified existing debug implementation coverage with `mise exec -- flutter test --no-pub test/shared/debug/debug_gesture_overlay_test.dart test/features/map/presentation/providers/location_provider_test.dart test/shared/widgets/tab_shell_test.dart`.
- Verification passed with `mise exec -- eac check` and `git diff --check`.

## Completed 2026-05-19 — map first-slice implementation boundaries
- Reviewed current map implementation anchors: `LocationNotifier`, `PlayerMarkerNotifier`, `MapNotifier`, `ExplorationEligibility`, `DetectCellEntry`, `RecordCellVisit`, `VisitQueueProvider`, `FogStateService`, and `DebugGestureOverlay`.
- Extended `docs/map-design.md` with first-slice implementation boundaries mapping product contracts to clean architecture seams.
- Added the provider graph for Location source → Marker trust / Cell data / Map readiness → Exploration eligibility → Cell border crossing → Visit recorder / Fog / Entry feedback / Detail state.
- Added the recommended implementation order: readiness gate, marker trust gate, exploration eligibility, border crossing identity, visit result, fog recompute, entry feedback/detail state, and debug harness coverage.
- Verification passed with `mise exec -- eac check` and `git diff --check`.

## Completed 2026-05-19 — SuperBDD player action catalog
- Checked the EAC and main-website examples: actions live in `actionCapabilities`, capabilities list `requiredActions`, and `@action.<id>` scenarios belong inside the real feature files that own the behavior rather than a generic player-actions feature.
- Replaced the intentionally empty `product/actions.ts` with a player action catalog spanning Map, natural science lenses, Exploration-Discovery Lifecycle, Progression-Permanence, Motivation, and Multiplayer.
- Updated `product/capabilities.ts` so each capability lists its required player actions while keeping only real feature files in `cucumberFeatures`.
- Distributed every documented player action scenario into its owning feature file and removed the generic `features/player-actions.feature` artifact.
- Verification passed with `mise exec -- eac check`.

## Completed 2026-05-19 — typed player action references
- Continued aligning EarthNova's SuperBDD shape to the main-website example by adding `PlayerActionKey`, `PlayerActionId`, `playerActions`, and `mutationPlayerActions` exports to `product/actions.ts`.
- Rewrote `product/capabilities.ts` to import `playerActions` and reference typed action ids instead of repeating raw action-id strings in `requiredActions`.
- This keeps the action catalog centralized while reducing typo risk in capability wiring.

## Completed 2026-05-19 — SuperBDD workflow layer
- Added typed workflow ids through `playerActionWorkflows` in `product/actions.ts`.
- Added `product/workflows.ts` with typed workflow definitions for Map exploration, Discovery ownership, conservation, collection commitment, sanctuary placement, buddy care, lineage breeding, quest rewards, recap acknowledgement, community contribution, and trade exchange.
- Wired stateful player actions to their owning workflows and added capability-level workflow ownership in `product/capabilities.ts`.
- Verification passed: `mise exec -- eac check` and `git diff --check`.

## Completed 2026-05-19 — app interaction action enforcement
- Added `lib/shared/product/player_actions.dart` as the Dart mirror of SuperBDD player action ids from `product/actions.ts`.
- Updated `ObservableInteraction` so interaction telemetry must include either `player_action_id` for a known `PlayerActions.*` id or `telemetry_only_reason` for explicit non-product/debug/account/filter interactions.
- Wired current app interaction surfaces: Map cell taps, map level gestures, map-to-Pack edge swipe, Pack item inspection, encounter acknowledgement, territory back navigation, bottom-tab navigation, auth submit, settings/sign-out, debug overlay toggle, and Pack filtering/search/sort telemetry.
- Added focused enforcement tests:
  - `test/shared/product/player_actions_test.dart`
  - `test/shared/observability/player_action_interaction_enforcement_test.dart`
  - updated `test/shared/observability/widgets/observable_interaction_test.dart`
- Verification passed: focused action/observability tests, `mise exec -- flutter analyze --no-pub`, `mise exec -- eac check`, and `git diff --check`.

## Completed 2026-05-19 — map border-crossing identity slice
- Chose the next real Map gap by comparing the implementation to `docs/map-design.md`: the app still granted progression on initial occupancy/trust recovery instead of on actual border crossing, and it lacked a shared border-crossing identity payload.
- Added `lib/features/map/domain/entities/cell_border_crossing_event.dart` and extended `ExplorationStateData` with `lastBorderCrossingEvent`.
- Updated `ExplorationNotifier` so:
  - initial occupancy and trusted recovery in the same cell emit `map.cell_tracked` only
  - visit/fog/discovery mutation requires an eligible transition into a different tracked map cell
  - paused GPS/unavailable states can explicitly block mutation through `ExplorationEligibility`
  - accepted crossings emit one shared border-crossing payload into `map.cell_entered`, `map.cell_visited`, and `map.fog_cleared`
- Updated `MapScreen` to consume `lastBorderCrossingEvent` for encounter/discovery triggers instead of a generic entry sequence.
- Added/updated focused tests:
  - `test/features/map/domain/entities/cell_border_crossing_event_test.dart`
  - `test/features/map/presentation/providers/exploration_provider_test.dart`
  - `test/features/map/presentation/screens/map_screen_test.dart`
- Verification passed:
  - `mise exec -- flutter test --no-pub test/features/map/domain/entities/cell_border_crossing_event_test.dart test/features/map/presentation/providers/exploration_provider_test.dart test/features/map/presentation/screens/map_screen_test.dart test/features/map/domain/use_cases/detect_cell_entry_test.dart`
  - `mise exec -- flutter analyze --no-pub`
  - `mise exec -- eac check`
  - `git diff --check`

## Completed 2026-05-19 — map explored-cell distinction correction
- Jeremy explicitly rejected dedicated border jitter suppression; removed the implementation, focused tests, `observedAt` test hook, `jitter_suppressed` event field, and SuperBDD/design references.
- Jeremy clarified the current fog overlay should not make explored territory look like one continuous area; explored Voronoi map cells must remain visually distinct.
- Updated the tessellation render model so shared edges between adjacent explored cells are emitted and painted as subtle revealed-cell seams instead of being suppressed as same-state internals.
- Updated `features/map-fog-overlay.feature` and `docs/map-design.md` to prefer distinct explored cell boundaries while still suppressing frontier/unknown grid seams.
- Added focused render-model coverage in `test/features/map/presentation/rendering/cell_tessellation_render_model_test.dart`.

## Completed 2026-05-19 — global daily map state design
- Jeremy clarified that the daily seed/revisit loop should be global map state, not personalized per-player state.
- Added `Global Map State Model` as a Map data-model feature and authored `features/map-global-map-state-model.feature`.
- Updated `docs/map-design.md` to state that daily map-cell state is shared by GMT day, missed daily opportunities expire, no catch-up/residue/banked daily loot is retained, and player-specific fog/visits/claims/rewards remain personal.
- Chose the hybrid architecture for global map state: deterministic on-demand resolution from global seeds is canonical, while persisted rows are limited to period seed metadata, player claims/audits, special event instances, and intentional caches/snapshots.
- Strengthened the global map state BDD so the hybrid architecture is selected by scenarios: shared player-visible daily state rules out personalization, GMT rollover scale rules out full per-cell materialization, and claim/audit/event scenarios require persisted facts.
- Jeremy clarified that BDD should decide the resolver payload shape too. Added BDD scenarios and map-design tables deriving `GlobalMapCellState` and `PlayerMapCellStateView` from map rendering, social consistency, claim audit, and downstream handoff needs.

## Completed 2026-05-19 — fog overlay perceptual correction
- Screenshot review showed explored/explored seams were topologically emitted but visually too subtle to perceive; the explored footprint still read as one pale blob.
- Added failing tests requiring fully opaque unknown fog, stronger revealed-cell seams, and a fetch radius large enough for wide GPS-level viewports.
- Updated fog rendering so unknown/non-frontier fog is fully opaque, revealed-cell seams use stronger high-contrast strokes, and fetched map-cell coverage increases from 2200m to 3200m to reduce explored cells appearing behind unloaded unknown fog.
- Jeremy refined the visual target: revealed mosaic borders should be darker, preferably dark grey, so explored cell separations read over both land and water.
- Follow-up beta review found the dark grey seams were much better but slightly too thick; tune explored seam widths down while keeping the dark neutral color.
- Added map cell detail sheet cell-state display so tapping cells outside the explored footprint can reveal whether they are present, explored, frontier, or unknown.
- Verification passed: focused fog/render/map screen tests, `mise exec -- flutter analyze --no-pub`, `mise exec -- eac check`, and `git diff --check`.

## Completed 2026-05-19 — root AGENTS SuperBDD workflow guidance
- Updated root `AGENTS.md` to make EarthNova workflow explicitly SuperBDD-driven for product behavior, gameplay rules, UI flows, payload contracts, and state-model changes.
- Added clear guidance to read `features/*.feature` and `product/*.ts` before coding, update SuperBDD with player-visible contract changes, let scenarios drive architecture, and require `mise exec -- eac check` alongside relevant tests when product truth changes.

## Completed 2026-05-19 — frontier adjacency correction
- Jeremy clarified that frontier should only include map cells sharing a border with an explored/revealed map cell, not every fetched unvisited cell.
- Updated `FogStateService` so present and explored cells contribute revealed borders; only fetched unvisited cells sharing one of those borders become frontier, while other fetched unvisited cells become unknown.
- Updated SuperBDD and map design docs so frontier/unknown semantics are driven by shared map-cell borders, with corner-only contact explicitly excluded.

## Completed 2026-05-19 — spinning-world loading indicator
- Replaced the shared ellipsis loading animation with a spinning-world emoji cycle (`🌍 → 🌎 → 🌏`) so app, GPS, and map readiness loading states feel EarthNova-native.
- Updated Map Frame SuperBDD and `docs/map-design.md` to describe the shared spinning-world readiness/loading state.

## Completed 2026-05-19 — map bootstrap observability hardening
- Recent logs showed `map.bootstrap.timed_out` after `map.gps_started` with no `map.map_created`, no style, no cells, and no location readiness; the screen mounted but the bootstrap pipeline had insufficient pre-map diagnostics.
- Added GPS startup stage observability: permission request, current-position request, waiting watchdog, and timeout watchdog with `startup_stage` and `startup_attempt`.
- Added location-state diagnostics to `map.bootstrap.timed_out` so future failures say whether the map was blocked on loading, denied, paused, active, or error state.
- Added runbook SQL for map bootstrap / GPS startup diagnostics.

## Completed 2026-05-19 — overlay pinning to MapLibre camera
- Jeremy reported that the Voronoi cell overlay was drifting relative to the base map while moving, implying the cells were not visually pinned to geography.
- Root cause in the current implementation: overlay projection used the desired smoothed camera-follow target, not the actual MapLibre camera position/zoom currently rendered by the map widget.
- Updated `MapScreen` so shimmer, overlay painting, marker projection, and tap hit-testing all use the latest `onCameraMove` camera position/zoom from MapLibre, with fallback to the desired camera before the first callback arrives.

## Completed 2026-05-19 — exact MapLibre overlay projection
- Jeremy asked why we would not use MapLibre's exact screen-coordinate API anyway; the only real tradeoff was async/batch projection complexity versus better map anchoring.
- Updated the fog overlay path to batch-project marker, cell vertices, and cell centers through `MapLibreMapController.toScreenLocationBatch`, coalescing camera-change requests and falling back to the synchronous Mercator projector only until exact screen coordinates are ready.
- Added projection mode diagnostics to `map.geometry_rendered` and SuperBDD coverage requiring fog cell borders to stay pinned to base-map streets, rivers, and landmarks.
