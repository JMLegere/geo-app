-- EarthNova Phase 3 — Server-Authoritative Persistence
-- daily_seeds table for server-side encounter validation.
-- The write queue itself is client-only (SQLite) — no server table needed.

-- ---------------------------------------------------------------------------
-- daily_seeds — One row per calendar day (midnight GMT).
-- Server generates a random seed each day. Client caches on app open.
-- Used to deterministically re-derive encounters for validation.
-- ---------------------------------------------------------------------------

CREATE TABLE daily_seeds (
  seed_date  DATE PRIMARY KEY,              -- Calendar day (UTC)
  seed_value TEXT NOT NULL,                  -- Random hex string (32 chars)
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS: all authenticated users can read seeds; only service_role writes.
ALTER TABLE daily_seeds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "daily_seeds_select_authenticated"
  ON daily_seeds FOR SELECT
  USING (auth.role() = 'authenticated');

-- service_role bypasses RLS by default — no explicit insert policy needed.

-- Auto-generate today's seed if it doesn't exist (called by Edge Function).
-- This is a convenience function — the Edge Function is the primary writer.
CREATE OR REPLACE FUNCTION public.ensure_daily_seed()
RETURNS TEXT AS $$
DECLARE
  today DATE := CURRENT_DATE;
  existing TEXT;
  new_seed TEXT;
BEGIN
  SELECT seed_value INTO existing FROM daily_seeds WHERE seed_date = today;
  IF existing IS NOT NULL THEN
    RETURN existing;
  END IF;

  new_seed := encode(gen_random_bytes(16), 'hex');
  INSERT INTO daily_seeds (seed_date, seed_value)
    VALUES (today, new_seed)
    ON CONFLICT (seed_date) DO NOTHING;

  -- Re-read in case of race condition.
  SELECT seed_value INTO existing FROM daily_seeds WHERE seed_date = today;
  RETURN existing;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
