-- Surface geometry provenance and advisory visual-quality metadata.
--
-- Topology validation proves a source_version is a complete non-overlapping
-- tessellation. This migration adds a separate visual-quality summary so QA and
-- clients can distinguish mathematically-valid geometry from geometry that may
-- still render with janky/sliver-prone shapes.

CREATE OR REPLACE FUNCTION cell_geometry_visual_quality_summary(
  p_source_version TEXT
)
RETURNS JSONB
LANGUAGE SQL
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  WITH dumped AS (
    SELECT
      cells.cell_id,
      cells.geom,
      cells.area_m2,
      ST_Perimeter(cells.geom::geography) AS perimeter_m,
      (dumped).path AS polygon_path,
      (dumped).geom AS polygon_geom
    FROM cell_geometry_cells cells
    CROSS JOIN LATERAL ST_Dump(cells.geom) AS dumped
    WHERE cells.source_version = p_source_version
  ), rings AS (
    SELECT
      cell_id,
      polygon_path,
      ST_ExteriorRing(polygon_geom) AS ring_geom,
      GREATEST(ST_NPoints(ST_ExteriorRing(polygon_geom)) - 1, 0) AS exterior_vertices
    FROM dumped
  ), points AS (
    SELECT
      cell_id,
      polygon_path,
      (point_dump).path[1] AS point_index,
      (point_dump).geom AS point_geom
    FROM rings
    CROSS JOIN LATERAL ST_DumpPoints(ring_geom) AS point_dump
  ), edge_lengths AS (
    SELECT
      p1.cell_id,
      ST_Distance(p1.point_geom::geography, p2.point_geom::geography) AS edge_length_m
    FROM points p1
    JOIN points p2
      ON p2.cell_id = p1.cell_id
     AND p2.polygon_path = p1.polygon_path
     AND p2.point_index = p1.point_index + 1
  ), vertices_by_cell AS (
    SELECT
      cell_id,
      SUM(exterior_vertices)::INTEGER AS unique_exterior_vertices
    FROM rings
    GROUP BY cell_id
  ), edge_by_cell AS (
    SELECT
      cell_id,
      MIN(edge_length_m) FILTER (WHERE edge_length_m > 0.01) AS min_edge_length_m
    FROM edge_lengths
    GROUP BY cell_id
  ), per_cell AS (
    SELECT
      cells.cell_id,
      cells.area_m2,
      ST_Perimeter(cells.geom::geography) AS perimeter_m,
      vertices_by_cell.unique_exterior_vertices,
      edge_by_cell.min_edge_length_m,
      (
        4 * pi() * cells.area_m2 /
        NULLIF(
          ST_Perimeter(cells.geom::geography) * ST_Perimeter(cells.geom::geography),
          0
        )
      ) AS compactness
    FROM cell_geometry_cells cells
    JOIN vertices_by_cell
      ON vertices_by_cell.cell_id = cells.cell_id
    LEFT JOIN edge_by_cell
      ON edge_by_cell.cell_id = cells.cell_id
    WHERE cells.source_version = p_source_version
  ), summary AS (
    SELECT
      COUNT(*)::INTEGER AS cell_count,
      COALESCE(
        COUNT(*) FILTER (WHERE unique_exterior_vertices > 4)::DOUBLE PRECISION /
          NULLIF(COUNT(*), 0),
        0.0
      ) AS organic_vertex_ratio,
      MIN(unique_exterior_vertices)::INTEGER AS min_exterior_vertices,
      percentile_cont(0.01) WITHIN GROUP (ORDER BY unique_exterior_vertices)
        AS p01_exterior_vertices,
      percentile_cont(0.50) WITHIN GROUP (ORDER BY unique_exterior_vertices)
        AS p50_exterior_vertices,
      MIN(compactness) AS min_compactness,
      percentile_cont(0.01) WITHIN GROUP (ORDER BY compactness)
        AS p01_compactness,
      percentile_cont(0.05) WITHIN GROUP (ORDER BY compactness)
        AS p05_compactness,
      MIN(min_edge_length_m) AS min_edge_length_m,
      percentile_cont(0.01) WITHIN GROUP (ORDER BY min_edge_length_m)
        AS p01_min_edge_length_m,
      percentile_cont(0.05) WITHIN GROUP (ORDER BY min_edge_length_m)
        AS p05_min_edge_length_m,
      COUNT(*) FILTER (WHERE compactness < 0.25)::INTEGER
        AS compactness_lt_025_count,
      COUNT(*) FILTER (WHERE min_edge_length_m < 8)::INTEGER
        AS min_edge_lt_8m_count
    FROM per_cell
  )
  SELECT jsonb_build_object(
    'contract_version', 'cell-geometry-visual-quality-v1',
    'cell_count', cell_count,
    'organic_vertex_ratio', organic_vertex_ratio,
    'organic_vertex_ratio_threshold', 0.90,
    'min_exterior_vertices', min_exterior_vertices,
    'p01_exterior_vertices', p01_exterior_vertices,
    'p50_exterior_vertices', p50_exterior_vertices,
    'min_compactness', min_compactness,
    'p01_compactness', p01_compactness,
    'p05_compactness', p05_compactness,
    'p01_compactness_threshold', 0.20,
    'min_edge_length_m', min_edge_length_m,
    'p01_min_edge_length_m', p01_min_edge_length_m,
    'p05_min_edge_length_m', p05_min_edge_length_m,
    'compactness_lt_025_count', compactness_lt_025_count,
    'min_edge_lt_8m_count', min_edge_lt_8m_count,
    'min_edge_threshold_m', 8.0,
    'min_edge_threshold_mode', 'advisory',
    'visual_quality_passed',
      cell_count > 0 AND organic_vertex_ratio >= 0.90 AND p01_compactness >= 0.20
  )
  FROM summary;
