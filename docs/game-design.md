# Game Design

Comprehensive design reference for EarthNova (working title). Synthesized from game design jam session. This is directional, not rigid — design evolves through building.

> "Everything we're doing here is an ongoing conversation. Don't take this design as gospel and continue to learn and negotiate as we build over time."

## Current vs Target

| Aspect | Current Implementation | Target Design |
|--------|----------------------|---------------|
| Species model | Binary collected/not | Inventory items with quantity |
| Discovery | Auto-collect, 3s toast | Rarity-scaled TCG-style reveals |
| Journal | Filtered catalog (Pokédex) | Inventory-first management hub |
| Museum | Does not exist | 7 habitat wings, permanent donations |
| Sanctuary | Grouped species list | Grid-based zoo with appeal system |
| NPCs | Do not exist | Full characters, discoverable on map |
| Navigation | **Done** — 4-tab shell (Map \| Home \| Town \| Pack) | ✓ Shipped |
| Auth | **Done** — Anonymous auto-login, upgrade prompt, email/OAuth upgrade flow | ✓ Shipped |
| Quests | Do not exist | Treasure maps + NPC bundles |
| Daily rotation | Does not exist | Midnight GMT world seed |
| Restoration | 3 species = restored | Under review, may be reworked |

---

## 1. Design Philosophy **(confirmed)**

- **Core fantasy**: iNaturalist × Stardew Valley × Pokémon Go
- **Genre**: Cozy game (Animal Crossing, Stardew, Spiritfarer, Cozy Grove, Pokémon)
- **Audience**: Nurturing, wholesome players — not competitive or hardcore
- **Stardew piece**: Collecting to fill spaces (museum, zoo), maintaining a home, exploring/foraging — NOT farming
- **Design is directional**: Evolves through building, not carved in stone
- **Engagement spectrum**: OSRS-inspired — passive baseline, active play gets better rewards

---

## 2. Game Identity **(confirmed)**

**Working Title:** EarthNova — combines "Earth" (nature/GPS exploration) + "Nova" (Ark Nova inspiration)

**Core Fantasy:** Field researcher exploring the real world, discovering species, curating a museum, building a sanctuary.

**Target Audience:** Cozy/friendly game players. Games they play: Animal Crossing, Stardew Valley, Spiritfarer, Cozy Grove, Pokémon.

**Player Identity (shifts by area):**
- **Map**: Explorer / Adventurer — discovering territory, fog of war, treasure maps
- **Museum**: Researcher / Naturalist — documenting species, curating exhibits, science
- **Home/Sanctuary**: Keeper / Caretaker — nurturing, arranging, building, maintaining

---

## 3. Visual Direction **(confirmed)**

**Perspective:** Top-down like Stardew Valley.

**UI Feel:** Tight and clean like iOS, but cutesy like PuffPals Island Skies. Adorable watercolour illustrations inside crisp, modern UI containers.

**Art Style:** Watercolour. EVERYTHING gets illustrated — species, items, NPCs, environments, collectibles.

**Art Pipeline:** Now = AI-generated watercolour placeholders. Future = hand-drawn or commissioned.

---

## 4. Game Areas & Navigation **(confirmed)**

**4-Tab Bottom Bar:** Map | Home | Town | Pack

| Tab | Purpose | Current State |
|-----|---------|---------------|
| **Map** | GPS exploration, fog reveal, species discovery | Exists |
| **Home** | Sanctuary — maintaining collection, curating exhibits | Partially exists (grouped list) |
| **Town** | NPC hub — summary of discovered NPCs | Does not exist |
| **Pack** | Field Pack — inventory management, usability-first | Exists as Journal (needs reconceptualization) |

Profile/settings accessed via gear icon (not a dedicated tab).

---

## 5. Core Loop **(confirmed)**

```
Explore map → Reveal fog → Discover species → Manage inventory →
  ↓                                                              ↑
Museum donation (permanent) OR Sanctuary placement (flexible) ──┘
  ↓
Unlock wings, NPCs, treasure maps → Directed exploration
```

**Moment-to-Moment:** Fog reveal with juice, hints in adjacent cells, passive vs active play (active = better rewards), real-world location matters.

**Discovery Dopamine:** "Almost got it" moments, treasure maps for rare species, silhouettes of undiscovered species in museum wings, shareable moments, no pity system.

**Organizing Satisfaction:** Journal = Inventory (usability-first), sub-collections, completed sets feel special (golden border, NPC reaction).

**Building Satisfaction:** Sanctuary appeal maximization (Ark Nova puzzle), NPCs react to sanctuary, social features planned.

**Session Hooks:** Daily world changes, daily/weekly challenges, long-term goals (complete museum, beautiful sanctuary), mistakes are minor setbacks.

**Immersion:** Seasons change world visually, weather affects spawns, NPCs remember you.

---

