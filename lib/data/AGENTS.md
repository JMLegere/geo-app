# data/

Drift ORM schema, repositories, sync, and location services. Local SQLite cache + write queue.

- `app_database.dart` / `database.dart` — Drift DB with platform-aware connection
- `repos/` — Repository pattern wrappers over Drift tables
- `sync/` — Write queue processor, Supabase persistence

See /AGENTS.md for project-wide rules.
