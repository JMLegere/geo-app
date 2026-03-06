# Draft: Game Design Jam

## Core Fantasy (confirmed)
- iNaturalist × Stardew Valley × Pokémon Go
- **Stardew piece**: Collecting things to fill spaces (museum, zoo, aquarium), maintaining a home, exploring/foraging
- NOT the farming — the collecting, curating, and maintaining
- Cozy game genre: Animal Crossing, Stardew, Spiritfarer, Cozy Grove, Pokémon

## Target Audience (confirmed)
- Cozy/friendly game players
- Not competitive, not hardcore — nurturing and wholesome
- Games they play: Animal Crossing, Stardew Valley, Spiritfarer, Cozy Grove, Pokémon

## Three Main Areas (brainstorm, names not final)
1. **Map** — GPS exploration, fog reveal, species discovery (exists)
2. **Home** (zoo/sanctuary) — maintaining your collection, curating exhibits (partially exists as Sanctuary)
3. **NPCs** (shops, museums, quest givers) — social/progression layer (does NOT exist yet)

## Design Decisions Made
- Home is for now a collection menu, but eventually players should BUILD their home to maximize appeal
- Inspired by **Ark Nova** board game zoo-building mechanic (appeal system, enclosure placement)
- **New species discovery should have a splash popup** — not the current 3s toast. A celebration moment for first-time finds
- Repeat discoveries (already collected) can stay as small toasts — splash is for NEW only

## CORE SYSTEM CHANGE: Inventory Model (confirmed — KEY SHIFT)
- **Species are INVENTORY ITEMS, not binary checkmarks**
- You can collect MULTIPLES of the same species (find 2 ducks = 2 items)
- **Journal tab = active inventory** — shows what's "on the player" right now
- Journal must be USABLE above all else — this is where players manage their collection
- From inventory, player CHOOSES what to do with each animal:
  - Donate to a museum wing
  - Place in sanctuary
  - Keep in inventory
- **One animal per museum wing** — a duck goes in ONE wing. Want it in both Freshwater and Plains? Find two ducks.
- This creates Ark Nova-style resource allocation: strategic decisions about WHERE to place limited resources
- Fundamentally changes the game from "collect and done" to "collect → manage → place strategically"

### Inventory UX Decisions (confirmed)
- **Stacking with preview**: "Mallard ×3" — expandable to see individuals (future unique traits)
- **Unlimited carry**: No backpack limit. Pure cozy. Place whenever you feel like it.
- **Bidirectional placement**: Journal has "Donate"/"Place" buttons AND Museum/Sanctuary have "Fill from inventory"
- **Museum donations are PERMANENT** — adds weight, "are you sure?" moment (like Stardew donations)
- **Sanctuary placement is FLEXIBLE** — rearrange freely, pick up and move, your personal space
- **Release mechanic**: Can release animals back to nature (feel-good animation, manages overflow)
- **Museum wing display**: Grid of display slots — see filled/empty, like Stardew museum. Empty slots = motivation.

