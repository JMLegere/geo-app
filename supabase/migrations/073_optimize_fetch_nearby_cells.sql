DROP FUNCTION IF EXISTS fetch_nearby_cells(
  DOUBLE PRECISION,
  DOUBLE PRECISION,
  DOUBLE PRECISION
);

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
  WITH params AS (
    SELECT
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326) AS point_geom,
      p_radius_meters AS radius_meters,
      GREATEST(
        p_radius_meters / 110574.0,
        p_radius_meters / (
          111320.0 * GREATEST(abs(cos(radians(p_lat))), 0.01)
        )
      ) AS radius_degrees
  ), nearby_geometry AS (
    SELECT
      cell_geom.source_version,
      cell_geom.cell_id,
      cell_geom.geom,
      cell_geom.metadata
    FROM cell_geometry_current cell_geom
    CROSS JOIN params
    WHERE cell_geom.geom && ST_Expand(params.point_geom, params.radius_degrees)
      AND ST_DWithin(
        cell_geom.geom::geography,
        params.point_geom::geography,
        params.radius_meters
      )
  ), nearby_cells AS (
    SELECT
      cp.cell_id,
      cp.habitats,
      COALESCE(geometry_json.polygons->0->0, '[]'::jsonb) AS polygon,
      geometry_json.polygons,
      d.id AS district_id,
      c.id AS city_id,
      s.id AS state_id,
      country.id AS country_id,
      cell_geom.source_version AS geometry_source_version,
      cell_geom.metadata->>'generation_mode' AS geometry_generation_mode,
      cell_geom.metadata->>'centroid_dataset_version' AS centroid_dataset_version,
      cell_geom.metadata->>'geometry_contract' AS geometry_contract,
      versions.validation_summary->'visual_quality' AS geometry_visual_quality
    FROM nearby_geometry cell_geom
    JOIN cell_properties cp
      ON cp.cell_id = cell_geom.cell_id
    JOIN cell_geometry_versions versions
      ON versions.source_version = cell_geom.source_version
    CROSS JOIN LATERAL (
      SELECT cell_geometry_latlng_polygons_jsonb(cell_geom.geom) AS polygons
    ) geometry_json
    LEFT JOIN districts d ON d.id = cp.location_id
    LEFT JOIN cities c ON c.id = d.city_id
    LEFT JOIN states s ON s.id = c.state_id
    LEFT JOIN countries country ON country.id = s.country_id
  )
  SELECT
    nearby_cells.cell_id,
    nearby_cells.habitats,
    nearby_cells.polygon,
    nearby_cells.polygons,
    nearby_cells.district_id,
    nearby_cells.city_id,
    nearby_cells.state_id,
    nearby_cells.country_id,
    nearby_cells.geometry_source_version,
    nearby_cells.geometry_generation_mode,
    nearby_cells.centroid_dataset_version,
    nearby_cells.geometry_contract,
    nearby_cells.geometry_visual_quality
  FROM nearby_cells
  WHERE jsonb_typeof(nearby_cells.polygon) = 'array'
    AND jsonb_array_length(nearby_cells.polygon) >= 4;
$$;

GRANT EXECUTE ON FUNCTION fetch_nearby_cells(
  DOUBLE PRECISION,
  DOUBLE PRECISION,
  DOUBLE PRECISION
) TO authenticated;
