# Event-Driven Engine Architecture

> Target architecture for EarthNova. Replaces the current monolithic main-thread model with a pure Dart game engine communicating via typed events. Solves three problems simultaneously: **observability** (structured event stream), **performance** (UI thread never blocked >8ms), **resilience** (errors become events, not exceptions).
>
> For how it works today, see [current-architecture.md](current-architecture.md). For the previous ideal target, see [ideal-architecture.md](ideal-architecture.md) (design decisions there still apply; this doc describes the execution architecture).

---

## Design Principles

1. **Everything is an event.** A discovery, a cell visit, an error, a hydration completion — same shape, same stream. The event stream IS observability, sync, and state.
2. **The engine is a firewall.** Errors inside the engine become error events, not exceptions. Nothing propagates to the UI. Nothing cascades. Nothing kills the widget tree.
3. **One architecture, two runtimes.** Same Dart code runs in an isolate on native, chunked microtasks on web. The UI layer doesn't know which.
4. **Fat events.** Every event carries all context needed to understand it without joins. Storage is cheap; queryability is expensive.
5. **The UI is a thin consumer.** Receives events, renders them, sends user inputs back. No computation, no I/O, no game logic.

---

## System Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Main Thread (UI)                       │
│                                                          │
│  ┌──────────────┐  ┌──────────────────────────────────┐ │
│  │ RubberBand    │  │  Screen Layer                     │ │
│  │ (60fps vsync) │  │  MapScreen · Sanctuary · Pack     │ │
│  │               │  │  Town · Onboarding · Settings     │ │
│  │  GPS → interp │  │                                   │ │
│  │  → camera     │  │  Receives GameOutput events       │ │
│  │  → marker     │  │  Sends EngineInput messages       │ │
│  └──────┬────────┘  └──────────────┬────────────────────┘ │
│         │ position samples (10Hz)  │ user inputs          │
│  ┌──────▼──────────────────────────▼────────────────────┐ │
│  │              Message Bus (streams)                    │ │
│  │   Stream<EngineInput> ↓        Stream<GameEvent> ↑   │ │
│  └──────────────────┬───────────────────┬───────────────┘ │
│                     │                   │                  │
├─────────────────────┼───────────────────┼──────────────────┤
│                     │  BOUNDARY          │                  │
├─────────────────────┼───────────────────┼──────────────────┤
│                     │                   │                  │
│  ┌──────────────────▼───────────────────┴───────────────┐ │
│  │                   GameEngine                          │ │
│  │   Pure Dart. No Flutter. No Riverpod.                │ │
│  │   Wraps GameCoordinator (composition).               │ │
│  │                                                      │ │
│  │   Injected (not owned):                              │ │
│  │   • FogStateResolver      • SpeciesService           │ │
│  │   • CellPropertyResolver  • DailySeedService         │ │
│  │   • CellService (Voronoi) • LootTable                │ │
│  │   • DiscoveryService      • StatsService             │ │
│  │                                                      │ │
│  │   Emits: Stream<GameEvent>  (fat structured events)  │ │
│  │   Reads: Stream<EngineInput> (positions, taps, auth) │ │
│  └──────────────────────────────────────────────────────┘ │
│                     │                                      │
│  ┌──────────────────▼───────────────────────────────────┐ │
│  │            Event Consumers (provider layer)           │ │
│  │  PersistenceConsumer — SQLite + write queue           │ │
│  │  EnrichmentManager — cache + backfill                │ │
│  │  Provider projections — fog, inventory, player state  │ │
│  │  EventSink — app_events table                        │ │
│  └──────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘

