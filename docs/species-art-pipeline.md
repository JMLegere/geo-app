# Species Art Pipeline

> Design doc for generating and displaying per-species art across all UI surfaces.

## Principles

1. **Finish what players own first.** The 438 already-enriched species get both assets before touching the remaining 32k. New discoveries get art inline during enrichment.
2. **Two calls per species, icons first.** Icon and illustration are different styles — can't derive one from the other. Icons ship first (grid transformation), illustrations second (card payoff).
3. **Non-blocking.** Art generation is background work. The app functions with emoji placeholders. Art appears when ready — no loading spinners gating gameplay.

---

## Assets Per Species

Each species needs **2 assets** from **2 separate generation calls**:

| Asset | Dimensions | Format | Style | Purpose |
|-------|-----------|--------|-------|---------|
| **Icon** | 96×96 px | WebP (transparent) | Pixel art chibi, chunky, transparent BG | Pack grid, discovery toast, sanctuary tile |
| **Illustration** | 512×512 px | WebP | Oil painting TCG card art, action-driven | Species card hero, sharing |

### Icon Style

Pixel art chibi sprite. 32×32 pixel art with chibi proportions: oversized head (50%+ of body), tiny stubby body, big round shiny eyes. Crisp visible pixels, no anti-aliasing, no smooth gradients. 4-6 colors from the animal's real palette. Front-facing, whole body visible, grounded at bottom. Keep only 1-2 most distinctive features. Transparent background.

### Illustration Style — TCG Card Art (Oil Painting)

Oil painting illustration following MTG/Pokémon TCG card art conventions:

**Pose & Composition:**
- Dramatic 3/4 view, slightly low angle to make the creature feel heroic
- Animal fills most of the frame — portrait, not landscape
- Action driven by `food_preference` (see Action Mapping below)
- Pose modifier from dominant stat (see Pose Modifiers below)
- Shallow depth of field, background atmospheric and painterly

**Technique:**
- Rich oil painting style — visible brushwork, bold color, strong value contrast
- Dramatic lighting with a clear light source
- Painterly realism, not photorealistic. Saturated but not garish

**Background:**
- Soft atmospheric habitat-appropriate scene, NOT competing with subject
- Shallow depth of field — background painterly and atmospheric
- Type-appropriate: forest species get dappled green light, saltwater gets ocean spray, desert gets warm amber haze

**Avoid:**
- Centered composition, flat lighting, white/blank backgrounds
- Cartoon style, digital airbrush look
- Text, labels, borders, frames
- Visible AI artifacts, inconsistent lighting

**Reference illustrators:** Rebecca Guay (ethereal drama), Terese Nielsen (luminous realism), Mitsuhiro Arita (creature portraiture).

### Action Mapping (from `food_preference`)

The illustration shows the animal **performing a characteristic action** driven by its diet:

| food_preference | Action |
|-----------------|--------|
| critter | Stalking or pouncing on small prey, predatory focus |
| fish | Diving into water or catching a fish, splash and motion |
| fruit | Reaching for or eating ripe fruit from a branch |
| grub | Pecking at the ground or probing bark for insects |
| nectar | Hovering at or perched on a flower, feeding |
| seed | Foraging on the ground among scattered seeds or grasses |
| veg | Grazing on fresh vegetation or browsing leafy branches |
| *(default)* | Resting calmly in its natural habitat |

### Pose Modifiers (from dominant stat)

Layered on top of the action to adjust the visual feel:

| Dominant Stat | Pose Modifier |
|---------------|---------------|
| Brawn (highest) | Powerful, muscular, dominant presence in the frame |
| Speed (highest) | Captured mid-motion, dynamic angle, sense of velocity |
| Wit (highest) | Alert eyes, watchful, cunning expression |
| Balanced | Natural and relaxed in the moment |

Habitat and climate also influence the illustration's ambient lighting and environment cues (see Prompt Templates below).

### Storage

```
Supabase Storage bucket: species-art
├── {definitionId}_icon.webp     # 96×96 chibi icon (transparent BG)
└── {definitionId}.webp          # 512×512 watercolor illustration
```

