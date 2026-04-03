# Sanctuary Feature

Species sanctuary (Home tab). Shows `placed` items grouped by habitat. Players place fauna from their Pack into the sanctuary.

---

## Architecture

- `sanctuaryProvider`: `NotifierProvider<SanctuaryNotifier, SanctuaryState>` — placed items grouped by habitat. Reads `itemsProvider`.
- `SanctuaryState`: Immutable. `placements: Map<Habitat, List<ItemInstance>>`, `totalPlaced`.
- `SanctuaryScreen` — tab-per-habitat layout with `HabitatSection` widgets.

---

## Tabs / Layout

| Widget | Role |
|--------|------|
| `ZooTab` | Main sanctuary view — all habitats with placed items |
| `HabitatSection` | Single habitat row with species tiles |
| `SanctuarySpeciesTile` | Individual placed species card |
| `SanctuaryHealthIndicator` | Visual indicator of sanctuary health (streak-based) |
| `StreakBadge` | Shows current visit streak |
| `SanctuaryStubTab` | Placeholder for unimplemented sanctuary tabs |

---

## Item Lifecycle Integration

- `SanctuaryNotifier` reads `itemsProvider` and filters for `ItemInstanceStatus.placed`.
- Placing an item: call `itemsProvider.notifier.placeItem(instanceId)` → status changes to `placed` → sanctuary auto-refreshes via `ref.listen`.
- Returning to pack: call `itemsProvider.notifier.releaseItem(instanceId)` → status changes to `released`.
- Sanctuary feeding (producing orbs) is a **future feature** — infrastructure exists but no feeding loop yet.

---

## Conventions

- Group items by `FaunaDefinition.habitats.first` (primary habitat) for display.
- Max items per habitat section: uncapped (scroll within section).
- Sanctuary health is derived from `playerProvider.currentStreak` — no separate health state.

---

## Gotchas

- `sanctuaryProvider` does NOT persist to SQLite — persistence is handled by `itemsProvider` (which uses `ItemInstanceRepository`).
- Species metadata comes from `SpeciesCache`, not direct Drift queries.
- Sanctuary feeding loop (orb production: habitat orb + class orb + climate orb) is NOT yet implemented.

See /AGENTS.md for project-wide rules.
