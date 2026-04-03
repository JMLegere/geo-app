# core/database

Drift ORM schema, table definitions, and database connection factory.

**Schema version:** 24. 6 core tables + 4 hierarchy tables. Generated file: `app_database.g.dart` (never hand-edit).

**Key rules:**
- Run `dart run build_runner build` after any schema change.
- `autoIncrement()` tables must NOT override `primaryKey` (only `LocalWriteQueueTable`).
- FogState stored as string (`"observed"`, `"concealed"`, etc.) — never as int.
- Nullable field updates use `Value<T>` wrappers: `Value(x)` to set, `Value.absent()` to skip.
- Platform-aware: `connection_native.dart` (file-backed) vs `connection_web.dart` (in-memory).

See /lib/core/AGENTS.md for full schema and table details.