Native: Engine runs in Isolate (real OS thread)
Web:    Engine runs on main thread with chunked microtasks
```

---

## The Engine

### What It Owns

| Domain | What | Why Inside |
|--------|------|------------|
| Fog | `FogStateResolver`, visited cell tracking | Core game logic, CPU-heavy |
| Cells | `CellService`, `CellCache`, `CellPropertyResolver` | Spatial queries, geometry memoization |
| Species | `SpeciesService`, `LootTable`, `SpeciesDataLoader` | 6MB asset parse, encounter rolls |
| Discovery | `DiscoveryService`, `StatsService`, affix generation | SHA-256 rolls, stat generation |
| Biome | `BiomeFeatureIndex`, `HabitatService` | 28MB asset parse, spatial lookups |
| Seed | `DailySeedService` | Supabase RPC, seed caching |
| Geography | `CountryResolver`, `ContinentResolver` | Asset parse, ray-casting |
| Persistence | `AppDatabase` (Drift), all repositories | All I/O off the UI thread |
| Sync | `WriteQueueRepository`, `SupabasePersistence` | Network I/O off the UI thread |
| GeoJSON | `FogOverlayController`, `AdminBoundaryGeoJsonBuilder` | Heaviest single computation (~80ms) |
| Enrichment | `EnrichmentService`, `EnrichmentRepository` | Network + persistence |

### What It Does NOT Own

| Domain | What | Why Outside |
|--------|------|-------------|
| Animations | `RubberBandController` | Needs `vsync` (Flutter `Ticker`), 60fps |
| Camera | `CameraController`, `MapController` | MapLibre JS interop, must be main thread |
| Widgets | All screens, toasts, overlays | Flutter widget tree |
| MapLibre | Source updates, layer management | Platform view, main thread only |
| Navigation | Tab switching, routing | Flutter `Navigator` |
| Auth UI | Login screen, upgrade prompts | Widget layer |

### Engine Interface

```dart
/// Messages INTO the engine
sealed class EngineInput {
  const EngineInput();
}

class PositionUpdate extends EngineInput {
  final double lat;
  final double lon;
  final double accuracy;
  const PositionUpdate(this.lat, this.lon, this.accuracy);
}

class CellTapped extends EngineInput {
  final String cellId;
  const CellTapped(this.cellId);
}

class AuthChanged extends EngineInput {
  final String? userId;
  const AuthChanged(this.userId);
}

class AppBackgrounded extends EngineInput {
  const AppBackgrounded();
}

class AppResumed extends EngineInput {
  const AppResumed();
}

/// The engine itself
class GameEngine {
  GameEngine({
    required Stream<EngineInput> input,
  });

  /// All engine output — fat structured events
  Stream<GameEvent> get events;

  /// Start the engine (loads assets, hydrates state)
  Future<void> start();

  /// Graceful shutdown
  Future<void> dispose();
}
```

---

## The Event Model

### Envelope

Every event shares the same envelope:

```dart
class GameEvent {
  final String sessionId;     // UUID v4, per app launch
  final String? userId;       // Supabase auth user ID
  final String deviceId;      // SHA-256 fingerprint (12 chars)
  final DateTime timestamp;   // UTC
  final String category;      // state | user | system | performance
  final String event;         // cell_entered, species_discovered, etc.
  final Map<String, dynamic> data;  // fat payload, all context included
}
```

### Event Catalog

#### State Events (game world changed)

| Event | Key Data Fields |
|-------|----------------|
| `cell_entered` | cellId, habitats, climate, continent, fogState, lat, lon |
| `cell_exited` | cellId, previousFogState, newFogState |
| `species_discovered` | definitionId, displayName, rarity, cellId, habitats, affixes, dailySeed |
| `fog_changed` | cellId, oldState, newState, triggerCellId |
| `seed_rotated` | seedValue, seedDate, previousSeed |
| `enrichment_complete` | definitionId, animalClass, foodPreference, climate, stats |
| `cell_properties_resolved` | cellId, habitats, climate, continent, locationId |

#### User Events (player did something)

| Event | Key Data Fields |
|-------|----------------|
| `session_started` | platform, appVersion, deviceId |
| `session_ended` | durationSec, reason (background/close/crash) |
| `tab_switched` | fromTab, toTab |
| `cell_tapped` | cellId, lat, lon |
| `settings_opened` | — |

#### System Events (infrastructure)

| Event | Key Data Fields |
|-------|----------------|
| `hydration_complete` | durationMs, itemCount, cellCount, enrichmentCount, source (sqlite/supabase) |
| `auth_restored` | userId, method (session/anonymous/fresh) |
| `auth_expired` | userId, reason |
| `auth_error` | error, willRetry |
| `network_error` | url, status, error, context |
| `sync_flushed` | confirmed, rejected, retried, staleDeleted |
| `webgl_context_lost` | — |
| `webgl_context_restored` | — |
| `js_error` | message, source, line, col |
| `crash` | error, stackTrace, context |
| `asset_loaded` | asset, durationMs, sizeBytes |

#### Performance Events (timing)

| Event | Key Data Fields |
|-------|----------------|
| `fog_computed` | cellCount, durationMs, changedCount |
| `geojson_built` | layerCount, featureCount, durationMs |
| `api_call` | endpoint, method, durationMs, status |
| `sqlite_op` | table, operation, rowCount, durationMs |

---

## Persistence

### Event Storage

Events are the primary persistence unit. Two destinations:

**Local (SQLite):** `app_events` table mirrors the event envelope. Used for offline session reconstruction and debugging.

**Remote (Supabase):** `app_events` table. Same schema. Flushed in batches (every 30s or on app background). Dashboard queries run here.

```sql
CREATE TABLE app_events (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id  uuid NOT NULL,
  user_id     uuid,
  device_id   text,
  category    text NOT NULL,
  event       text NOT NULL,
  data        jsonb,
  created_at  timestamptz DEFAULT now()
);

