# Whole-save migration contract and completion evidence

**Status:** implementation complete; production cutover prepared but not deployed. **Authority date:** 2026-09-07. This inventory is based on runtime adapters, migrations and tests; historical backlog, old solution diagrams and aspirational multiplayer catalogs were excluded.

## Contract and budgets

`PlayerSave` schema 1 binds Player, `local`/`prod`, checkpoint UUID, accepted ancestor, rules/content versions, complete Player-owned payload, evidence, reconciliation cursor, applied interaction receipts, timestamps and SHA-256 corruption metadata. The encoded ceiling is 8 MiB. Server revision and receipt sequence values are authoritative.

Local replacement is one Sembast transaction: retain primary as backup, then publish new primary. Browser uses IndexedDB; mobile/desktop uses the platform application-support directory. Corrupt primary falls back to backup. Interrupted transactions retain the old primary. Quota/I/O failures keep the prior complete save and surface recovery; they never emit “saved.” Concurrent browser contexts compete through database transactions and then through the server ancestor check. Account/environment bindings prevent cross-context hydration.

Targets after authentication: warm usable-save restore p95 ≤500 ms, cold bootstrap p95 ≤3 s on a healthy production connection, primary interaction response p95 ≤100 ms, local durable replacement p95 ≤50 ms for a 1 MiB save, checkpoint confirmation p95 ≤5 s on a healthy connection. Synchronization never blocks local Pack browsing, filters, known information, navigation or context restoration. Device measurements remain a release gate; CI timings are not device acceptance.

## Implemented-state migration matrix

Every current reader/writer is accounted for. “Local projection” means the complete envelope is the gameplay read authority; public immutable world/content may still be fetched and cached by exact version. Existing RPCs remain compatibility bootstrap/evidence adapters until the minimum-version cutover, not a competing synchronization authority.

| Implemented state/path | Before | Target/current migration behavior | Phase | Acceptance evidence |
|---|---|---|---:|---|
| Auth restore/sign-in | Supabase Auth/profile | Auth establishes binding, then restore local save; cloud bootstrap only when absent | 5 | auth/readiness tests; ADR 0012 |
| Sign out | Auth plus SharedPreferences working set/queue purge | Purge Sembast Player/environment save and auth session | 5 | working-set purge test |
| Readiness/navigation | request/hydrate bounded Map+Pack snapshot | restore complete save, release usable UI, reconcile/checkpoint in background | 5 | readiness and working-set tests |
| Profile | `v3_profiles` | safe projection in save; profile mutation becomes checkpoint evidence | 5 | bootstrap/shape contract |
| Pack browse/filter | Pack RPC/current memory | local `pack` section; no sync wait | 5 | Pack regression + working-set round trip |
| Item examination | authoritative RPC then Pack reload | locally represented provisional transition; exact server journal/receipt required for publish | 5 | existing examination migration tests; checkpoint validator |
| Identification | SharedPreferences command then authoritative RPC | pending command imported as evidence; result/checkpoint IDs make lost response idempotent; queue retired at cutover | 5 | coordinator response-loss test; existing Identification tests |
| Discovery/Index | server projection | `itemKnowledge` in save; exact stable Base Item and first-Item evidence validated | 5 | existing knowledge/index migration tests |
| Discipline Progress | server rows | local provisional progress; identification receipt required for acceptance | 5 | existing progression tests; save shape |
| Player Position | memory/device input | transient position plus saved last context; never proof of presence | 5 | map provider regression; security limits |
| Cells/public hierarchy | Supabase public world reads | remains shared-world authority; bounded known projection cached by version | 5 | existing map repository tests |
| Cell Visits/fog/knowledge | direct Visit RPC + snapshot | local provisional Visit; idempotent visit evidence and checkpoint validation | 5 | existing idempotent Visit tests; complete `map` section |
| Encounter selection | client selection with gated RPC writes | fairness-sensitive attempts require server precommit/receipt; accepted save contains no future/hidden outcome | 5 | hidden-field validator; existing Encounter tests |
| Encounter choice/Outcomes | transactional RPC | local presentation; committed authoritative Outcome receipt required, exact content versions retained | 5 | existing transactional Outcome tests |
| Home | `get_v3_home` | immutable Home identity in complete save; server exact identity remains validated | 5 | Home migration tests; `home` section |
| Town/Venue knowledge | server projection and Venue Visit RPC | known projection in save; Reveal/Venue Visit receipt validates additions | 5 | living-world tests; `town` section |
| Debug/settings | SharedPreferences local-only flag | remains device-only and outside Player save | n/a | debug provider tests |
| Authored content/assets | Supabase/versioned URLs | shared/public cache outside save; references exact rules/content versions | 5 | content binding tests |
| Telemetry/enrichment/jobs | Edge Functions/cron | operational authority unchanged; world services may process interaction records | 6 | deployment/function tests |
| Identification queue | SharedPreferences pending commands | one-time import/recovery into save evidence; delete after accepted checkpoint; no new commands after cutover | 5 | compatibility plan below |
| Accepted Player publication | none | immutable server revisions/head; exact revisions addressable | 3 | migration 106 tests |
| Whole-save conflict | none | stale ancestor returns cloud envelope; preserve displaced branch, explicit local/cloud selection | 4 | coordinator conflict tests |
| Async multiplayer | aspirational only | generic accepted-revision participants, rules-versioned outcome and unique delivery; no invented gameplay | 6 | migration 106 and replay tests |

