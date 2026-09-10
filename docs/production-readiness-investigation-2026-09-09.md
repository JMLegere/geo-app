# Production readiness investigation — 2026-09-09

## Executive conclusion

Production cannot currently substantiate the promised **complete load within 30
seconds and meaningful interaction response within 100 ms afterward**. Three
independent contract breaks are confirmed:

1. the deployed bundle does not identify its commit (`APP_VERSION` is
   `2026-09-09-1610-local`), so neither the deployment nor an iPhone session can
   be tied to an exact Git revision;
2. App Readiness admits the Pack after its JSON projection is present but does
   not fetch or decode Pack artwork, while 32,690 of 32,759 production species
   have neither icon nor art; and
3. the web server gives unhashed fonts, images, CanvasKit, and MapLibre assets a
   one-year `immutable` cache lifetime. A returning Home Screen client can
   therefore combine fresh application JavaScript with stale glyph and static
   assets.

The merged map fix is present in the served JavaScript and makes the readiness
predicate stricter. It is not evidence that Map is usable on the affected
iPhone: production telemetry, an authenticated affected-player session, and a
real-device trace were unavailable in this execution. The repair sequence below
starts by making those facts observable, then fixes the data and readiness
contracts rather than hiding them behind the loading screen.

## Scope, method, and evidence boundaries

The investigation used the production URL, anonymous production REST data,
served resource inspection, an iPhone 13 Playwright viewport, and source/test
inspection. It made no production writes and did not use the affected Player's
credentials or saved progress.

Captured at approximately 19:36–19:40 UTC:

- production HTML, bootstrap, JavaScript, service worker, manifests, fonts,
  MapLibre files, and response headers;
- fresh isolated mobile-browser startup for 15 seconds, repeated in a second
  isolated context;
- production species artwork coverage and a HEAD request for every populated
  artwork URL; and
- current branch `b7732b9ef959358915900fe554600dc6a9bc0739` and its map-fix diff.

The isolated browser reached Login in about 7.1 seconds without request errors.
That proves only unauthenticated bootstrap, not App Readiness. Its navigation
response completed in 709 ms; `main.dart.js` took 426 ms and transferred 1.45
MB compressed. The startup also downloaded roughly 3.14 MB of font files,
including six Lucide variable-font weights, before authentication. CanvasKit was
cross-origin and its transfer size was unavailable from the browser timing API.

**Unavailable evidence:** Railway/GitHub deployment records, private telemetry,
authenticated Pack rows, the reported screenshots, Safari remote-inspector
logs, and a physical iPhone. Consequently this report does not claim to have
reproduced the affected Player's blank Map, Pack stutter, or Home Screen cache
state. Those checks are explicit release gates below, rather than silently
inferred from Chromium.

## 1. What production is running

| Evidence | Observation | Consequence |
|---|---|---|
| Served `main.dart.js` | SHA-256 `f23187d06e4bf267147ecf67e1ef13afe27676fc4d6ce7afcea762812b6d410f`; embedded version `2026-09-09-1610-local` | Exact source commit is unknown from the artifact. |
| Served bootstrap | SHA-256 `ecceef3aff421d0ea11c471803ee728d90dadb8f1a82af219cbec54ac2f1179a`; requests `main.dart.js?v=480ac1c5` | The main entry point is cache-busted, but this hash is not a Git identity. |
| Current source | HEAD `b7732b9`; production bundle contains the new meaningful-overlay predicate and the text introduced by that revision | Strong evidence that the #602 source is included, but not a cryptographic deployment match. |
| Build pipeline | Docker derives the version from `RAILWAY_GIT_COMMIT_SHA`, then falls back to Git, then `local` | Railway supplied no SHA and the Docker build context had no usable `.git`; deployment provenance failed open. |
| Service worker | Served worker unregisters itself and reloads controlled clients | Old Flutter cache removal is attempted, but browser HTTP caches remain. |
| Static cache | `main.dart.js`, bootstrap, HTML and service worker are `no-store`; most other paths are `max-age=31536000, immutable` | A new app can request the same old font/static URL and legally receive a year-old response. |

