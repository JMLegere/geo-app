# Test Suite

1694 tests. flutter_test only — no mockito, no mocktail. All mocks hand-written.

## Run Commands

```bash
eval "$(~/.local/bin/mise activate bash)"
LD_LIBRARY_PATH=. flutter test          # All tests (H3 FFI needs LD_LIBRARY_PATH)
LD_LIBRARY_PATH=. flutter test test/core/  # Subsystem only
```

## Structure

Mirrors lib/ exactly. ~125 test files.

Additional directories:
- `fixtures/` — `species_fixture.dart` with `kSpeciesFixtureJson` (50 species, all habitats/continents/IUCN statuses)
- `integration/` — 7 offline workflow suites (game loop, persistence, fog, discovery, audit, hydration, write queue)
- `performance/` — benchmarks for 33k species parse, Voronoi grid, fog computation

## Key Fixtures

- `kSpeciesFixtureJson` — 50-species JSON string covering all 7 habitats, 6 continents, 6 IUCN statuses, 5 taxonomic classes. Used in 10+ test files.
- `createTestDatabase()` — `AppDatabase(NativeDatabase.memory())`. In `test/core/persistence/test_helpers.dart`.
- `GameSession` — Full game session fixture wiring all services. In `test/integration/offline_game_loop_test.dart`.
- `test/core/models/animal_size_test.dart` — 28 tests for `AnimalSize` enum (gram ranges, rangeSpan, fromString, boundary coverage).

## Mock Pattern

Hand-written interface implementations with deterministic behavior:

```dart
class MockCellService implements CellService {
  @override
  String getCellId(double lat, double lon) => 'cell_${lat.round()}_${lon.round()}';
  // ... deterministic grid-based cells
}
```

Mock classes: MockCellService variants, MockWriteQueueRepository, MockSupabasePersistence. Other services are used directly or stubbed inline.

## Factory Pattern

`make*()` functions with sensible defaults for test setup:
- `makeInMemoryDb()`, `makeCellProgress()`, `makeItemInstance()`, `makeProfile()`
- `makeSmallCellService()` — VoronoiCellService with 5×5 grid, seed=42
- `buildSpeciesService()` — SpeciesService from kSpeciesFixtureJson

Defined per-file (not shared). Each test file has its own factories.

## Integration Tests

| Suite | What it tests |
|-------|---------------|
| `offline_game_loop_test.dart` | Full session: player → cells → species → collection → restoration → streaks |
| `offline_persistence_test.dart` | SQLite round-trips: create → explore → collect → update → reopen |
| `offline_fog_test.dart` | Fog state transitions through all 5 states |
| `offline_discovery_test.dart` | Species encounter events: roll → emit → collect |
| `offline_audit_test.dart` | Data consistency: no orphaned records, all FK valid |
| `offline_hydration_test.dart` | Inventory hydration: SQLite → repo → InventoryNotifier, race safety, restart persistence |
| `enrichment_merge_test.dart` | Enrichment merge into species service, graceful degradation without enrichments |
| `write_queue_integration_test.dart` | Write queue: enqueue → read → confirm → reject → increment → stale cleanup |

## Performance Budgets

| Benchmark | Budget |
|-----------|--------|
| Parse 33k species JSON | < 5s |
| Build SpeciesService indices | < 3s |
| Species lookup per cell | < 50ms |
| Voronoi grid (40×40) | < 2s |
| Fog state (100 cells) | < 100ms |

## Gotchas

- `driftRuntimeOptions.dontWarnAboutMultipleDatabases = true` — REQUIRED in `setUpAll()` for any Drift test
- `ProviderContainer` must be disposed in `tearDown()` — leaks otherwise
- `collectEvents()` helper captures sync stream events — body runs synchronously
- H3 tests need `LD_LIBRARY_PATH=.` or FFI call will crash
- Performance tests use generous budgets (3× typical desktop time) — don't tighten without CI benchmarking

## Cell Properties Tests

| File | Tests | What it covers |
|------|-------|---------------|
| `test/core/cells/country_resolver_test.dart` | 44 | Country→continent resolution, bbox filter, ray-casting, fallback |
| `test/core/cells/event_resolver_test.dart` | 11 | Deterministic event assignment, ~12% rate, equal weights |
| `test/core/cells/cell_property_resolver_test.dart` | 10 | Habitat+climate+continent integration, mock lookups |
| `test/core/game/game_coordinator_test.dart` | 9 (cell group) | Cell property resolution in game tick, cache, callbacks |
| `test/core/species/species_service_test.dart` | ~19 (event group) | Migration species, nesting site, climate preference, empty pools |
| `test/features/discovery/services/discovery_service_test.dart` | 7 (event group) | cellPropertiesLookup integration, event→encounter replacement |
| `test/features/sync/services/location_enrichment_service_test.dart` | 12 | Null client no-op, dedup, callback wiring, dispose safety, AdminLevel parsing |
| `test/features/map/utils/cell_property_geojson_builder_test.dart` | 16 | Icon visibility rules, GeoJSON Point features, offsets, fog filtering, icon ID naming |
| `test/features/map/utils/territory_border_geojson_builder_test.dart` | 19 | Border fill BFS, border lines shared-edge detection, admin level stacking, color generation, unmapped neighbor handling |

## Coverage Gaps

No tests for: `core/config/`, `core/database/` (schema), `shared/`, `features/onboarding/`, `features/map/models/`, `features/sync/providers/` (SyncNotifier rollback), `features/map/utils/map_icon_renderer.dart` (requires Flutter Canvas — widget test needed).
