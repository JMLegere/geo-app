# core/services

Pure Dart services that don't belong to a specific subdomain. No Flutter, no Riverpod.

**`DailySeedService`:** `fetchSeed()`, `refreshSeed()`, `currentSeed`, `isDiscoveryPaused`, `state`. Accepts `SeedFetcher` callback — network-free in core/. Falls back to `kDailySeedOfflineFallback` (`'offline_no_rotation'`) on error.

**Key rules:**
- No Supabase imports in `lib/core/` — wired via callback by `dailySeedServiceProvider`.
- Seed cached in-memory only (24h TTL). No Drift table.
- `isDiscoveryPaused` returns `true` only when seed is stale AND no fallback available.

See /lib/core/AGENTS.md for full service API.
