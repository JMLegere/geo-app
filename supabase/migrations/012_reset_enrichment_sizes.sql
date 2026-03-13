-- Reset all enrichment sizes to NULL so species get re-enriched
-- with the improved size classification prompt.
-- The Edge Functions check: if size IS NULL, they fall through to LLM re-enrichment.
UPDATE species_enrichment SET size = NULL WHERE size IS NOT NULL;
