-- Migration 021: pg_cron schedule + enrichment_events table for observability

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Enrichment event log for observability (queryable history of pipeline runs)
CREATE TABLE IF NOT EXISTS enrichment_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,         -- 'classification_success', 'classification_error', 'art_success', 'art_error', 'rate_limited', 'worker_run'
  definition_id TEXT,               -- species definition_id (null for worker_run events)
  provider_name TEXT,               -- LLM provider or 'gemini' for art
  asset_type TEXT,                  -- 'icon' or 'illustration' (art events only)
  duration_ms INTEGER,              -- operation duration
  error_message TEXT,               -- error detail (error events only)
  metadata JSONB,                   -- flexible extra data (summary counts, etc.)
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_enrichment_events_type ON enrichment_events (event_type);
CREATE INDEX IF NOT EXISTS idx_enrichment_events_created ON enrichment_events (created_at);
CREATE INDEX IF NOT EXISTS idx_enrichment_events_definition ON enrichment_events (definition_id) WHERE definition_id IS NOT NULL;

-- Auto-cleanup: keep 30 days of events
CREATE OR REPLACE FUNCTION cleanup_old_enrichment_events() RETURNS void AS $$
BEGIN
  DELETE FROM enrichment_events WHERE created_at < now() - interval '30 days';
END;
$$ LANGUAGE plpgsql;

-- RLS: service role only (Edge Function writes, no client access)
ALTER TABLE enrichment_events ENABLE ROW LEVEL SECURITY;
GRANT ALL ON enrichment_events TO service_role;

-- Schedule hourly enrichment queue processing
SELECT cron.schedule(
  'process-enrichment-queue',
  '0 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://bfaczcsrpfcbijoaeckb.supabase.co/functions/v1/process-enrichment-queue',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);

-- Schedule daily cleanup of old enrichment events
SELECT cron.schedule(
  'cleanup-enrichment-events',
  '0 3 * * *',
  $$ SELECT cleanup_old_enrichment_events(); $$
);
