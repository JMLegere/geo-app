# Game Loop

No traditional frame-based game loop. Event-driven pipeline triggered by GPS updates.

## Primary Pipeline: GPS → GameCoordinator → Render

```
GPS/Simulator (1 Hz)
  │
  ▼
gameCoordinatorProvider
  → maps LocationService.filteredLocationStream → core stream type
  → GameCoordinator._onRawGpsUpdate()
    ├─ stores rawGpsPosition + accuracy
    ├─ broadcasts to onRawGpsUpdate stream (sync)
    └─ checks GPS accuracy (real GPS only)
  │
  ▼
MapScreen subscribes to onRawGpsUpdate
  → _rubberBand.setTarget(lat, lon)
  │
  ▼
RubberBandController._onTick()          ← Ticker, 60 fps
  → interpolates display position toward target
  → speed = max(minSpeedMps, multiplier × distance)
  → snap when < 5m
  │
  ▼
_onDisplayPositionUpdate(lat, lon)      ← 60 fps
  ├─ markerPosition.value = (lat, lon)  ← ValueNotifier → PlayerMarkerLayer
  ├─ cameraController.onLocationUpdate  ← MapLibre moveCamera (instant)
  └─ gameCoordinator.updatePlayerPosition(lat, lon)
      │
      ▼
  GameCoordinator._processGameLogic()   ← ~10 Hz (every 6th frame)
      ├─ fogResolver.onLocationUpdate()
      └─ onPlayerLocationUpdate callback → LocationNotifier
```

## Secondary Pipelines

### Species Discovery (event-driven)
```
fogResolver.onVisitedCellAdded (sync stream)
  → DiscoveryService
    → dailySeedService.currentSeed (stale guard: pauses if >24h)
    → speciesService.getSpeciesForCell(cellId, habitats, continent, dailySeed)
    → deterministic roll (SHA-256 seeded by "${dailySeed}_${cellId}")
    → emit DiscoveryEvent (includes dailySeed) on onDiscovery stream
  → GameCoordinator._onDiscovery()
    → StatsService.rollIntrinsicAffix()
    → creates ItemInstance with UUID + dailySeed
    → onItemDiscovered callback
      → discoveryProvider.notifier.showDiscovery()
      → itemsProvider.notifier.addItem()
      → DiscoveryNotificationOverlay toast
```

### Daily Seed System (Phase 4 — IMPLEMENTED)

```
App startup
  → gameCoordinatorProvider._hydrateAndStart()
    → dailySeedService.fetchSeed()
      → SeedFetcher callback (Supabase RPC: ensure_daily_seed())
      → Returns today's seed string
      → Cached in-memory with 24h TTL (kDailySeedGraceHours)
    → On failure: falls back to 'offline_no_rotation' static seed
```

**Stale seed guard**: If `dailySeedService.isDiscoveryPaused` (seed older than 24h + no fallback), `DiscoveryService` skips encounter generation. Discoveries resume when seed refreshes.

**Offline behavior**: Without Supabase, seed is `kDailySeedOfflineFallback` = `'offline_no_rotation'`. Species don't rotate daily but encounters still work. When Supabase is configured, seeds rotate at midnight GMT.

### Design Target: Discovery System
> These describe the INTENDED design, not current implementation. See `game-design.md`.

- Rarity-scaled discovery reveals (LC = small toast → EX = full-screen ceremony)
- Auto-collect for common species (LC, NT), tap-to-photograph for rare (VU+)
- Inventory model: species go to Pack as stacked items, not binary collected flags
- Cell activities (forage, lure, survey, habitat care) for active players = more drops

### Achievement Evaluation (pull-based)
```
Game state change (species collected / cell explored / streak updated)
  → caller explicitly calls achievementProvider.notifier.checkAchievements()
  → builds AchievementContext (reads 4 providers: player, collection, restoration, species)
  → AchievementService.evaluate(context) → newly unlocked list
  → push to achievementNotificationProvider queue
  → AchievementNotificationOverlay toast
```

### Caretaking Streaks (on visit)
```
Cell visited → caretakingProvider.notifier.recordVisit()
  → reads playerProvider.notifier.setStreak(current, longest)
  → bidirectional sync (caretaking reads+writes player state)
```

**Streak rules:**
- First visit ever → streak = 1
- Same day visit → no change (no double-counting)
- Consecutive day (lastVisit = yesterday) → streak += 1
- Missed day (lastVisit < yesterday) → streak resets to 1, longestStreak preserved

## Tick Rates

| System | Rate | Why |
|--------|------|-----|
| GPS input | 1 Hz | Battery drain, accuracy filtering |
| Rubber-band interpolation | 60 fps | Smooth marker movement |
| Game logic (fog, state) | ~10 Hz | Throttled via frame % 6 |
| GeoJSON source updates | ~10 Hz | Tied to MapScreen _renderFrame (~10 Hz) |
| MapLibre camera moves | 60 fps | Tied to rubber-band |
| Achievement checks | On-demand | Pull-based, not periodic |
| Sync to Supabase | Manual | User-triggered from sync screen |

## Fog State Machine

States are **computed** per frame from position + history. Not stored, not a traditional state machine.

| State | Density | Condition | Visual |
|-------|---------|-----------|--------|
| Observed | 0.0 | Player is in this cell now | Fully clear |
| Hidden | 0.5 | Previously visited, not current | Semi-transparent fog |
| Concealed | 0.95 | Adjacent to player's current cell | Nearly opaque (barely visible) |
| Unexplored | 1.0 | Frontier or within 1000m detection radius | Fully opaque (behind base layer) |
| Undetected | 1.0 | Default — never interacted | Fully opaque |

**Fog never re-closes.** Once a cell is detected (any state != Undetected), it stays at least Unexplored permanently via `_everDetectedCellIds` set.

**Leaving a cell:** Observed → Hidden immediately. This is intentional — states are dynamic, not progressive.
