-- Denormalize species identity fields onto item_instances so clients can
-- display collection items without joining back to the species catalogue.
-- These columns are snapshotted at discovery time and treated as immutable.
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS display_name TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS scientific_name TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS category_name TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS rarity_name TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS habitats_json TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS continents_json TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS taxonomic_class TEXT;
