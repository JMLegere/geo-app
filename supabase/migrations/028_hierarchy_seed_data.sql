-- Seed hierarchy data: Canada > New Brunswick > Fredericton + Saint John
-- Test data so hierarchy screens render real content.

-- Country: Canada
INSERT INTO countries (id, name, centroid_lat, centroid_lon, continent, boundary_json)
VALUES (
  'country_ca',
  'Canada',
  56.1304,
  -106.3468,
  'northAmerica',
  NULL
) ON CONFLICT (id) DO NOTHING;

-- State: New Brunswick
INSERT INTO states (id, name, centroid_lat, centroid_lon, country_id, boundary_json)
VALUES (
  'state_nb',
  'New Brunswick',
  46.5653,
  -66.4619,
  'country_ca',
  NULL
) ON CONFLICT (id) DO NOTHING;

-- Cities
INSERT INTO cities (id, name, centroid_lat, centroid_lon, state_id, boundary_json, cells_total)
VALUES
  ('city_fredericton', 'Fredericton', 45.9636, -66.6431, 'state_nb', NULL, 6000),
  ('city_saintjohn', 'Saint John', 45.2733, -66.0633, 'state_nb', NULL, 4500),
  ('city_moncton', 'Moncton', 46.0878, -64.7782, 'state_nb', NULL, 5000)
ON CONFLICT (id) DO NOTHING;

-- Districts in Fredericton
INSERT INTO districts (id, name, centroid_lat, centroid_lon, city_id, boundary_json, cells_total, source, source_id)
VALUES
  ('dist_downtown_fred', 'Downtown', 45.9636, -66.6431, 'city_fredericton', NULL, 800, 'seed', NULL),
  ('dist_northside', 'North Side', 45.9750, -66.6300, 'city_fredericton', NULL, 900, 'seed', NULL),
  ('dist_southside', 'South Side', 45.9500, -66.6500, 'city_fredericton', NULL, 850, 'seed', NULL),
  ('dist_knowledge_park', 'Knowledge Park', 45.9450, -66.6200, 'city_fredericton', NULL, 700, 'seed', NULL),
  ('dist_skyline_acres', 'Skyline Acres', 45.9800, -66.6600, 'city_fredericton', NULL, 750, 'seed', NULL),
  ('dist_silverwood', 'Silverwood', 45.9550, -66.6700, 'city_fredericton', NULL, 600, 'seed', NULL),
  ('dist_hanwell', 'Hanwell', 45.9300, -66.7000, 'city_fredericton', NULL, 1400, 'seed', NULL)
ON CONFLICT (id) DO NOTHING;

-- Districts in Saint John
INSERT INTO districts (id, name, centroid_lat, centroid_lon, city_id, boundary_json, cells_total, source, source_id)
VALUES
  ('dist_uptown_sj', 'Uptown', 45.2733, -66.0633, 'city_saintjohn', NULL, 600, 'seed', NULL),
  ('dist_east_sj', 'East Side', 45.2800, -66.0400, 'city_saintjohn', NULL, 900, 'seed', NULL),
  ('dist_west_sj', 'West Side', 45.2650, -66.0900, 'city_saintjohn', NULL, 1000, 'seed', NULL),
  ('dist_millidgeville', 'Millidgeville', 45.3000, -66.0600, 'city_saintjohn', NULL, 800, 'seed', NULL),
  ('dist_rothesay', 'Rothesay', 45.3800, -65.9900, 'city_saintjohn', NULL, 1200, 'seed', NULL)
ON CONFLICT (id) DO NOTHING;

-- Districts in Moncton
INSERT INTO districts (id, name, centroid_lat, centroid_lon, city_id, boundary_json, cells_total, source, source_id)
VALUES
  ('dist_downtown_moncton', 'Downtown', 46.0878, -64.7782, 'city_moncton', NULL, 700, 'seed', NULL),
  ('dist_north_moncton', 'North End', 46.1100, -64.7900, 'city_moncton', NULL, 900, 'seed', NULL),
  ('dist_riverview', 'Riverview', 46.0600, -64.8100, 'city_moncton', NULL, 1100, 'seed', NULL),
  ('dist_dieppe', 'Dieppe', 46.0800, -64.6800, 'city_moncton', NULL, 1300, 'seed', NULL),
  ('dist_magnetic_hill', 'Magnetic Hill', 46.1200, -64.8500, 'city_moncton', NULL, 1000, 'seed', NULL)
ON CONFLICT (id) DO NOTHING;
