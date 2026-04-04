-- Migration 035: Add species filter metadata to v3_items
-- Denormalizes taxonomic_class, habitats_json, continents_json from species table
-- so the Flutter client can filter the pack grid without JOINs.

ALTER TABLE v3_items ADD COLUMN IF NOT EXISTS taxonomic_class TEXT;
ALTER TABLE v3_items ADD COLUMN IF NOT EXISTS habitats_json   TEXT;
ALTER TABLE v3_items ADD COLUMN IF NOT EXISTS continents_json  TEXT;

-- Backfill from species table (LEFT JOIN so non-species items get NULL)
UPDATE v3_items
SET
  taxonomic_class = s.taxonomic_class,
  habitats_json   = s.habitats_json,
  continents_json  = s.continents_json
FROM species s
WHERE v3_items.definition_id = s.definition_id
  AND v3_items.taxonomic_class IS NULL;