**URL patterns:**
- Icon: `{SUPABASE_URL}/storage/v1/object/public/species-art/{definitionId}_icon.webp`
- Illustration: `{SUPABASE_URL}/storage/v1/object/public/species-art/{definitionId}.webp`

**Public bucket** — no auth needed to read. Images are cache-friendly (immutable content, cacheable forever once generated).

---

## Species Card Modal

The detail view is a **centered floating card modal** — not a bottom sheet. One-sided (no flip). The card IS the reward for discovering a species.

### Layout (2:3 aspect ratio, scrollable below fold)

```
┌─────────────────────────────────┐
│  Red Fox               [EN] [★]│  ← Name plate (fixed)
│  Vulpes vulpes                  │
├─────────────────────────────────┤
│                                 │
│     Watercolor illustration     │  ← Art zone (fixed, ~55%)
│     on habitat-colored card     │     BoxFit.cover, vignette edges
│                                 │     Pose reflects dominant stat
│                                 │
├─────────────────────────────────┤
│  💪 ████████░░░  27             │  ← Stats (fixed)
│  ⚡ ██████░░░░░  18             │     RGB-derived colors
│  🧠 ████████████  45            │     Animated fill, staggered 80ms
├─────────────────────────────────┤
│ 🌲Forest · 🏯Asia ·            │  ← Identity strip (fixed)
│ ⚖️2.4kg · 🍖Critter            │     4 key items
├ ─ ─ ─ ─ scrollable ─ ─ ─ ─ ─ ─┤
│  🐾 Mammal · Carnivore         │  ← Extended metadata
│  🌡️ Temperate · ☀️ Year-round  │     Compact rows, scrollable
│  📍 Wild · Mar 15, 2026        │     Same style as identity strip
│  📦 Cell abc123                 │
└─────────────────────────────────┘
```

The card is a fixed 2:3 aspect ratio for name plate + art + stats + identity strip. Below the identity strip, a scrollable section contains extended metadata (animal type/class, climate, season, provenance, date, cell ID). The scroll region is inside the card — the card itself doesn't grow. A subtle fade or divider separates the fixed and scrollable zones.

### Habitat-Colored Card (MTG-style)

The card frame/background color is driven by the species' primary habitat — like MTG land colors define card identity.

| Habitat | Card Color | Reference |
|---------|-----------|-----------|
| Forest | Deep green | MTG Forest |
| Plains | Warm tan/wheat | MTG Plains |
| Freshwater | Teal/cyan | MTG Island (freshwater variant) |
| Saltwater | Deep blue | MTG Island |
| Swamp | Dark olive/murky green | MTG Swamp |
| Mountain | Slate grey/stone | MTG Mountain |
| Desert | Amber/sand | —  |

The habitat gradient from `HabitatColors` provides the card's surface tint. The art zone background, the name plate background, and the stats/identity strip backgrounds all draw from this palette at varying opacities.

**Multi-habitat species: marbling, not blending.** A species with Forest + Saltwater gets distinct green and blue veins/swirls — not a muddied teal. Each habitat's color stays identifiable. Implementation: `CustomPaint` with 2-3 layered Perlin noise channels, each tinted to a habitat color, composited with soft-light or overlay blend mode. The marble pattern is seeded by `definitionId` so each species gets a unique but deterministic pattern.

Single-habitat species get a clean solid gradient from their habitat palette.

This means you can identify a species' habitat(s) at a glance from the card color alone — forest cards are green, saltwater cards are blue, mountain cards are grey, and a forest/saltwater dual-habitat card has green and blue marble veins.

### Rarity Frame Progression

| Rarity | Frame Treatment |
|--------|----------------|
| LC (white) | 2px solid, neutral border |
| NT (green) | 2.5px solid green, subtle inner glow |
| VU (blue) | 3px double border (outer blue, inner lighter blue) |
| EN (gold) | 3px gold gradient edge (metallic shimmer) + outer glow |
| CR (purple) | 3.5px animated holographic shimmer (diagonal gradient sweep, 4s cycle) |
| EX (amber) | 4px animated prismatic border (existing `PrismaticBorder` widget) + floating particles |

