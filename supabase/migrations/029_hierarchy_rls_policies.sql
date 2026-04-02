-- Migration 029: Add RLS read policies for hierarchy tables
--
-- Hierarchy tables (countries, states, cities, districts) are globally shared
-- reference data. RLS was enabled with no policies, causing all SELECT queries
-- from the app to return empty arrays silently — blocking district attribution
-- and showing "Territory unknown" in the cell info sheet.

-- Countries
CREATE POLICY "hierarchy_countries_read"
  ON countries FOR SELECT
  TO anon, authenticated
  USING (true);

-- States
CREATE POLICY "hierarchy_states_read"
  ON states FOR SELECT
  TO anon, authenticated
  USING (true);

-- Cities
CREATE POLICY "hierarchy_cities_read"
  ON cities FOR SELECT
  TO anon, authenticated
  USING (true);

-- Districts
CREATE POLICY "hierarchy_districts_read"
  ON districts FOR SELECT
  TO anon, authenticated
  USING (true);
