# Design Jam 2: Item Expansion & Economy

> Design jam session (2026-03-06). Expands the item model from 5 to 7 categories, adds fauna taxonomy, food/orb economy, climate zones, and lazy AI enrichment. All decisions confirmed by user unless marked TBD.

---

## Summary of Changes

| Aspect | Before (Design Jam 1) | After (Design Jam 2) |
|--------|----------------------|---------------------|
| Item categories | 5 (Fauna, Flora, Mineral, Fossil, Artifact) | 7 (+Food, +Orb) |
| Fauna taxonomy | Flat (just species + taxonomicClass string) | 3-tier: Type → Class → Species |
| Animal types | None | 5: Mammal, Bird, Fish, Reptile, Bug |
| Animal classes | None | ~35 (Carnivore, Songbird, Rodent, Crocodile, etc.) |
| Food | Not in game | 6 subtypes, obtained via exploration, fed to sanctuary animals |
| Orbs | Not in game | 3-dimensional currency (habitat × class × climate) |
| Climate | Not modeled | 4 zones (tropic, temperate, boreal, frigid) from real latitude |
| Species stats | Crowdsourced (first 50, triangle picker) | AI-canonical on first discovery |
| Species classification | N/A | AI-canonical on first discovery |
| Art | Crowdsourced | Still crowdsourced (unchanged) |
| Enrichment timing | N/A | Lazy per-species on first global discovery |
| Spawning filters | Habitat + continent + season | Habitat + continent + season + **climate** |

---

## New Item Categories

### Food (6 subtypes)

Food items are found during exploration and fed to sanctuary animals. Each animal class has food preferences — feeding the right food produces orbs.

| Food Type | Found in | Fed to (typical) |
|-----------|----------|-------------------|
| food-critter | Plains, forest | Carnivores, birds of prey |
| food-fish | Freshwater, saltwater | Sea mammals, water-breathers, some birds |
| food-fruit | Forest, plains | Herbivores, primates, some birds |
| food-grub | Forest, swamp | Reptiles, bugs, insectivore birds |
| food-nectar | Plains, forest | Bugs (bees, butterflies), some birds |
| food-veg | Plains, swamp | Herbivores, rodents |

**Food preference per species is AI-determined** on first discovery, then canonical. The AI picks from the 6 food types based on the species' real-world diet. Crowdsourcing for food preference was considered but deferred — AI is authoritative for factual classification.

**How food is obtained**: Drops from cells during exploration. The LootRoller includes food in its drop table, filtered by habitat (food-fish drops near water, food-fruit in forests, etc.). Activity type may also affect food drops (forage = more food).

### Orb (3 dimensions, ~46 types)

Orbs are the **primary game currency**. Produced by sanctuary animals when fed. Three dimensions:

| Dimension | Source | Count | Examples |
|-----------|--------|-------|---------|
| **Habitat** | Animal's habitat | 7 | orb-forest, orb-swamp, orb-saltwater, orb-freshwater, orb-mountain, orb-plains, orb-desert |
| **Class** | Animal's class | ~35 | orb-carnivore, orb-songbird, orb-rodent, orb-crocodile, orb-beetle |
| **Climate** | Animal's climate zone | 4 | orb-tropic, orb-temperate, orb-boreal, orb-frigid |

**Feeding a sanctuary animal produces 3 orbs**: one from each dimension. A tropical forest crocodile fed food-critter → orb-tropic + orb-forest + orb-crocodile.

**Orb spend mechanics**: TBD. Orbs are the primary game currency — spending options will be designed later. Possible uses: restoration, breeding catalysts, lure crafting, cosmetics, NPC shop purchases.

**Data model:**

```dart
class OrbDefinition extends ItemDefinition {
  final OrbDimension dimension;  // habitat, class, climate
  final String variant;          // "forest", "carnivore", "tropic"
}

enum OrbDimension { habitat, animalClass, climate }
```

