-- DB-side organic cell geometry staging from deterministic centroids.
--
-- 042 was intentionally pragmatic for the first beta repair: v_<x>_<y>
-- lattice centers imply half-step square Voronoi cells. Product QA showed that
-- square source truth dominates the map. This function keeps the existing cell_id
-- compatibility contract, but replaces the center set with deterministic organic
-- centroids and stages a true point-Voronoi tessellation clipped to the existing
-- coverage footprint.
--
-- Publish remains the existing validated source-version flow:
--   stage_cell_geometry_from_organic_centroids(...)
--   validate_cell_geometry_source_version(...)
--   publish_cell_geometry_source_version(...)
-- Existing cell_geometry_validation_runs, cell_geometry_validation_issues, and
-- cell_geometry_publish_events preserve auditability for the full source-truth
-- transition.

CREATE OR REPLACE FUNCTION cell_geometry_hash_unit(p_value TEXT)
RETURNS DOUBLE PRECISION
LANGUAGE SQL
IMMUTABLE
STRICT
AS $$
  SELECT (
    ('x' || substr(md5(p_value), 1, 15))::bit(60)::bigint::DOUBLE PRECISION /
    1152921504606846975.0
  );
$$;

CREATE OR REPLACE FUNCTION stage_cell_geometry_from_organic_centroids(
  p_source_version TEXT,
  p_centroid_dataset_version TEXT DEFAULT 'earthnova-organic-centroids-v1',
  p_source TEXT DEFAULT 'db-organic-voronoi-from-deterministic-centroids',
  p_jitter_ratio DOUBLE PRECISION DEFAULT 0.34
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_grid_scale CONSTANT DOUBLE PRECISION := 500.0;
  v_half_step_degrees DOUBLE PRECISION := 0.5 / v_grid_scale;
  v_jitter_degrees DOUBLE PRECISION;
  v_expected_cell_count INTEGER;
  v_staged_count INTEGER;
  v_voronoi_count INTEGER;
  v_coverage_geom geometry(MultiPolygon, 4326);
BEGIN
  IF p_source_version IS NULL OR btrim(p_source_version) = '' THEN
    RAISE EXCEPTION 'source_version is required';
  END IF;

  IF p_centroid_dataset_version IS NULL OR btrim(p_centroid_dataset_version) = '' THEN
    RAISE EXCEPTION 'centroid_dataset_version is required';
  END IF;

  IF p_jitter_ratio IS NULL OR p_jitter_ratio < 0.05 OR p_jitter_ratio > 0.49 THEN
    RAISE EXCEPTION 'jitter_ratio must be between 0.05 and 0.49';
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

  v_jitter_degrees := p_jitter_ratio / v_grid_scale;

  DROP TABLE IF EXISTS tmp_cell_geometry_organic_centroids;
  DROP TABLE IF EXISTS tmp_cell_geometry_organic_voronoi;

  CREATE TEMP TABLE tmp_cell_geometry_organic_centroids ON COMMIT DROP AS
  WITH parsed AS (
    SELECT
      cell_id,
      split_part(cell_id, '_', 2)::INTEGER AS grid_x,
      split_part(cell_id, '_', 3)::INTEGER AS grid_y,
      split_part(cell_id, '_', 2)::DOUBLE PRECISION / v_grid_scale AS original_center_lat,
      split_part(cell_id, '_', 3)::DOUBLE PRECISION / v_grid_scale AS original_center_lng
    FROM cell_properties
    WHERE cell_id ~ '^v_-?[0-9]+_-?[0-9]+$'
  ), jittered AS (
    SELECT
      parsed.*,
      original_center_lat +
        ((cell_geometry_hash_unit(cell_id || ':' || p_centroid_dataset_version || ':lat') * 2.0 - 1.0) * v_jitter_degrees)
        AS organic_center_lat,
      original_center_lng +
        ((cell_geometry_hash_unit(cell_id || ':' || p_centroid_dataset_version || ':lng') * 2.0 - 1.0) * v_jitter_degrees)
        AS organic_center_lng
    FROM parsed
  )
  SELECT
    cell_id,
    grid_x,
    grid_y,
    original_center_lat,
    original_center_lng,
    organic_center_lat,
    organic_center_lng,
    ST_SetSRID(
      ST_MakePoint(organic_center_lng, organic_center_lat),
      4326
    )::geometry(Point, 4326) AS centroid_point,
    ST_MakeEnvelope(
      original_center_lng - v_half_step_degrees,
      original_center_lat - v_half_step_degrees,
      original_center_lng + v_half_step_degrees,
      original_center_lat + v_half_step_degrees,
      4326
    )::geometry(Polygon, 4326) AS coverage_square
  FROM jittered;

  CREATE INDEX tmp_cell_geometry_organic_centroids_point_idx
    ON tmp_cell_geometry_organic_centroids USING GIST (centroid_point);

  SELECT ST_Multi(ST_UnaryUnion(ST_Collect(coverage_square)))::geometry(MultiPolygon, 4326)
  INTO v_coverage_geom
  FROM tmp_cell_geometry_organic_centroids;

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
    'db:function:stage_cell_geometry_from_organic_centroids',
    NULL,
    jsonb_build_object(
      'centroid_dataset_version', p_centroid_dataset_version,
      'generation_mode', 'db-deterministic-jittered-centroid-voronoi',
      'geometry_contract', 'true-voronoi-clipped-to-lattice-coverage',
      'jitter_ratio', p_jitter_ratio
    )
  )
  ON CONFLICT (source_version) DO UPDATE
  SET source = EXCLUDED.source,
      status = 'staged',
      expected_cell_count = EXCLUDED.expected_cell_count,
      coverage_geom = EXCLUDED.coverage_geom,
      coverage_area_m2 = EXCLUDED.coverage_area_m2,
      artifact_uri = EXCLUDED.artifact_uri,
      artifact_sha256 = EXCLUDED.artifact_sha256,
      validation_summary = EXCLUDED.validation_summary,
      validated_at = NULL,
      activated_at = NULL;

  DELETE FROM cell_geometry_staging
  WHERE source_version = p_source_version;

  CREATE TEMP TABLE tmp_cell_geometry_organic_voronoi ON COMMIT DROP AS
  SELECT
    row_number() OVER () AS voronoi_id,
    dumped.geom::geometry(Polygon, 4326) AS geom
  FROM (
    SELECT (ST_Dump(ST_VoronoiPolygons(ST_Collect(centroid_point), 0.0, v_coverage_geom))).geom
    FROM tmp_cell_geometry_organic_centroids
  ) AS dumped;

  CREATE INDEX tmp_cell_geometry_organic_voronoi_geom_idx
    ON tmp_cell_geometry_organic_voronoi USING GIST (geom);

  SELECT COUNT(*)::INTEGER
  INTO v_voronoi_count
  FROM tmp_cell_geometry_organic_voronoi;

  IF v_voronoi_count <> v_expected_cell_count THEN
    RAISE EXCEPTION 'Generated % Voronoi polygons but expected %', v_voronoi_count, v_expected_cell_count;
  END IF;

  WITH assigned AS (
    SELECT
      centroids.cell_id,
      centroids.grid_x,
      centroids.grid_y,
      centroids.original_center_lat,
      centroids.original_center_lng,
      centroids.organic_center_lat,
      centroids.organic_center_lng,
      nearest.geom AS voronoi_geom
    FROM tmp_cell_geometry_organic_centroids centroids
    CROSS JOIN LATERAL (
      SELECT geom
      FROM tmp_cell_geometry_organic_voronoi voronoi
      ORDER BY voronoi.geom <-> centroids.centroid_point
      LIMIT 1
    ) nearest
  ), clipped AS (
    SELECT
      assigned.*,
      ST_Multi(
        ST_CollectionExtract(
          ST_MakeValid(ST_Intersection(assigned.voronoi_geom, v_coverage_geom)),
          3
        )
      )::geometry(MultiPolygon, 4326) AS geom
    FROM assigned
  ), payloads AS (
    SELECT
      cell_id,
      grid_x,
      grid_y,
      original_center_lat,
      original_center_lng,
      organic_center_lat,
      organic_center_lng,
      geom,
      ST_PointOnSurface(geom)::geometry(Point, 4326) AS centroid,
      ST_Envelope(geom)::geometry(Polygon, 4326) AS bbox,
      ST_Area(geom::geography) AS area_m2,
      ST_AsGeoJSON(geom, 9, 0)::jsonb AS raw_geometry,
      jsonb_build_object(
        'grid_x', grid_x,
        'grid_y', grid_y,
        'original_center_lat', original_center_lat,
        'original_center_lng', original_center_lng,
        'organic_center_lat', organic_center_lat,
        'organic_center_lng', organic_center_lng,
        'centroid_dataset_version', p_centroid_dataset_version,
        'generation_mode', 'db-deterministic-jittered-centroid-voronoi',
        'geometry_contract', 'true-voronoi-clipped-to-lattice-coverage',
        'jitter_ratio', p_jitter_ratio,
        'jitter_degrees', v_jitter_degrees,
        'grid_scale', v_grid_scale
      ) AS raw_properties
    FROM clipped
    WHERE geom IS NOT NULL
      AND NOT ST_IsEmpty(geom)
      AND ST_IsValid(geom)
      AND ST_Area(geom::geography) > 0
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
    jsonb_build_object(
      'cell_id', cell_id,
      'geometry', raw_geometry,
      'properties', raw_properties
    ) AS raw_payload,
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
    RAISE EXCEPTION 'Staged % organic geometry rows but expected %', v_staged_count, v_expected_cell_count;
  END IF;

  RETURN v_staged_count;
END;
$$;

GRANT EXECUTE ON FUNCTION cell_geometry_hash_unit(TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION stage_cell_geometry_from_organic_centroids(
  TEXT,
  TEXT,
  TEXT,
  DOUBLE PRECISION
) TO service_role;
