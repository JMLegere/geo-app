# EarthNova — Runbook

> Operational procedures. For architecture and design decisions, see `docs/design.md`.

---

## Quick Reference

| Thing | Value |
|-------|-------|
| Prod URL | https://geo-app-production-47b0.up.railway.app |
| Supabase project | `bfaczcsrpfcbijoaeckb` |
| Supabase dashboard | https://supabase.com/dashboard/project/bfaczcsrpfcbijoaeckb |
| Railway dashboard | https://railway.app |
| Git main branch | `main` — auto-deploys to Railway on push |

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
  --dart-define=SUPABASE_URL=https://bfaczcsrpfcbijoaeckb.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon_key>

# Run all common tasks
just          # lists all available commands
just test     # flutter test
just analyze  # flutter analyze
just build    # flutter build web
just deploy   # trigger Railway deploy (manual)
```

See `Justfile` for full task list.

---

## Deploy

Railway auto-deploys from `main`. Push to main → CI runs → on success, Railway picks up the new commit and builds the Dockerfile.

**Manual deploy trigger:**
```bash
# Via Railway CLI
railway up

# Or trigger via GitHub Actions
gh workflow run deploy-supabase.yml
```

**Deploy checklist:**
1. CI green (`flutter analyze` + `flutter test`)
2. Push to `main`
3. Watch Railway dashboard for build progress
4. Verify prod URL loads within 60s of deploy finishing
5. Check `app_logs` for `app.cold_start` + `supabase.init_success` within 2 min

**If deploy fails:**
- Check Railway build logs: Railway dashboard → Deployments → latest
- Common cause: `flutter build web` failed — check Dockerfile asset validation lines
- Rollback: Railway dashboard → previous deployment → Redeploy

---

## Supabase Operations

### Connect

```bash
# Link CLI to prod project
supabase link --project-ref bfaczcsrpfcbijoaeckb

# Run a query against prod
supabase db query --linked "SELECT count(*) FROM v3_items"

# Or via API (useful in scripts)
curl -X POST \
  "https://api.supabase.com/v1/projects/bfaczcsrpfcbijoaeckb/database/query" \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query": "SELECT count(*) FROM v3_items"}'
```

### Apply migrations

```bash
# Check which migrations are pending
supabase migration list --linked

# Push pending migrations
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

-- Check recent app_logs (last 50)
SELECT session_id, user_id, category, event, data, created_at
FROM app_logs
ORDER BY created_at DESC
LIMIT 50;

-- Find all errors in the last hour
SELECT session_id, user_id, event, data, created_at
FROM app_logs
WHERE category = 'error'
  AND created_at > now() - interval '1 hour'
ORDER BY created_at DESC;

-- Find all sign-in errors in the last 24h
SELECT data->>'error_message'    AS error,
       data->>'supabase_code'    AS code,
       data->>'supabase_status'  AS status,
       count(*)                  AS occurrences
FROM app_logs
WHERE event = 'auth.sign_in_error'
  AND created_at > now() - interval '24 hours'
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

Use these against `app_logs` after releasing UI observability changes.

