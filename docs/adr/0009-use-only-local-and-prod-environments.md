# ADR 0009: Use only local and prod environments

- Status: Accepted
- Date: 2026-08-18
- Authority: `CONTEXT.md` — Execution Environment
- Issue: #569

EarthNova has exactly two active execution environments: `local` and `prod`.

`local` is a locally run Flutter/Desktop client. `prod` is the deployed production client. Both use the production Supabase project, so local gameplay actions mutate production data and must never be treated as disposable test activity.

Merging to `main` runs verification but does not deploy. Production deployment remains an explicit human-authorized operation. The external Railway environment may retain its platform name `production`, while EarthNova records the runtime environment as `prod`.

The beta app, workflow, credentials, and release stage are retired from active operation. Existing beta infrastructure and data are not deleted or mutated by this decision; archival or deletion requires separate destructive authorization.

Compatibility literals and historical evidence containing the word `beta` remain unchanged when renaming them would break authentication or rewrite history.