### Card Presentation

- **Centered modal** with 60% dark scrim. `showGeneralDialog`, not bottom sheet.
- **Entrance:** Scale 0.85→1.0 with `easeOutBack` (450ms). Stat bars fill staggered after 200ms delay.
- **Dismiss:** Tap scrim, swipe card down, or back button.
- **Responsive:** 85% screen width on phone, 55% on tablet, 35% on web. Max 440px wide.

### Identity Strip (4 items)

| Item | Source | Format |
|------|--------|--------|
| Habitat | IUCN/enrichment | `🌲Forest` |
| Continent | IUCN | `🏯Asia` |
| Weight | Instance-level (deterministic from SHA-256) | `⚖️2.4kg` |
| Diet | Enrichment (foodPreference) | `🍖Critter` |

Weight is instance-specific — two Red Foxes can have different weights. This makes each card feel unique even for the same species.

### Stat Bars — RGB Color Identity

Colors derived from stats, not hardcoded:

| Stat | Color Formula |
|------|--------------|
| Brawn | `Color.fromRGBO(brawn/90*255, 60, 60, 1.0)` |
| Speed | `Color.fromRGBO(60, speed/90*255, 60, 1.0)` |
| Wit | `Color.fromRGBO(60, 60, wit/90*255, 1.0)` |

Bars are 6px tall, pill-shaped, with subtle inner glow. Emoji icon left, number right. No text labels. Animated fill on card entrance (350ms, staggered 80ms apart).

### Fallback States

**Art loading (URL exists, image fetching):**
- Habitat-colored card surface visible
- Animal class emoji (48px) centered in art zone
- Shimmer overlay sweeping L→R

**No enrichment yet:**
- Habitat-colored card surface
- Generic category emoji (🐾 for fauna)
- "Awaiting study" muted text
- No stat bars (stats unknown)

**No art URL (enriched but art not generated):**
- Habitat-colored card surface
- Animal class emoji (48px) centered
- Stats and identity strip show normally

---

## UI Surfaces Summary

| Surface | File | Display Size | Asset | Fallback |
|---------|------|-------------|-------|----------|
| Pack grid | `item_slot_widget.dart` | ~64–80px | `_icon.webp` | Emoji via `GameIcons.fauna()` |
| Species card (NEW) | `species_card_modal.dart` | ~300–350px | `.webp` | Habitat card + emoji |
| Discovery toast | `discovery_notification.dart` | 44×44px | `_icon.webp` | Emoji |
| Sanctuary tile | `sanctuary_species_tile.dart` | 34–40px | `_icon.webp` | Emoji |
| Map cell icons | `map_screen.dart` | 64×64px | No change | Emoji → PNG |

---

## Image Loading Widget

Shared `SpeciesArtImage` widget used by all surfaces:

```dart
class SpeciesArtImage extends StatefulWidget {
  final String? artUrl;       // icon_url or art_url from enrichment
  final String fallbackEmoji; // from GameIcons.fauna()
  final double size;
  final BorderRadius? borderRadius;
  final bool animate;         // enable 2-frame idle hop (default false)
  final int animationSeed;    // phase-offset so sprites don't hop in sync
}
```

**Behavior:**
- `artUrl` non-null → `Image.network(url)` with fade-in
- `artUrl` null → emoji Text widget (current behavior)
- Network error → emoji fallback
- Loading → emoji (no spinner — instant fallback, art replaces when cached)

**Idle animation** (when `animate: true` and `artUrl` is non-null):
- 2-frame hop: frame 1 = resting position, frame 2 = 2px up (snaps, no tween)
- Phase offset derived from `animationSeed.hashCode` — each sprite hops at a different point in the cycle
- Duration: `Durations.spriteIdle` (1800ms) — half resting, half hopped
- Wrapped in `RepaintBoundary` to isolate repaints

Flutter's default image cache (1000 images, 100MB) is sufficient. Icons are ~5–15KB, illustrations ~30–80KB. 438 species × 50KB = ~22MB.

---

