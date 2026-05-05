-- ============================================================================
-- Migration 048: Terminal-agent lifecycle diagnostics
-- ============================================================================
-- Adds opinionated SQL surfaces over OTel-shaped telemetry so agents can query
-- flow progress, missing terminal events, and dependency failures without
-- scraping raw JSON logs by hand.
-- ============================================================================

CREATE OR REPLACE VIEW telemetry_flow_lifecycle_v AS
SELECT
  l.occurred_at AS event_at,
  l.session_id,
  l.user_id,
  l.trace_id,
  l.span_id,
  l.category,
  l.event_name,
  l.severity_text,
  l.attributes->>'flow' AS flow,
  l.attributes->>'phase' AS phase,
  l.attributes->>'dependency' AS dependency,
  l.attributes->>'previous_state' AS previous_state,
  l.attributes->>'next_state' AS next_state,
  l.attributes->>'reason' AS reason,
  l.body,
  l.attributes
FROM telemetry_logs l
WHERE l.attributes ? 'flow'
   OR l.attributes ? 'phase';

CREATE OR REPLACE VIEW telemetry_incomplete_flows_v AS
WITH flow_events AS (
  SELECT *
  FROM telemetry_flow_lifecycle_v
  WHERE flow IS NOT NULL
    AND phase IS NOT NULL
), summaries AS (
  SELECT
    session_id,
    user_id,
    trace_id,
    flow,
    min(event_at) AS first_event_at,
    max(event_at) AS last_event_at,
    (array_agg(phase ORDER BY event_at DESC))[1] AS last_phase,
    COALESCE(
      array_remove(
        array_agg(DISTINCT dependency)
          FILTER (WHERE phase = 'waiting_on' AND dependency IS NOT NULL),
        NULL
      ),
      ARRAY[]::text[]
    ) AS waiting_on_dependencies,
    bool_or(phase = 'started') AS saw_started,
    bool_or(phase IN ('completed', 'failed', 'timed_out', 'cancelled'))
      AS saw_terminal,
    jsonb_agg(
      jsonb_build_object(
        'event_at', event_at,
        'event_name', event_name,
        'phase', phase,
        'dependency', dependency,
        'reason', reason
      ) ORDER BY event_at
    ) AS lifecycle_events
  FROM flow_events
  GROUP BY session_id, user_id, trace_id, flow
)
SELECT *
FROM summaries
WHERE saw_started
  AND NOT saw_terminal
  AND last_event_at < now() - interval '30 seconds';

CREATE OR REPLACE VIEW telemetry_dependency_failures_v AS
SELECT
  event_at,
  session_id,
  user_id,
  trace_id,
  span_id,
  flow,
  dependency,
  event_name,
  severity_text,
  reason,
  body,
  attributes
FROM telemetry_flow_lifecycle_v
WHERE phase = 'dependency_failed'
   OR (phase = 'failed' AND dependency IS NOT NULL);
