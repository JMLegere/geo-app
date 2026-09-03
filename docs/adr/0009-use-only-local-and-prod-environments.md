# ADR 0009: Use only local and prod environments

- Status: Superseded in part by ADR 0011
- Date: 2026-08-18
- Authority: `CONTEXT.md` — Execution Environment
- Issue: #569

EarthNova has exactly two active execution environments: `local` and `prod`.

`local` is a locally run Flutter/Desktop client. `prod` is the deployed production client. Both use the production Supabase project, so local gameplay actions mutate production data and must never be treated as disposable test activity.

At the time of this decision, merging to `main` ran verification but did not deploy and production deployment was an explicit manual operation. ADR 0011 later replaced only that delivery policy with automatic exact-SHA deployment after successful `main` CI. The external Railway environment may retain its platform name `production`, while EarthNova records the runtime environment as `prod`.

The beta app, workflow, credentials, and release stage are retired from active operation. Existing beta infrastructure and data are not deleted or mutated by this decision; archival or deletion requires separate destructive authorization.

Compatibility literals and historical evidence containing the word `beta` remain unchanged when renaming them would break authentication or rewrite history.
