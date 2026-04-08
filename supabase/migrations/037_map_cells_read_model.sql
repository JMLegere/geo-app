-- Nearby cell read model with full geometry + hierarchy payload for map rendering.

CREATE OR REPLACE VIEW v3_map_cells_read_model AS
SELECT
  cp.cell_id,
  cp.habitats,
  CASE
    WHEN d.boundary_json IS NULL OR btrim(d.boundary_json) = '' THEN '[]'::jsonb
    ELSE d.boundary_json::jsonb
  END AS polygon,
  d.id AS district_id,
  c.id AS city_id,
  s.id AS state_id,
  country.id AS country_id,
  d.centroid_lat,
  d.centroid_lon
FROM cell_properties cp
JOIN districts d ON d.id = cp.location_id
JOIN cities c ON c.id = d.city_id
JOIN states s ON s.id = c.state_id
JOIN countries country ON country.id = s.country_id;

CREATE OR REPLACE FUNCTION fetch_nearby_cells(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_meters DOUBLE PRECISION DEFAULT 2000
)
RETURNS TABLE (
  cell_id TEXT,
  habitats TEXT[],
  polygon JSONB,
  district_id TEXT,
  city_id TEXT,
  state_id TEXT,
  country_id TEXT
)
LANGUAGE SQL
STABLE
SECURITY INVOKER
AS $$
  SELECT
    model.cell_id,
    model.habitats,
    model.polygon,
    model.district_id,
    model.city_id,
    model.state_id,
    model.country_id
  FROM v3_map_cells_read_model model
  WHERE jsonb_typeof(model.polygon) = 'array'
    AND jsonb_array_length(model.polygon) > 0
    AND (
      6371000 * acos(
        LEAST(
          1.0,
          GREATEST(
            -1.0,
            cos(radians(p_lat))
              * cos(radians(model.centroid_lat))
              * cos(radians(model.centroid_lon) - radians(p_lng))
              + sin(radians(p_lat)) * sin(radians(model.centroid_lat))
          )
        )
      )
    ) <= p_radius_meters;
$$;

GRANT EXECUTE ON FUNCTION fetch_nearby_cells(
  DOUBLE PRECISION,
  DOUBLE PRECISION,
  DOUBLE PRECISION
) TO authenticated;
