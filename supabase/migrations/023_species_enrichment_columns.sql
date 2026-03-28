-- Migration 023: Add enrichment version stamp and prompt columns missing from 019.
-- Without these, process-enrichment-queue Edge Function's SELECT fails silently and no species get enriched.

-- Prompt columns (pipeline writes prompts before generating images)
ALTER TABLE species ADD COLUMN IF NOT EXISTS icon_prompt TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS art_prompt  TEXT;

-- Per-field enrichment version stamps (tracks which pipeline commit produced each value)
ALTER TABLE species ADD COLUMN IF NOT EXISTS animal_class_enrichver    TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS food_preference_enrichver TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS climate_enrichver         TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS brawn_enrichver           TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS wit_enrichver             TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS speed_enrichver           TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS size_enrichver            TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS icon_prompt_enrichver     TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS art_prompt_enrichver      TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS icon_url_enrichver        TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS art_url_enrichver         TEXT;

-- Backfill enrichver for already-enriched species so the pipeline doesn't re-process them.
-- 'v1-backfill' signals these values pre-date version stamps, not produced by the current pipeline.
UPDATE species
SET
  animal_class_enrichver    = 'v1-backfill',
  food_preference_enrichver = 'v1-backfill',
  climate_enrichver         = 'v1-backfill',
  brawn_enrichver           = 'v1-backfill',
  wit_enrichver             = 'v1-backfill',
  speed_enrichver           = 'v1-backfill',
  size_enrichver            = 'v1-backfill',
  icon_url_enrichver        = 'v1-backfill',
  art_url_enrichver         = 'v1-backfill'
WHERE enriched_at IS NOT NULL;

-- Rebuild classification index to include enrichver check so species that have a class
-- but no version stamp are still picked up for stamping by the pipeline.
DROP INDEX IF EXISTS idx_species_needs_classification;
CREATE INDEX idx_species_needs_classification
  ON species (definition_id) WHERE animal_class IS NULL OR animal_class_enrichver IS NULL;
