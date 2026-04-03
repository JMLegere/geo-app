# core/persistence

Repository pattern wrapping `AppDatabase`. All CRUD abstractions for features/.

**5 repositories:** `CellProgressRepository`, `ItemInstanceRepository`, `ProfileRepository`, `WriteQueueRepository`, `CellPropertyRepository`.

**Key rules:**
- Repositories take `AppDatabase` in constructor — no Riverpod dependency.
- All methods return `Future<T>` — no synchronous database access.
- Read-modify-write for incremental updates (e.g., `addDistance` reads current, adds delta, writes back).
- `Value<T>` wrappers for nullable Drift fields.
- Cell properties are globally shared — no userId in `CellPropertyRepository`.

See /lib/core/AGENTS.md for full repository API.
