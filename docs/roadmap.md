# Roadmap

Nested hierarchy of all planned work for EarthNova. Derived from `game-design.md`, `AGENTS.md`, and technical docs. Design is directional — this roadmap evolves through building.

> Status key: **Done** = shipped, **In Progress** = active, **Planned** = designed but not started, **Future** = confirmed direction but not designed, **Deferred** = explicitly not ready to plan

---

## Initiative 1: Core Navigation & App Shell — Done

4-tab app shell shipped. Map | Home | Town | Pack with IndexedStack keep-alive, tab persistence, web MapVisibility.

### Project 1.1: Tab Navigation System — Done
- [x] Implement 4-tab bottom bar scaffold (Map | Home | Town | Pack)
- [x] Route between tabs with state preservation (IndexedStack keep-alive)
- [ ] Add gear icon → profile/settings screen (deferred to v2)
- [x] Persist selected tab across app restarts (SharedPreferences)

### Project 1.2: Pack Tab (Field Pack) — In Progress
Reconceptualize Journal from filtered catalog → inventory-first management hub.
- [x] Rename Journal → Pack throughout codebase
- [ ] Redesign Pack as inventory grid (stacked items: "Mallard ×3")
- [ ] Add "Donate to Museum" action per species
- [ ] Add "Place in Sanctuary" action per species
- [ ] Add "Release" action (return to wild, feel-good animation)
- [ ] Bidirectional placement: Pack → Museum/Sanctuary AND Museum/Sanctuary → "Fill from inventory"

### Project 1.3: Home Tab (Sanctuary Hub) — Done
Current sanctuary screen becomes Home tab entry point.
- [x] Wire current sanctuary screen into Home tab
- [x] Achievement access via trophy icon in SanctuaryScreen AppBar

### Project 1.4: Town Tab (NPC Hub) — In Progress
New tab showing discovered NPCs.
- [x] Create empty Town tab scaffold (themed "Coming Soon" placeholder)
- [ ] Show list of discovered NPCs with portraits/names
- [ ] Tap NPC → conversation/interaction screen

---

## Initiative 2: Inventory Model Overhaul

**KEY SHIFT**: Species as inventory items with quantity, not binary collected flags. Touches persistence, state, and every downstream consumer.

### Project 2.1: Database Schema Migration — Planned
- [ ] Migrate `LocalCollectedSpeciesTable` from binary flag to quantity-tracked model
- [ ] Add `quantity` column (or individual instance tracking)
- [ ] Migrate `CollectionRepository` to support add/remove/count operations
- [ ] Write data migration for existing collected species (each becomes quantity=1)

### Project 2.2: Inventory State Management — Planned
- [ ] Create `InventoryNotifier` (replaces collection notifier for inventory operations)
- [ ] Support stacking: group by species ID, show count
- [ ] Support consumption: donate (permanent remove), place (flexible remove), release (permanent remove)
- [ ] Update `collectionProvider` downstream consumers

### Project 2.3: Supabase Sync Updates — Planned
- [ ] Update Supabase schema for inventory model
- [ ] Update `SupabasePersistence` upsert methods for quantity tracking
- [ ] Ensure offline-first: SQLite remains source of truth

---

## Initiative 3: Discovery System Upgrade

Evolve from auto-collect toast → TCG-style rarity-scaled reveals.

### Project 3.1: Rarity-Scaled Discovery Reveals — Planned
- [ ] LC (Common): Quick small toast (refine current)
- [ ] NT (Uncommon): Slightly fancier toast with species art
- [ ] VU (Rare): Splash popup with watercolour art reveal + tap to dismiss/detail
- [ ] EN (Ultra Rare): Dramatic splash with glow, pause, art reveal
- [ ] CR (Legendary): Full-screen reveal with particles, sound, ceremony
- [ ] EX (Chase/Secret Rare): Maximum ceremony — holy grail moment
- [ ] Auto-dismiss after ~8s OR tap opens full species detail