$$;

UPDATE cell_geometry_versions versions
SET validation_summary = jsonb_set(
  versions.validation_summary,
  '{visual_quality}',
  cell_geometry_visual_quality_summary(versions.source_version),
  true
)
WHERE EXISTS (
  SELECT 1
  FROM cell_geometry_cells cells
  WHERE cells.source_version = versions.source_version
);

DROP FUNCTION IF EXISTS fetch_nearby_cells(
  DOUBLE PRECISION,
  DOUBLE PRECISION,
  DOUBLE PRECISION
);

CREATE OR REPLACE VIEW v3_map_cells_read_model AS
SELECT
  cp.cell_id,
  cp.habitats,
  COALESCE(geometry_json.polygons->0->0, '[]'::jsonb) AS polygon,
  geometry_json.polygons,
  d.id AS district_id,
  c.id AS city_id,
  s.id AS state_id,
  country.id AS country_id,
  ST_Y(cg.centroid) AS centroid_lat,
  ST_X(cg.centroid) AS centroid_lon,
  cg.source_version AS geometry_source_version,
  cg.metadata->>'generation_mode' AS geometry_generation_mode,
  cg.metadata->>'centroid_dataset_version' AS centroid_dataset_version,
  cg.metadata->>'geometry_contract' AS geometry_contract,
  versions.validation_summary->'visual_quality' AS geometry_visual_quality
FROM cell_properties cp
JOIN cell_geometry_current cg
  ON cg.cell_id = cp.cell_id
JOIN cell_geometry_versions versions
  ON versions.source_version = cg.source_version
CROSS JOIN LATERAL (
  SELECT cell_geometry_latlng_polygons_jsonb(cg.geom) AS polygons
) geometry_json
LEFT JOIN districts d ON d.id = cp.location_id
LEFT JOIN cities c ON c.id = d.city_id
LEFT JOIN states s ON s.id = c.state_id
LEFT JOIN countries country ON country.id = s.country_id;

CREATE FUNCTION fetch_nearby_cells(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_meters DOUBLE PRECISION DEFAULT 2000
)
RETURNS TABLE (
  cell_id TEXT,
  habitats TEXT[],
  polygon JSONB,
  polygons JSONB,
  district_id TEXT,
  city_id TEXT,
  state_id TEXT,
  country_id TEXT,
  geometry_source_version TEXT,
  geometry_generation_mode TEXT,
  centroid_dataset_version TEXT,
  geometry_contract TEXT,
  geometry_visual_quality JSONB
)
LANGUAGE SQL
STABLE
SECURITY INVOKER
AS $$
  SELECT
    model.cell_id,
    model.habitats,
    model.polygon,
    model.polygons,
    model.district_id,
    model.city_id,
    model.state_id,
    model.country_id,
    model.geometry_source_version,
    model.geometry_generation_mode,
    model.centroid_dataset_version,
    model.geometry_contract,
    model.geometry_visual_quality
  FROM v3_map_cells_read_model model
  WHERE jsonb_typeof(model.polygon) = 'array'
    AND jsonb_array_length(model.polygon) >= 4
    AND ST_DWithin(
      ST_SetSRID(ST_MakePoint(model.centroid_lon, model.centroid_lat), 4326)::geography,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
      p_radius_meters
    );
$$;

GRANT EXECUTE ON FUNCTION cell_geometry_visual_quality_summary(TEXT) TO authenticated;
GRANT SELECT ON v3_map_cells_read_model TO authenticated;
GRANT EXECUTE ON FUNCTION fetch_nearby_cells(
  DOUBLE PRECISION,
  DOUBLE PRECISION,
  DOUBLE PRECISION
) TO authenticated;
