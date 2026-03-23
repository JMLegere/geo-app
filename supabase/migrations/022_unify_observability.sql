-- ============================================================================
-- Unify observability into app_logs
-- ============================================================================
-- Merges app_events into app_logs. All client observability now flows through
-- one table: debugPrint → DebugLogBuffer → LogFlushService → app_logs.
-- Structured events get text representation in `lines`; optional `event` and
-- `data` columns exist for backend use (Edge Functions).

-- 1. Add structured event columns to app_logs (nullable — text-only rows omit them).
ALTER TABLE app_logs ADD COLUMN IF NOT EXISTS category text;
ALTER TABLE app_logs ADD COLUMN IF NOT EXISTS event text;
ALTER TABLE app_logs ADD COLUMN IF NOT EXISTS data jsonb;

-- 2. Add indexes for structured queries and session correlation.
CREATE INDEX IF NOT EXISTS idx_app_logs_event ON app_logs (event, created_at);
CREATE INDEX IF NOT EXISTS idx_app_logs_session ON app_logs (session_id, created_at);

-- 3. 7-day retention — purge old rows daily at 3am UTC.
SELECT cron.schedule(
  'purge_old_app_logs',
  '0 3 * * *',
  $$DELETE FROM app_logs WHERE created_at < now() - interval '7 days'$$
);

-- 4. Drop app_events — all data now lives in app_logs.
--    Note: existing app_events data is NOT migrated (it's operational telemetry,
--    not permanent data). The oldest rows are only 8 days old.
DROP TABLE IF EXISTS app_events;
