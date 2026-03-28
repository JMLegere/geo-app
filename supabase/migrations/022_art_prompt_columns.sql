-- ============================================================================
-- Add icon_prompt and art_prompt columns to species table
-- ============================================================================
-- 2-stage art pipeline: LLM generates prompts, then image gen uses them.

ALTER TABLE species ADD COLUMN IF NOT EXISTS icon_prompt TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS art_prompt TEXT;

CREATE INDEX IF NOT EXISTS idx_species_needs_prompt
  ON species (definition_id)
  WHERE animal_class IS NOT NULL AND (icon_prompt IS NULL OR art_prompt IS NULL);
