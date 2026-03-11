-- Cell properties & location hierarchy for the cell properties system.
-- Cell properties are global (not per-user) — first discoverer writes them.
-- Location nodes form a hierarchy: World > Continent > Country > State > City > District.

-- Location hierarchy: admin boundaries from OSM (Nominatim)
CREATE TABLE location_nodes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  osm_id          BIGINT UNIQUE NOT NULL,
  name            TEXT NOT NULL,
  admin_level     TEXT NOT NULL,          -- AdminLevel enum: world, continent, country, state, city, district
  parent_id       UUID REFERENCES location_nodes(id),
  color_hex       TEXT,                   -- Primary flag color hex, or null for deterministic random
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_location_nodes_parent ON location_nodes(parent_id);
CREATE INDEX idx_location_nodes_osm ON location_nodes(osm_id);

-- Cell properties: permanent geo-derived facts, globally shared
CREATE TABLE cell_properties (
  cell_id         TEXT PRIMARY KEY,
  habitats        TEXT[] NOT NULL,        -- e.g. {'forest', 'freshwater'}
  climate         TEXT NOT NULL,          -- Climate enum name
  continent       TEXT NOT NULL,          -- Continent enum name
  location_id     UUID REFERENCES location_nodes(id),  -- nullable, backfilled async via Nominatim
  created_by      UUID REFERENCES auth.users NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_cell_properties_location ON cell_properties(location_id);

-- RLS: cell_properties are readable by all authenticated users,
-- writable only by the first discoverer (insert-only, no updates except location_id backfill).
ALTER TABLE cell_properties ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read cell properties"
  ON cell_properties FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert cell properties"
  ON cell_properties FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = created_by);

-- Allow location_id backfill by service role (Edge Function)
CREATE POLICY "Service role can update location_id"
  ON cell_properties FOR UPDATE
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Location nodes: readable by all, writable by service role only (Edge Function creates these)
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
