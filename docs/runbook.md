# EarthNova — Runbook

> Operational procedures. For architecture and design decisions, see `docs/design.md`.

---

## Quick Reference

| Thing | Value |
|-------|-------|
| Prod URL | https://geo-app-production-47b0.up.railway.app |
| Beta URL | https://geo-app-beta.up.railway.app |
| Prod Supabase project | `bfaczcsrpfcbijoaeckb` |
| Beta Supabase project | `ggkvcpgvxqaqzwxehlns` |
| Railway dashboard | https://railway.app |
| Git main branch | `main` — auto-deploys to beta first |

---

## Local Dev

```bash
# Install toolchain (Flutter 3.41.3, Supabase CLI, Terraform)
mise install

# Activate toolchain in current shell (Flutter, Supabase CLI, Terraform)
eval "$(~/.local/bin/mise activate bash)"

# Railway CLI (installed via npm, already in node PATH)
# Auth: railway login (browser OAuth — already logged in if you see `railway whoami`)
# Supabase CLI: already in mise.toml — `supabase --version` to verify

# Install dependencies
flutter pub get

# Run tests
flutter test

# Analyze
flutter analyze

# Build web (local)
flutter build web \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon_key>

# Trigger a beta deploy from the current checkout
gh workflow run deploy-beta.yml

# Promote a beta-validated commit to production
gh workflow run deploy-production.yml
```

See `.github/workflows/` for the deploy flow.

---

## Deploy

`main` is the trunk branch. CI runs on PRs and on pushes to `main`.

**Automatic path:**
1. Merge to `main`
2. CI passes
3. `deploy-beta.yml` deploys the same commit to Railway `beta`
4. The reusable `deploy-supabase.yml` applies migrations/functions to beta Supabase
5. Validate beta before any production rollout

**Manual promotion:**
```bash
gh workflow run deploy-production.yml
```

Optional input: `commit_sha` if you want to promote a specific already-validated commit.

**Beta checklist:**
1. CI green (`flutter analyze` + `flutter test`)
2. Beta Railway deploy green
3. Beta login succeeds
4. Core frontend smoke flows succeed
5. Beta Supabase migrations/functions finished cleanly

**Production checklist:**
1. Beta validation complete
2. Trigger `deploy-production.yml`
3. Verify prod URL loads within 60s
4. Check `telemetry_logs` for `app.cold_start` + `supabase.init_success`
5. Keep rollback target handy in Railway Deployments

**If deploy fails:**
- Check GitHub Actions logs first
- Check Railway build logs for the affected environment
- Redeploy the previous healthy Railway deployment if needed

---

## Supabase Operations

### Connect

```bash
# Link CLI to prod project
supabase link --project-ref bfaczcsrpfcbijoaeckb

# Link CLI to beta project
supabase link --project-ref ggkvcpgvxqaqzwxehlns

# Run a management API query
curl -X POST \
  "https://api.supabase.com/v1/projects/bfaczcsrpfcbijoaeckb/database/query" \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query": "SELECT count(*) FROM v3_items"}'
```

### Apply migrations

```bash
# GitHub Actions is the default path. Beta migrations require
# SUPABASE_BETA_DB_PASSWORD; production migrations require
# SUPABASE_PRODUCTION_DB_PASSWORD. If no DB password is configured,
# the workflow skips migrations and still deploys Edge Functions.
gh workflow run deploy-beta.yml

# For direct CLI work, link the target project first and then push.
# Set SUPABASE_DB_PASSWORD in non-interactive shells.
supabase db push --linked
```

### Common queries