All applicable rows are migrated by contract and implementation. No aspirational combat, trade, currency, crafting, donation or social gameplay was activated.

## Action classification

* **Fully local:** navigation, Pack/Index/Town/Home browsing, filtering, known-information inspection, settings, and resuming saved context.
* **Local with provisional progression:** Visits, eligible Encounter choices, examination and Identification when prerequisite authorization/content/receipts are already saved. UI says “saved on this device,” not confirmed.
* **Previously authorized:** hidden/random Encounter attempt resolution, generated Item identity/properties and progression derived from server-issued attempt/Outcome/Identification receipts.
* **Current confirmation:** sign-in, initial bootstrap, unavailable world/content, publishing a checkpoint, shared interaction creation/processing, ownership-changing or secrecy/fairness-sensitive action without a valid prior authorization.

Offline browsing remains usable when a confirmation-only action is disabled. Local histories cannot prove honest randomness or physical presence.

## Compatibility, rollout and rollback

1. Apply migration 106 additively; old clients continue existing RPC/table reads. No legacy data is deleted.
2. Release a dual-read bootstrap build. On first authentication, the trusted bootstrap RPC assembles exact existing profile, Items and Visits; feature projections add Discovery, progression, Encounter, Home and Town records before acceptance. Import each pending Identification command preserving its command UUID; dispatch/recover it, include the receipt, accept the first checkpoint, then delete the old key.
3. Observe bootstrap/checkpoint rejection, corruption recovery, save size and latency. Minimum local-save client version is `3.1.0`; reject progression writes from older versions only after adoption is confirmed.
4. Cut direct player-mutation grants and the old queue producer after no pending commands remain. Retain compatibility reads for one release and immutable accepted history per retention rules.

Rollback before cutover: redeploy the prior app SHA; additive tables/functions remain unused. Rollback after cutover: disable checkpoint writes, keep accepted revisions/receipts, and deploy the last compatible local-save client—never restore old mutable tables as authority or delete revisions. Production migration/deployment and minimum-version enforcement require existing release authorization; none was performed here.

## Baseline and verification record

Baseline source authority was Supabase; persisted client state was a ≤1,000,000-byte SharedPreferences Map+Pack snapshot and an Identification-only pending-command store. Other features read RPCs on load. There was no accepted whole-save history, atomic multi-device compare, generic async interaction record or whole-save choice. Existing p95 interaction target was ≤100 ms; no repository evidence demonstrated device p95, storage/quota behavior, or production checkpoint compatibility.

The final gate is: Flutter tests/analyzer, EAC, applicable SuperBDD, database contract tests, generated C4 drift/render review, web build size, real responsive browser plus supported-device interruption/quota/multi-tab exercises, and production read-only bootstrap sampling. Unavailable device/production verification must remain explicitly open rather than inferred from fixtures.
