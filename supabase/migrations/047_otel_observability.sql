-- ============================================================================
-- Migration 047: OpenTelemetry-shaped observability source of truth
-- ============================================================================
-- True big-bang cutover:
--   - create canonical OTel-shaped logs + spans tables
--   - expose terminal-queryable views for common debugging paths
--   - remove the old app_logs/app_events compatibility surface
--   - do not backfill old operational telemetry
--
-- Clients do not insert into these tables directly. The app and browser beacon
-- path both send telemetry envelopes to the telemetry-ingest Edge Function,
-- which validates payloads and inserts with the service role.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Retire old operational telemetry and its retention job.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_namespace
    WHERE nspname = 'cron'
  ) AND EXISTS (
    SELECT 1
    FROM cron.job
    WHERE jobname = 'purge_old_app_logs'
  ) THEN
    PERFORM cron.unschedule('purge_old_app_logs');
  END IF;
END $$;

DROP FUNCTION IF EXISTS cleanup_old_events();
DROP TABLE IF EXISTS app_events CASCADE;
DROP TABLE IF EXISTS app_logs CASCADE;

CREATE TABLE telemetry_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- OTel LogRecord time fields.
  occurred_at timestamptz NOT NULL,
  observed_at timestamptz NOT NULL DEFAULT now(),

  -- OTel resource attributes flattened for simple terminal queries.
  service_name text NOT NULL DEFAULT 'earthnova-app',
  service_version text,
  deployment_environment text,
  platform text,

  -- Actor/session correlation.
  session_id uuid NOT NULL,
  device_id text,
  user_id uuid,

  -- Optional OTel trace linkage for logs emitted inside spans.
  trace_id text,
  span_id text,
  trace_flags text NOT NULL DEFAULT '01',

  -- Event/log payload.
  severity_text text NOT NULL DEFAULT 'INFO',
  category text NOT NULL,
  event_name text NOT NULL,
  body text,
  attributes jsonb NOT NULL DEFAULT '{}'::jsonb,
  dropped_attributes_count integer NOT NULL DEFAULT 0,

  CONSTRAINT telemetry_logs_trace_id_format
    CHECK (trace_id IS NULL OR trace_id ~ '^[0-9a-f]{32}$'),
  CONSTRAINT telemetry_logs_span_id_format
    CHECK (span_id IS NULL OR span_id ~ '^[0-9a-f]{16}$'),
  CONSTRAINT telemetry_logs_trace_flags_format
    CHECK (trace_flags ~ '^[0-9a-f]{2}$'),
  CONSTRAINT telemetry_logs_severity_text_known
    CHECK (severity_text IN ('TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL')),
  CONSTRAINT telemetry_logs_attributes_object
    CHECK (jsonb_typeof(attributes) = 'object'),
  CONSTRAINT telemetry_logs_dropped_attributes_nonnegative
    CHECK (dropped_attributes_count >= 0)
);

CREATE TABLE telemetry_spans (
  -- OTel span identity.
  trace_id text NOT NULL,
  span_id text NOT NULL,
  parent_span_id text,

  -- OTel span naming/kind.
  span_name text NOT NULL,
  span_kind text NOT NULL DEFAULT 'internal',

  -- Timing. duration_ms is generated so queries cannot drift from timestamps.
  started_at timestamptz NOT NULL,
  ended_at timestamptz,
  duration_ms bigint GENERATED ALWAYS AS (
    CASE
      WHEN ended_at IS NULL THEN NULL
      ELSE GREATEST(
        0,
        floor(EXTRACT(EPOCH FROM (ended_at - started_at)) * 1000)::bigint
      )
    END
  ) STORED,

  -- OTel span status.
  status_code text NOT NULL DEFAULT 'unset',
  status_message text,

  -- OTel resource attributes flattened for simple terminal queries.
  service_name text NOT NULL DEFAULT 'earthnova-app',
  service_version text,
  deployment_environment text,
  platform text,

  -- Actor/session correlation.
  session_id uuid NOT NULL,
  device_id text,
  user_id uuid,

  -- Span payload.
  attributes jsonb NOT NULL DEFAULT '{}'::jsonb,
  events jsonb NOT NULL DEFAULT '[]'::jsonb,
  dropped_attributes_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),

  PRIMARY KEY (trace_id, span_id),

  CONSTRAINT telemetry_spans_trace_id_format
    CHECK (trace_id ~ '^[0-9a-f]{32}$'),
  CONSTRAINT telemetry_spans_span_id_format
    CHECK (span_id ~ '^[0-9a-f]{16}$'),
  CONSTRAINT telemetry_spans_parent_span_id_format
    CHECK (parent_span_id IS NULL OR parent_span_id ~ '^[0-9a-f]{16}$'),
  CONSTRAINT telemetry_spans_kind_known
    CHECK (span_kind IN ('internal', 'client', 'server', 'producer', 'consumer')),
  CONSTRAINT telemetry_spans_status_code_known
    CHECK (status_code IN ('unset', 'ok', 'error')),
  CONSTRAINT telemetry_spans_ended_after_started
    CHECK (ended_at IS NULL OR ended_at >= started_at),
  CONSTRAINT telemetry_spans_attributes_object
    CHECK (jsonb_typeof(attributes) = 'object'),
  CONSTRAINT telemetry_spans_events_array
    CHECK (jsonb_typeof(events) = 'array'),
  CONSTRAINT telemetry_spans_dropped_attributes_nonnegative
    CHECK (dropped_attributes_count >= 0)
);

