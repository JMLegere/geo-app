# core/fog

Fog-of-war state resolution. `FogStateResolver` computes per-cell fog state from player position + visit history.

**CRITICAL:** FogState is COMPUTED, never stored. Only `visitedCellIds` are persisted. Storing computed fog state causes desync.

**Priority order:** Observed > Hidden > Concealed > Unexplored > Undetected.

**Key rules:**
- `onLocationUpdate()` stream controller uses `sync: true` — events are emitted synchronously. Listeners must not perform async work.
- Detection radius from `kDetectionRadiusMeters` (1000m) in `shared/constants.dart`.
- Exploration frontier maintained incrementally — when a cell becomes Observed, its unvisited neighbors become Unexplored.

See /lib/core/AGENTS.md for full fog resolver API.
