# ADR 0012: Play from local saves and synchronize validated checkpoints

- Status: Accepted
- Date: 2026-09-07
- Authority: approved local-save migration Outcome Contract
- Supersedes: ADR 0008; ADR 0010's Identification-only synchronization limit

EarthNova plays against one durable, complete, Player- and environment-bound local save. The app persists changes atomically and presents from that save without waiting for network synchronization. It submits immutable whole-save checkpoints with an accepted ancestor and progression evidence. The Game API validates ownership, state and supported progression, then atomically assigns the next server revision or returns a whole-save conflict. An accepted revision is the only state published to asynchronous interactions.

Complete means all implemented Player-owned mutable progress: safe profile projection; Pack Items and permanent exact Base Item Version/Property Value bindings; Discovery and Discipline Progress; Visits and Player Cell knowledge; Encounter occurrences, selections, committed Outcomes and receipts; Home identity; and known Venue, Villager and Service knowledge. Credentials, shared-world authority, unpublished content, undiscovered Item identity/property values and preselected future Outcomes are never client-owned save content. Authored public content remains a versioned cache referenced by identity.

PostgreSQL supplies revision order. Client clocks, deterministic replay, hashes and action histories are untrusted evidence, not legitimacy. The server derives the actor from authentication, checks the expected ancestor under a row lock, validates exact identities/versions and required receipts, and accepts a revision transactionally. Reusing a checkpoint identity is idempotent. Direct table grants do not provide a checkpoint bypass.

Mutable local work and immutable published revisions are separate. Asynchronous interactions reference exact accepted revisions and a rules version. Their durable records and per-Player deliveries are unique and transactionally reconciled; save restoration cannot reverse a completed shared effect. Delivery may repeat, application may not.

Whole-save conflict selection deliberately rejects field merging. The displaced branch is retained locally before replacement. Choosing local retains its ancestry and therefore still requires validation; choosing cloud first reconciles later shared deliveries. Accepted revisions referenced by interactions, unresolved conflicts or receipts cannot be compacted. Other superseded revisions have a 90-day recovery floor; compaction is an operator job and must prove no dependency before deletion.

Sembast is the cross-platform transactional local store: IndexedDB in browsers and an application-support database on native/desktop platforms. A transaction rotates primary to backup before replacement. Integrity metadata detects corruption; recovery reads the backup. Storage failures are explicit and never reported as saved. Sign out purges the Player/environment partition. Browser eviction results in authenticated bootstrap or a readiness failure, never an invented empty save.

ADR 0008's bounded working set becomes the projection of this complete save rather than an independently authoritative cache. ADR 0010's six responsibilities remain, but its narrow Identification command queue is superseded by checkpoint synchronization after pending-command migration. Flutter, Railway and Supabase remain deployment choices; the six boundaries do not imply six deployables.

## Security limits

Validated structure and receipts prevent invalid state and duplication; they do not prove honest offline play. Deterministic histories can be searched, device time can be changed and location plausibility does not prove presence. Mechanics whose fairness depends on hidden randomness require server-issued precommitment/receipts or current authoritative execution. Detection of automation and suspicious patterns is operational telemetry, separate from state validity. Checksums detect accidental corruption only and are not anti-cheat.