### Project 3.2: Discovery Agency — Planned
- [ ] Common species (LC, NT): Auto-collect on proximity (keep current behavior)
- [ ] Rare species (VU+): Require tap-to-photograph interaction
- [ ] Photography UI: camera frame overlay, shutter animation
- [ ] Species goes to Pack inventory after photograph/auto-collect

### Project 3.3: Daily World Seed — Planned
- [ ] Implement midnight GMT seed rotation (seed = date + cellId, client-side)
- [ ] First visit: permanent species seeded by cell ID (existing behavior)
- [ ] Repeat visits: daily rotation pool from world seed
- [ ] Show "daily species" indicator on map cells
- [ ] Respawn cycle: cells offer new species each day

### Project 3.4: Adjacent Cell Previews — Planned
- [ ] Show silhouettes/glows of species in adjacent fogged cells
- [ ] "One more cell" pull: highlight adjacent cells with hints
- [ ] Animate hint elements to create movement motivation

---

## Initiative 4: Museum System

New NPC-run exhibit facility with habitat wings and permanent donations.

### Project 4.1: Museum Data Model — Planned
- [ ] Create Museum model (wings, donation slots, unlock state)
- [ ] 7 fauna wings: Forest, Plains, Freshwater, Saltwater, Swamp, Mountain, Desert
- [ ] 3 future non-fauna wings: Botanical Garden, Mineral Gallery, Fossil Hall
- [ ] Wing unlock logic (donation milestone thresholds)
- [ ] Map each species to eligible wings via habitat data

