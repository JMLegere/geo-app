-- Migration 074: Add identification lifecycle state to v3_items.
-- Discovery now acquires unidentified finds first; Identification later reveals the
-- known species fields on the same owned item identity.

ALTER TABLE v3_items
  ADD COLUMN IF NOT EXISTS identification_state TEXT NOT NULL DEFAULT 'identified',
  ADD COLUMN IF NOT EXISTS identified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS identified_display_name TEXT,
  ADD COLUMN IF NOT EXISTS identified_scientific_name TEXT,
  ADD COLUMN IF NOT EXISTS identified_taxonomic_class TEXT,
  ADD COLUMN IF NOT EXISTS identified_habitats_json TEXT,
  ADD COLUMN IF NOT EXISTS identified_continents_json TEXT;

UPDATE v3_items
SET identification_state = 'identified'
WHERE identification_state IS NULL;

CREATE INDEX IF NOT EXISTS idx_v3_items_user_identification_state
  ON v3_items(user_id, identification_state, acquired_at DESC);
