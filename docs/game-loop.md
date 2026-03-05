# Game Loop

No traditional frame-based game loop. Event-driven pipeline triggered by GPS updates.

## Primary Pipeline: GPS → Render

```
GPS/Simulator (1 Hz)
  │
  ▼
_onLocationUpdate()
  → _rubberBand.setTarget(lat, lon)    ← stores target only
  │
  ▼
RubberBandController._onTick()          ← Ticker, 60 fps
  → interpolates display position toward target
  → speed = max(minSpeedMps, multiplier × distance)
  → snap when < 5m (prevents sub-pixel oscillation)
  │
  ▼
_onDisplayPositionUpdate(lat, lon)      ← 60 fps
  ├─ markerPosition.value = (lat, lon)  ← ValueNotifier → PlayerMarkerLayer rebuild
  ├─ cameraController.onLocationUpdate  ← MapLibre moveCamera (instant, not animate)
  └─ gameLogicFrame % 6 == 0?          ← throttle to ~10 Hz
      │
      ▼
  _processGameLogic(lat, lon)           ← ~10 Hz
      ├─ fogResolver.onLocationUpdate()
      │    ├─ resolve current cell → Observed
      │    ├─ if new cell: add to visitedCellIds, emit FogStateChangedEvent
      │    └─ update frontier (unvisited neighbors)
      ├─ locationProvider.notifier.updateLocation()
      ├─ fogOverlayController.update()
      │    ├─ viewport sampling (25px grid + 20% padding)
      │    ├─ cell discovery → persistent discoveredCellIds set
      │    └─ build 3 GeoJSON strings (base, mid, border)
      └─ updateFogSources()             ← MapLibre updateGeoJsonSource × 3
```

## Secondary Pipelines

### Species Discovery (event-driven)
```
fogResolver.onVisitedCellAdded (sync stream)
  → DiscoveryService
    → speciesService.getSpeciesForCell(cellId, habitats, continent)
    → deterministic roll (SHA-256 seeded by cellId)
    → emit DiscoveryEvent on onDiscovery stream
  → map_screen subscribes
    → discoveryProvider.notifier.showDiscovery()
    → DiscoveryNotificationOverlay toast
```

### Design Target: Discovery System
> These describe the INTENDED design, not current implementation. See `game-design.md`.

- Rarity-scaled discovery reveals (LC = small toast → EX = full-screen ceremony)
- Auto-collect for common species (LC, NT), tap-to-photograph for rare (VU+)
- Daily world seed (midnight GMT): cells rotate species daily, deterministic per day
- First visit: permanent species seeded by cell ID. Repeat visits: daily rotation pool
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
| GeoJSON source updates | ~10 Hz | Tied to game logic |
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
