DROP FUNCTION IF EXISTS stage_cell_geometry_from_organic_centroids(
  TEXT,
  TEXT,
  TEXT,
  DOUBLE PRECISION,
  DOUBLE PRECISION
);

CREATE FUNCTION stage_cell_geometry_from_organic_centroids(
  p_source_version TEXT,
  p_centroid_dataset_version TEXT DEFAULT 'earthnova-organic-centroids-v1',
  p_source TEXT DEFAULT 'db-organic-voronoi-from-deterministic-centroids',
  p_jitter_ratio DOUBLE PRECISION DEFAULT 0.34,
  p_coverage_buffer_meters DOUBLE PRECISION DEFAULT 250.0
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_grid_scale CONSTANT DOUBLE PRECISION := 500.0;
  v_half_step_degrees DOUBLE PRECISION := 0.5 / v_grid_scale;
  v_cluster_eps_degrees CONSTANT DOUBLE PRECISION := 1.5 / v_grid_scale;
  v_jitter_degrees DOUBLE PRECISION;
  v_coverage_buffer_meters DOUBLE PRECISION := p_coverage_buffer_meters;
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

  IF p_coverage_buffer_meters IS NULL OR p_coverage_buffer_meters < 0 OR p_coverage_buffer_meters > 1000 THEN
    RAISE EXCEPTION 'coverage_buffer_meters must be between 0 and 1000';
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
  DROP TABLE IF EXISTS tmp_cell_geometry_cluster_coverage;
  DROP TABLE IF EXISTS tmp_cell_geometry_cluster_voronoi;

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
    ST_SetSRID(
      ST_MakeEnvelope(
        original_center_lng - v_half_step_degrees,
        original_center_lat - v_half_step_degrees,
        original_center_lng + v_half_step_degrees,
        original_center_lat + v_half_step_degrees,
        4326
      ),
      4326
    )::geometry(Polygon, 4326) AS coverage_square,
    ST_ClusterDBSCAN(
      ST_SetSRID(ST_MakePoint(organic_center_lng, organic_center_lat), 4326),
      eps := v_cluster_eps_degrees,
      minpoints := 1
    ) OVER () AS cluster_id
  FROM jittered;

  CREATE INDEX tmp_cell_geometry_organic_centroids_point_idx
    ON tmp_cell_geometry_organic_centroids USING GIST (centroid_point);

  CREATE TEMP TABLE tmp_cell_geometry_cluster_coverage ON COMMIT DROP AS
  SELECT
    cluster_id,
    COUNT(*)::INTEGER AS centroid_count,
    ST_Multi(
      ST_Buffer(
        ST_UnaryUnion(ST_Collect(coverage_square))::geography,
        v_coverage_buffer_meters
      )::geometry
    )::geometry(MultiPolygon, 4326) AS coverage_geom
  FROM tmp_cell_geometry_organic_centroids
  GROUP BY cluster_id;

  CREATE INDEX tmp_cell_geometry_cluster_coverage_geom_idx
    ON tmp_cell_geometry_cluster_coverage USING GIST (coverage_geom);

  SELECT ST_Multi(ST_UnaryUnion(ST_Collect(coverage_geom)))::geometry(MultiPolygon, 4326)
  INTO v_coverage_geom
  FROM tmp_cell_geometry_cluster_coverage;

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
      'geometry_contract', 'true-voronoi-clipped-to-buffered-lattice-coverage',
      'jitter_ratio', p_jitter_ratio,
      'coverage_buffer_meters', v_coverage_buffer_meters,
      'cluster_eps_degrees', v_cluster_eps_degrees,
      'grid_scale', v_grid_scale
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

  CREATE TEMP TABLE tmp_cell_geometry_cluster_voronoi ON COMMIT DROP AS
  SELECT
    clusters.cluster_id,
    dumped.geom::geometry(Polygon, 4326) AS geom
  FROM tmp_cell_geometry_cluster_coverage clusters
  CROSS JOIN LATERAL (
    SELECT (ST_Dump(clusters.coverage_geom)).geom
    WHERE clusters.centroid_count = 1
    UNION ALL
    SELECT (ST_Dump(ST_VoronoiPolygons(
      (
        SELECT ST_Collect(centroid_point)
        FROM tmp_cell_geometry_organic_centroids centroids
        WHERE centroids.cluster_id = clusters.cluster_id
      ),
      0.0,
      clusters.coverage_geom
    ))).geom
    WHERE clusters.centroid_count > 1
  ) dumped;

  CREATE INDEX tmp_cell_geometry_cluster_voronoi_geom_idx
    ON tmp_cell_geometry_cluster_voronoi USING GIST (geom);

  SELECT COUNT(*)::INTEGER
  INTO v_voronoi_count
  FROM tmp_cell_geometry_cluster_voronoi;

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
      centroids.cluster_id,
      COALESCE(containing.geom, nearest.geom) AS voronoi_geom,
      coverage.coverage_geom
    FROM tmp_cell_geometry_organic_centroids centroids
    JOIN tmp_cell_geometry_cluster_coverage coverage
      ON coverage.cluster_id = centroids.cluster_id
    LEFT JOIN LATERAL (
      SELECT geom
      FROM tmp_cell_geometry_cluster_voronoi voronoi
      WHERE voronoi.cluster_id = centroids.cluster_id
        AND ST_Covers(voronoi.geom, centroids.centroid_point)
      ORDER BY voronoi.geom <-> centroids.centroid_point
      LIMIT 1
    ) containing ON true
    LEFT JOIN LATERAL (
      SELECT geom
      FROM tmp_cell_geometry_cluster_voronoi voronoi
      WHERE voronoi.cluster_id = centroids.cluster_id
      ORDER BY voronoi.geom <-> centroids.centroid_point
      LIMIT 1
    ) nearest ON true
  ), clipped AS (
    SELECT
      assigned.cell_id,
      assigned.grid_x,
      assigned.grid_y,
      assigned.original_center_lat,
      assigned.original_center_lng,
      assigned.organic_center_lat,
      assigned.organic_center_lng,
      ST_Multi(
        ST_CollectionExtract(
          ST_MakeValid(ST_Intersection(assigned.voronoi_geom, assigned.coverage_geom)),
          3
        )
      )::geometry(MultiPolygon, 4326) AS geom
    FROM assigned
  ), assessed AS (
    SELECT
      cell_id,
      grid_x,
      grid_y,
      original_center_lat,
      original_center_lng,
      organic_center_lat,
      organic_center_lng,
      geom,
      geom IS NULL AS geom_is_null,
      CASE WHEN geom IS NULL THEN false ELSE ST_IsEmpty(geom) END AS geom_is_empty,
      CASE
        WHEN geom IS NULL OR ST_IsEmpty(geom) THEN false
        ELSE ST_IsValid(geom)
      END AS geom_is_valid,
      CASE
        WHEN geom IS NULL OR ST_IsEmpty(geom) OR NOT ST_IsValid(geom) THEN NULL
        ELSE ST_Area(geom::geography)
      END AS area_m2_candidate,
      CASE WHEN geom IS NULL THEN NULL ELSE ST_AsGeoJSON(geom, 9, 0)::jsonb END AS raw_geometry
    FROM clipped
  ), payloads AS (
    SELECT
      cell_id,
      raw_geometry,
      jsonb_build_object(
        'grid_x', grid_x,
        'grid_y', grid_y,
        'original_center_lat', original_center_lat,
        'original_center_lng', original_center_lng,
        'organic_center_lat', organic_center_lat,
        'organic_center_lng', organic_center_lng,
        'centroid_dataset_version', p_centroid_dataset_version,
        'generation_mode', 'db-deterministic-jittered-centroid-voronoi',
        'geometry_contract', 'true-voronoi-clipped-to-buffered-lattice-coverage',
        'jitter_ratio', p_jitter_ratio,
        'jitter_degrees', v_jitter_degrees,
        'coverage_buffer_meters', v_coverage_buffer_meters,
        'cluster_eps_degrees', v_cluster_eps_degrees,
        'grid_scale', v_grid_scale
      ) AS raw_properties,
      CASE
        WHEN NOT geom_is_null AND NOT geom_is_empty AND geom_is_valid AND area_m2_candidate > 0
        THEN geom
        ELSE NULL
      END AS parsed_geom,
      CASE
        WHEN NOT geom_is_null AND NOT geom_is_empty AND geom_is_valid AND area_m2_candidate > 0
        THEN ST_PointOnSurface(geom)::geometry(Point, 4326)
        ELSE NULL
      END AS parsed_centroid,
      CASE
        WHEN NOT geom_is_null AND NOT geom_is_empty AND geom_is_valid AND area_m2_candidate > 0
        THEN ST_Envelope(geom)::geometry(Polygon, 4326)
        ELSE NULL
      END AS parsed_bbox,
      CASE
        WHEN NOT geom_is_null AND NOT geom_is_empty AND geom_is_valid AND area_m2_candidate > 0
        THEN area_m2_candidate
        ELSE NULL
      END AS parsed_area_m2,
      CASE
        WHEN NOT geom_is_null AND NOT geom_is_empty AND geom_is_valid AND area_m2_candidate > 0
        THEN 'pending'
        ELSE 'invalid'
      END AS validation_status,
      to_jsonb(array_remove(ARRAY[
        CASE WHEN geom_is_null THEN 'geometry_null_after_clip' END,
        CASE WHEN NOT geom_is_null AND geom_is_empty THEN 'geometry_empty_after_clip' END,
        CASE WHEN NOT geom_is_null AND NOT geom_is_empty AND NOT geom_is_valid THEN 'geometry_invalid_after_clip' END,
        CASE WHEN NOT geom_is_null AND NOT geom_is_empty AND geom_is_valid AND COALESCE(area_m2_candidate, 0) <= 0 THEN 'geometry_nonpositive_area_after_clip' END
      ]::TEXT[], NULL)) AS validation_errors
    FROM assessed
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
    parsed_geom,
    parsed_centroid,
    parsed_bbox,
    parsed_area_m2,
    validation_status,
    validation_errors
  FROM payloads;

  GET DIAGNOSTICS v_staged_count = ROW_COUNT;

  RETURN v_staged_count;
END;
$$;

GRANT EXECUTE ON FUNCTION stage_cell_geometry_from_organic_centroids(
  TEXT,
  TEXT,
  TEXT,
  DOUBLE PRECISION,
  DOUBLE PRECISION
) TO service_role;
