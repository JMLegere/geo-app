-- ============================================================================
-- Schedule hourly pipeline health check via pg_cron
-- ============================================================================
-- Invokes the pipeline-health Edge Function every hour at minute 30.
-- Sends a ntfy push notification with enrichment stats + stall detection.

SELECT cron.schedule(
  'pipeline_health_hourly',
  '30 * * * *',
  $$SELECT net.http_post(
    url := 'https://bfaczcsrpfcbijoaeckb.supabase.co/functions/v1/pipeline-health',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
    ),
    body := '{}'::jsonb
  )$$
);