CREATE INDEX idx_app_events_session ON app_events (session_id, created_at);
CREATE INDEX idx_app_events_category ON app_events (category, event);
CREATE INDEX idx_app_events_user ON app_events (user_id, created_at);
```

### Game State Persistence

Game state tables (`profiles`, `item_instances`, `cell_progress`, `cell_properties`, `species_enrichment`) remain as-is. The engine writes to them as a side effect of processing events. The event stream is the audit log; the state tables are the current snapshot.

```
Engine processes PositionUpdate
  → computes new fog states
  → discovers species
  → emits: CellEntered, SpeciesDiscovered, FogChanged events
  → writes: cell_progress, item_instances to SQLite + write queue
  → flushes: events to app_events table (batched)
```

### Relationship Between Events and State

Events are immutable facts. State tables are mutable projections. If state tables are lost (cleared cache, new device), they can be reconstructed from the event stream. Events cannot be reconstructed from state.

---

## Error Handling

### The Firewall Principle

The engine never throws to the outside. All errors become events:

```dart
// Inside the engine
try {
  final response = await supabase.functions.invoke('enrich-species-batch', ...);
  // process response
} catch (e) {
  emit(GameEvent(
    category: 'system',
    event: 'network_error',
    data: { 'url': 'enrich-species-batch', 'error': e.toString(), 'willRetry': true },
  ));
  // engine continues running — queue for retry
}
```

### Error Categories and Responses

| Error Type | Engine Response | UI Response |
|-----------|----------------|-------------|
| Network failure | Emit `network_error`, queue for retry, continue | Show offline indicator |
| Auth expired | Emit `auth_expired`, pause game loop, wait for re-auth | Show re-auth prompt |
| SQLite failure | Emit `crash`, attempt recovery, continue if possible | Show "save failed" toast |
| Asset load failure | Emit `crash`, fall back to cached/default data | Degrade gracefully |
| WebGL context lost | N/A (UI side) | Attempt to restore canvas, show reload prompt if unrecoverable |
| MapLibre JS error | N/A (UI side) | Caught at JS level, logged as event, map re-initializes |

### Auth Resilience

```
Auth token expires during gameplay
  → Supabase call returns 401
  → Engine catches, emits auth_expired event
  → Engine pauses: queues writes, continues fog/discovery with cached data
  → UI receives auth_expired → shows re-auth flow
  → User re-authenticates → UI sends AuthChanged(newUserId) to engine
  → Engine emits auth_restored, flushes write queue, resumes
  → No crash, no blank screen, no lost state
```

### Network Resilience

```
Network drops during gameplay
  → Engine catches network errors, emits network_error events
  → Game logic continues (all data is local: species catalog, biome index, cached seed)
  → Writes queue locally in SQLite
  → UI shows offline indicator (driven by network_error events)
  → Network returns → engine flushes queue, emits sync_flushed
  → UI hides offline indicator
```

---

## Execution Model

### Native (Isolate)

```dart
// Main thread (simplified)
void main() async {
  final receivePort = ReceivePort();
  await Isolate.spawn(_engineEntryPoint, receivePort.sendPort);

  final sendPort = await receivePort.first as SendPort;

  // Send inputs to engine
  rubberBand.onUpdate = (lat, lon) {
    sendPort.send(PositionUpdate(lat, lon, accuracy));
  };

  // Receive events from engine
  receivePort.listen((event) {
    if (event is GameEvent) handleEvent(event);
  });
}

// Engine isolate
void _engineEntryPoint(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  final engine = GameEngine(input: receivePort.cast<EngineInput>());
  engine.events.listen(mainSendPort.send);
  engine.start();
}
```

True parallelism. Engine and UI run on separate CPU cores. Position updates and events cross the isolate boundary via `SendPort`.

### Web (Chunked Microtasks)

```dart
// Same GameEngine class — different runner
class ChunkedEngineRunner {
  final GameEngine engine;

