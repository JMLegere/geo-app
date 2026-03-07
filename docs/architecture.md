# Architecture

> For game design vision (what WILL be built), see [game-design.md](game-design.md).

## Layer Diagram

```
┌─────────────────────────────────────────────────┐
│  main.dart                                       │
│  ProviderScope → FogOfWorldApp → route logic     │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────┐
│  features/                                       │
│  ┌─────────┐ ┌─────────┐ ┌───────────────────┐  │
│  │   map   │ │  pack   │ │   achievements    │  │
│  │  (hub)  │ │sanctuary│ │   discovery       │  │
│  │         │ │  sync   │ │   caretaking      │  │
│  │         │ │navigate │ │   auth            │  │
│  │         │ │onboard  │ │   restoration     │  │
│  └────┬────┘ └────┬────┘ └────────┬──────────┘  │
│       │           │               │              │
└───────┼───────────┼───────────────┼──────────────┘
        │           │               │
┌───────▼───────────▼───────────────▼──────────────┐
│  core/                                            │
│  state/ → game/ → fog/ → cells/ → species/ → models/    │
│           persistence/ → database/                │
└──────────────────────────────────────────────────┘
        │
┌───────▼──────────────────────────────────────────┐
│  shared/                                          │
│  constants.dart, app_theme.dart, widgets/         │
└──────────────────────────────────────────────────┘
```

## Dependency Rules (Enforced)

| From | May Import | Must NOT Import |
|------|-----------|-----------------|
| `features/X` | `core/*`, `shared/*`, other features (if hub) | — |
| `core/*` | `core/*` (sibling), `package:*` | `features/*`, `shared/*` (exception: `gameCoordinatorProvider` imports features/ as wiring layer) |
| `shared/*` | `core/models/` (enums only) | `features/*`, `core/state/`, `core/persistence/` |
| `main.dart` | Everything | — |

## Feature Boundary Classification

| Feature | Type | Cross-Feature Imports |
|---------|------|----------------------|
| **map** | Leaf (renderer) | Reads gameCoordinatorProvider only (no longer orchestrates) |
| **achievements** | Hub | discovery, restoration, player, collection, species |
| **pack** | Composite | discovery, collection, species |
| **navigation** | Hub | map, sanctuary, pack (TabShell orchestrates all tabs) |
| **sanctuary** | Composite | discovery, collection, player, caretaking |
| **sync** | Composite | auth, supabase bootstrap |
| **auth** | Leaf | supabase bootstrap only |
| **location** | Leaf | none (pure services) |
| **biome** | Leaf | none (pure services) |
| **caretaking** | Leaf | none (reads playerProvider) |
| **seasonal** | Leaf | none (pure services) |
| **restoration** | Leaf | none |
| **discovery** | Leaf | none (provider in map/) |
| **onboarding** | Leaf | none |

## Feature Structure Patterns

**Full feature** (5 subdirs): `models/`, `providers/`, `services/`, `screens/`, `widgets/`
Used by: auth, achievements, sync

**Minimal feature** (1-3 subdirs): `services/` only, or `services/` + `providers/`
Used by: biome, location, caretaking, restoration, seasonal

**Map feature** (unique): `controllers/`, `layers/`, `models/`, `providers/`, `utils/`, `widgets/` + `map_screen.dart` at root

## Initialization Chain

```
main()
  → SupabaseBootstrap.initialize() [non-blocking, 3s timeout]
  → ProviderScope(overrides: [supabaseBootstrapProvider])
    → FogOfWorldApp
      → watch(onboardingProvider)  [SharedPreferences]
      → watch(authProvider)        [awaits supabase ready]
      → route:
          onboarded == null  → splash (loading)
          onboarded == false → OnboardingScreen
          auth loading       → _LoadingSplash
          authenticated      → TabShell (4-tab: Map | Home | Town | Pack)
          unauthenticated    → LoginScreen
```

Auth states are `{unauthenticated, loading, authenticated}`. Anonymous sign-in happens automatically — users start exploring immediately. `upgradePromptProvider` triggers a save-progress banner after 5 collected species for anonymous users.

## Glossary

| Term | Definition |
|------|------------|
| **Cell** | Spatial region on the map (Voronoi polygon or H3 hexagon) |
| **Fog-of-war** | Visibility system that reveals the map as you explore — Civilization style |
| **Encounter** | A species appearing in a cell when you visit it (3 per cell, deterministic) |
| **Loot table** | Weighted random selection (Path of Exile 10^x progression) |
| **Restoration** | Collecting 3 unique species in a cell = fully restored habitat |
| **Sanctuary** | Personal species collection, grouped by habitat |
| **Caretaking** | Daily visit streak tracking |
| **Detection radius** | 1000m — cells within this radius become at least Unexplored |
| **Exploration frontier** | Unvisited cells adjacent to visited cells |
| **Museum** | NPC-run exhibit space with 7 habitat wings, permanent donations (target design) |
| **Pack** | Field Pack — inventory tab for managing collected species (target design) |
| **Town** | NPC hub showing discovered NPCs (target design) |
| **Treasure map** | Quest item marking real-world area where specific rare species can be found (target design) |
| **Daily seed** | Midnight GMT world rotation — deterministic per-day species spawns (target design) |
