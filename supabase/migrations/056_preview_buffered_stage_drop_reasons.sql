CREATE FUNCTION diagnose_stage_cell_geometry_from_organic_centroids(
  p_centroid_dataset_version TEXT DEFAULT 'earthnova-organic-centroids-v1',
  p_jitter_ratio DOUBLE PRECISION DEFAULT 0.34,
  p_coverage_buffer_meters DOUBLE PRECISION DEFAULT 250.0
)
RETURNS TABLE (
  expected_cell_count INTEGER,
  candidate_row_count INTEGER,
  valid_candidate_count INTEGER,
  null_geom_count INTEGER,
  empty_geom_count INTEGER,
  invalid_geom_count INTEGER,
  nonpositive_area_count INTEGER
)
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH parsed AS (
    SELECT
      cp.cell_id,
      split_part(cp.cell_id, '_', 2)::INTEGER AS grid_x,
      split_part(cp.cell_id, '_', 3)::INTEGER AS grid_y
    FROM cell_properties cp
    WHERE cp.cell_id ~ '^v_-?[0-9]+_-?[0-9]+$'
  ), jittered AS (
    SELECT
      cell_id,
      grid_x,
      grid_y,
      grid_y / 500.0 AS original_center_lat,
      grid_x / 500.0 AS original_center_lng,
      grid_y / 500.0 +
        ((cell_geometry_hash_unit(cell_id || ':' || p_centroid_dataset_version || ':lat') * 2.0 - 1.0) * (p_jitter_ratio / 500.0))
        AS organic_center_lat,
      grid_x / 500.0 +
        ((cell_geometry_hash_unit(cell_id || ':' || p_centroid_dataset_version || ':lng') * 2.0 - 1.0) * (p_jitter_ratio / 500.0))
        AS organic_center_lng
    FROM parsed
  ), centroids AS (
    SELECT
      cell_id,
      ST_SetSRID(
        ST_MakePoint(organic_center_lng, organic_center_lat),
        4326
      )::geometry(Point, 4326) AS centroid_point,
      ST_SetSRID(
        ST_MakeEnvelope(
          original_center_lng - (0.5 / 500.0),
          original_center_lat - (0.5 / 500.0),
          original_center_lng + (0.5 / 500.0),
          original_center_lat + (0.5 / 500.0),
          4326
        ),
        4326
      )::geometry(Polygon, 4326) AS coverage_square
    FROM jittered
  ), coverage AS (
    SELECT ST_Multi(
             ST_Buffer(
               ST_UnaryUnion(ST_Collect(coverage_square))::geography,
               p_coverage_buffer_meters
             )::geometry
           )::geometry(MultiPolygon, 4326) AS geom
    FROM centroids
  ), voronoi AS (
    SELECT
      row_number() OVER () AS voronoi_id,
      dumped.geom::geometry(Polygon, 4326) AS geom
    FROM (
      SELECT (ST_Dump(ST_VoronoiPolygons(ST_Collect(centroid_point), 0.0, (SELECT geom FROM coverage)))).geom
      FROM centroids
    ) dumped
  ), assigned AS (
    SELECT
      centroids.cell_id,
      COALESCE(containing.geom, nearest.geom) AS voronoi_geom
    FROM centroids
    LEFT JOIN LATERAL (
      SELECT geom
      FROM voronoi
      WHERE ST_Covers(voronoi.geom, centroids.centroid_point)
      ORDER BY voronoi.geom <-> centroids.centroid_point
      LIMIT 1
    ) containing ON true
    LEFT JOIN LATERAL (
      SELECT geom
      FROM voronoi
      ORDER BY voronoi.geom <-> centroids.centroid_point
      LIMIT 1
    ) nearest ON true
  ), clipped AS (
    SELECT
      assigned.cell_id,
      ST_Multi(
        ST_CollectionExtract(
          ST_MakeValid(ST_Intersection(assigned.voronoi_geom, (SELECT geom FROM coverage))),
          3
        )
      )::geometry(MultiPolygon, 4326) AS geom
    FROM assigned
  ), assessed AS (
    SELECT
      cell_id,
      geom,
      geom IS NULL AS geom_is_null,
      CASE WHEN geom IS NULL THEN false ELSE ST_IsEmpty(geom) END AS geom_is_empty,
      CASE WHEN geom IS NULL OR ST_IsEmpty(geom) THEN false ELSE ST_IsValid(geom) END AS geom_is_valid,
      CASE
        WHEN geom IS NULL OR ST_IsEmpty(geom) OR NOT ST_IsValid(geom) THEN NULL
        ELSE ST_Area(geom::geography)
      END AS area_m2_candidate
    FROM clipped
  )
  SELECT
    (SELECT COUNT(*)::INTEGER FROM parsed) AS expected_cell_count,
    COUNT(*)::INTEGER AS candidate_row_count,
    COUNT(*) FILTER (
      WHERE NOT geom_is_null
        AND NOT geom_is_empty
        AND geom_is_valid
        AND area_m2_candidate > 0
    )::INTEGER AS valid_candidate_count,
    COUNT(*) FILTER (WHERE geom_is_null)::INTEGER AS null_geom_count,
    COUNT(*) FILTER (WHERE NOT geom_is_null AND geom_is_empty)::INTEGER AS empty_geom_count,
    COUNT(*) FILTER (WHERE NOT geom_is_null AND NOT geom_is_empty AND NOT geom_is_valid)::INTEGER AS invalid_geom_count,
    COUNT(*) FILTER (
      WHERE NOT geom_is_null
        AND NOT geom_is_empty
        AND geom_is_valid
        AND COALESCE(area_m2_candidate, 0) <= 0
    )::INTEGER AS nonpositive_area_count
  FROM assessed;
$$;

GRANT EXECUTE ON FUNCTION diagnose_stage_cell_geometry_from_organic_centroids(
  TEXT,
  DOUBLE PRECISION,
  DOUBLE PRECISION
) TO service_role;
