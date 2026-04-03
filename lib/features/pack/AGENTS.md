# Pack Feature

Collection viewer. Displays all `ItemInstance` objects the player owns, grouped by category and filterable by rarity/habitat/type.

---

## Architecture

- `packProvider`: `NotifierProvider<PackNotifier, PackState>` — filter state (selected category, rarity filter, sort order). Reads `itemsProvider` for the item list.
- `PackState`: Immutable. `selectedCategory`, `rarityFilter`, `sortOrder`, `searchQuery`.
- `PackScreen` — 4-tab screen: Fauna, Character, and stub tabs for other categories.

---

## Tabs

| Tab | Widget | What it shows |
|-----|--------|---------------|
| Fauna | `FaunaGridTab` | Grid of collected fauna `ItemInstance` objects |
| Character | `CharacterTab` | Player stats, profile |
| (Flora/Mineral/etc.) | `CategoryStubTab` | "Coming soon" placeholder |

---

## Species Card Components

| Widget | Role |
|--------|------|
| `SpeciesCard` | Full card (art + stats + rarity frame) |
| `SpeciesCardArtZone` | Art display with loading/placeholder state |
| `SpeciesCardStats` | RGB stat bars (brawn/speed/wit) |
| `SpeciesCardRarityFrame` | Rarity-colored border + badge icons |
| `SpeciesCardModal` | Full-screen detail modal |
| `ItemDetailSheet` | Bottom sheet for item instance details |
| `ItemSlotWidget` | Compact grid slot (thumbnail + rarity pip) |

---

## Conventions

- `packProvider` does NOT own items — it only owns filter state. Items come from `itemsProvider`.
- `PackNotifier` uses `ref.listen(itemsProvider)` to react to new discoveries without resetting filter state.
- Species card art: show `artUrl` from `LocalSpeciesTable` if non-null; fall back to emoji derived from `animalType`.
- Stats bars are RGB-coded: R=brawn, G=speed, B=wit. Values are 0–100 (base ±30% variance).

---

## Gotchas

- `FaunaGridTab` only shows `ItemInstanceStatus.active` items — donated/placed/released items are hidden.
- Species data comes from `SpeciesCache` (synchronous) — never query `SpeciesRepository` directly in pack widgets.
- Do NOT read `speciesRepositoryProvider` in pack widgets — use `speciesCacheProvider` for sync lookups.

See /AGENTS.md for project-wide rules.
