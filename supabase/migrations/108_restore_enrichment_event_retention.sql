-- Restore migration 021's 30-day enrichment diagnostic retention.
-- Applying this migration restores scheduling without running cleanup now.
CREATE OR REPLACE FUNCTION public.cleanup_old_enrichment_events()
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog
AS $$
BEGIN
  DELETE FROM public.enrichment_events
  WHERE created_at < now() - interval '30 days';
END;
$$;

ALTER FUNCTION public.cleanup_old_enrichment_events() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.cleanup_old_enrichment_events()
  FROM PUBLIC, anon, authenticated;

-- Named pg_cron schedules upsert for the same migration role.
-- 03:00 follows the server's configured cron.timezone.
SELECT cron.schedule(
  'cleanup-enrichment-events',
  '0 3 * * *',
  $$ SELECT public.cleanup_old_enrichment_events(); $$
);
