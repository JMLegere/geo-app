-- 030_claimed_species.sql
-- Tracks globally unique extinct species claims.
-- Only one player can ever own each extinct/EW species in the system.

CREATE TABLE claimed_species (
  definition_id   TEXT        PRIMARY KEY,
  claimed_by      UUID        NOT NULL REFERENCES auth.users(id),
  claimed_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS: all authenticated users can read claims (needed for client-side cache)
ALTER TABLE claimed_species ENABLE ROW LEVEL SECURITY;

CREATE POLICY "claimed_species_select_authenticated"
  ON claimed_species FOR SELECT
  USING (auth.role() = 'authenticated');

-- INSERT only via service role (Edge Function uses service role key)
-- No INSERT policy needed — service role bypasses RLS

-- Index for "show me my claims" queries
CREATE INDEX idx_claimed_species_claimed_by ON claimed_species(claimed_by);
