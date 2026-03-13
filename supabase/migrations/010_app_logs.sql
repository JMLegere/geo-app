-- App observability logs: rolling 7-day window of client debug output.
-- Flushed every 30s from DebugLogBuffer + on app background.

CREATE TABLE IF NOT EXISTS app_logs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid,
  session_id uuid NOT NULL,
  lines text NOT NULL,
  app_version text,
  platform text,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- Indexes for purge and session queries
CREATE INDEX idx_app_logs_created_at ON app_logs (created_at);
CREATE INDEX idx_app_logs_session_id ON app_logs (session_id);

-- RLS: authenticated users (including anonymous) can insert.
-- Service role bypasses RLS for reads (agent queries).
ALTER TABLE app_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "insert_logs" ON app_logs
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- Daily purge of entries older than 7 days.
-- Run manually or enable pg_cron extension:
--   SELECT cron.schedule('purge-old-app-logs', '0 3 * * *',
--     $$DELETE FROM app_logs WHERE created_at < now() - interval '7 days'$$);
--
-- Manual purge:
--   DELETE FROM app_logs WHERE created_at < now() - interval '7 days';
