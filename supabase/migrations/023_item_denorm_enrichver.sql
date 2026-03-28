-- ============================================================================
-- Item instance denormalization + per-field enrichment versions
-- ============================================================================
-- Adds denormalized enrichment fields to item_instances for client display.
-- Adds per-field enrichver stamps to both tables for the pipeline.

-- Item instance table: denormalized species + cell + location fields
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS icon_url TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS art_url TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS animal_class_name TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS animal_class_name_enrichver TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS food_preference_name TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS food_preference_name_enrichver TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS climate_name TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS climate_name_enrichver TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS size_name TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS size_name_enrichver TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS brawn INTEGER;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS brawn_enrichver TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS wit INTEGER;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS wit_enrichver TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS speed INTEGER;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS speed_enrichver TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS icon_url_enrichver TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS art_url_enrichver TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS cell_habitat_name TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS cell_habitat_name_enrichver TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS cell_climate_name TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS cell_climate_name_enrichver TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS cell_continent_name TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS cell_continent_name_enrichver TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS location_district TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS location_district_enrichver TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS location_city TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS location_city_enrichver TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS location_state TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS location_state_enrichver TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS location_country TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS location_country_enrichver TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS location_country_code TEXT;
ALTER TABLE item_instances ADD COLUMN IF NOT EXISTS location_country_code_enrichver TEXT;

-- Species table: per-field enrichment version stamps
ALTER TABLE species ADD COLUMN IF NOT EXISTS animal_class_enrichver TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS food_preference_enrichver TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS climate_enrichver TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS brawn_enrichver TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS wit_enrichver TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS speed_enrichver TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS size_enrichver TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS icon_prompt_enrichver TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS art_prompt_enrichver TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS icon_url_enrichver TEXT;
ALTER TABLE species ADD COLUMN IF NOT EXISTS art_url_enrichver TEXT;