Orbs are **not** AI-enriched. They're mechanically defined by their dimensions — no enrichment needed.

---

## Fauna Taxonomy

### 3-Tier Hierarchy

```
Fauna (ItemCategory)
 └─ Animal Type (5): Mammal, Fish, Bird, Reptile, Bug
     └─ Animal Class (~35): Carnivore, Songbird, Rodent, Crocodile...
         └─ Species (32k IUCN records): Red Fox, Blue Jay...
```

### Animal Types (5)

| Type | Icon | IUCN taxonomicClass mapping |
|------|------|-----------------------------|
| Mammal | 🐾 | Mammalia |
| Bird | 🪶 | Aves |
| Fish | 🐟 | Actinopterygii, Chondrichthyes, Cephalaspidomorphi, Myxini, Sarcopterygii |
| Reptile | 🦎 | Reptilia, Amphibia |
| Bug | 🐛 | Insecta, Arachnida, Gastropoda, Malacostraca, Chilopoda, Diplopoda |

**Type is deterministic** — derived from `taxonomicClass` via a lookup table. No AI needed. Computed on load.

### Animal Classes (~35)

The user's game-designed sub-classifications. Each type has multiple classes:

**Bird (7):** Bird of Prey, Game Bird, Nightbird, Parrot, Songbird, Waterfowl, Woodpecker

**Bug (9):** Bee, Beetle, Butterfly, Cicada, Dragonfly, Land Mollusk, Locust, Scorpion, Spider

**Fish (6):** Cartilaginous Fish, Cephalopod, Clams/Urchins & Crustaceans, Jawless Fish, Lobe-finned Fish, Ray-finned Fish

**Mammal (8):** Bat, Carnivore, Hare, Herbivore, Primate, Rodent, Sea Mammal, Shrew

**Reptile (5):** Amphibian, Crocodile, Lizard, Snake, Turtle

**Class is AI-determined** on first discovery. The AI maps from scientific name + taxonomicClass to one of the ~35 game classes. Canonical forever after.

### Data Model Changes

```dart
class FaunaDefinition extends ItemDefinition {
  final String taxonomicClass;       // existing: "Mammalia", "Aves", etc.
  final AnimalType? animalType;      // NEW: deterministic from taxonomicClass
  final String? animalClass;         // NEW: AI-enriched ("Carnivore", "Songbird")
  final String? foodPreference;      // NEW: AI-enriched ("food-critter", etc.)
  final Climate? climate;            // NEW: AI-enriched or inferred from range
}

enum AnimalType { mammal, bird, fish, reptile, bug }
enum Climate { tropic, temperate, boreal, frigid }
```

Fields are nullable because enrichment is lazy — species start with only IUCN data (`taxonomicClass`, `scientificName`, etc.). `animalType` can be computed immediately from `taxonomicClass`. `animalClass`, `foodPreference`, and `climate` arrive via AI on first discovery.

---

## Climate Zones

### 4 Zones from Real Latitude

| Climate | Latitude Range | Real-world regions |
|---------|---------------|-------------------|
| Tropic | 0°–23.5° | Amazon, SE Asia, Central Africa, Northern Australia |
| Temperate | 23.5°–55° | Most of US/Europe, eastern China, southern Australia |
| Boreal | 55°–66.5° | Canada, Scandinavia, Siberia |
| Frigid | 66.5°–90° | Arctic, Antarctic, high mountains |

**Player's climate zone = f(latitude)**. Simple `abs(lat)` check — no API needed.

**Climate as spawn filter**: Species have a climate attribute. The LootRoller filters species by the player's current climate zone. Tropical species only appear near the equator. Boreal species only at high latitudes. This is the "real geography driving gameplay" principle.

**Climate as orb dimension**: Animals produce a climate orb when fed, based on their native climate zone.

**Climate on species**: AI-enriched on first discovery, or potentially inferrable from IUCN continent data + latitude ranges of known habitats.

---

## Lazy AI Enrichment

