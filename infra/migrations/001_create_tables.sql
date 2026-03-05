BEGIN;

CREATE TABLE IF NOT EXISTS profiles (
  id              text PRIMARY KEY,
  display_name    text,
  current_streak  integer NOT NULL DEFAULT 0,
  longest_streak  integer NOT NULL DEFAULT 0,
  total_distance_km double precision NOT NULL DEFAULT 0,
  current_season  text,
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cell_progress (
  user_id           text NOT NULL,
  cell_id           text NOT NULL,
  fog_state         text NOT NULL DEFAULT 'undetected',
  distance_walked   double precision NOT NULL DEFAULT 0,
  visit_count       integer NOT NULL DEFAULT 0,
  restoration_level double precision NOT NULL DEFAULT 0,
  last_visited      timestamptz,
  updated_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, cell_id)
);

CREATE TABLE IF NOT EXISTS collected_species (
  user_id      text NOT NULL,
  species_id   text NOT NULL,
  cell_id      text NOT NULL,
  collected_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, species_id, cell_id)
);

CREATE INDEX IF NOT EXISTS idx_cell_progress_user ON cell_progress (user_id);
CREATE INDEX IF NOT EXISTS idx_collected_species_user ON collected_species (user_id);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE cell_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE collected_species ENABLE ROW LEVEL SECURITY;

CREATE POLICY profiles_owner ON profiles
  FOR ALL USING (auth.uid()::text = id)
  WITH CHECK (auth.uid()::text = id);

CREATE POLICY cell_progress_owner ON cell_progress
  FOR ALL USING (auth.uid()::text = user_id)
  WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY collected_species_owner ON collected_species
  FOR ALL USING (auth.uid()::text = user_id)
  WITH CHECK (auth.uid()::text = user_id);

COMMIT;
