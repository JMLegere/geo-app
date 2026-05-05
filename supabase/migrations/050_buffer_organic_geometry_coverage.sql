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
  v_coverage_buffer_meters CONSTANT DOUBLE PRECISION := 250.0;
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
  FROM cell_properties cp
  WHERE cp.cell_id ~ '^v_-?[0-9]+_-?[0-9]+$';

  IF v_expected_cell_count = 0 THEN
    RAISE EXCEPTION 'No lattice-derived cell ids found in cell_properties';
  END IF;

  v_jitter_degrees := p_jitter_ratio / v_grid_scale;

  DROP TABLE IF EXISTS tmp_cell_geometry_organic_centroids;
  DROP TABLE IF EXISTS tmp_cell_geometry_organic_voronoi;

  CREATE TEMP TABLE tmp_cell_geometry_organic_centroids ON COMMIT DROP AS
  WITH parsed AS (
    SELECT
      cell_id,
      split_part(cell_id, '_', 2)::INTEGER AS grid_x,
      split_part(cell_id, '_', 3)::INTEGER AS grid_y
    FROM cell_properties
    WHERE cell_id ~ '^v_-?[0-9]+_-?[0-9]+$'
  ), jittered AS (
    SELECT
      cell_id,
      grid_x,
      grid_y,
      grid_y / v_grid_scale AS original_center_lat,
      grid_x / v_grid_scale AS original_center_lng,
      grid_y / v_grid_scale +
        ((cell_geometry_hash_unit(cell_id || ':' || p_centroid_dataset_version || ':lat') * 2.0 - 1.0) * v_jitter_degrees)
        AS organic_center_lat,
      grid_x / v_grid_scale +
        ((cell_geometry_hash_unit(cell_id || ':' || p_centroid_dataset_version || ':lng') * 2.0 - 1.0) * v_jitter_degrees)
        AS organic_center_lng
    FROM parsed
  )
  SELECT
    cell_id,
    original_center_lat,
    original_center_lng,
    organic_center_lat,
    organic_center_lng,
    ST_SetSRID(
      ST_MakePoint(organic_center_lng, organic_center_lat),
      4326
    )::geometry(Point, 4326) AS centroid_point,
    ST_SetSRID(
      ST_MakeEnvelope(
        original_center_lng - v_half_step_degrees,
        original_center_lat - v_half_step_degrees,
        original_center_lng + v_half_step_degrees,
        original_center_lat + v_half_step_degrees,
        4326
      ),
      4326
    )::geometry(Polygon, 4326) AS coverage_square
  FROM jittered;

  CREATE INDEX tmp_cell_geometry_organic_centroids_point_idx
    ON tmp_cell_geometry_organic_centroids USING GIST (centroid_point);

  SELECT ST_Multi(
           ST_Buffer(
             ST_UnaryUnion(ST_Collect(coverage_square))::geography,
             v_coverage_buffer_meters
           )::geometry
         )::geometry(MultiPolygon, 4326)
  INTO v_coverage_geom
  FROM tmp_cell_geometry_organic_centroids;

  INSERT INTO cell_geometry_versions (
    source_version,
    source,
    status,
    expected_cell_count,
    coverage_geom,
    coverage_area_m2,
    staging_strategy,
    validation_summary,
    metadata
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
      'geometry_contract', 'true-voronoi-clipped-to-buffered-lattice-coverage',
      'jitter_ratio', p_jitter_ratio,
      'coverage_buffer_meters', v_coverage_buffer_meters,
      'grid_scale', v_grid_scale
    )
  )
  ON CONFLICT (source_version) DO UPDATE
  SET source = EXCLUDED.source,
      status = EXCLUDED.status,
      expected_cell_count = EXCLUDED.expected_cell_count,
      coverage_geom = EXCLUDED.coverage_geom,
      coverage_area_m2 = EXCLUDED.coverage_area_m2,
      staging_strategy = EXCLUDED.staging_strategy,
      validation_summary = EXCLUDED.validation_summary,
      metadata = EXCLUDED.metadata,
      created_at = now(),
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
      assigned.cell_id,
      assigned.organic_center_lat,
      assigned.organic_center_lng,
      ST_Multi(
        ST_CollectionExtract(
          ST_MakeValid(ST_Intersection(assigned.voronoi_geom, v_coverage_geom)),
          3
        )
      )::geometry(MultiPolygon, 4326) AS geom
    FROM assigned
  )
  INSERT INTO cell_geometry_staging (
    source_version,
    cell_id,
    raw_payload,
    raw_properties,
    parsed_geom,
    parsed_centroid,
    validation_status,
    validation_message
  )
  SELECT
    p_source_version,
    clipped.cell_id,
    jsonb_build_object(
      'cell_id', clipped.cell_id,
      'lat', clipped.organic_center_lat,
      'lng', clipped.organic_center_lng
    ),
    jsonb_build_object(
      'centroid_dataset_version', p_centroid_dataset_version,
      'generation_mode', 'db-deterministic-jittered-centroid-voronoi',
      'geometry_contract', 'true-voronoi-clipped-to-buffered-lattice-coverage',
      'jitter_ratio', p_jitter_ratio,
      'jitter_degrees', v_jitter_degrees,
      'coverage_buffer_meters', v_coverage_buffer_meters,
      'grid_scale', v_grid_scale
    ) AS raw_properties,
    clipped.geom,
    ST_PointOnSurface(clipped.geom)::geometry(Point, 4326),
    CASE
      WHEN clipped.geom IS NULL OR ST_IsEmpty(clipped.geom) THEN 'invalid'
      ELSE 'pending'
    END,
    CASE
      WHEN clipped.geom IS NULL OR ST_IsEmpty(clipped.geom) THEN 'geometry was empty after clipping to buffered coverage'
      ELSE NULL
    END
  FROM clipped;

  GET DIAGNOSTICS v_staged_count = ROW_COUNT;

  RETURN v_staged_count;
END;
$$;

GRANT EXECUTE ON FUNCTION stage_cell_geometry_from_organic_centroids(
  TEXT,
  TEXT,
  TEXT,
  DOUBLE PRECISION
) TO service_role;
