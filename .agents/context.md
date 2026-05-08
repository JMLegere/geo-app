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