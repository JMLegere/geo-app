CREATE OR REPLACE FUNCTION diagnose_staged_geometry_overlap_window(
  p_source_version TEXT,
  p_focus_lat DOUBLE PRECISION,
  p_focus_lng DOUBLE PRECISION,
  p_focus_radius_meters DOUBLE PRECISION DEFAULT 1500.0
)
RETURNS TABLE (
  cell_count INTEGER,
  overlap_pair_count INTEGER,
  total_overlap_area_m2 DOUBLE PRECISION,
  max_overlap_area_m2 DOUBLE PRECISION
)
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH focus_point AS (
    SELECT ST_SetSRID(ST_MakePoint(p_focus_lng, p_focus_lat), 4326)::geography AS geom
  ), local_rows AS (
    SELECT
      staging.id,
      staging.cell_id,
      staging.parsed_geom,
      staging.parsed_centroid
    FROM cell_geometry_staging staging
    CROSS JOIN focus_point focus
    WHERE staging.source_version = p_source_version
      AND staging.validation_status IN ('pending', 'valid', 'warning')
      AND staging.parsed_geom IS NOT NULL
      AND staging.parsed_centroid IS NOT NULL
      AND ST_DWithin(staging.parsed_centroid::geography, focus.geom, p_focus_radius_meters)
  ), raw_overlap_rows AS (
    SELECT
      a.cell_id,
      b.cell_id AS related_cell_id,
      ST_Area(ST_Intersection(a.parsed_geom, b.parsed_geom)::geography) AS overlap_area_m2
    FROM local_rows a
    JOIN local_rows b
      ON a.id < b.id
     AND ST_Intersects(a.parsed_geom, b.parsed_geom)
  ), overlap_rows AS (
    SELECT *
    FROM raw_overlap_rows
    WHERE overlap_area_m2 > 0
  )
  SELECT
    (SELECT COUNT(*)::INTEGER FROM local_rows) AS cell_count,
    COUNT(*)::INTEGER AS overlap_pair_count,
    COALESCE(SUM(overlap_area_m2), 0) AS total_overlap_area_m2,
    COALESCE(MAX(overlap_area_m2), 0) AS max_overlap_area_m2
  FROM overlap_rows;
$$;

GRANT EXECUTE ON FUNCTION diagnose_staged_geometry_overlap_window(
  TEXT,
  DOUBLE PRECISION,
  DOUBLE PRECISION,
  DOUBLE PRECISION
) TO service_role;