## Generation Pipeline

### Priority Order

Icons first, illustrations second. Icons transform the grid immediately. Illustrations are the card payoff.

### Edge Function: `generate-species-art`

```
Input: {
  definition_id, scientific_name, common_name,
  asset_type: "icon" | "illustration",
  // For illustrations only:
  habitat?, brawn?, wit?, speed?, climate?
}
Output: { url }

Steps:
1. Check if asset already exists in Storage → return URL
2. Build asset-specific prompt (incorporating identity for illustrations)
3. Call image generation API
4. Upload to species-art/{definitionId}[_icon].webp
5. UPDATE species_enrichment SET icon_url|art_url = {url}
6. Return URL
```

**Batch variant:** `generate-species-art-batch` — up to 5 species + asset_type, sequential processing.

### Backfill Strategy (438 enriched species)

```
Pass 1: Icons for all 438       → grid goes from emoji to cute sprites
Pass 2: Illustrations for all 438 → species cards get watercolor art
```

**Backfill script per pass:**
1. Query species missing the target asset
2. Chunk into batches of 5
3. Call batch function per chunk, rate-limited (1 batch/minute)
4. Log progress `{completed}/{total}`

**At 500 images/day free tier:** ~2 days total (1 day icons, 1 day illustrations).

### Inline Art for New Discoveries

After `enrich-species` classification succeeds:
1. Fire icon generation (high priority)
2. Fire illustration generation (lower priority)
3. Both best-effort — enrichment succeeds even if art fails
4. Failed art retried later via `generate-species-art`

### Provider Selection

| Provider | Model | Free Tier | Quality | Speed |
|----------|-------|-----------|---------|-------|
| **Google Gemini** | Imagen 3 | 500/day | High | ~5s |
| **Stability AI** | SDXL / SD3 | Limited | High | ~3-8s |
| **Replicate** | Various | ~$0.003/img | Varies | ~5-15s |

**Recommendation:** Gemini Imagen 3. Free tier covers backfill in ~2 days. New discoveries (~5-20/day) well within limits.

### Art Pillars

Three visual pillars define EarthNova's art identity:

- **MTG/Pokemon TCG** → dramatic composition, creature-as-hero, heroic low angle
- **Action-driven** → animals performing characteristic behaviors based on diet, not static poses
- **Oil painting** → visible brushwork, bold color, strong value contrast, painterly realism

### Prompt Templates

**Icon prompt:**
```
Pixel art chibi of a {name} ({scientific}).
32×32 sprite. Chibi proportions: oversized head (50%+ of body),
tiny stubby body, big round shiny eyes. Cute and chunky.

Pixel art style: crisp visible pixels, no anti-aliasing, no smooth
gradients. Hard pixel edges. 4-6 colors from the animal's real
palette. Front-facing, whole body visible, grounded at bottom.

Must read as "{name}" at a glance — keep the 1-2 most
distinctive features (color pattern, ears, beak, horns, etc)
and drop everything else.

Transparent background. No ground, no shadow, no effects.
Output as PNG with transparency.
```

**Illustration prompt:**
```
Oil painting illustration of a {name} ({scientific}) in the style of
classic Magic: The Gathering and Pokémon TCG card art.

The animal is {action}. {pose_modifier}.
Setting: {habitat_atmosphere}. {climate_lighting}.

Composition: Dramatic 3/4 view, slightly low angle to make the creature
feel heroic. The animal fills most of the frame — this is a portrait,
not a landscape. Shallow depth of field, background atmospheric and
painterly.

Technique: Rich oil painting style — visible brushwork, bold color,
strong value contrast, dramatic lighting with a clear light source.
Painterly realism, not photorealistic. Saturated but not garish.
Think Rebecca Guay, Terese Nielsen, Mitsuhiro Arita.

Avoid: Centered composition, flat lighting, white/blank backgrounds,
cartoon style, digital airbrush look, text, labels, borders, frames.
```

Note: `{action}` is derived from `food_preference` (see Action Mapping above). `{pose_modifier}` is derived from the dominant stat (see Pose Modifiers above). Dimension constraints (96×96, 512×512) are controlled via API parameters, not prompt text.

