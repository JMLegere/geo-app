-- DB-side geometry staging from encoded cell IDs.
--
-- This avoids uploading a huge geometry artifact through the Supabase
-- Management API. It derives the current v_<x>_<y> lattice centers directly
-- from cell_properties and stages the bounded point-Voronoi square implied by
-- each encoded center.

CREATE OR REPLACE FUNCTION stage_cell_geometry_from_cell_ids(
  p_source_version TEXT,
  p_source TEXT DEFAULT 'db-lattice-voronoi-from-cell-id-centers'
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expected_cell_count INTEGER;
  v_staged_count INTEGER;
  v_coverage_geom geometry(MultiPolygon, 4326);
BEGIN
  IF p_source_version IS NULL OR btrim(p_source_version) = '' THEN
    RAISE EXCEPTION 'source_version is required';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM cell_geometry_active_version active
    WHERE active.source_version = p_source_version
  ) OR EXISTS (
    SELECT 1
    FROM cell_geometry_cells cells
    WHERE cells.source_version = p_source_version
  ) THEN
    RAISE EXCEPTION 'Cannot restage source_version % with active or canonical geometry rows', p_source_version;
  END IF;

  SELECT COUNT(*)::INTEGER
  INTO v_expected_cell_count
  FROM cell_properties
  WHERE cell_id ~ '^v_-?[0-9]+_-?[0-9]+$';

  IF v_expected_cell_count = 0 THEN
    RAISE EXCEPTION 'No encoded v_<x>_<y> cell_properties rows found';
  END IF;

  WITH parsed AS (
    SELECT
      cell_id,
      split_part(cell_id, '_', 2)::INTEGER AS grid_x,
      split_part(cell_id, '_', 3)::INTEGER AS grid_y,
      split_part(cell_id, '_', 2)::DOUBLE PRECISION / 500.0 AS center_lat,
      split_part(cell_id, '_', 3)::DOUBLE PRECISION / 500.0 AS center_lng
    FROM cell_properties
    WHERE cell_id ~ '^v_-?[0-9]+_-?[0-9]+$'
  ), squares AS (
    SELECT
      cell_id,
      ST_MakeEnvelope(
        center_lng - (0.5 / 500.0),
        center_lat - (0.5 / 500.0),
        center_lng + (0.5 / 500.0),
        center_lat + (0.5 / 500.0),
        4326
      ) AS geom
    FROM parsed
  )
  SELECT ST_Multi(ST_UnaryUnion(ST_Collect(geom)))::geometry(MultiPolygon, 4326)
  INTO v_coverage_geom
  FROM squares;

  INSERT INTO cell_geometry_versions (
    source_version,
    source,
    status,
    expected_cell_count,
    coverage_geom,
    coverage_area_m2,
    artifact_uri,
    artifact_sha256,
    validation_summary
  )
  VALUES (
    p_source_version,
    p_source,
    'staged',
    v_expected_cell_count,
    v_coverage_geom,
    ST_Area(v_coverage_geom::geography),
    'db:function:stage_cell_geometry_from_cell_ids',
    NULL,
    '{}'::jsonb
  )
  ON CONFLICT (source_version) DO UPDATE
  SET source = EXCLUDED.source,
      status = 'staged',
      expected_cell_count = EXCLUDED.expected_cell_count,
      coverage_geom = EXCLUDED.coverage_geom,
      coverage_area_m2 = EXCLUDED.coverage_area_m2,
      artifact_uri = EXCLUDED.artifact_uri,
      artifact_sha256 = EXCLUDED.artifact_sha256,
      validation_summary = '{}'::jsonb,
      validated_at = NULL,
      activated_at = NULL;

  DELETE FROM cell_geometry_staging
  WHERE source_version = p_source_version;

  WITH parsed AS (
    SELECT
      cell_id,
      split_part(cell_id, '_', 2)::INTEGER AS grid_x,
      split_part(cell_id, '_', 3)::INTEGER AS grid_y,
      split_part(cell_id, '_', 2)::DOUBLE PRECISION / 500.0 AS center_lat,
      split_part(cell_id, '_', 3)::DOUBLE PRECISION / 500.0 AS center_lng
    FROM cell_properties
    WHERE cell_id ~ '^v_-?[0-9]+_-?[0-9]+$'
  ), squares AS (
    SELECT
      cell_id,
      grid_x,
      grid_y,
      center_lat,
      center_lng,
      ST_Multi(
        ST_MakeEnvelope(
          center_lng - (0.5 / 500.0),
          center_lat - (0.5 / 500.0),
          center_lng + (0.5 / 500.0),
          center_lat + (0.5 / 500.0),
          4326
        )
      )::geometry(MultiPolygon, 4326) AS geom
    FROM parsed
  ), payloads AS (
    SELECT
      cell_id,
      grid_x,
      grid_y,
      center_lat,
      center_lng,
      geom,
      ST_PointOnSurface(geom)::geometry(Point, 4326) AS centroid,
      ST_Envelope(geom)::geometry(Polygon, 4326) AS bbox,
      ST_Area(geom::geography) AS area_m2,
      ST_AsGeoJSON(geom, 9, 0)::jsonb AS raw_geometry,
      jsonb_build_object(
        'cell_id', cell_id,
        'geometry', ST_AsGeoJSON(geom, 9, 0)::jsonb,
        'properties', jsonb_build_object(
          'grid_x', grid_x,
          'grid_y', grid_y,
          'center_lat', center_lat,
          'center_lng', center_lng,
          'generation_mode', 'db-uniform-lattice-bounded-voronoi'
        )
      ) AS raw_payload,
      jsonb_build_object(
        'grid_x', grid_x,
        'grid_y', grid_y,
        'center_lat', center_lat,
        'center_lng', center_lng,
        'generation_mode', 'db-uniform-lattice-bounded-voronoi'
      ) AS raw_properties
    FROM squares
  )
  INSERT INTO cell_geometry_staging (
    source_version,
    cell_id,
    raw_payload,
    raw_geometry,
    raw_properties,
    parsed_geom,
    parsed_centroid,
    parsed_bbox,
    parsed_area_m2,
    validation_status,
    validation_errors
  )
  SELECT
    p_source_version,
    cell_id,
    raw_payload,
    raw_geometry,
    raw_properties,
    geom,
    centroid,
    bbox,
    area_m2,
    'pending',
    '[]'::jsonb
  FROM payloads;

  GET DIAGNOSTICS v_staged_count = ROW_COUNT;

  IF v_staged_count <> v_expected_cell_count THEN
    RAISE EXCEPTION 'Staged % geometry rows but expected %', v_staged_count, v_expected_cell_count;
  END IF;

  RETURN v_staged_count;
END;
$$;

GRANT EXECUTE ON FUNCTION stage_cell_geometry_from_cell_ids(TEXT, TEXT) TO service_role;