### Trigger

When any item is discovered **for the first time globally** (no player has ever found this species/item before), a background AI enrichment job fires.

### Per-Category Enrichment

| Category | AI Output | Model |
|----------|-----------|-------|
| **Fauna** | animalClass, foodPreference, stats (brawn+wit+speed=90), watercolor art | Structured JSON + image gen |
| **Flora** | plantType, growth conditions, watercolor art | Structured JSON + image gen |
| **Mineral** | crystalSystem, hardness, formation, watercolor art | Structured JSON + image gen |
| **Fossil** | fossilType, geologicPeriod, formation, watercolor art | Structured JSON + image gen |
| **Artifact** | era, material, cultural context, watercolor art | Structured JSON + image gen |
| **Food** | No enrichment — food types are predefined | N/A |
| **Orb** | No enrichment — orb dimensions are mechanical | N/A |

### Example Prompt (Fauna)

```
You are a wildlife biologist. Given this species:
  Name: Red Fox (Vulpes vulpes)
  IUCN Class: Mammalia

Classify into EXACTLY this JSON format:
{
  "animalClass": "<one of: Bird of Prey, Game Bird, Nightbird, Parrot, Songbird, Waterfowl, Woodpecker, Bee, Beetle, Butterfly, Cicada, Dragonfly, Land Mollusk, Locust, Scorpion, Spider, Cartilaginous Fish, Cephalopod, Clams Urchins & Crustaceans, Jawless Fish, Lobe-finned Fish, Ray-finned Fish, Bat, Carnivore, Hare, Herbivore, Primate, Rodent, Sea Mammal, Shrew, Amphibian, Crocodile, Lizard, Snake, Turtle>",
  "foodPreference": "<one of: food-critter, food-fish, food-fruit, food-grub, food-nectar, food-veg>",
  "brawn": <int 0-90>,
  "wit": <int 0-90>,
  "speed": <int 0-90>
}

Stats MUST sum to exactly 90. Assign based on real-world characteristics of this species.
```

### Architecture

```
First global discovery of species X
    → Server checks: species_enrichment table has entry for X?
    → No → INSERT into enrichment_queue (species_id, status: pending)
    → Supabase Edge Function processes queue:
        1. Call LLM API (Groq/Gemini) for structured classification
        2. Call image gen API for watercolor art
        3. Store art in Supabase Storage
        4. UPDATE species_enrichment with results
        5. UPDATE enrichment_queue status → completed
    → On failure: exponential backoff, max 3 retries
    → Client polls/subscribes for enrichment completion
```

**Rate limiting**: Job queue with token bucket. AI calls are not blocking — gameplay continues while enrichment runs in background. Species works fine with just IUCN data; enrichment adds richness.

---

## Species Stats — AI Canonical

### Change from Design Jam 1

**Before:** First 50 players set stats via triangle picker (barycentric coordinates). Running median → canonical at 50th vote. Crowdsourcing was the mechanic.

**After:** AI generates stats on first discovery. Canonical immediately. No triangle picker. No running median. No crowdsourcing for stats.

**Rationale:** Simpler, faster to ship, factually grounded (AI knows cheetah = fast). Crowdsourcing can be re-added later as an override/adjustment mechanic if desired.

### What Survives from species-community-system.md

| Feature | Status |
|---------|--------|
| Triangle stat picker | **Removed for now** |
| Running median | **Removed for now** |
| First 50 mechanic (stats) | **Removed for now** |
| `needsStatPick` flag | **Removed for now** |
| Art crowdsourcing | **Unchanged** — still works as designed |
| Art voting (51% lock) | **Unchanged** |
| AI watercolor default | **Unchanged** — now part of enrichment pipeline |
| Badges (First Discovery, Pioneer, etc.) | **Unchanged** — still relevant |
| Species color (RGB from stats) | **Unchanged** — but derived from AI stats, not crowd stats |
| Proximity reward | **Removed for now** (no crowd stats = no accuracy comparison) |
| Species Card UI | **Unchanged** — layers, frames, badges all still apply |