  Future<void> processInput(EngineInput input) async {
    // Break heavy work into chunks, yield between them
    // so the browser can paint frames and handle taps

    if (input is PositionUpdate) {
      // Step 1: cell lookup (fast, do immediately)
      final cellId = engine.getCellId(input.lat, input.lon);

      // Yield to event loop — let UI paint a frame
      await Future.delayed(Duration.zero);

      // Step 2: fog computation (chunk per 100 cells)
      await engine.computeFogChunked(cellId, chunkSize: 100);

      // Step 3: GeoJSON building (chunk per 50 features)
      await engine.buildGeoJsonChunked(chunkSize: 50);
    }
  }
}
```

Same engine code. On web, the runner wraps it with yield points. Work spreads across 3-5 frames instead of blocking one frame for 148ms. The UI thread responds to taps within a single frame (<10ms).

### Unified Interface

The UI layer doesn't know which runner is active:

```dart
// Platform-aware engine factory
abstract class EngineRunner {
  Stream<GameEvent> get events;
  void send(EngineInput input);
  Future<void> start();
  Future<void> dispose();
}

// Conditional import — same pattern as CrashLogPersistence
export 'engine_runner_native.dart'
    if (dart.library.js_interop) 'engine_runner_web.dart';
```

---

## UI Layer

### What MapScreen Becomes

```dart
class MapScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with SingleTickerProviderStateMixin {

  late final RubberBandController _rubberBand;
  late final EngineRunner _engine;
  MapController? _mapController;

  @override
  void initState() {
    super.initState();
    _engine = ref.read(engineRunnerProvider);
    _rubberBand = RubberBandController(
      vsync: this,
      onUpdate: _onDisplayUpdate,
    );

    // GPS → rubber band
    _engine.events.whereType<GpsReceived>().listen((e) {
      _rubberBand.setTarget(e.lat, e.lon);
    });

    // Engine events → MapLibre updates
    _engine.events.listen(_handleEvent);
  }

  void _onDisplayUpdate(double lat, double lon) {
    // Animate marker + camera (every frame, <1ms)
    _markerPosition.value = (lat: lat, lon: lon);
    _mapController?.moveCamera(center: Position(lon, lat));

    // Feed engine (throttled internally)
    _engine.send(PositionUpdate(lat, lon, _currentAccuracy));
  }

  void _handleEvent(GameEvent event) {
    switch (event.event) {
      case 'fog_updated':
        _mapController?.setGeoJsonSource('fog-base', event.data['baseGeoJson']);
        _mapController?.setGeoJsonSource('fog-mid', event.data['midGeoJson']);
        _mapController?.setGeoJsonSource('fog-border', event.data['borderGeoJson']);
      case 'species_discovered':
        // show toast
      case 'network_error':
        // show offline indicator
      case 'auth_expired':
        // show re-auth prompt
    }
  }
}
```

~100 lines. No fog computation. No discovery rolls. No GeoJSON building. No persistence. Just: receive events, update visuals, send inputs.

### Riverpod's Role

Riverpod becomes optional. Two valid approaches:

**Minimal:** Engine owns all state. Riverpod provides the `EngineRunner` singleton and thin read-only projections for widgets that need `ref.watch`:

```dart
final engineRunnerProvider = Provider<EngineRunner>((ref) => createEngineRunner());
final inventoryProvider = StreamProvider<List<ItemInstance>>((ref) {
  return ref.watch(engineRunnerProvider).events
    .where((e) => e.event == 'inventory_changed')
    .map((e) => e.data['items'] as List<ItemInstance>);
});
```

**Full:** Keep existing providers but have them consume the event stream instead of being mutated directly. More refactoring but cleaner for widget consumption.

Both work. The key constraint: **no provider ever does computation or I/O.** Providers are projections of the event stream, nothing more.

---

## Observability

### Built-In

The event stream IS the observability system. Every `GameEvent` is:
1. Rendered by the UI (gameplay)
2. Persisted to `app_events` (observability)
3. Available for dashboard queries (analytics)

No separate logging system needed for structured data. The existing `DebugLogBuffer` → `app_logs` pipeline remains for raw debug output (stack traces, verbose debugging).

### Session Timeline

Reconstruct any user's session by querying events:

```sql
SELECT event, data, created_at
FROM app_events
WHERE session_id = 'abc-123'
ORDER BY created_at;
```

Result:
```
00:00  session_started    { platform: "web", version: "β2026-03-15" }
00:02  hydration_complete { durationMs: 1847, itemCount: 290 }
00:03  asset_loaded       { asset: "species_data.json", durationMs: 1200 }
00:15  cell_entered       { cellId: "v_22956", habitats: ["forest"], fogState: "observed" }
00:15  species_discovered { displayName: "Red Fox", rarity: "LC", cellId: "v_22956" }
00:42  tab_switched       { from: "map", to: "pack" }
03:45  network_error      { url: "enrich-species-batch", status: 0, error: "Load failed" }
03:46  auth_expired       { userId: "7751acc2", reason: "token_expired" }
```

### Fleet Dashboard Queries

```sql
-- Error rate per hour
SELECT date_trunc('hour', created_at), count(*)
FROM app_events WHERE category = 'system' AND event = 'crash'
GROUP BY 1 ORDER BY 1;

