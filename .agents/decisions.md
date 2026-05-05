# Decisions

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