### Habitat Atmosphere (from `habitats_json` first entry)

| Habitat | Atmosphere |
|---------|-----------|
| forest | Dappled green light filtering through a forest canopy |
| plains | Open golden grassland with warm horizon light |
| freshwater | Misty riverbank with soft teal reflections |
| saltwater | Coastal scene with ocean spray and deep blue atmosphere |
| swamp | Lush wetland with filtered olive-green light |
| mountain | Rocky alpine scene with cool slate-grey mist |
| desert | Warm amber haze over dry sandy terrain |
| *(default)* | Soft natural outdoor setting |

### Climate Lighting

| Climate | Lighting |
|---------|---------|
| tropic | Warm golden tropical light, lush greens |
| temperate | Soft natural daylight, gentle warmth |
| boreal | Cool crisp northern light, muted tones |
| frigid | Cold blue-white arctic light, stark contrast |

**Prompt tuning:** First batch of ~10 species should be manually reviewed before running the full backfill. Expect 2-3 iterations on wording.

---

## Schema Changes

### Supabase

Add `icon_url` column to `species_enrichment`:

```sql
ALTER TABLE species_enrichment ADD COLUMN icon_url text;
```

`art_url` column already exists.

### Local SQLite

Add `iconUrl` column to `LocalSpeciesEnrichmentTable`. Requires Drift schema bump + migration.

### New Supabase Storage Bucket

```sql
INSERT INTO storage.buckets (id, name, public) VALUES ('species-art', 'species-art', true);
```

---

## Card Widget Files

```
lib/features/pack/widgets/
├── species_card_modal.dart         # showSpeciesCardModal() + dialog wrapper
├── species_card.dart               # Main card widget (name + art + stats + strip)
├── species_card_art_zone.dart      # Art + habitat-colored background + vignette
├── species_card_stats.dart         # Animated RGB stat bars
├── species_card_rarity_frame.dart  # Rarity-driven border (LC→EX progression)
└── item_detail_sheet.dart          # Kept as legacy fallback
```

---

## Execution Order

| Step | What | Depends On | Effort |
|------|------|------------|--------|
| **A1** | Supabase Storage bucket + `icon_url` column | Nothing | 15 min |
| **A2** | `generate-species-art` Edge Function | A1 | 2-3 hrs |
| **A3** | Backfill icons (438 species) | A2 | ~1 day (automated) |
| **A4** | Backfill illustrations (438 species) | A2 | ~1 day (automated) |
| **A'** | Add art generation to `enrich-species` inline | A2 | 30 min |
| **B** | `SpeciesArtImage` widget + `iconUrl` in Drift/model | A3 | 1-2 hrs |
| **C1** | Wire icons into pack grid, toast, sanctuary | B | 1-2 hrs |
| **C2** | Build species card modal (replaces detail sheet) | B, A4 | 3-5 hrs |
| **E** | RGB stat colors + badge system | C2 | 2-3 hrs |

**Critical path:** A1 → A2 → A3 → B → C1 (icons on grid). Card modal (C2) can start in parallel once illustrations exist (A4).

---

## Monitoring

- **Backfill progress:** `SELECT count(*) FILTER (WHERE icon_url IS NOT NULL) as icons, count(*) FILTER (WHERE art_url IS NOT NULL) as illustrations, count(*) as total FROM species_enrichment`
- **Failed generations:** Edge Function logs
- **Client:** `ObservabilityBuffer.event('art_loaded', { definition_id, type: 'icon'|'illustration', source: 'network'|'cache'|'fallback' })`

---

## Resolved Questions

1. **Image generation API** — `GEMINI_API_KEY` is configured in Supabase secrets. Using Gemini Imagen 3.
2. **Multi-habitat card color** — Marbling effect with per-habitat color channels, seeded by `definitionId`.
3. **Extra metadata** — Scrollable section below the identity strip inside the card. No flip/back face needed.

## Open Questions

1. **Art style iteration** — First 10 species need manual review before full backfill. Prompt wording will need 2-3 tuning passes.
