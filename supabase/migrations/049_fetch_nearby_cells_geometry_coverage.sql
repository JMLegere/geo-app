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
  JOIN cell_geometry_current cell_geom
    ON cell_geom.cell_id = model.cell_id
  WHERE jsonb_typeof(model.polygon) = 'array'
    AND jsonb_array_length(model.polygon) >= 4
    AND ST_DWithin(
      cell_geom.geom::geography,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
      p_radius_meters
    );
$$;

GRANT EXECUTE ON FUNCTION fetch_nearby_cells(
  DOUBLE PRECISION,
  DOUBLE PRECISION,
  DOUBLE PRECISION
) TO authenticated;