-- P95 hydration time
SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY (data->>'durationMs')::int)
FROM app_events WHERE event = 'hydration_complete';

-- Daily active users
SELECT date_trunc('day', created_at), count(DISTINCT user_id)
FROM app_events WHERE event = 'session_started'
GROUP BY 1;
```

---

## Implementation Plan

### Phase 1: Event Foundation

> No behavior change. Existing app continues to work. Events flow alongside current callbacks.

**1.1 Event model**
- Create `lib/core/engine/game_event.dart` — `GameEvent` class with envelope fields (sessionId, userId, deviceId, timestamp, category, event, data)
- Create `lib/core/engine/engine_input.dart` — `EngineInput` sealed class (PositionUpdate, CellTapped, AuthChanged, AppBackgrounded, AppResumed)
- Event data payloads are `Map<String, dynamic>` (fat events — all context inline)

**1.2 Event sink**
- Create `lib/core/engine/event_sink.dart` — batches events, flushes every 30s (same pattern as `LogFlushService`)
- **Decision: Callback injection, not SupabaseClient.** EventSink accepts `EventFlusher` callback + `UserIdResolver` callback instead of importing `supabase_flutter`. This keeps `lib/core/` free of Supabase imports (enforced by `offline_audit_test.dart`). The provider layer injects `(rows) => client.from('app_events').insert(rows)`.
- Flush on app background, flush on crash detection
- Silent failure — never throws to caller

**1.3 Supabase schema**
- Create migration: `app_events` table (id uuid PK, session_id, user_id, device_id, category text, event text, data jsonb, created_at timestamptz)
- Indexes on (session_id, created_at), (category, event), (user_id, created_at)
- RLS: authenticated + anon can insert

**1.4 Instrument existing GameCoordinator**
- Add `EventSink` as optional dependency to `GameCoordinator` (constructor injection)
- Emit events alongside existing callbacks — every `onCellVisited`, `onItemDiscovered`, `onCellPropertiesResolved` callback also emits a `GameEvent`
- Emit system events: `session_started`, `hydration_complete`, `network_error`, `auth_restored`, `auth_expired`
- Wire `EventSink` in `gameCoordinatorProvider` (reads `supabaseClientProvider`)
- Existing callbacks, providers, and UI unchanged

**1.5 Performance instrumentation**
- Add `Stopwatch` timing to hydration (done in Phase 1)
- **Decision: Fog, GeoJSON, API, and SQLite timing deferred to Phase 2.** Those systems live in `features/map/` today. Instrumenting them now to rewrite them in Phase 2 is waste. When they move into the engine, timing is added naturally.
- Emit `performance` category events with `durationMs` in data payload

**Deliverable:** Structured events flowing to `app_events` table. Queryable. Zero behavior change. Existing `app_logs` continues as debug fallback.

**Files created:** 3 new (`game_event.dart`, `engine_input.dart`, `event_sink.dart`)
**Files modified:** 2 (`game_coordinator.dart`, `game_coordinator_provider.dart`)
**Risk:** Low — additive only, no existing code removed

---

### Phase 2: Engine Extraction

> GameCoordinator wrapped by GameEngine. Callbacks chain with events. Still runs on main thread.

**2.1 Create GameEngine wrapper** ✅
- Created `lib/core/engine/game_engine.dart` — wraps `GameCoordinator` via composition (~198 lines)
- Converts all 6 coordinator callbacks to `GameEvent` emissions via `_emit()` helper
- Routes `EngineInput` messages to coordinator methods via `send()` switch expression
- Exposes single `Stream<GameEvent>` output (broadcast, sync)
- Proxies coordinator state: `rawGpsPosition`, `playerPosition`, `cellPropertiesCache`, etc.

**2.2 Services injected, not owned** ✅
- **Decision: Services are constructor-injected, not created by the engine.** FogStateResolver, CellService, StatsService, CellPropertyResolver are passed in by the provider layer. This keeps asset loading (rootBundle) and async initialization in Riverpod FutureProviders where they belong. Engine works without optional services (graceful degradation). Matches the existing DailySeedService pattern (SeedFetcher callback).

**2.3 Persistence stays outside** ✅
- **Decision: Persistence is an event consumer, NOT an engine concern.** Engine emits events. Provider subscribes and persists to SQLite + write queue. Reasons: (1) Drift databases can't cross isolate boundaries (Phase 4 blocker), (2) persistence needs userId from auth (Riverpod dependency), (3) persistence triggers feature-layer services (enrichment, admin boundaries). The design doc's system diagram was stale — updated to show persistence outside engine boundary.

**2.4 Wire GameEngine into provider** ✅
- `gameCoordinatorProvider` creates `GameEngine` instead of bare `GameCoordinator`
- Accesses coordinator via `engine.coordinator` — all existing wiring unchanged
- Callback chaining: provider saves GameEngine's handler before overwriting, calls it first in its own handler. Both event emission (GameEngine) and Riverpod mutations (provider) fire.
- EventSink passed to GameEngine only (no double emission)
- Provider return type stays `Provider<GameCoordinator>` — consumers unchanged

**2.5 Deferred to Phase 5**
- PersistenceConsumer extraction (Oracle recommended splitting the ~1300-line provider — deferred to Thin UI phase)
- Callback → event stream migration (provider still uses callbacks for Riverpod mutations — will migrate when providers become event projections)
- Service provider retirement (fogResolverProvider, etc. still exist — removed when engine owns service lifecycle)

**Deliverable:** `GameEngine` class with stream I/O. Game logic wrapped. Event emission alongside existing callbacks. Zero behavior change.

**Files created:** 2 (`game_engine.dart`, `game_engine_test.dart` — 16 tests)
**Files modified:** 1 (`game_coordinator_provider.dart` — GameEngine construction + callback chaining)
**Risk:** Low — composition pattern preserves 595 lines of tested game logic. Callback chaining is additive.

---

### Phase 3: Error Resilience

> Engine is a firewall. Errors become events. App never blanks out.

**3.1 Engine-level error boundary** ✅
- All 6 callback handlers wrapped in try-catch with `_emitCrash()` helper
- `send()` method wrapped in try-catch
- Crash events include: error message, first 10 lines of stack trace, context (which handler/input)
- Engine continues processing after errors — subsequent callbacks still fire
- Never throws to the UI thread

**3.2 Network + auth error handling** ✅ (Phase 1)
- Already instrumented in Phase 1: `network_error` and `persistence_error` events emitted from provider catch blocks
- Auth state changes emit `auth_state_changed` events
- `connectivity_changed` and offline mode deferred — not needed until Phase 4 when engine runs in background

**3.3 UI-side error containment** ✅
- **Fixed ErrorBoundary cascade:** Replaced 4 per-tab ErrorBoundaries with 1 wrapping the IndexedStack. Bottom nav bar stays visible during errors (Scaffold body is wrapped, not the Scaffold itself).
- **ErrorBoundary API improved:** `onError` signature now includes `VoidCallback reset` parameter. DefaultErrorFallback receives the reset callback directly — no more `markNeedsBuild()` hack.
- **JS-level error capture** (Phase 1): `window.onerror`, `onunhandledrejection`, `webglcontextlost` listeners in `web/index.html` → flushed to `app_events` via `js_error_drain.dart`.
- MapScreen's internal ErrorBoundary left unchanged (separate concern).

**Deliverable:** Engine errors become events. ErrorBoundary cascade fixed. Errors visible in event stream. No blank screens from error cascade.

**Files modified:** 3 (`game_engine.dart` — try-catch wrappers, `error_boundary.dart` — API + reset, `tab_shell.dart` — single boundary)
**Risk:** Low — error handling is additive. ErrorBoundary fix is targeted.

---

### Phase 4: Background Execution

> Engine moves off the main thread. UI interaction latency drops to <10ms.

**4.1 EngineRunner abstraction**
- Create `lib/core/engine/engine_runner.dart` — abstract class:
  ```dart
  abstract class EngineRunner {
    Stream<GameEvent> get events;
    void send(EngineInput input);
    Future<void> start({...asset data...});
    Future<void> dispose();
  }
  ```
- Conditional import: `engine_runner_native.dart` / `engine_runner_web.dart`

**4.2 Web runner (chunked microtasks)**
- `ChunkedEngineRunner` — runs `GameEngine` on the main thread
- Wraps heavy operations with yield points (`await Future.delayed(Duration.zero)`)
- Chunking targets: fog computation (per 100 cells), GeoJSON build (per 50 features), asset parsing (per 1000 records)
- `EngineInput` processing is async — multiple inputs can queue

**4.3 Native runner (isolate)**
- `IsolateEngineRunner` — spawns `GameEngine` in a separate isolate
- `SendPort` / `ReceivePort` for message passing
- Asset data serialized across isolate boundary at startup
- `GameEvent` objects cross back via `SendPort` (must be serializable — no closures, no references)
- GeoJSON strings cross as `String` (copy cost acceptable — measured in Phase 1)

**4.4 Wire UI to EngineRunner**
- Replace `ref.read(engineProvider)` with `ref.read(engineRunnerProvider)`
- `MapScreen` subscribes to `engineRunner.events`
- `RubberBandController` stays on main thread, sends `PositionUpdate` via `engineRunner.send()`
- Persistence consumer subscribes to `engineRunner.events` for persistence intents

**4.5 Verify performance**
- Compare `fog_computed` and `geojson_built` event timings before/after
- Verify UI thread frame budget: instrument with `SchedulerBinding.instance.addTimingsCallback`
- Target: P95 interaction latency <10ms

**Deliverable:** EngineRunner abstraction established. MainThreadEngineRunner wraps GameEngine. Isolate runner added when native ships.

**Decision: MainThreadEngineRunner only for now.** The web app runs GameEngine on the main thread. Chunked microtasks require making GameCoordinator's synchronous game logic async (deep internal change — deferred). Isolate runner requires serializing services across boundaries (needed when native ships — not now). The EngineRunner interface is the contract; implementation varies by platform.

**Files created:** 3 (`engine_runner.dart`, `main_thread_engine_runner.dart`, `engine_runner_test.dart` — 9 tests)
**Files modified:** 0
**Risk:** Low — pure abstraction, no behavior change.

---

### Phase 5: Thin UI

> Route MapScreen through EngineRunner. Assess provider migration.

**Decision: The "1470→100 lines" target was wrong.** MapScreen is already 95% pure renderer — MapLibre setup, fog layers, camera control, icon registration. Only ~22 lines were game logic. The real Phase 5 work was creating `engineRunnerProvider` and routing position updates through the engine's message bus.

**5.1 Create engineRunnerProvider** ✅
- Exposes `EngineRunner` to the widget layer via `Provider<EngineRunner>`
- Watches `gameCoordinatorProvider` (ensures engine is created)
- Returns `MainThreadEngineRunner` wrapping the GameEngine

**5.2 MapScreen uses engine.send()** ✅
- `_gameCoordinator.updatePlayerPosition(lat, lon)` → `_engineRunner.send(PositionUpdate(lat, lon, 0))`
- MapScreen now communicates with game logic exclusively via `EngineInput` messages
- Rubber-band → EngineRunner → GameEngine → GameCoordinator (same pipeline, cleaner boundary)

**5.3 Provider migration assessment** ✅ (assessed, not needed)
- **Decision: Providers stay as-is.** Converting providers to event projections requires the event stream to carry typed objects (ItemInstance, CellProperties), but events carry flat primitives (for isolate/JSONB compatibility). The callback chaining from Phase 2 already achieves the same result — typed objects flow via callbacks, events flow via stream.
- **Blast radius was prohibitive:** inventoryProvider (14 files, 131 matches), playerProvider (22 files, 150 matches). Rewriting all consumers for no functional benefit is wrong.

**Deliverable:** engineRunnerProvider live. MapScreen routes position through EngineRunner. Providers unchanged (correct decision, not a deferral).

**Files modified:** 2 (`game_coordinator_provider.dart` — engineRunnerProvider, `map_screen.dart` — engine.send())
**Risk:** Low — minimal surface area, targeted change.

---

### Phase 6: Observability Dashboard

> Full operational visibility across all users and sessions.

**6.1 Session timeline**
- SQL query pattern: `SELECT * FROM app_events WHERE session_id = ? ORDER BY created_at`
- Build a simple admin page (or use Supabase dashboard with saved queries)
- Timeline shows every event in a session with timestamps and fat data

**6.2 Fleet health**
- Saved SQL queries for: crash rate per hour, P95 hydration time, daily active users, error types distribution
- Alert on crash rate spike (>N crashes/hour)

**6.3 Performance tracking**
- P50/P95 for: hydration, fog computation, GeoJSON build, API latency
- Track regressions across app versions (filter by `app_version` in events)

**6.4 Event retention policy**
- 30-day rolling window in Supabase (cron job: `DELETE FROM app_events WHERE created_at < now() - interval '30 days'`)
- Performance events: 7-day retention (higher volume, lower value after analysis)

**6.4 Event retention policy** ✅
- `cleanup_old_events()` function deployed: 7-day retention for performance events, 30-day for everything else
- Invoke via pg_cron or Supabase scheduled function: `SELECT cleanup_old_events();`

**Deliverable:** Retention policy live. Dashboard queries ready. Session timelines queryable once events flow (after first deployment with event emission).

**Files created:** 1 migration (`017_app_events_retention.sql`)
**Risk:** Low — read-only queries against existing data.

**Dashboard Queries (ready to use):**
```sql
-- Session timeline
SELECT event, data, created_at FROM app_events
WHERE session_id = '<id>' ORDER BY created_at;