### Implications of Inventory Model
- Species discovery is no longer a one-time event — re-finding species has VALUE
- Museum completion requires strategic duplicate hunting
- Journal becomes the MOST IMPORTANT tab (central hub for all decisions)
- Current code assumption (species = binary collected/not) needs fundamental rework
- CollectedSpecies table needs to track QUANTITY or individual instances
- Sanctuary placement and museum donation are CONSUMPTION actions (removes from inventory)
- Museum donation is PERMANENT (can't take back) — forces thoughtful placement
- Sanctuary is FLEXIBLE (can rearrange) — low-pressure creative space

## Home Progression Vision
- **Phase 1 (now)**: Collection menu — view what you've collected, grouped somehow
- **Phase 2 (future)**: Build/arrange your zoo/sanctuary to maximize appeal
- Appeal system inspired by Ark Nova: animal placement, enclosure types, synergies
- This is the long-term "Stardew farm" equivalent — your personal creation

## NPC Design (confirmed)
- **Full characters** with names, personality, dialogue — like Blathers, Tom Nook
- NPCs are the social/progression layer of the game
- Part of the "NPCs" area (3rd main area)

## Museum vs Sanctuary (confirmed)
- **Museum** = separate place. You DONATE things to fill displays (like Stardew's museum). NPC-run.
- **Sanctuary/Home** = your personal zoo/garden that YOU build and maintain (Ark Nova style)
- Two distinct progression tracks: completionist (museum) vs creative builder (sanctuary)

## Discovery Splash Popup (confirmed — TCG-style)
- **Tap OR auto-dismiss**: Auto-fades after ~8 seconds, but tapping opens full species detail
- This is a celebration moment — the "you pulled it!" feeling
- **Rarity-scaled ceremony** — reveal escalates with IUCN rarity:
  - LC (Common): Quick small toast
  - NT (Uncommon): Slightly fancier toast
  - VU (Rare): Splash popup with art reveal
  - EN (Ultra Rare): Dramatic splash, glow, pause
  - CR (Legendary): Full-screen reveal, particles, sound
  - EX (Chase/Secret Rare): Maximum ceremony, holy grail moment
- Each new cell is a "booster pack" — what species will you pull?
- Duplicates still get toasts (they have value for museum/sanctuary placement)

## TCG Dopamine Model (confirmed — KEY DESIGN PHILOSOPHY)
- The dopamine loop should feel like a **trading card game**
- Each species IS a card (conceptually): illustration, rarity, stats, habitat
- **Presentation: card-inspired but not literal** — species detail pages echo TCG composition (art + stats + badge) but don't look like physical cards
- Pack opening = entering a new cell
- The reveal = discovery splash (escalates with rarity)
- The binder = Journal (organized collection, satisfying to browse)
- Completion chase = filling museum wings, habitat sets
- Duplicates have value = museum placement in different wings

## Visual Style (confirmed)
- **Perspective**: Top-down like Stardew Valley
- **UI feel**: Tight and clean like iOS, but cutesy like PuffPals Island Skies
  - PuffPals reference: hyper-cute, rounded, colorful cel-shaded, big-eyed characters, chibi proportions
  - iOS reference: minimal chrome, clear hierarchy, whitespace, system-level polish
  - Blend: adorable watercolour illustrations inside crisp, modern UI containers
- **Art style**: Watercolour
- **Illustrations**: EVERYTHING gets illustrated — species, items, NPCs, environments, collectibles
- **Art pipeline (now)**: AI-generated watercolour illustrations as placeholder/MVP
- **Art pipeline (future)**: Presumably hand-drawn or commissioned watercolour illustrations

## Discovery Agency (confirmed)
- **Different per type**: Common species auto-collect, rare species require interaction
- Rarity = more engagement to collect
- Fits the cozy vibe while giving rare finds extra weight

## Collectible Categories (confirmed — 4 top-level)
1. **Fauna** (species) — core 32k IUCN dataset, split by taxonomic class
2. **Plants / Flora** — trees, flowers, fungi (FUTURE — not in current data)
3. **Minerals / Gems** — rocks, crystals (FUTURE — not in current data)
4. **Artifacts / Fossils** — ancient items, bones (FUTURE — not in current data)

### Fauna Organization
- 25 taxonomic classes exist in IUCN data (displayed per-species as their class)
- **Museum wings grouped by HABITAT**, not taxonomic class
  - 7 habitats already defined: Forest, Plains, Freshwater, Saltwater, Swamp, Mountain, Desert
  - Every species already has habitat data in the IUCN dataset
  - A "Freshwater" wing naturally contains fish, amphibians, crustaceans, etc.
  - A "Forest" wing naturally contains mammals, birds, insects, reptiles, etc.
  - Multi-habitat species appear in ALL matching wings (confirmed). A duck in both Freshwater + Plains.
- Taxonomic class is metadata shown per-species (e.g. "Class: Mammalia") not a grouping axis
- Top 6 classes: Fish (9.1k), Reptiles (5.4k), Birds (5.4k), Mammals (4.1k), Amphibians (3.4k), Insects (3.2k)
- Fish and insects are NOT separate gameplay categories — they're taxonomic classes
- All fauna discovered the same way (auto-collect common, tap-to-photograph rare)
- All get watercolour illustrations

## Discovery Agency (confirmed)
- **Common species** (LC, NT): Auto-collect on proximity (low friction, cozy)
- **Rare species** (VU, EN, CR, EX): Tap to "photograph" — you're a field researcher
- Rarity (IUCN status) determines engagement level
- Photography mechanic is thematic (field journal, watercolour sketches)
- Same mechanic for ALL fauna regardless of taxonomic class

## Navigation (confirmed)
- **4-tab bottom bar**: Map | Home | Town | Pack
- "Pack" = Field Pack (thematic — you're a field researcher with a pack)
- Pack tab = inventory-first design, usability above all
- Profile/settings accessed via gear icon (not a dedicated tab)

## NPC Discovery (confirmed — KEY DESIGN INSIGHT)
- **NPCs are discovered on the map** while exploring — NOT always available
- **Town tab** is a summary/hub of NPCs you've found so far
- NPCs are part of the exploration loop — finding new NPCs is itself a discovery event
- This means NPCs have locations/territories in the real world

## Sanctuary Layout (confirmed)
- **Grid-based** like Stardew farm
- Tile grid: place enclosures, paths, decorations on discrete tiles
- Clear and structured — matches the "clean iOS" UI philosophy
- Future Ark Nova phase: strategic placement within grid for appeal/synergy

## Daily World Seed (confirmed — KEY MECHANIC)
- **Midnight GMT**: Every day, the entire world gets a new seed
- **Deterministic per-day**: Every player who visits the same cell on the same day gets the same species
- **First visit**: Seeded by cell ID (permanent species, always there)
- **Daily rotation**: Additional species pool rotated daily via world seed
- Creates "Wordle effect" — social sharing of daily finds, daily motivation
- World feels alive — different every day, same for everyone
- No server-side RNG needed — seed = date + cellId, computed client-side
- Respawn cycle: cells give new species each day (time-gated, midnight GMT reset)

## Deferred Decisions (user not ready)
- **Economy/shops**: Not thought through yet — skip for now
- **Quest style**: Partially answered — treasure maps + NPC bundles are the quest system. Details TBD.

## NPC Spawn Mechanic (confirmed)
- **Mix of milestone + location**
- Some NPCs unlock from achievements/progress (collected X species, restored Y cells)
- Others from visiting enough unique biomes/areas or real-world location types
- Creates two discovery vectors: exploration-based AND progress-based

## Game Title (confirmed)
- **Working title: EarthNova**
- Combines "Earth" (nature/GPS exploration) + "Nova" (Ark Nova inspiration)

## Museum Structure (confirmed)
- **Unlockable wings** — start with one room, unlock new wings as you donate more
- Progression: donations → wing unlocks → more display space → more motivation to collect
- **Fauna wings by habitat** (7): Forest, Plains, Freshwater, Saltwater, Swamp, Mountain, Desert
- **Future non-fauna wings** (3): Botanical Garden (plants), Mineral Gallery (gems), Fossil Hall (artifacts)
- Total potential: 10 wings (7 habitat + 3 non-fauna)

## Restoration Mechanic (UNDER REVIEW)
- Current code: 3 unique species in a cell = fully restored
- **Designer questions if this mechanic is pulling its weight**
- May be reworked or removed as inventory model and cell activities develop
- Don't invest heavily here — mechanic is unstable

## Map Visual Priority (confirmed)
- **Fog reveal is KING** — the primary satisfaction is peeling back fog
- Adjacent cell hints, treasure map markers, daily species markers are all SECONDARY overlays
- Fog is the frame; everything else layers on top

## Deferred Decisions (designer not ready — DO NOT plan these)
- **Economy/shops**: Not thought through yet
- **NPC count**: Not specified
- **Sound/music**: Not discussed
- **Monetization**: Too early
- **Social features**: Important but not designed yet

## Design Philosophy (META — CRITICAL)
> "Everything we're doing here is an ongoing conversation. Don't take this design as gospel
> and continue to learn and negotiate as we build over time."
- Design is DIRECTIONAL, not a rigid spec
- Docs should capture philosophy and direction, not carved-in-stone requirements
- Continue to question and refine during implementation
- Design evolves through building

## Cell Activities (confirmed — all are possibilities)
- **Photograph/sketch**: Already confirmed for rares. Could extend to all species for bonus drops.
- **Forage/dig**: Tap to search area. Each tap reveals items. Limited uses per cell.
- **Set a lure/bait**: Place attractant, come back later to collect (like OSRS birdhouses).
- **Field survey**: Quick ID challenge — "Is this a Mallard or Teal?" Correct = bonus. Teaches real species.
- **Habitat care**: Clear debris, plant seeds, water area. Improves cell spawn rate. Ties into restoration.
- All are potential "training methods" at different engagement intensities.
- Not all need to ship at once — can introduce progressively.

## Find the Fun — Design Responses (confirmed)

### The Walk (moment-to-moment)
- **Fog reveal should have juice** — satisfying dissolve, sound, color change
- **Hints in adjacent fogged cells** — see silhouettes/glows of what's nearby. Creates "I need to go THERE" pull.
- **Passive vs Active play**: Both work, but **active engagement gives better progress/rewards**. Passive = things happen. Active = better outcomes.
- **Real-world location matters**: Habitat, continent, specific location ALL affect what you find. Parks denser? Waterfronts = aquatic?
- **Adjacent cell highlights** as the "one more cell" hook — can see good stuff nearby

### The Pull (discovery dopamine)
- **"Almost got it" moment**: Show good stuff in adjacent cells. Offer quests for rare things. **TREASURE MAPS** for rare species!
- **See what you're missing**: Silhouettes of undiscovered species in museum wings. Know what you're hunting for.
- **Shareable moments**: Finding rare species should be screenshot/share worthy.
- **No pity system**: Rare is genuinely rare. Aspirational, not guaranteed.

### The Collection (organizing satisfaction)
- **Journal = Inventory** (rename/reconceptualize). Inventory-first design, usability above all.
- **Sub-collections**: Break collections into smaller completable sets. Completed sets look visually satisfying.
- **Completed collections should feel special**: Visual reward for finishing a set (golden border, special effect, NPC reaction).

### The Home (building satisfaction)
- **Sanctuary appeal maximization** is the fun — Ark Nova puzzle of placement for max appeal
- **NPCs react to your sanctuary**: "Your freshwater section is beautiful!"
- **Social features needed**: Show off sanctuary to other players. Planned but not designed yet.

### The Progression (session hooks)
- **Daily hook**: World changes + daily and weekly challenges/rotations
- **Long-term goals**: YES — complete museum, beautiful sanctuary, all species, etc.
- **Mistakes are minor setbacks only** — cozy game, never devastating

### The World (immersion)
- **Seasons change the world visually**: Snow on fog, autumn colors, seasonal NPC dialogue
- **Weather affects gameplay**: Real-world weather → different spawns (rain = amphibians, night = different species)
- **NPCs remember you**: Track your progress, comment on it, relationship building

### Engagement Intensity Model (confirmed — OSRS-inspired)
- Like Old School RuneScape skill training — **multiple intensity levels** of play
- Everyone gets passive baseline, but active activities get more loot
- Not binary (passive/active) but a SPECTRUM:
  - **AFK/Passive**: Walk your commute, auto-collect commons. Lowest yield. Game runs in background.
  - **Light active**: Check phone, photograph rares, browse adjacent cells. Medium yield.
  - **High active**: Follow treasure maps, complete activities, do mini-tasks. Highest yield.
- "Small activities that get you more drops" — engagement-scaled rewards
- Active play → more species per cell (passive = 1, active = up to 3)
- Active play → bonus items from interaction (photographing gives extras)

### Treasure Maps / Quest System (confirmed — KEY MECHANIC)
- **Treasure maps ARE the quest system** — "this is one type of quest I was talking about"
- Directed exploration: maps mark a real-world area where a specific rare species can be found
- Creates purposeful trips, not just random wandering
- Makes rare species achievable without a pity system

**Treasure map sources (ALL confirmed):**
- NPC quest rewards (ranger heard rumors...)
- Random exploration drops (message in a bottle)
- Museum curator requests ("I need X for the Forest wing")
- Weekly challenge rewards
- Milestone unlocks (hit collection thresholds → maps to rarer species)

### Other New Mechanics
- **Daily/weekly challenges**: Rotating content that changes what's available
- **Weather-based spawns**: Real-world weather integration (rain = amphibians, etc.)
- **Adjacent cell previews**: See hints of what's in nearby fogged cells

## Sub-Collections / Set System (confirmed)
- **All set types work** — break the 32k species pool into completable sub-goals:
  - Habitat sets (all Forest species, all Freshwater, etc.)
  - Taxonomic class sets (all Mammals, all Birds, etc.)
  - Continent sets (all Asian, all African species)
  - Rarity sets (one of each IUCN status — the "rainbow set")
  - Themed/curated sets ("Big Cats", "Coral Reef Life", "Migratory Birds")
  - NPC request sets (curator asks for specific themed collections)
- **Sets can be DYNAMIC** — like Stardew community center bundles
  - NPCs present a bundle of specific species to collect → reward on completion
  - Bundles could rotate seasonally or per-NPC
  - Completing all bundles from an NPC → major unlock
- Completed sets look visually satisfying (golden border, special effect, NPC reaction)
- Completion unlocks rewards (new wing, treasure map, sanctuary cosmetic)

## Player Identity (confirmed)
- **Shifts by game area** — three roles that feel distinct:
  - **Map**: Explorer / Adventurer — discovering territory, fog of war, treasure maps
  - **Museum**: Researcher / Naturalist — documenting species, curating exhibits, science
  - **Home/Sanctuary**: Keeper / Caretaker — nurturing, arranging, building, maintaining
- Each tab can have its own tone, UX personality, and visual language

## Deferred from Find the Fun
- Session arc shape (not sure yet)
- Hardest decision in the game (not sure yet)
- Reasons NOT to collect (needs exploration)
- Social feature design (important but not designed yet)

## Research Findings
- Current code has no navigation between screens (map is a dead end)
- Discovery is passive (auto-collect on cell entry, 3s toast)
- Sanctuary exists but is just a grouped species list — no "maintenance" mechanic
- Journal is a filtered species catalog (Pokédex-style)
- 13 achievements exist with thresholds
- Caretaking is just a streak counter — no actual "care" actions
