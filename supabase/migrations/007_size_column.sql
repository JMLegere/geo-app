-- Add size column to species_enrichment for animal size classification.
-- Nullable: enrichments created before this migration have no size.
ALTER TABLE species_enrichment ADD COLUMN size TEXT;
