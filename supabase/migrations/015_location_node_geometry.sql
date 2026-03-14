-- Add geometry_json column to location_nodes for storing simplified admin boundary polygons.
-- Populated by the resolve-admin-boundaries Edge Function via Nominatim.
-- NULL until fetched. Stores simplified GeoJSON string (Polygon or MultiPolygon).
ALTER TABLE location_nodes ADD COLUMN IF NOT EXISTS geometry_json text NULL;