## 6. Discovery System **(confirmed)**

**TCG Dopamine Model (KEY DESIGN PHILOSOPHY):** The dopamine loop should feel like a trading card game. Each species IS a card (conceptually): illustration, rarity, stats, habitat. Pack opening = entering a new cell. The reveal = discovery splash (escalates with rarity). The binder = Journal. Duplicates have value = museum placement in different wings.

**Rarity-Scaled Reveals:**

| IUCN Status | Rarity Tier | Reveal Treatment |
|-------------|-------------|------------------|
| LC | Common | Quick small toast |
| NT | Uncommon | Slightly fancier toast |
| VU | Rare | Splash popup with art reveal |
| EN | Ultra Rare | Dramatic splash, glow, pause |
| CR | Legendary | Full-screen reveal, particles, sound |
| EX | Chase/Secret Rare | Maximum ceremony, holy grail moment |

**Discovery Splash:** Tap OR auto-dismiss (~8s). Celebration moment. Each new cell is a "booster pack". Duplicates still get toasts (they have value).

**Discovery Agency:** Common species (LC, NT) = auto-collect. Rare species (VU+) = tap to "photograph". Photography mechanic is thematic (field journal, watercolour sketches).

---

## 7. Engagement Intensity **(confirmed — OSRS-inspired)**

Like Old School RuneScape skill training — **multiple intensity levels** of play. Not binary (passive/active) but a SPECTRUM:

| Intensity | Behavior | Yield |
|-----------|----------|-------|
| **AFK/Passive** | Walk commute, auto-collect commons, game in background | Lowest yield |
| **Light Active** | Check phone, photograph rares, browse adjacent cells | Medium yield |
| **High Active** | Follow treasure maps, complete activities, do mini-tasks | Highest yield |

Active play → more species per cell (passive = 1, active = up to 3), bonus items from interaction.

**Cell Activities (all are possibilities):** Photograph/sketch, forage/dig, set lure/bait (OSRS birdhouses), field survey (ID challenge), habitat care (clear debris, plant seeds). Not all need to ship at once.

---

## 8. Inventory (Pack) **(confirmed — KEY SHIFT)**

**Species are INVENTORY ITEMS, not binary checkmarks.** You can collect MULTIPLES of the same species (find 2 ducks = 2 items). Journal tab = active inventory. From inventory, player CHOOSES: donate to museum wing, place in sanctuary, keep in inventory.

**Inventory UX:** Stacking with preview ("Mallard ×3"), unlimited carry (pure cozy), bidirectional placement (Journal has "Donate"/"Place" buttons AND Museum/Sanctuary have "Fill from inventory"), museum donations are PERMANENT (like Stardew), sanctuary placement is FLEXIBLE (rearrange freely), release mechanic (feel-good animation).

**Implications:** Species discovery is no longer one-time event — re-finding species has VALUE. Museum completion requires strategic duplicate hunting. Journal becomes MOST IMPORTANT tab. **One animal per museum wing** — multi-habitat species need duplicates for multiple wings. Creates Ark Nova-style resource allocation. Fundamentally changes game from "collect and done" to "collect → manage → place strategically".

---

## 9. Museum **(confirmed)**

**Structure:** Unlockable wings — start with one room, unlock new wings as you donate more. **Fauna wings by habitat** (7): Forest, Plains, Freshwater, Saltwater, Swamp, Mountain, Desert. **Future non-fauna wings** (3): Botanical Garden (plants), Mineral Gallery (gems), Fossil Hall (artifacts). Total potential: 10 wings.