```sql
-- Check a specific user's items
SELECT id, display_name, rarity, acquired_at
FROM v3_items
WHERE user_id = '<uuid>'
ORDER BY acquired_at DESC
LIMIT 20;

-- Check migration row counts (verify data migration)
SELECT
  (SELECT count(*) FROM profiles)       AS old_profiles,
  (SELECT count(*) FROM v3_profiles)    AS v3_profiles,
  (SELECT count(*) FROM item_instances) AS old_items,
  (SELECT count(*) FROM v3_items)       AS v3_items;

-- Check recent telemetry logs (last 50)
SELECT occurred_at,
       session_id,
       user_id,
       trace_id,
       span_id,
       category,
       event_name,
       severity_text,
       attributes
FROM telemetry_logs
ORDER BY occurred_at DESC
LIMIT 50;

-- Check a session timeline across logs + spans
SELECT event_at, signal_type, name, status_or_severity, duration_ms, attributes
FROM telemetry_session_timeline_v
WHERE session_id = '<uuid>'
ORDER BY event_at;

-- Find all errors in the last hour
SELECT error_at, signal_type, session_id, user_id, trace_id, name, body, attributes
FROM telemetry_recent_errors_v
WHERE error_at > now() - interval '1 hour'
ORDER BY error_at DESC;

-- Find all sign-in errors in the last 24h
SELECT attributes->>'error_message'   AS error,
       attributes->>'supabase_code'   AS code,
       attributes->>'supabase_status' AS status,
       count(*)                       AS occurrences
FROM telemetry_logs
WHERE event_name = 'auth.sign_in_error'
  AND occurred_at > now() - interval '24 hours'
GROUP BY 1, 2, 3
ORDER BY occurrences DESC;

-- Check if a user can log in (verify derived email exists in auth)
SELECT id, email, created_at
FROM auth.users
WHERE email = '<digits>@earthnova.app';

-- Count items with frame 2 vs without (enrichment progress)
SELECT
  count(*) FILTER (WHERE icon_url_frame2 IS NOT NULL) AS animated,
  count(*) FILTER (WHERE icon_url_frame2 IS NULL)     AS static,
  count(*)                                             AS total
FROM v3_items;
```

### UI observability queries

Use these against `telemetry_logs` after releasing UI observability changes.

