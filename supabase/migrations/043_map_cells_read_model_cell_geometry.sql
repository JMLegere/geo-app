-- Repair map cell read model to use true active per-cell geometry.
--
-- Legacy 037 incorrectly sourced `polygon` from district/admin boundaries.
-- This migration makes active PostGIS cell geometry the source of truth and
-- keeps a legacy exterior-ring `polygon` field while adding the richer
-- `polygons -> rings -> points` transport field for the renderer upgrade.

CREATE OR REPLACE FUNCTION cell_geometry_latlng_polygons_jsonb(p_geom geometry)
RETURNS JSONB
LANGUAGE SQL
IMMUTABLE
STRICT
AS $$
  WITH dumped_polygons AS (
    SELECT
      (dumped).path[1] AS polygon_index,
      (dumped).geom AS polygon_geom
    FROM ST_Dump(p_geom) AS dumped
  ), rings AS (
    SELECT
      polygon_index,
      0 AS ring_index,
      ST_ExteriorRing(polygon_geom) AS ring_geom
    FROM dumped_polygons

    UNION ALL

    SELECT
      polygon_index,
      interior_index AS ring_index,
      ST_InteriorRingN(polygon_geom, interior_index) AS ring_geom
    FROM dumped_polygons
    CROSS JOIN LATERAL generate_series(1, ST_NumInteriorRings(polygon_geom)) AS interior_index
  ), points AS (
    SELECT
      rings.polygon_index,
      rings.ring_index,
      (dumped_point).path[1] AS point_index,
      (dumped_point).geom AS point_geom
    FROM rings
    CROSS JOIN LATERAL ST_DumpPoints(rings.ring_geom) AS dumped_point
  ), ring_json AS (
    SELECT
      polygon_index,
      ring_index,
      jsonb_agg(
        jsonb_build_object(
          'lat', ST_Y(point_geom),
          'lng', ST_X(point_geom)
        )
        ORDER BY point_index
      ) AS ring_points
    FROM points
    GROUP BY polygon_index, ring_index
  ), polygon_json AS (
    SELECT
      polygon_index,
      jsonb_agg(ring_points ORDER BY ring_index) AS polygon_rings
    FROM ring_json
    GROUP BY polygon_index
  )
  SELECT COALESCE(jsonb_agg(polygon_rings ORDER BY polygon_index), '[]'::jsonb)
  FROM polygon_json;
$$;

DROP FUNCTION IF EXISTS fetch_nearby_cells(
  DOUBLE PRECISION,
  DOUBLE PRECISION,
  DOUBLE PRECISION
);

DROP VIEW IF EXISTS v3_map_cells_read_model;

CREATE VIEW v3_map_cells_read_model AS
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
  cg.source_version AS geometry_source_version
FROM cell_properties cp
JOIN cell_geometry_current cg
  ON cg.cell_id = cp.cell_id
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
  geometry_source_version TEXT
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
    model.geometry_source_version
  FROM v3_map_cells_read_model model
  WHERE jsonb_typeof(model.polygon) = 'array'
    AND jsonb_array_length(model.polygon) >= 4
    AND ST_DWithin(
      ST_SetSRID(ST_MakePoint(model.centroid_lon, model.centroid_lat), 4326)::geography,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
      p_radius_meters
    );
$$;

GRANT EXECUTE ON FUNCTION cell_geometry_latlng_polygons_jsonb(geometry) TO authenticated;
GRANT SELECT ON v3_map_cells_read_model TO authenticated;
GRANT EXECUTE ON FUNCTION fetch_nearby_cells(
  DOUBLE PRECISION,
  DOUBLE PRECISION,
  DOUBLE PRECISION
) TO authenticated;