**Donation Mechanics:** Permanent donations (can't take back), one animal per wing (multi-habitat species appear in ALL matching wings = requires duplicates), grid display with empty/filled slots (like Stardew museum), silhouettes of undiscovered species.

**Museum vs Sanctuary:** Museum = separate place, NPC-run, donate to fill displays. Sanctuary = your personal zoo/garden, YOU build and maintain (Ark Nova style). Two distinct progression tracks: completionist (museum) vs creative builder (sanctuary).

---

## 10. Sanctuary **(confirmed)**

**Layout:** Grid-based like Stardew farm. Tile grid: place enclosures, paths, decorations on discrete tiles.

**Progression Vision:** Phase 1 (now) = collection menu. Phase 2 (future) = build/arrange zoo to maximize appeal. Appeal system inspired by Ark Nova: animal placement, enclosure types, synergies.

**Placement Mechanics:** Flexible placement (rearrange freely), appeal maximization is the fun (Ark Nova puzzle), NPCs react to sanctuary, social features planned.

---

## 11. NPCs **(confirmed)**

**Character Design:** Full characters with names, personality, dialogue — like Blathers, Tom Nook. NPCs are the social/progression layer.

**Discovery Mechanic (KEY DESIGN INSIGHT):** NPCs are discovered on the map while exploring — NOT always available. Town tab is a summary/hub of NPCs you've found so far. NPCs are part of the exploration loop — finding new NPCs is itself a discovery event. NPCs have locations/territories in the real world.

**Spawn Mechanic:** Mix of milestone + location. Some NPCs unlock from achievements/progress (collected X species, restored Y cells). Others from visiting enough unique biomes/areas or real-world location types. Two discovery vectors: exploration-based AND progress-based.

**NPC Interactions:** NPCs remember you, museum curator requests, quest givers (treasure maps, bundles), shops (deferred).

---

## 12. Collectible Categories **(confirmed — 4 top-level)**

1. **Fauna** (species) — core 32k IUCN dataset, split by taxonomic class
2. **Plants / Flora** — trees, flowers, fungi (FUTURE)
3. **Minerals / Gems** — rocks, crystals (FUTURE)
4. **Artifacts / Fossils** — ancient items, bones (FUTURE)

**Fauna Organization:** 25 taxonomic classes exist in IUCN data (displayed per-species as their class). **Museum wings grouped by HABITAT**, not taxonomic class. 7 habitats: Forest, Plains, Freshwater, Saltwater, Swamp, Mountain, Desert. Multi-habitat species appear in ALL matching wings (requires duplicates). Taxonomic class is metadata shown per-species (e.g. "Class: Mammalia") not a grouping axis. Top 6 classes: Fish (9.1k), Reptiles (5.4k), Birds (5.4k), Mammals (4.1k), Amphibians (3.4k), Insects (3.2k). All fauna discovered the same way (auto-collect common, tap-to-photograph rare). All get watercolour illustrations.

---

## 13. Sub-Collections & Sets **(confirmed)**

Break the 32k species pool into completable sub-goals:

**Set Types (all work):** Habitat sets, taxonomic class sets, continent sets, rarity sets (one of each IUCN status — "rainbow set"), themed/curated sets ("Big Cats", "Coral Reef Life"), NPC request sets.

**Dynamic Sets (like Stardew community center bundles):** NPCs present a bundle of specific species to collect → reward on completion. Bundles could rotate seasonally or per-NPC. Completing all bundles from an NPC → major unlock.

**Completion Rewards:** Completed sets look visually satisfying (golden border, special effect, NPC reaction). Completion unlocks rewards (new wing, treasure map, sanctuary cosmetic).

---

## 14. Quest System **(confirmed — KEY MECHANIC)**

**Treasure Maps ARE the Quest System:** Directed exploration — maps mark a real-world area where a specific rare species can be found. Creates purposeful trips, not just random wandering. Makes rare species achievable without a pity system.

**Treasure Map Sources (ALL confirmed):** NPC quest rewards (ranger heard rumors...), random exploration drops (message in a bottle), museum curator requests ("I need X for the Forest wing"), weekly challenge rewards, milestone unlocks (hit collection thresholds → maps to rarer species).

**Other Quest Types:** NPC bundles (Stardew-style themed collections), daily/weekly challenges (rotating content).

---

## 15. World Systems **(confirmed)**

**Daily World Seed (KEY MECHANIC):** Midnight GMT — every day, the entire world gets a new seed. Deterministic per-day: every player who visits the same cell on the same day gets the same species. First visit: seeded by cell ID (permanent species). Daily rotation: additional species pool rotated daily via world seed. Creates "Wordle effect" — social sharing of daily finds, daily motivation. No server-side RNG needed — seed = date + cellId, computed client-side. Respawn cycle: cells give new species each day (time-gated, midnight GMT reset).

**Seasons:** 2 seasons — Summer (May–Oct), Winter (Nov–Apr). 80% of species are year-round, 10% summer-only, 10% winter-only. Seasons change world visually: snow on fog, autumn colors, seasonal NPC dialogue.

**Weather:** Real-world weather → different spawns (rain = amphibians, night = different species).

**Map Visual Priority:** Fog reveal is KING — the primary satisfaction is peeling back fog. Adjacent cell hints, treasure map markers, daily species markers are all SECONDARY overlays. Fog is the frame; everything else layers on top.

**Adjacent Cell Previews:** Hints in adjacent fogged cells — see silhouettes/glows of what's nearby. Creates "I need to go THERE" pull. Adjacent cell highlights as "one more cell" hook.

---

## 16. Mechanics & Deferred Items

**Restoration Mechanic (UNDER REVIEW — tentative):** Current code: 3 unique species in a cell = fully restored. Designer questions if this mechanic is pulling its weight. May be reworked or removed as inventory model and cell activities develop. Don't invest heavily here — mechanic is unstable.

**Deferred Decisions (designer not ready — DO NOT plan these):** Economy/shops, NPC count, sound/music, monetization, social features, session arc shape, hardest decision in the game, reasons NOT to collect, camera AI, real-time Supabase sync, multiplayer.