### Project 4.2: Museum UI — Planned
- [ ] Museum entry screen (wing selector, unlock progress)
- [ ] Wing detail screen: grid display with filled/empty slots
- [ ] Silhouettes of undiscovered species (know what you're hunting for)
- [ ] Donation flow: select from Pack → confirm permanent donation → slot fills
- [ ] "Are you sure?" confirmation (donations are permanent, like Stardew)

### Project 4.3: Museum NPC (Curator) — Planned
- [ ] Create museum curator NPC (Blathers-like character)
- [ ] Curator dialogue: reacts to donations, requests specific species
- [ ] Curator requests: "I need X for the Forest wing" → generates treasure map

---

## Initiative 5: Sanctuary Rebuild

Evolve from grouped species list → grid-based zoo builder with appeal system.

### Project 5.1: Sanctuary Grid System — Planned
- [ ] Implement tile grid (Stardew farm style)
- [ ] Place enclosures on discrete tiles
- [ ] Species placement within enclosures (consume from inventory, flexible)
- [ ] Pick up and rearrange freely
- [ ] Path/decoration placement

### Project 5.2: Appeal System — Future
Ark Nova-inspired placement optimization puzzle.
- [ ] Define appeal scoring (animal synergies, enclosure types, placement bonuses)
- [ ] Visual feedback: appeal score display, NPC reactions
- [ ] Appeal milestones → unlocks

---

## Initiative 6: NPC System

Full characters with personality, discovered via exploration.

### Project 6.1: NPC Framework — Planned
- [ ] NPC data model (name, personality, dialogue trees, location, portrait)
- [ ] NPC spawn system: milestone-based + location-based triggers
- [ ] NPC discovery event (exploration loop: finding NPCs is a discovery moment)
- [ ] NPC memory: track player progress, reference it in dialogue

### Project 6.2: NPC Interactions — Planned
- [ ] Conversation UI (dialogue boxes with portrait, choices)
- [ ] Museum curator: requests species, reacts to donations
- [ ] Quest givers: issue treasure maps, NPC bundles
- [ ] NPCs react to sanctuary state ("Your freshwater section is beautiful!")

### Project 6.3: NPC Bundles — Planned
Stardew community center-style themed collections.
- [ ] Bundle data model: NPC → list of required species → reward
- [ ] Bundle UI: show progress, remaining species, reward preview
- [ ] Bundle completion: ceremony, NPC reaction, reward grant
- [ ] Bundles rotate seasonally or per-NPC (dynamic)

---

## Initiative 7: Quest System

Treasure maps as the primary quest mechanic for directed exploration.

### Project 7.1: Treasure Map System — Planned
- [ ] Treasure map data model (target location, target species, source, expiry)
- [ ] Map UI: show treasure map markers on game map
- [ ] Discovery flow: arrive at location → find rare species → complete map
- [ ] Treasure map inventory in Pack

### Project 7.2: Treasure Map Sources — Planned
- [ ] NPC quest rewards (ranger heard rumors...)
- [ ] Random exploration drops (message in a bottle)
- [ ] Museum curator requests ("I need X for the Forest wing")
- [ ] Weekly challenge rewards
- [ ] Milestone unlocks (collection thresholds → maps to rarer species)

### Project 7.3: Daily/Weekly Challenges — Planned
- [ ] Challenge data model (objective, reward, duration, rotation)
- [ ] Daily challenge: rotates at midnight GMT with world seed
- [ ] Weekly challenge: longer-form goals
- [ ] Challenge UI: show active challenges, progress, rewards

---

## Initiative 8: Engagement Intensity & Cell Activities

OSRS-inspired activity spectrum — passive to high-active play styles.

### Project 8.1: Cell Activity Framework — Future
- [ ] Activity data model (type, cell, duration, rewards)
- [ ] Per-cell activity menu (tap cell → choose activity)
- [ ] Activity types: Photograph, Forage/dig, Set lure/bait, Field survey, Habitat care
- [ ] Active play → more species per cell (passive=1, active=up to 3)

### Project 8.2: Photography Mechanic — Planned
- [ ] Camera overlay UI for VU+ species
- [ ] Photograph action → species captured to Pack
- [ ] Bonus drops from photographing (active play reward)

### Project 8.3: Lure/Bait System — Future
- [ ] Place attractant in cell, come back later to collect (OSRS birdhouses pattern)
- [ ] Timer-based: set and return

### Project 8.4: Field Survey — Future
- [ ] Quick species ID challenge ("Is this a Mallard or Teal?")
- [ ] Correct answer = bonus drops
- [ ] Teaches real species identification

---

## Initiative 9: Sub-Collections & Sets

Break 32k species pool into completable sub-goals.

### Project 9.1: Set System Framework — Planned
- [ ] Set data model (type, species list, completion state, reward)
- [ ] Set types: habitat, taxonomic class, continent, rarity, themed, NPC bundle
- [ ] Set completion detection and reward grant
- [ ] Visual reward: golden border, special effect, NPC reaction

### Project 9.2: Set UI — Planned
- [ ] Set browser: view all available sets, progress per set
- [ ] Set detail: show species in set (found/missing), completion percentage
- [ ] Completion ceremony per set

---

## Initiative 10: World Systems

Seasonal visuals, weather-based spawns, world immersion.

### Project 10.1: Seasonal Visuals — Future
- [ ] Snow on fog in winter, autumn colors in fall
- [ ] Seasonal NPC dialogue changes
- [ ] Seasonal map tile overlays

### Project 10.2: Weather-Based Spawns — Future
- [ ] Real-world weather API integration
- [ ] Weather → spawn modifiers (rain = amphibians, night = nocturnal species)
- [ ] Weather indicator on map UI

---

## Initiative 11: Visual & Art Direction

Watercolour art pipeline, species illustrations, UI polish.

### Project 11.1: Design System — Done
- [x] Design tokens (spacing, radii, shadows, durations, curves, blurs, opacities, component sizes)
- [x] EarthNovaTheme ThemeExtension with dark/light factories + BuildContext extension
- [x] Shared components: FrostedGlassContainer, RarityBadge, HabitatGradient
- [x] Refactor 8 widgets to use design system (eliminate duplicate rarity/habitat helpers)
- [x] 23 new tests (design_tokens_test + earth_nova_theme_test)

### Project 11.2: Species Illustrations — Future
- [ ] AI-generated watercolour illustrations for species (MVP pipeline)
- [ ] Illustration display in discovery splash, Pack, Museum, Sanctuary
- [ ] Future: hand-drawn or commissioned replacements

### Project 11.3: UI Polish — Future
- [ ] iOS-clean + PuffPals-cute aesthetic pass
- [ ] Fog reveal juice: satisfying dissolve, sound, color change
- [ ] Particle effects at fog edges
- [ ] Discovery ceremony animations (per rarity tier)

### Project 11.4: Sound & Music — Deferred
- [ ] Not designed yet — deferred by designer

---

## Initiative 12: Additional Collectible Categories

Expand beyond fauna to 4 top-level collectible types.

### Project 12.1: Plants / Flora — Future
- [ ] Dataset sourcing (trees, flowers, fungi)
- [ ] Discovery mechanics (same auto-collect/photograph model?)
- [ ] Botanical Garden museum wing

### Project 12.2: Minerals / Gems — Future
- [ ] Dataset sourcing (rocks, crystals)
- [ ] Discovery mechanics (forage/dig activity?)
- [ ] Mineral Gallery museum wing

### Project 12.3: Artifacts / Fossils — Future
- [ ] Dataset sourcing (ancient items, bones)
- [ ] Discovery mechanics
- [ ] Fossil Hall museum wing

---

## Initiative 13: Infrastructure & Technical Foundations

Backend, sync, platform, DevOps work that enables all other initiatives.

### Project 13.1: Map & Fog Polish — In Progress
- [x] Fix player marker visibility on load (broadcast stream race)
- [x] Fix concealed cell visual layer (pre-rendered mid-fog)
- [x] 3-layer fog architecture (base, mid, cell borders)
- [x] Rubber-band smooth marker movement
- [x] CSS injection for web platform map visibility (TabShell ↔ MapVisibility integration)
- [ ] Real tile provider (MBTiles or Mapbox API)
- [ ] Fog reveal animations (dissolve/fade, not instant)

### Project 13.2: CI/CD — In Progress
- [x] Fix CI config (replaced stale Unity config with Flutter)
- [x] Automated `flutter test` + `flutter analyze` on push/PR to main
- [ ] Automated web build + deploy to Railway

### Project 13.3: Real-Time Supabase Sync — Future
- [ ] Replace manual sync with real-time subscriptions
- [ ] Conflict resolution for offline-first + cloud sync
- [ ] Sync status indicator in UI

### Project 13.4: Analytics & Engagement — Future
- [ ] Event tracking (species collected, cells visited, sessions, retention)
- [ ] Engagement metrics dashboard

### Project 13.5: Platform Expansion — Future
- [ ] iOS build verification and TestFlight
- [ ] Android build verification and Play Store
- [ ] Push notifications

### Project 13.6: Authentication & Account Upgrade — In Progress
- [x] Anonymous auto-login on app launch (Supabase anonymous auth)
- [x] Session persistence across reloads (JWT in local storage)
- [x] isAnonymous field on UserProfile model
- [x] upgradeWithEmail() and linkOAuthIdentity() on AuthService
- [x] 5-species upgrade prompt trigger
- [x] Save-progress banner on Home/Pack tabs
- [x] Upgrade bottom sheet (email + Google + Apple options)
- [x] Settings screen with profile and sign-out
- [x] Destructive sign-out warning for anonymous users
- [x] Supabase/OAuth prerequisites documented
- [x] End-to-end upgrade flow wiring + integration tests
- [ ] Google OAuth external setup (manual, documented)
- [ ] Apple OAuth external setup (manual, documented)
- [ ] Email verification flow (v2)
- [ ] Account deletion (v2)

---

## Initiative 14: Social & Multiplayer

Community features for sharing and interaction.

### Project 14.1: Social Features — Deferred
- [ ] Show off sanctuary to other players
- [ ] Share rare finds (screenshot-worthy moments)
- [ ] Leaderboards
- [ ] Trading

### Project 14.2: Multiplayer — Deferred
- [ ] Not designed — explicitly deferred

---

## Initiative 15: Monetization

### Project 15.1: Business Model — Deferred
- [ ] Not designed — explicitly deferred by designer ("too early")

---

## Mechanics Under Review

| Mechanic | Current State | Status |
|----------|--------------|--------|
| Restoration | 3 unique species = restored cell | **Tentative** — designer questions value, may rework |
| Economy/Shops | Not designed | **Deferred** |
| Session arc shape | Not defined | **Deferred** |
| Reasons NOT to collect | Not explored | **Deferred** |
| Camera/AI identification | Not started | **Future** |

---

## Technical Roadmap

Architecture evolution required to support the product roadmap. See [current-architecture.md](current-architecture.md) and [ideal-architecture.md](ideal-architecture.md) for detailed analysis.

### TR-1: Inventory Model Migration (blocks: Museum, Pack redesign, NPC bundles)
Current: binary `CollectedSpecies` (collected or not). Target: quantity-tracked inventory items.
- Schema migration (add quantity tracking or instance-based model)
- Repository API changes (add/remove/count instead of toggle)
- Provider rewiring (collectionProvider consumers → inventoryProvider)
- Data migration for existing users (each collected species → quantity=1)

### TR-2: Event-Sourced State Persistence (blocks: reliable sync, undo, replay)
Current: in-memory Riverpod notifiers with manual DB writes. State and persistence are decoupled — easy to lose data.
- Define domain events (SpeciesCollected, CellVisited, StreakUpdated, etc.)
- Event store (append-only SQLite table or dedicated event log)
- Notifiers rebuild from event stream, not ad-hoc state
- Supabase sync becomes event replication, not row-level upsert

### TR-3: Map Feature Decomposition (blocks: maintainability at scale)
Current: `map/` is a "god feature" (25 files) that orchestrates fog, discovery, location, biome, seasonal, camera, GeoJSON rendering.
- Extract map orchestration into a dedicated game loop service
- Move discovery subscription out of map_screen into a standalone coordinator
- Separate rendering concerns (GeoJSON layers) from game logic (fog transitions)

### TR-4: Service Locator / DI Cleanup (blocks: testability, modularity)
Current: services are created inline in notifiers or via `Provider<T>`. No formal DI.
- Evaluate whether Riverpod `Provider<T>` is sufficient or if a lightweight DI container is needed
- Ensure all services are injectable and mockable for integration testing
- Remove any remaining tight coupling between notifiers and concrete implementations

### TR-5: Species Data Pipeline (blocks: daily seed, categories expansion, performance)
Current: 6 MB monolithic JSON asset loaded at startup into memory.
- Lazy loading or pagination for species queries
- Index by habitat, continent, rarity for efficient loot table lookups
- Daily seed integration (cell × date → deterministic species pool)
- Extensibility for non-fauna categories (plants, minerals, fossils)

### TR-6: Sync Architecture (blocks: multi-device, real-time features)
Current: write-through to Supabase (no queue, no conflict resolution, manual trigger).
- Offline queue with retry for unreliable connections
- Conflict resolution strategy (last-write-wins vs merge)
- Real-time subscriptions for multi-device sync
- Sync status observability (what's pending, what failed)

---

## Priority Guidance

Based on design jam emphasis and dependency analysis:

| Priority | Initiatives | Rationale |
|----------|------------|-----------|
| **P0 — Unblocks everything** | ~~1 (Navigation)~~, 2 (Inventory) | ~~Tab shell~~ **shipped**. Inventory model is the remaining prerequisite for Museum, Pack, NPC, and quest systems |
| **P1 — Core game loop** | 3 (Discovery), 4 (Museum), 7 (Quests) | These define the collect→manage→place loop that IS the game |
| **P2 — Depth & retention** | 5 (Sanctuary), 6 (NPCs), 9 (Sets) | Add progression depth, social layer, completionist goals |
| **P3 — Engagement breadth** | 8 (Activities), 10 (World), 11 (Visual) | Polish, variety, immersion — make the world feel alive |
| **P1 — Infra (ongoing)** | 13 (Infrastructure) | Auth upgrade shipped (P13.6); CI shipped (P13.2); map polish in progress; deploy automation + sync/analytics remain |
| **P4 — Expansion** | 12 (Collectibles), 14 (Social), 15 (Monetization) | New content types, community, business model |
