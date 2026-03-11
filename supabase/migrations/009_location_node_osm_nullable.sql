-- Fix location_nodes: make osm_id nullable, change id from UUID to TEXT.
-- osm_id is null for synthetic nodes (world, continent).
-- id uses deterministic slug format (e.g. "country_canada") for idempotent upserts.

-- Drop FK constraint from cell_properties first
ALTER TABLE cell_properties DROP CONSTRAINT IF EXISTS cell_properties_location_id_fkey;

-- Recreate location_nodes with TEXT primary key and nullable osm_id
DROP TABLE IF EXISTS location_nodes CASCADE;

CREATE TABLE location_nodes (
  id              TEXT PRIMARY KEY,
  osm_id          BIGINT UNIQUE,
  name            TEXT NOT NULL,
  admin_level     TEXT NOT NULL,
  parent_id       TEXT REFERENCES location_nodes(id),
  color_hex       TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_location_nodes_parent ON location_nodes(parent_id);
CREATE INDEX idx_location_nodes_osm ON location_nodes(osm_id) WHERE osm_id IS NOT NULL;

-- Restore FK on cell_properties (now TEXT → TEXT)
ALTER TABLE cell_properties
  ALTER COLUMN location_id TYPE TEXT,
  ADD CONSTRAINT cell_properties_location_id_fkey
    FOREIGN KEY (location_id) REFERENCES location_nodes(id);

-- RLS
ALTER TABLE location_nodes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read location nodes"
  ON location_nodes FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Service role can manage location nodes"
  ON location_nodes FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