The application font manifest and current files match each other in a fresh
session: Material Icons (13,864 bytes), Geist (168,932), Geist Mono (171,072),
Lucide (749,776), and six Lucide weight fonts (about 2.61 MB total). That does
not prove an installed Home Screen app has them: their URLs are not content
hashed. The missing Pack glyph is defined as `Icons.backpack_outlined`, hence it
comes from the tree-shaken Material Icons font. A stale subset at the same URL
is the leading explanation, but an affected-iPhone network/cache capture is
required to confirm it.

## 2. Artwork source-to-screen trace

### Production data

`Least Yellow Bat` (`fauna_rhogeessa_mira`, *Rhogeessa mira*) has null
`icon_url`, `icon_url_frame2`, `art_url`, and both enrichment-version fields in
the live `species` table. This is a confirmed source-data absence, not a
download or decoder failure.

The complete anonymous species audit returned:

| Metric | Count | Coverage |
|---|---:|---:|
| Species | 32,759 | 100% |
| `icon_url` populated | 68 | 0.208% |
| `art_url` populated | 67 | 0.205% |
| `icon_url_frame2` populated | 0 | 0% |
| Neither icon nor art | 32,690 | 99.789% |

All 135 populated URLs returned HTTP 200 to HEAD requests. Their aggregate
encoded size was 22,956,835 bytes, median 160,918 bytes, maximum 1,885,860
bytes. These are catalog figures, not the affected Pack figures because RLS and
missing credentials prevented reading that Pack.

### Pipeline and rendering path

1. The enrichment function selects species whose URLs are null or whose
   enrichment version is stale, generates files, stores their URLs, and updates
   `species`.
2. Item acquisition snapshots URL fields into `v3_items`; examination's safe
   projection returns those item-row URLs. It does not dynamically repair a
   previously created Item from a subsequently enriched species record.
3. Pack fetch returns the complete active Item JSON array. The Client Working
   Set persists those strings and Item metadata, not image bytes or decode
   receipts.
4. The Pack grid is lazy (`GridView.builder`). Opening an examined card then
   calls `Image.network(art_url)`; while it downloads it shows the icon path,
   which may trigger a second network image, then finally a category fallback.
   No stage precaches or proves decode completion.

Thus previously unseen cards are explicitly allowed to load after App Readiness
and cannot be guaranteed to respond with requested artwork in 100 ms. The
minimum decoded memory estimate for a Pack is
`sum(width × height × 4 bytes)` for every resident frame, regardless of encoded
download size; dimensions were not stored in the audited projection, so an
honest full-Pack memory number cannot yet be computed. The repair must add
dimensions/byte sizes to the media manifest and enforce a bounded thumbnail
working set. Loading full-resolution art for every species is neither necessary
nor a safe memory strategy.

## 3. Map and loading readiness trace

Map steady state requires location, MapLibre creation, style load, base-map
settling, fetched cells, and one accepted overlay frame. Revision #602 additionally
requires a non-empty render-cell set and, for active location, at least one
present cell. Paused location accepts a non-empty cell set. This removes the
specific false-ready path where an opaque/empty overlay could dismiss loading.

Important remaining risks:

- Cell fetch readiness means a renderable `MapState` exists; it does not prove
  viewport coverage, projected geometry intersection, or visible pixels.
- Base-map readiness falls back after five seconds even without a positive
  renderer signal.
- The exact screen-projection pipeline is asynchronous and distinct from the
  milestone booleans.
- The fix can now convert a former blank-map success into a deterministic
  12-second readiness failure. That is safer, but does not repair missing cells,
  bad geometry, position/viewport mismatch, or a MapLibre render failure.

App Readiness has three checkpoints: working set, Pack, and map surface. A cold
load first awaits unbounded Map and Pack network futures; only afterward does it
start a 12-second polling wait for Map steady state. There is therefore **no
end-to-end 30-second deadline**. A hanging initial request can leave the overlay
indefinitely. On a snapshot path, cached metadata plus Map readiness permits
input before background refresh. Retry repeats the same operation; failure copy
includes the terminal cause and offers Retry/Sign out, but there is no timeout
around the original network work.

Pack readiness means only that Item DTOs were accepted. It does not wait for
thumbnail download or decode. Search, filtering, and sorting run synchronously
over all Items and rebuild/sort lists on each change; no production p95 measure
connects input to the first meaningful frame. The existing telemetry can expose
long tasks and coarse frame pacing, but it does not establish per-interaction
input-to-content latency or image-decode completion.

