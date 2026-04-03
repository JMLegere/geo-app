# domain/seed/

Daily seed service. Fetches seed from Supabase RPC, caches 24h in memory. Offline fallback: `'offline_no_rotation'`.

`isDiscoveryPaused` = true only when seed is stale AND no fallback available.

See /AGENTS.md for project-wide rules.