### Instance Stats Model (Simplified)

| Instance # | Base stats source | Variance |
|-----------|------------------|----------|
| All | AI-canonical base | ±30% per-instance (SHA-256 deterministic) |

No special handling for first 50. All instances use the same AI base + variance.

---

## Updated Item Category Enum

```dart
enum ItemCategory {
  fauna,     // 32k IUCN species
  flora,     // plants, trees, fungi (TBD dataset)
  mineral,   // rocks, crystals, gems (TBD dataset)
  fossil,    // ancient remains (TBD dataset)
  artifact,  // human-made historical items (TBD dataset)
  food,      // 6 subtypes: critter, fish, fruit, grub, nectar, veg
  orb,       // 3-dimensional currency: habitat × class × climate
}
```

---

## Updated LootRoller Design

The LootRoller now needs to account for:
- 7 item categories (was 5)
- Climate as a filtering dimension (new)
- Food drops by habitat
- Orbs are NOT loot-rolled — they're produced by sanctuary feeding

### LootContext

```dart
class LootContext {
  final String cellId;
  final List<Habitat> habitats;    // from ESA land cover
  final Continent continent;
  final Climate climate;           // NEW: from player latitude
  final String dailySeed;
  final ActivityType activity;     // explore, forage, dig, survey
  final Season season;
}
```

### Activity → Eligible Categories

| Activity | Eligible drops |
|----------|---------------|
| explore | fauna, flora, food |
| forage | flora, food, mineral |
| dig | mineral, fossil, artifact |
| survey | fauna |

**Orbs are never loot drops** — only produced via sanctuary feeding.

### Climate Filtering

Species with a `climate` attribute are filtered by the player's climate zone. A tropical species won't drop in Norway. A boreal species won't drop in Thailand.

Species without climate data (pre-enrichment) are assumed to be climate-agnostic until enriched.

---

## Sanctuary Feeding Loop

```
1. Explore world → find animals + food
2. Place animals in sanctuary
3. Feed appropriate food type to animals
4. Fed animal produces 3 orbs:
   - 1 habitat orb (from animal's habitat)
   - 1 class orb (from animal's class)
   - 1 climate orb (from animal's climate)
5. Spend orbs on... TBD
```

This creates strategic collection incentive: you want diverse animals across all three dimensions to produce diverse orbs.

---

## Open Questions (From This Jam)

| Question | Status | Notes |
|----------|--------|-------|
| Orb spend mechanics | TBD | Primary currency, but what do you buy? Restoration? Breeding? Lures? Cosmetics? |
| Food preference per class vs per species | AI per species | AI determines per species, but class provides a strong default pattern |
| Can food be crafted/combined? | TBD | Or only found via exploration? |
| Orb production rate | TBD | How many feedings per day? Cooldown? |
| Do orb climate variants include all from file list? | TBD | File shows boreal, frigid, temperate, tropic — matches our 4 climate zones |
| Flora/Mineral/Fossil/Artifact base datasets | TBD | Fauna has 32k IUCN. Other categories need data sources. |
| Sanctuary grid mechanics | TBD | How animals are placed, fed, managed |
| Can animals be fed wrong food? | TBD | Reduced orbs? No orbs? Negative effect? |

---

## Impact on Existing Specs

| Spec | Impact |
|------|--------|
| `item-system-design.md` | Categories → 7, FaunaDefinition gains new fields |
| `species-community-system.md` | Stats section largely superseded (AI canonical). Art section unchanged. Badges unchanged. |
| `game-design.md` | Section 12 (Collectible Categories) needs update: 5 → 7 |
| `AGENTS.md` | Product Architecture section needs full update |
| `roadmap.md` | New project for item expansion + enrichment pipeline |
| `data-model.md` | New enums (AnimalType, Climate, OrbDimension), updated ItemCategory |
