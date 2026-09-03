# ADR 0010: Evolve toward six target container responsibilities

- Status: Accepted
- Date: 2026-09-03
- Issue: #592

EarthNova will evolve toward six explicit software responsibility boundaries:

1. **Player App** — the responsive Flutter experience and application use cases.
2. **Local State and Sync** — the bounded Client Working Set, safe pending-command persistence, retry, and recovery.
3. **Identity and Game API** — authenticated sessions, owner-bound reads, and idempotent commands.
4. **Game World Store** — authoritative versioned world and Player state in PostgreSQL/PostGIS.
5. **Background World Services** — telemetry, enrichment, scheduled processing, health, cleanup, and notifications.
6. **Asset Delivery** — public delivery of static and generated art.

A target container is a responsibility boundary, not necessarily a separate process, repository, service, or deployment. The current mapping remains Flutter; SharedPreferences plus an in-app synchronization coordinator; Supabase Auth/PostgREST/RPC; PostgreSQL/PostGIS; Edge Functions plus scheduled database processing; and Supabase Storage/public URLs. Independently deployed services require a later approved decision.

The final bounded-context map remains deliberately open. These responsibility seams guide incremental vertical slices without asserting that each seam is a final domain boundary.

The first approved slice adds durable recovery only for the already transactional and canonically idempotent `identify_v3_item` command. No other command kind is queue-enabled by this decision.