-- Query indexes: time/session/trace first, then common event/error lookups.
CREATE INDEX idx_telemetry_logs_occurred_at
  ON telemetry_logs (occurred_at DESC);
CREATE INDEX idx_telemetry_logs_session_time
  ON telemetry_logs (session_id, occurred_at DESC);
CREATE INDEX idx_telemetry_logs_trace_time
  ON telemetry_logs (trace_id, occurred_at DESC)
  WHERE trace_id IS NOT NULL;
CREATE INDEX idx_telemetry_logs_event_time
  ON telemetry_logs (event_name, occurred_at DESC);
CREATE INDEX idx_telemetry_logs_category_time
  ON telemetry_logs (category, occurred_at DESC);
CREATE INDEX idx_telemetry_logs_user_time
  ON telemetry_logs (user_id, occurred_at DESC)
  WHERE user_id IS NOT NULL;
CREATE INDEX idx_telemetry_logs_severity_time
  ON telemetry_logs (severity_text, occurred_at DESC);
CREATE INDEX idx_telemetry_logs_attributes_gin
  ON telemetry_logs USING gin (attributes);

CREATE INDEX idx_telemetry_spans_started_at
  ON telemetry_spans (started_at DESC);
CREATE INDEX idx_telemetry_spans_session_time
  ON telemetry_spans (session_id, started_at DESC);
CREATE INDEX idx_telemetry_spans_trace_tree
  ON telemetry_spans (trace_id, parent_span_id, started_at);
CREATE INDEX idx_telemetry_spans_name_time
  ON telemetry_spans (span_name, started_at DESC);
CREATE INDEX idx_telemetry_spans_status_time
  ON telemetry_spans (status_code, started_at DESC);
CREATE INDEX idx_telemetry_spans_user_time
  ON telemetry_spans (user_id, started_at DESC)
  WHERE user_id IS NOT NULL;
CREATE INDEX idx_telemetry_spans_attributes_gin
  ON telemetry_spans USING gin (attributes);

ALTER TABLE telemetry_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemetry_spans ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE telemetry_logs IS
  'OpenTelemetry-shaped log records. Insert only through telemetry-ingest Edge Function/service role.';
COMMENT ON TABLE telemetry_spans IS
  'OpenTelemetry-shaped spans. Insert only through telemetry-ingest Edge Function/service role.';

-- Terminal-friendly timeline view: one ordered shape for both logs and spans.
CREATE VIEW telemetry_session_timeline_v AS
SELECT
  l.occurred_at AS event_at,
  'log'::text AS signal_type,
  l.session_id,
  l.user_id,
  l.trace_id,
  l.span_id,
  NULL::text AS parent_span_id,
  l.event_name AS name,
  l.category,
  l.severity_text AS status_or_severity,
  l.body,
  l.attributes,
  NULL::bigint AS duration_ms
FROM telemetry_logs l
UNION ALL
SELECT
  s.started_at AS event_at,
  'span'::text AS signal_type,
  s.session_id,
  s.user_id,
  s.trace_id,
  s.span_id,
  s.parent_span_id,
  s.span_name AS name,
  NULL::text AS category,
  s.status_code AS status_or_severity,
  s.status_message AS body,
  s.attributes,
  s.duration_ms
FROM telemetry_spans s;

CREATE VIEW telemetry_recent_errors_v AS
SELECT
  l.occurred_at AS error_at,
  'log'::text AS signal_type,
  l.session_id,
  l.user_id,
  l.trace_id,
  l.span_id,
  l.event_name AS name,
  l.category,
  l.severity_text AS severity_or_status,
  l.body,
  l.attributes
FROM telemetry_logs l
WHERE l.severity_text IN ('ERROR', 'FATAL')
   OR l.category = 'error'
