-- Allow beta-scale organic Voronoi validation to complete under Supabase defaults.
--
-- The topology validator intentionally does full spatial validation before publish.
-- Organic Voronoi polygons are more complex than the temporary square lattice, so
-- the overlap pass can exceed the platform default statement timeout even when it
-- passes. Keep the validation gate intact, but give the function enough time for
-- the current beta-scale 7,820-cell source-version.

ALTER FUNCTION validate_cell_geometry_source_version(
  TEXT,
  DOUBLE PRECISION,
  DOUBLE PRECISION
) SET statement_timeout = '600s';