```sql
-- Jank events above threshold (>100ms) in last 24h
WITH parsed_jank AS (
  SELECT
    session_id,
    user_id,
    event_name,
    attributes->>'screen_name' AS screen_name,
    attributes,
    occurred_at,
    CASE
      WHEN jsonb_typeof(attributes->'build_duration_ms') = 'number'
        THEN (attributes->>'build_duration_ms')::numeric
      WHEN (attributes->>'build_duration_ms') ~ '^[0-9]+(\\.[0-9]+)?$'
        THEN (attributes->>'build_duration_ms')::numeric
      ELSE NULL
    END AS build_duration_ms
  FROM telemetry_logs
  WHERE event_name = 'ui.widget.build_jank'
    AND occurred_at > now() - interval '24 hours'
)
SELECT session_id, user_id, screen_name, build_duration_ms, occurred_at, attributes
FROM parsed_jank
WHERE build_duration_ms > 100
ORDER BY build_duration_ms DESC, occurred_at DESC;

-- Interaction coverage by screen/widget/action in last 24h
SELECT
  COALESCE(attributes->>'screen_name', 'unknown') AS screen_name,
  COALESCE(attributes->>'widget_name', 'unknown') AS widget_name,
  COALESCE(attributes->>'action_type', 'unknown') AS action_type,
  count(*) AS events,
  count(DISTINCT session_id) AS sessions,
  max(occurred_at) AS last_seen_at
FROM telemetry_logs
WHERE event_name = 'interaction.action'
  AND occurred_at > now() - interval '24 hours'
GROUP BY 1, 2, 3
ORDER BY events DESC, screen_name, widget_name, action_type;


-- Screen lifecycle expected → ready/failed/timeout correlation
WITH screen_events AS (
  SELECT
    session_id,
    COALESCE(attributes->>'screen_name', attributes->>'to_screen', 'unknown') AS screen_name,
    event_name,
    occurred_at,
    attributes
  FROM telemetry_logs
  WHERE event_name LIKE 'ui.screen.%'
    AND occurred_at > now() - interval '24 hours'
)
SELECT
  session_id,
  screen_name,
  min(occurred_at) FILTER (WHERE event_name = 'ui.screen.expected') AS expected_at,
  min(occurred_at) FILTER (WHERE event_name = 'ui.screen.mounted') AS mounted_at,
  min(occurred_at) FILTER (WHERE event_name = 'ui.screen.first_build') AS first_build_at,
  min(occurred_at) FILTER (WHERE event_name = 'ui.screen.ready') AS ready_at,
  min(occurred_at) FILTER (WHERE event_name = 'ui.screen.load_timeout') AS timeout_at,
  min(occurred_at) FILTER (WHERE event_name = 'ui.screen.disposed_before_ready') AS disposed_before_ready_at,
  max(occurred_at) AS last_seen_at
FROM screen_events
GROUP BY session_id, screen_name
ORDER BY last_seen_at DESC;

-- Screens with non-terminal or bad terminal lifecycle in last 24h
WITH screen_summary AS (
  SELECT
    session_id,
    COALESCE(attributes->>'screen_name', attributes->>'to_screen', 'unknown') AS screen_name,
    bool_or(event_name = 'ui.screen.expected') AS expected,
    bool_or(event_name = 'ui.screen.ready') AS ready,
    bool_or(event_name = 'ui.screen.load_timeout') AS timed_out,
    bool_or(event_name = 'ui.screen.disposed_before_ready') AS disposed_before_ready,
    max(occurred_at) AS last_seen_at
  FROM telemetry_logs
  WHERE event_name LIKE 'ui.screen.%'
    AND occurred_at > now() - interval '24 hours'
  GROUP BY session_id, COALESCE(attributes->>'screen_name', attributes->>'to_screen', 'unknown')
)
SELECT *
FROM screen_summary
WHERE timed_out
   OR disposed_before_ready
   OR (expected AND NOT ready AND last_seen_at < now() - interval '10 seconds')
ORDER BY last_seen_at DESC;

-- Route/non-route navigation funnel pairs in last 24h
WITH nav AS (
  SELECT
    session_id,
    occurred_at,
    COALESCE(attributes->>'transition_type', 'unknown') AS transition_type,
    COALESCE(attributes->>'from_screen', lag(attributes->>'screen_name') OVER (
      PARTITION BY session_id
      ORDER BY occurred_at
    ), 'unknown') AS from_screen,
    COALESCE(attributes->>'to_screen', attributes->>'screen_name', 'unknown') AS to_screen
  FROM telemetry_logs
  WHERE event_name LIKE 'navigation.%'
    AND occurred_at > now() - interval '24 hours'
)
SELECT
  transition_type,
  from_screen,
  to_screen,
  count(*) AS transitions,
  count(DISTINCT session_id) AS sessions
FROM nav
GROUP BY 1, 2, 3
ORDER BY transitions DESC, transition_type, from_screen, to_screen;

-- Per-screen error boundary counts in last 24h
SELECT
  COALESCE(attributes->>'screen_name', 'unknown') AS screen_name,
  count(*) AS errors,
  count(DISTINCT session_id) AS sessions,
  max(occurred_at) AS last_seen_at
FROM telemetry_logs
WHERE event_name = 'error.screen_boundary_caught'
  AND occurred_at > now() - interval '24 hours'
GROUP BY 1
ORDER BY errors DESC, screen_name;

-- Low-level browser event coverage in last 24h
SELECT
  event_name,
  COALESCE(attributes->>'surface', 'unknown') AS surface,
  COALESCE(attributes->>'flow', 'unknown') AS flow,
  count(*) AS events,
  count(DISTINCT session_id) AS sessions,
  max(occurred_at) AS last_seen_at
FROM telemetry_logs
WHERE category = 'low_level'
  AND occurred_at > now() - interval '24 hours'
GROUP BY 1, 2, 3
ORDER BY events DESC, event_name;

-- Pinch/zoom attempts seen below Flutter's gesture recognizer
SELECT
  occurred_at,
  session_id,
  event_name,
  attributes->>'source' AS source,
  attributes->>'gesture_direction' AS gesture_direction,
  attributes->>'threshold_met' AS threshold_met,
  attributes->>'within_maplibre' AS within_maplibre,
  attributes->>'touch_action' AS touch_action
FROM telemetry_logs
WHERE category = 'low_level'
  AND event_name IN ('low_level.gesture_pinch_started', 'low_level.gesture_pinch_ended', 'low_level.wheel_input')
  AND occurred_at > now() - interval '24 hours'
ORDER BY occurred_at DESC;

```

### Post-deploy UI observability validation playbook

Run after every production deploy that touches UI observability, navigation, or screen composition.

1. Open `https://geo-app-production-47b0.up.railway.app` in a fresh browser session (incognito is preferred).
2. Exercise major flows end-to-end:
   - loading → login → tab shell transitions
   - each tab switch in the bottom navigation
   - map root toggles and hierarchy navigation (all available levels)
   - pack interactions (card taps, list interactions)
   - settings actions
3. Trigger representative gestures: tap, long-press, drag/pan/zoom where supported.
4. Validate observability rows in Supabase using the queries above (`telemetry_logs`, last 24h):
   - `interaction.action`
   - `low_level.%`
   - `navigation.%`
   - `ui.screen.%`
   - `ui.widget.build_jank`
   - `error.screen_boundary_caught`
