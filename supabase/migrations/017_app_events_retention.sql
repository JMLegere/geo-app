-- 30-day rolling retention for app_events.
-- Performance events (high volume) retained for 7 days.
-- Run via pg_cron or Supabase scheduled function.

CREATE OR REPLACE FUNCTION cleanup_old_events()
RETURNS void AS $$
BEGIN
  DELETE FROM app_events
  WHERE category = 'performance'
    AND created_at < now() - interval '7 days';

  DELETE FROM app_events
  WHERE category != 'performance'
    AND created_at < now() - interval '30 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
