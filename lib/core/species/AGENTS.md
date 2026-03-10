# Species System

Deterministic encounter generation, weighted loot tables, and geographic filtering.

## SpeciesService

Core encounter mechanic. `getSpeciesForCell(cellId, habitats, continent, {dailySeed, encounterSlots})`:
1. Union species pools for all (habitat, continent) combinations
2. Build weighted LootTable (weights from IucnStatus enum)
3. Roll `encounterSlots` (default 3) times deterministically (seeded by `"${dailySeed}_${cellId}"`)
4. Return unique species (no duplicates per cell)

**Daily seed**: Required `dailySeed` parameter. Combined seed format: `"${dailySeed}_${cellId}"` passed to `rollMultiple()`. Same cell + same day = same species. Different day = different species.

Also provides: `getPoolForArea()`, `forHabitat()`, `forContinent()`, `all`, `totalSpecies`.

## LootTable<T>

Generic weighted random selection:
- `roll(seed: String)` → SHA-256 hash → 32-bit value mod totalWeight → binary search through cumulative weights
- `rollMultiple(baseSeed, n)` → `"${baseSeed}_$attempt"` for each roll. maxAttempts = n * 10 to avoid infinite loops.
- Weights are additive: item with weight 100000 (LC) is 100000× more likely than weight 1 (EX)

## SpeciesDataLoader

`fromJsonString(json)` → `List<FaunaDefinition>`. Silently skips records with unknown habitats/continents/IUCN statuses (logs warning). This is intentional — allows partial dataset updates without breaking the app.

## ContinentResolver

`resolve(lat, lon)` → Continent. Bounding-box lookup:
- Africa checked BEFORE Asia (overlapping longitudes at east coast)
- Africa split into west (-20 to 35 lon) and east (35 to 52 lon) sub-boxes
- Europe: lat 35–72, lon -25–45
- Fallback heuristic for open-ocean coordinates

## IUCN Weight Table

| Status | Weight | Relative Frequency |
|--------|--------|--------------------|
| Least Concern | 243 | Common |
| Near Threatened | 81 | Uncommon |
| Vulnerable | 27 | Rare |
| Endangered | 9 | Very rare |
| Critically Endangered | 3 | Ultra rare |
| Extinct | 1 | Legendary |

3^x progression. Higher weight = MORE common (not rarer).

## Gotchas

- Changing SHA-256 algorithm or seed format breaks ALL existing cell→species mappings
- **Daily seed format**: `"${dailySeed}_${cellId}"` → `rollMultiple()` appends `"_$attempt"` per roll. Changing this format invalidates all existing encounters.
- `rollMultiple()` can return fewer than n items if pool is too small (even after n*10 attempts)
- Species pool union means a cell at a biome boundary may yield species from multiple habitats
- FaunaDefinition equality is by `scientificName` only — two records with same name but different metadata are "equal"
- Dataset has 32,752 records but not all are rollable — some have unknown habitats/continents and are silently filtered
- Offline fallback seed (`offline_no_rotation`) means species don't rotate daily but encounters still work