-- Crash rate per hour
SELECT date_trunc('hour', created_at) as hour, count(*)
FROM app_events WHERE event = 'crash'
GROUP BY 1 ORDER BY 1 DESC LIMIT 24;

-- P95 hydration time
SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY (data->>'duration_ms')::int)
FROM app_events WHERE event = 'hydration_complete';

-- Daily active users
SELECT date_trunc('day', created_at) as day, count(DISTINCT user_id)
FROM app_events WHERE event = 'session_started'
GROUP BY 1 ORDER BY 1 DESC;

-- Error distribution
SELECT event, count(*) FROM app_events
WHERE category = 'system' GROUP BY 1 ORDER BY 2 DESC;
```

---

### Phase Dependencies

```
Phase 1 (Event Foundation)
  ↓
Phase 2 (Engine Extraction) ←→ Phase 3 (Error Resilience)
  ↓                              ↓
Phase 4 (Background Execution)
  ↓
Phase 5 (Thin UI)
  ↓
Phase 6 (Observability Dashboard)
```

- Phases 2 and 3 can be worked in parallel — they touch different parts of the system
- Phase 4 depends on Phase 2 (engine must exist before backgrounding it)
- Phase 5 depends on Phase 4 (UI rewrite assumes engine is backgrounded)
- Phase 6 depends on Phase 1 (events must exist to query)
- Phase 6 can start as soon as Phase 1 ships (dashboard doesn't need the engine extraction)

### Effort Estimates

| Phase | Scope | Estimate |
|-------|-------|----------|
| 1. Event Foundation | 3 new files, 2 modified, 1 migration | 1-2 days |
| 2. Engine Extraction | 2 new files, ~15 modified, ~8 deleted | 3-5 days |
| 3. Error Resilience | ~5 files modified | 1-2 days |
| 4. Background Execution | 3 new files, ~5 modified | 2-3 days |
| 5. Thin UI | ~20 files modified (MapScreen + providers + tests) | 3-5 days |
| 6. Observability Dashboard | 1 migration, SQL queries | 1 day |
| **Total** | | **~11-18 days** |

---

## What This Replaces

| Current | New |
|---------|-----|
| `GameCoordinator` (1 class, coupled to providers) | `GameEngine` (pure Dart, stream-based) |
| `gameCoordinatorProvider` (800+ lines, wires everything) | `EngineRunner` + thin provider |
| `MapScreen` (1470 lines, orchestrates game) | `MapScreen` (~100 lines, renders events) |
| `app_logs` (text firehose) | `app_events` (structured events) + `app_logs` (debug fallback) |
| `FlutterError.onError` → crash | Errors become events, engine continues |
| 28 Riverpod providers (mixed state + logic) | Engine owns state; providers are projections |
| Everything on main thread | Engine in background, UI thread <8ms/frame |

---

## Open Questions

1. **GeoJSON delivery:** Engine builds GeoJSON strings and sends them as event data. On native, these strings cross the isolate boundary (copy cost). Is this acceptable, or should GeoJSON building move to the UI side? (Tradeoff: copy cost vs main-thread compute.)

2. **MapLibre `setFeatureState`:** The `maplibre` Flutter package doesn't expose this API yet. Contributing it upstream would eliminate GeoJSON source replacement entirely (~80x improvement). Worth pursuing as a separate workstream?

3. **Event retention:** How long to keep events in Supabase? 7 days? 30 days? Rolling window vs archive?

4. **Isolate warm-up:** On native, isolate spawn + asset loading takes time. Should the engine pre-warm during splash screen, or lazy-start on first GPS update?
