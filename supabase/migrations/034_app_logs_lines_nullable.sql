-- ============================================================================
-- Migration 034: Make app_logs.lines nullable for v3
-- ============================================================================
-- v3 ObservabilityService writes structured events (category/event/data) and
-- never sends the `lines` column (a v2 DebugLogBuffer text dump).
-- The NOT NULL constraint on `lines` causes every v3 flush to fail silently:
--
--   PostgrestException: null value in column "lines" of relation "app_logs"
--   violates not-null constraint
--
-- This means ZERO observability in prod since v3 launched.
-- Fix: make `lines` nullable. v3 rows will have lines=NULL. Old v2 rows
-- keep their existing text data.
-- ============================================================================

ALTER TABLE app_logs ALTER COLUMN lines DROP NOT NULL;
