-- Migration 019: Create unified `species` table
-- Replaces `species_enrichment` with a full species table (32,752 IUCN rows + enrichment columns).
-- Base data seeded by tool/seed_species_table.dart after migration.
-- species_enrichment NOT dropped here — client still reads it until PR 4.

CREATE TABLE IF NOT EXISTS species (
  definition_id       TEXT PRIMARY KEY,
  scientific_name     TEXT NOT NULL DEFAULT '',
  common_name         TEXT NOT NULL DEFAULT '',
  taxonomic_class     TEXT NOT NULL DEFAULT '',
  iucn_status         TEXT NOT NULL DEFAULT '',
  habitats_json       TEXT NOT NULL DEFAULT '[]',
  continents_json     TEXT NOT NULL DEFAULT '[]',
  -- Enrichment (null until AI-classified):
  animal_class        TEXT,
  food_preference     TEXT,
  climate             TEXT,
  brawn               INTEGER,
  wit                 INTEGER,
  speed               INTEGER,
  size                TEXT,
  icon_url            TEXT,
  art_url             TEXT,
  enriched_at         TIMESTAMPTZ
);

-- Migrate existing enrichments (base data defaults until seed script fills them)
INSERT INTO species (definition_id, animal_class, food_preference, climate, brawn, wit, speed, size, icon_url, art_url, enriched_at)
SELECT definition_id, animal_class, food_preference, climate, brawn, wit, speed, size, icon_url, art_url, enriched_at
FROM species_enrichment
ON CONFLICT (definition_id) DO UPDATE SET
  animal_class = EXCLUDED.animal_class,
  food_preference = EXCLUDED.food_preference,
  climate = EXCLUDED.climate,
  brawn = EXCLUDED.brawn,
  wit = EXCLUDED.wit,
  speed = EXCLUDED.speed,
  size = EXCLUDED.size,
  icon_url = EXCLUDED.icon_url,
  art_url = EXCLUDED.art_url,
  enriched_at = EXCLUDED.enriched_at;

-- Partial indices for queue queries (used by process-enrichment-queue)
CREATE INDEX IF NOT EXISTS idx_species_needs_classification
  ON species (definition_id) WHERE animal_class IS NULL;
CREATE INDEX IF NOT EXISTS idx_species_needs_art
  ON species (definition_id) WHERE animal_class IS NOT NULL
  AND (icon_url IS NULL OR art_url IS NULL);

-- RLS: read-only for clients
ALTER TABLE species ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read" ON species FOR SELECT USING (true);
