-- EarthNova Phase 1c — Enrichment Pipeline
-- Two tables: species_enrichment (global) and item_instances (per-user)

-- ---------------------------------------------------------------------------
-- species_enrichment — Global. One row per definition_id.
-- AI-enriched classification data for fauna species.
-- Only service_role can INSERT/UPDATE (Edge Functions). All authenticated
-- users can SELECT.
-- ---------------------------------------------------------------------------

CREATE TABLE species_enrichment (
  definition_id TEXT PRIMARY KEY,          -- e.g. "fauna_vulpes_vulpes"
  animal_class  TEXT NOT NULL,             -- e.g. "carnivore" (AnimalClass enum name)
  food_preference TEXT NOT NULL,           -- e.g. "critter" (FoodType enum name)
  climate       TEXT NOT NULL,             -- e.g. "temperate" (Climate enum name)
  brawn         INT  NOT NULL,
  wit           INT  NOT NULL,
  speed         INT  NOT NULL,
  art_url       TEXT,                      -- null until art generation is implemented
  enriched_at   TIMESTAMPTZ DEFAULT now(),
  CHECK (brawn + wit + speed = 90),
  CHECK (brawn >= 0 AND wit >= 0 AND speed >= 0)
);

-- RLS: all authenticated users can read; only service_role writes
ALTER TABLE species_enrichment ENABLE ROW LEVEL SECURITY;

CREATE POLICY "enrichment_select_authenticated"
  ON species_enrichment FOR SELECT
  USING (auth.role() = 'authenticated');

-- service_role bypasses RLS by default — no explicit insert/update policy needed.

CREATE INDEX idx_species_enrichment_enriched_at ON species_enrichment(enriched_at);

-- ---------------------------------------------------------------------------
-- item_instances — Per-user. Mirrors LocalItemInstanceTable in Drift.
-- ---------------------------------------------------------------------------

CREATE TABLE item_instances (
  id                 UUID PRIMARY KEY,
  user_id            UUID REFERENCES auth.users NOT NULL,
  definition_id      TEXT NOT NULL,
  affixes            TEXT DEFAULT '[]',
  parent_a_id        UUID,
  parent_b_id        UUID,
  acquired_at        TIMESTAMPTZ NOT NULL,
  acquired_in_cell_id TEXT,
  daily_seed         TEXT,
  status             TEXT DEFAULT 'active',
  created_at         TIMESTAMPTZ DEFAULT now(),
  updated_at         TIMESTAMPTZ DEFAULT now()
);

-- RLS: users can only CRUD their own rows
ALTER TABLE item_instances ENABLE ROW LEVEL SECURITY;

CREATE POLICY "item_instances_select_own"
  ON item_instances FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "item_instances_insert_own"
  ON item_instances FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "item_instances_update_own"
  ON item_instances FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "item_instances_delete_own"
  ON item_instances FOR DELETE
  USING (auth.uid() = user_id);

CREATE INDEX idx_item_instances_user_id       ON item_instances(user_id);
CREATE INDEX idx_item_instances_definition_id ON item_instances(definition_id);
