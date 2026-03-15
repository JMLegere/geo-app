-- Structured event table for observability, session reconstruction, and analytics.
-- Companion to app_logs (raw debug text). Events are typed with JSONB payloads.

CREATE TABLE app_events (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id  text NOT NULL,
  user_id     uuid,
  device_id   text,
  category    text NOT NULL,
  event       text NOT NULL,
  data        jsonb DEFAULT '{}'::jsonb,
  created_at  timestamptz DEFAULT now() NOT NULL
);

CREATE INDEX idx_app_events_session ON app_events (session_id, created_at);
CREATE INDEX idx_app_events_category ON app_events (category, event);
CREATE INDEX idx_app_events_user ON app_events (user_id, created_at);

ALTER TABLE app_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "authenticated_insert_events"
  ON app_events FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "anon_insert_events"
  ON app_events FOR INSERT TO anon
  WITH CHECK (true);