## 4. Prioritized findings and repair sequence

| Priority | Symptom | Cause / hypothesis | Supporting evidence | Affected code/data | Smallest complete repair | Verification |
|---:|---|---|---|---|---|---|
| P0 | Cannot know what production/iPhone runs | **Confirmed:** artifact version falls back to `local`; static assets are not revision-addressed | Served bundle/version/header hashes above | `Dockerfile`, deploy workflow, `nginx.conf`, web build | Fail the build unless a full expected SHA is supplied; publish a signed/JSON build manifest containing commit and hashes; name or URL-version every font/static asset; display/report build ID | CI artifact hash equals production; Safari inspector shows the manifest SHA and matching JS/font response hashes in fresh and installed Home Screen launches |
| P0 | Least Yellow Bat has no artwork | **Confirmed:** all media/version columns null in production | Exact REST row | `species`, enrichment queue, acquisition snapshot/projection | Repair/re-run enrichment for referenced Pack definitions first; backfill owned Item media through an explicit versioned migration/projection, not ad-hoc client lookup | DB assertions for bat and affected Pack; every URL GET + decode succeeds; card renders expected image offline from prepared working set |
| P0 | Nearly all catalog artwork absent | **Confirmed:** 32,690/32,759 rows have neither asset | Full paginated REST audit | enrichment pipeline/storage/data | Add queue health SLO, retry/dead-letter evidence, deterministic coverage job, and progressive prioritized generation | 100% of required live Pack definitions meet media contract; health alert fires on null/stale rows |
| P0 | “Complete within 30 seconds” is not enforced | **Confirmed:** network futures are unbounded and Map polling is 12 seconds only | Readiness control flow | `app_readiness.dart` | Put the entire readiness attempt under one monotonic 30-second deadline; cancel/ignore late generations; preserve valid snapshot degraded path; report named dependency and elapsed time | Fake-clock tests for every hang/failure/retry; production telemetry proves p95 and max terminal outcome ≤30 s |
| P0 | New Pack art loads after readiness | **Confirmed:** readiness stores URLs only and cards use lazy `Image.network` | readiness, grid, species card | Client Working Set/media layer | Define a bounded, versioned thumbnail manifest; download, integrity-check and decode required thumbnails before usable; persist bytes in the Player-bound save/cache with atomic manifest commit | Airplane-mode post-readiness browse of every Pack card; zero network requests and first meaningful frame ≤100 ms |
| P1 | Blank Map / loading timeout | #602 false-ready fix **present**; underlying cause remains unobserved | Served JS contains new predicate; no affected session telemetry/device trace | map providers, geometry/projection, MapLibre | Add one readiness diagnostic snapshot containing position, viewport, fetched bounds, intersecting/render/present counts, projection revision and visible-pixel proof; do not use fallback settling as positive proof | Fresh/returning real-iPhone sessions render aligned cells; screenshot/pixel assertion and telemetry terminal event ≤30 s |
| P1 | Missing Pack navigation icon | **Leading hypothesis:** stale tree-shaken Material font at immutable stable URL | glyph is `Icons.backpack_outlined`; font URL is unhashed and immutable | `tab_shell.dart`, font manifest, nginx cache | Covered by P0 asset revisioning; optionally use the already-versioned design icon system/SVG only if design authority approves | Clear and uncleared Safari cache plus Home Screen upgrade both render icon; requested font hash matches build manifest |
| P1 | Pack scroll/inspect misses 100 ms | **Confirmed architectural exposure; p95 not measured:** lazy network decode and synchronous list transforms are on the critical path | grid/card/filter implementation | Pack presentation/media cache | Keep thumbnails decoded near viewport, cap decode dimensions, move/index expensive projection work, debounce search only if it preserves meaningful immediate response, and instrument input-to-frame | Real iPhone production p50/p95/max for nav, scroll, search, filter, inspect; p95 ≤100 ms and no frame >100 ms |
| P2 | Large unauthenticated bootstrap | **Confirmed:** 1.45 MB JS and ~3.14 MB fonts transferred in test | Resource timings | Flutter web build/font selection | Subset/load only used fonts and self-host/version CanvasKit; set budgets | Cold constrained-network trace meets 30 s with byte budget regression check |

