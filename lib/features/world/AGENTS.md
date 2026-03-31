# World Feature

Shared geo-contextual state for the game world: biome classification, cell property resolution, and daily cell events. Consolidated from `features/biome/` and `core/cells/` (CellPropertyResolver + EventResolver).

---

## Subdirectories

### services/

- `BiomeService` (formerly `HabitatService`): `classifyLocation(lat, lon)` → `Set<Habitat>`. Queries `BiomeFeatureIndex` against ESA land cover data. Implements `HabitatLookup` interface consumed by `CellPropertyResolver`.
- `BiomeFeatureIndex`: Spatial index of ESA land cover polygons loaded from `assets/biome_features.json`. Point-in-polygon lookup. Falls back to `DefaultHabitatLookup` (plains) while loading.
- `CellPropertyResolver`: Synchronous resolution of permanent geo-derived cell properties. `resolve(cellId, lat, lon)` → `CellProperties`. Combines `HabitatLookup` + `ContinentLookup` + `Climate.fromLatitude()`. **Synchronous and instant** — safe to call in game tick.
- `EventResolver`: Deterministic daily event assignment. `static CellEvent? resolve(dailySeed, cellId)`. ~12% hit rate via SHA-256. Events: `migration` (foreign-continent species), `nestingSite` (EN/CR/EX guaranteed). Events REPLACE base encounters.
### providers/

- `habitatServiceProvider`: `Provider<BiomeService>` — singleton service, bridged to `HabitatLookup` for `CellPropertyResolver`.
- `cellPropertyResolverProvider`: `Provider<CellPropertyResolver>` — watches `habitatServiceProvider` + `countryResolverProvider`. Falls back to `DefaultHabitatLookup` + legacy `ContinentResolver` while async providers load.

### models/

Shared geo models used across world services. Thin — most types live in `core/models/`.

---

## Key Interfaces

- `HabitatLookup`: `Set<Habitat> classifyLocation(double lat, double lon)`. Implemented by `BiomeService`. `DefaultHabitatLookup` returns `{Habitat.plains}` as fallback.
- `ContinentLookup`: `Continent resolve(double lat, double lon)`. Implemented by `CountryResolver` (in `core/cells/`).

---

## Conventions

- `CellPropertyResolver.resolve()` is a plain class — test doubles must `implement` (not `extend`) it.
- `EventResolver` is stateless with a single static method — no instantiation needed.
- Cell properties are **globally shared** (no userId). Same `cellId` always resolves to same properties.
- Events are **not persisted** — recomputable from `dailySeed + cellId`.
- `cellPropertiesLookup` on `DiscoveryService` is wired post-construction by `gameCoordinatorProvider` to avoid circular dependency.

---

## Gotchas

- `CellPropertyResolver` moved here from `core/cells/`. Import path: `features/world/services/cell_property_resolver.dart`.
- `EventResolver` moved here from `core/cells/`. Event seed format: `"${dailySeed}_event_${cellId}"` — changing this breaks event reproducibility.
- `BiomeService` was previously `HabitatService` in `features/biome/`. Rename is intentional.

