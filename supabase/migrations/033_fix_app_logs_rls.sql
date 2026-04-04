-- ============================================================================
-- Migration 033: Fix app_logs RLS for observability
-- ============================================================================
-- The v3 ObservabilityService writes events before auth completes (user_id is null).
-- RLS blocks these inserts silently. This policy allows anonymous inserts so
-- we can observe the full auth flow including sign-in attempts.
-- ============================================================================

-- Allow anyone to INSERT into app_logs (observability is fire-and-forget diagnostic data)
CREATE POLICY "app_logs_insert_anon"
  ON app_logs FOR INSERT
  WITH CHECK (true);

-- Users can still only SELECT their own rows (existing policy)
-- This policy is additive — doesn't change existing SELECT/UPDATE/DELETE policies.