```sql
-- Jank events above threshold (>100ms) in last 24h
WITH parsed_jank AS (
  SELECT
    session_id,
    user_id,
    event,
    data->>'screen_name' AS screen_name,
    data,
    created_at,
    CASE
      WHEN jsonb_typeof(data->'build_duration_ms') = 'number'
        THEN (data->>'build_duration_ms')::numeric
      WHEN (data->>'build_duration_ms') ~ '^[0-9]+(\\.[0-9]+)?$'
        THEN (data->>'build_duration_ms')::numeric
      ELSE NULL
    END AS build_duration_ms
  FROM app_logs
  WHERE event = 'ui.widget.build_jank'
    AND created_at > now() - interval '24 hours'
)
SELECT session_id, user_id, screen_name, build_duration_ms, created_at, data
FROM parsed_jank
WHERE build_duration_ms > 100
ORDER BY build_duration_ms DESC, created_at DESC;

-- Interaction coverage by screen/widget/action in last 24h
SELECT
  COALESCE(data->>'screen_name', 'unknown') AS screen_name,
  COALESCE(data->>'widget_name', 'unknown') AS widget_name,
  COALESCE(data->>'action_type', 'unknown') AS action_type,
  count(*) AS events,
  count(DISTINCT session_id) AS sessions,
  max(created_at) AS last_seen_at
FROM app_logs
WHERE event = 'interaction.action'
  AND created_at > now() - interval '24 hours'
GROUP BY 1, 2, 3
ORDER BY events DESC, screen_name, widget_name, action_type;

-- Route/non-route navigation funnel pairs in last 24h
WITH nav AS (
  SELECT
    session_id,
    created_at,
    COALESCE(data->>'transition_type', 'unknown') AS transition_type,
    COALESCE(data->>'from_screen', lag(data->>'screen_name') OVER (
      PARTITION BY session_id
      ORDER BY created_at
    ), 'unknown') AS from_screen,
    COALESCE(data->>'to_screen', data->>'screen_name', 'unknown') AS to_screen
  FROM app_logs
  WHERE event LIKE 'navigation.%'
    AND created_at > now() - interval '24 hours'
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
  COALESCE(data->>'screen_name', 'unknown') AS screen_name,
  count(*) AS errors,
  count(DISTINCT session_id) AS sessions,
  max(created_at) AS last_seen_at
FROM app_logs
WHERE event = 'error.screen_boundary_caught'
  AND created_at > now() - interval '24 hours'
GROUP BY 1
ORDER BY errors DESC, screen_name;
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
4. Validate observability rows in Supabase using the queries above (`app_logs`, last 24h):
   - `interaction.action`
   - `navigation.%`
   - `ui.widget.build_jank`
   - `error.screen_boundary_caught`
5. Confirm route and non-route transitions both appear in navigation funnel results.
6. Confirm interaction coverage output includes expected `screen_name` / `widget_name` / `action_type` combinations for exercised flows.
7. Confirm no unexpected spikes in `error.screen_boundary_caught` for any single screen.
8. Confirm hierarchy navigation remains usable (no blocked transitions, no stuck level changes, no broken back-navigation).
9. Record the deploy SHA, validation timestamp, and any anomalies in the incident/deploy notes.

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
2. Check `app_logs` for `supabase.init_failure` events in the last hour
3. Check Supabase dashboard — is the project healthy? (Database → Health)
4. Check Railway build logs for any startup errors
5. If Supabase is down: users see "Couldn't connect" banner — this is expected behaviour

### Users can't log in

1. Query `app_logs` for `auth.sign_in_error` — what's the `supabase_code`?
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
4. Check `app_logs` for `items.fetch_error` — what's the `error_message`?

### Enrichment pipeline stalled

1. Check `process-enrichment-queue` function logs
2. Query: `SELECT count(*) FROM species WHERE icon_url IS NULL` — are candidates queued?
3. Check `PIPELINE_VERSION` env var — if it matches all enrichver stamps, nothing looks stale
4. Check Railway logs for the last deploy — did `PIPELINE_VERSION` change?
5. See postmortem: `docs/post-mortem.md`

### High error rate in app_logs

```sql
SELECT event, count(*) AS n
FROM app_logs
WHERE category = 'error'
  AND created_at > now() - interval '1 hour'
GROUP BY event
ORDER BY n DESC;
```

---

## Environment Variables

See `.env.example` for the full list. Required in Railway:

| Variable | Where set | Notes |
|----------|-----------|-------|
| `SUPABASE_URL` | Dockerfile (hardcoded) | Prod Supabase URL |
| `SUPABASE_ANON_KEY` | Dockerfile (hardcoded) | Public anon key — safe to commit |
| `SUPABASE_ACCESS_TOKEN` | Railway / GitHub secret | CLI auth — never commit |
| `PIPELINE_VERSION` | Set by deploy CI | Git short SHA — triggers enrichment rerun |

To rotate the anon key: update Dockerfile, push to main.