5. Confirm route and non-route transitions both appear in navigation funnel results.
6. Confirm every expected screen reaches `ui.screen.ready` and no screen emits `ui.screen.load_timeout` or `ui.screen.disposed_before_ready`.
7. Confirm interaction coverage output includes expected `screen_name` / `widget_name` / `action_type` combinations for exercised flows.
8. Confirm no unexpected spikes in `error.screen_boundary_caught` for any single screen.
9. Confirm hierarchy navigation remains usable (no blocked transitions, no stuck level changes, no broken back-navigation).
10. Record the deploy SHA, validation timestamp, and any anomalies in the incident/deploy notes.

### Edge Functions

```bash
# Deploy a specific function
supabase functions deploy process-enrichment-queue \
  --no-verify-jwt \
  --project-ref bfaczcsrpfcbijoaeckb

# Deploy all functions
supabase functions deploy --project-ref bfaczcsrpfcbijoaeckb

# Check function logs
supabase functions logs process-enrichment-queue --project-ref bfaczcsrpfcbijoaeckb
```

---

## Incident Response

### App not loading

1. Check Railway dashboard — is the latest deploy green?
2. Check `telemetry_logs` for `supabase.init_failure` events in the last hour
3. Check Supabase dashboard — is the project healthy? (Database → Health)
4. Check Railway build logs for any startup errors
5. If Supabase is down: users see "Couldn't connect" banner — this is expected behaviour

### Users can't log in

1. Query `telemetry_logs` for `auth.sign_in_error` — what's the `supabase_code`?
2. Common codes:
   - `invalid_credentials` — user has never signed up, or derived password mismatch. Check `_deriveEmail`/`_derivePassword` hasn't changed.
   - `over_email_send_rate_limit` — too many sign-up attempts
   - `network_failure` — Supabase unreachable
3. Verify `auth.users` has a row with `email = '<digits>@earthnova.app'` for the affected user
4. If `_deriveEmail`/`_derivePassword` changed: **critical** — all existing users locked out. Revert immediately.

### Pack shows no items

1. Query `v3_items` for the affected user — does data exist?
2. If no rows: check data migration ran (`SELECT count(*) FROM v3_items` vs `item_instances`)
3. If rows exist: check RLS — test with authenticated client that `SELECT * FROM v3_items` returns rows
4. Check `telemetry_logs` for `items.fetch_error` — what's the `error_message`?

### Enrichment pipeline stalled

1. Check `process-enrichment-queue` function logs
2. Query: `SELECT count(*) FROM species WHERE icon_url IS NULL` — are candidates queued?
3. Check `PIPELINE_VERSION` env var — if it matches all enrichver stamps, nothing looks stale
4. Check Railway logs for the last deploy — did `PIPELINE_VERSION` change?
5. See postmortem: `docs/post-mortem.md`

### High error rate in telemetry

```sql
SELECT name, count(*) AS n
FROM telemetry_recent_errors_v
WHERE error_at > now() - interval '1 hour'
GROUP BY name
ORDER BY n DESC;
```

---

## Environment Variables

See `.env.example` for the full list. Required secrets and variables:

| Variable | Where set | Notes |
|----------|-----------|-------|
| `SUPABASE_URL` | Railway env variable | Set per environment at build time |
| `SUPABASE_ANON_KEY` | Railway env variable | Public anon key for the target Supabase project |
| `SUPABASE_ACCESS_TOKEN` | GitHub secret | Required by Supabase CLI workflows |
| `SUPABASE_BETA_PROJECT_REF` | GitHub secret | `ggkvcpgvxqaqzwxehlns` |
| `SUPABASE_PRODUCTION_PROJECT_REF` | GitHub secret | `bfaczcsrpfcbijoaeckb` |
| `SUPABASE_BETA_DB_PASSWORD` | GitHub secret | Enables non-interactive beta `supabase db push` |
| `SUPABASE_PRODUCTION_DB_PASSWORD` | GitHub secret | Enables non-interactive production `supabase db push` |
| `RAILWAY_API_TOKEN` | GitHub secret | Required by Railway CLI workflows |
| `RAILWAY_PROJECT_ID` | Workflow env or secret | `e693a14e-316c-4280-842a-6258a048d326` |

To rotate an anon key: update the Railway environment variable for the affected environment, then redeploy that environment.
