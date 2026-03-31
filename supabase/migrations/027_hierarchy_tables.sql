-- District hierarchy tables (Phase 2)
-- 4 tables replacing the flat location_nodes table with a proper geographic hierarchy.
-- See docs/district-hierarchy-design.md for full design.

-- Countries (pre-populated from Natural Earth)
CREATE TABLE IF NOT EXISTS countries (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  centroid_lat DOUBLE PRECISION NOT NULL,
  centroid_lon DOUBLE PRECISION NOT NULL,
  continent TEXT NOT NULL,
  boundary_json TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- States / Provinces / Regions
CREATE TABLE IF NOT EXISTS states (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  centroid_lat DOUBLE PRECISION NOT NULL,
  centroid_lon DOUBLE PRECISION NOT NULL,
  country_id TEXT NOT NULL REFERENCES countries(id),
  boundary_json TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Cities / Localities
CREATE TABLE IF NOT EXISTS cities (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  centroid_lat DOUBLE PRECISION NOT NULL,
  centroid_lon DOUBLE PRECISION NOT NULL,
  state_id TEXT NOT NULL REFERENCES states(id),
  boundary_json TEXT,
  cells_total INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Districts / Neighbourhoods
CREATE TABLE IF NOT EXISTS districts (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  centroid_lat DOUBLE PRECISION NOT NULL,
  centroid_lon DOUBLE PRECISION NOT NULL,
  city_id TEXT NOT NULL REFERENCES cities(id),
  boundary_json TEXT,
  cells_total INT,
  source TEXT NOT NULL DEFAULT 'whosonfirst',
  source_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indices for hierarchy lookups
CREATE INDEX IF NOT EXISTS idx_districts_city ON districts(city_id);
CREATE INDEX IF NOT EXISTS idx_districts_centroid ON districts(centroid_lat, centroid_lon);
CREATE INDEX IF NOT EXISTS idx_cities_state ON cities(state_id);
CREATE INDEX IF NOT EXISTS idx_states_country ON states(country_id);
