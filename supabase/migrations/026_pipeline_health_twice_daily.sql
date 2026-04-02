-- ============================================================================
-- Slow pipeline health check to twice daily: 9am + 9pm AST (13:00 + 01:00 UTC)
-- ============================================================================

SELECT cron.unschedule('pipeline_health_hourly');

SELECT cron.schedule(
  'pipeline_health_twice_daily',
  '0 1,13 * * *',
  $$SELECT net.http_post(
    url := 'https://bfaczcsrpfcbijoaeckb.supabase.co/functions/v1/pipeline-health',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
    ),
    body := '{}'::jsonb
  )$$
);