UNION ALL
SELECT
  s.ended_at AS error_at,
  'span'::text AS signal_type,
  s.session_id,
  s.user_id,
  s.trace_id,
  s.span_id,
  s.span_name AS name,
  NULL::text AS category,
  s.status_code AS severity_or_status,
  s.status_message AS body,
  s.attributes
FROM telemetry_spans s
WHERE s.status_code = 'error';

CREATE VIEW telemetry_startup_funnel_v AS
SELECT
  l.session_id,
  l.user_id,
  l.trace_id,
  min(l.occurred_at) FILTER (WHERE l.event_name = 'app.cold_start')
    AS cold_start_at,
  min(l.occurred_at) FILTER (WHERE l.event_name = 'supabase.init_success')
    AS supabase_init_success_at,
  min(l.occurred_at) FILTER (WHERE l.event_name = 'auth.session_restore_started')
    AS auth_restore_started_at,
  min(l.occurred_at) FILTER (WHERE l.event_name = 'auth.session_restored')
    AS auth_restored_at,
  min(l.occurred_at) FILTER (WHERE l.event_name = 'map.gps_started')
    AS map_gps_started_at,
  min(l.occurred_at) FILTER (WHERE l.event_name = 'map.map_created')
    AS map_created_at,
  min(l.occurred_at) FILTER (WHERE l.event_name = 'map.style_loaded')
    AS map_style_loaded_at,
  min(l.occurred_at) FILTER (WHERE l.event_name = 'map.base_map_settled')
    AS base_map_settled_at,
  min(l.occurred_at) FILTER (WHERE l.event_name = 'map.cells_fetch_complete')
    AS cells_fetch_complete_at,
  min(l.occurred_at) FILTER (WHERE l.event_name = 'map.steady_state_ready')
    AS steady_state_ready_at,
  (
    count(*) FILTER (WHERE l.event_name = 'app.cold_start') > 0
  ) AS saw_cold_start,
  (
    count(*) FILTER (WHERE l.event_name = 'auth.session_restored') > 0
  ) AS saw_auth_restored,
  (
    count(*) FILTER (WHERE l.event_name = 'map.steady_state_ready') > 0
  ) AS saw_steady_state_ready
FROM telemetry_logs l
WHERE l.event_name IN (
  'app.cold_start',
  'supabase.init_success',
  'auth.session_restore_started',
  'auth.session_restored',
  'map.gps_started',
  'map.map_created',
  'map.style_loaded',
  'map.base_map_settled',
  'map.cells_fetch_complete',
  'map.steady_state_ready'
)
GROUP BY l.session_id, l.user_id, l.trace_id;

CREATE VIEW telemetry_map_readiness_v AS
SELECT
  l.session_id,
  l.user_id,
  l.trace_id,
  min(l.occurred_at) FILTER (WHERE l.event_name = 'map.gps_started')
    AS gps_started_at,
  min(l.occurred_at) FILTER (WHERE l.event_name = 'map.map_created')
    AS map_created_at,
  min(l.occurred_at) FILTER (WHERE l.event_name = 'map.style_loaded')
    AS style_loaded_at,
  min(l.occurred_at) FILTER (WHERE l.event_name = 'map.base_map_settled')
    AS base_map_settled_at,
  min(l.occurred_at) FILTER (WHERE l.event_name = 'map.cells_fetch_complete')
    AS cells_fetch_complete_at,
  min(l.occurred_at) FILTER (WHERE l.event_name = 'map.overlay_frame_painted')
    AS overlay_frame_painted_at,
  min(l.occurred_at) FILTER (WHERE l.event_name = 'map.steady_state_ready')
    AS steady_state_ready_at,
  jsonb_agg(
    jsonb_build_object(
      'event_name', l.event_name,
      'occurred_at', l.occurred_at,
      'attributes', l.attributes
    ) ORDER BY l.occurred_at
  ) AS readiness_events
FROM telemetry_logs l
WHERE l.event_name IN (
  'map.gps_started',
  'map.map_created',
  'map.style_loaded',
  'map.base_map_settled',
  'map.cells_fetch_complete',
  'map.overlay_frame_painted',
  'map.steady_state_ready'
)
GROUP BY l.session_id, l.user_id, l.trace_id;

CREATE OR REPLACE FUNCTION cleanup_old_telemetry()
RETURNS void AS $$
BEGIN
  DELETE FROM telemetry_logs
  WHERE occurred_at < now() - interval '30 days';

  DELETE FROM telemetry_spans
  WHERE started_at < now() - interval '30 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

SELECT cron.schedule(
  'purge_old_telemetry',
  '0 3 * * *',
  $$SELECT cleanup_old_telemetry()$$
);
