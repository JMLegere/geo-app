# Sync Feature

Offline-first sync: write queue processing, Supabase persistence, location enrichment, and observability.

---

## Architecture

### Services

- `SupabasePersistence` — write-through persistence layer. `upsertCellProgress()`, `upsertItemInstance()`, `upsertProfile()`, `upsertCellProperties()`. Null when Supabase not configured. Called by `gameCoordinatorProvider` after every SQLite write.
- `QueueProcessor` — flushes `WriteQueueRepository` to Supabase. Reads pending entries, calls Supabase REST, marks confirmed/rejected. Runs on reconnect and on app foreground.
- `LocationEnrichmentService` — resolves location hierarchy (country/state/city/district) for cells without a `locationId`. Calls Supabase RPC `enrich_cell_location()`. Fires post-discovery when `CellProperties.locationId == null`. Null when Supabase not configured.
- `ObservableHttpClient` — wraps Supabase HTTP calls with timing/error observability → `ObservabilityBuffer`.
- `LifecycleFlush` — triggers queue flush on app foreground (native: `WidgetsBindingObserver`, web: `visibilitychange` listener). Conditional import: `lifecycle_flush_native.dart` vs `lifecycle_flush_web.dart`.

### Providers

- `syncProvider`: `NotifierProvider<SyncNotifier, SyncStatus>` — tracks overall sync status (idle, syncing, error, notConfigured).
- `queueProcessorProvider`: `Provider<QueueProcessor?>` — null when Supabase not configured.
- `locationEnrichmentServiceProvider`: `Provider<LocationEnrichmentService?>` — null when Supabase not configured.
- `syncToastProvider`: `NotifierProvider<SyncToastNotifier, SyncToastState>` — drives `SyncToastOverlay`.

### Models

- `SyncStatus`: enum (idle, syncing, error, notConfigured, offline).

---

## Write Queue Flow

```
GameCoordinator writes to SQLite
  → simultaneously enqueues to WriteQueueRepository (status: pending)
  → QueueProcessor (on reconnect / foreground):
      read pending entries → POST to Supabase → mark confirmed
      → on 4xx: mark rejected (no retry)
      → on 5xx / network error: increment attempts (retry with backoff)
```

Stale entries (>24h, rejected, max attempts) are cleaned up by `WriteQueueRepository.deleteStale()`.

---

## Location Enrichment Flow

```
Cell visited → GameCoordinator.getCellProperties(cellId)
  → CellProperties.locationId == null → trigger LocationEnrichmentService.enrich(cellId, lat, lon)
  → Supabase RPC enrich_cell_location() → returns {locationId, country, state, city, district}
  → CellPropertyRepository.updateLocationId(cellId, locationId)
  → HierarchyRepository.upsert*() for country/state/city/district rows
  → Territory border layers refresh in MapScreen
```

---

## Conventions

- All sync services return `null` (no-op) when Supabase not configured — never throw.
- `SupabasePersistence` writes are fire-and-forget in `gameCoordinatorProvider` (try/catch, no await chain).
- `QueueProcessor` limits to 50 entries per flush cycle to avoid timeout.
- `LocationEnrichmentService` deduplicates in-flight requests by `cellId`.

---

## Gotchas

- `syncProvider` shows "not configured" state when `SUPABASE_URL` is empty — UI should check this before showing sync errors.
- `LifecycleFlush` uses conditional import — never import platform-specific file directly.
- Write queue entries that are rejected (4xx) are NOT retried — bad data, not transient errors.
- Location enrichment fires asynchronously from game tick — do NOT await in the hot path.

See /AGENTS.md for project-wide rules.