## 5. Production and real-iPhone acceptance protocol

No repair is complete until all of the following are attached to the release
evidence for the exact manifest SHA:

1. **Identity and cache:** record document, bootstrap, JS, manifest, Material,
   Geist/Lucide, MapLibre, CanvasKit, and media hashes. Repeat after upgrading an
   existing Home Screen install without clearing Safari data; hashes must match.
2. **Isolated Player:** use a dedicated production investigation account. Run
   cold/fresh, warm/returning, forced network failure with valid snapshot, and
   retry-without-snapshot. Do not use or erase the Player's real save.
3. **Readiness:** from navigation start, record every dependency and decoded-media
   receipt. Every run reaches usable, degraded, or explained failure within 30
   seconds; no progress-only terminal state is permitted.
4. **Map:** capture permission/location state, fetched bounds and cell count,
   viewport and geometry intersection, MapLibre/style/settle signals, projection
   revision, rendered present-cell count, and screenshot. Confirm #602 rejects
   an empty/opaque frame and accepts visible aligned geometry.
5. **Pack artwork:** include Least Yellow Bat and every Item in the test Pack.
   Verify storage authorization, GET status, integrity, decode dimensions,
   resident decoded bytes, and offline post-readiness browsing.
6. **Latency:** instrument input timestamp to the first frame containing usable
   requested content for tab navigation, scroll-to-new-row, search, each filter,
   sort, and inspection. Collect at least 100 representative interactions on
   the target iPhone/network profile and report p50/p95/max. The acceptance
   ceiling is p95 ≤100 ms; a tap highlight alone is not meaningful content.
7. **Smoothness:** report long tasks, worst frame delta and dropped frames during
   fast end-to-end Pack scrolling. Any network or full-resolution decode on the
   critical interaction path is an architectural failure, not a relaxed target.

## Reproduction commands

These commands are read-only except for installing local Playwright browser
dependencies:

```bash
curl -sS -D headers -o index.html https://geo-app-production-47b0.up.railway.app/
curl -sS -o main.dart.js https://geo-app-production-47b0.up.railway.app/main.dart.js
sha256sum main.dart.js flutter_bootstrap.js
rg -o '2026-[0-9-]{10,30}' main.dart.js
curl -sS https://geo-app-production-47b0.up.railway.app/assets/FontManifest.json
fc-query --format='%{charset}\n' MaterialIcons-Regular.otf
# Production REST pagination used limit=1000 and offsets 0..32000 with the
# public anon key already embedded in the served client. No authenticated tables
# or Player rows were queried.
npx playwright install chromium
node investigate.mjs
git show --stat --oneline b7732b9
```

## Implemented follow-up (not yet production-verified)

The subsequent repair change closes the repository-side P0 gaps identified by
this investigation: deployment now fails without an exact 40-character commit
SHA, stable static URLs must revalidate, one global 30-second readiness deadline
covers all initial work, and Pack media must reach decoded-or-fallback terminal
state before input is admitted. An additive projection migration lets examined
legacy Item snapshots use later species-media enrichment, while pipeline health
returns unhealthy until required icon and art coverage is complete.

These changes deliberately do not rewrite the evidence above. The production
species backfill remains operational work for the existing enrichment pipeline,
and deployment plus the physical-iPhone acceptance protocol remain required
before any production success claim.

### 2026-09-10 iPhone timeout follow-up

The reported “Map is taking too long to prepare” screen exposed a remaining
bootstrap ordering bug: the readiness predicate required a Present Cell, while
the fog projection depended only on `explorationState.currentCellId`. On an
iPhone cold start, trusted location and fetched geometry can be ready before
Cell-entry tracking publishes that ID, leaving every Cell opaque/unknown and
guaranteeing the 12-second Map timeout.

The repair now derives the visual Present Cell directly from the trusted startup
position and fetched polygons when the tracking ID has not arrived. Readiness
also accepts projected, viewport-intersecting translucent frontier/explored
geometry, while continuing to reject empty, offscreen, and fully opaque unknown
frames. This preserves the false-ready protection without requiring an
unrelated provider callback to win the startup race.
