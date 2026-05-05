-- ============================================================================
-- Migration 072: 14-day telemetry retention
-- ============================================================================
-- Observability is diagnostic, not permanent product data. Keep only the most
-- recent 14 days of OTel-shaped records so high-volume low-level telemetry stays
-- bounded in Supabase.
-- ============================================================================

CREATE OR REPLACE FUNCTION cleanup_old_telemetry()
RETURNS void AS $$
BEGIN
  DELETE FROM telemetry_logs
  WHERE occurred_at < now() - interval '14 days';

  DELETE FROM telemetry_spans
  WHERE started_at < now() - interval '14 days'
     OR created_at < now() - interval '14 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_namespace
    WHERE nspname = 'cron'
  ) AND EXISTS (
    SELECT 1
    FROM cron.job
    WHERE jobname = 'purge_old_telemetry'
  ) THEN
    PERFORM cron.unschedule('purge_old_telemetry');
  END IF;
END $$;

SELECT cron.schedule(
  'purge_old_telemetry',
  '0 3 * * *',
  $$SELECT cleanup_old_telemetry()$$
);
