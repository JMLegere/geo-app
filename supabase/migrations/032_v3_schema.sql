-- ============================================================================
-- Migration 032: EarthNova v3 schema
-- ============================================================================
-- Creates clean v3 tables alongside existing legacy tables.
-- Old tables (profiles, item_instances, cell_progress) remain UNTOUCHED.
-- Data is migrated from old → new via INSERT ... SELECT.
-- Old tables are kept as a safety net until v3 is confirmed stable.
-- ============================================================================

-- ============================================================================
-- v3_profiles
-- ============================================================================

CREATE TABLE v3_profiles (
  id            UUID REFERENCES auth.users PRIMARY KEY,
  phone         TEXT NOT NULL DEFAULT '',
  display_name  TEXT NOT NULL DEFAULT 'Explorer',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE v3_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "v3_profiles_select_own"
  ON v3_profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "v3_profiles_insert_own"
  ON v3_profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "v3_profiles_update_own"
  ON v3_profiles FOR UPDATE
  USING (auth.uid() = id);

-- ============================================================================
-- v3_items
-- ============================================================================

CREATE TABLE v3_items (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID REFERENCES auth.users NOT NULL,
  definition_id       TEXT NOT NULL,
  display_name        TEXT NOT NULL,
  scientific_name     TEXT,
  category            TEXT NOT NULL DEFAULT 'fauna',
  rarity              TEXT,
  icon_url            TEXT,
  icon_url_frame2     TEXT,   -- frame 2 for 2Hz idle animation (null until enriched)
  art_url             TEXT,
  acquired_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  acquired_in_cell_id TEXT,
  status              TEXT NOT NULL DEFAULT 'active',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE v3_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "v3_items_select_own"
  ON v3_items FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "v3_items_insert_own"
  ON v3_items FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "v3_items_update_own"
  ON v3_items FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "v3_items_delete_own"
  ON v3_items FOR DELETE
  USING (auth.uid() = user_id);

CREATE INDEX idx_v3_items_user_id
  ON v3_items(user_id);

CREATE INDEX idx_v3_items_definition_id
  ON v3_items(definition_id);

-- Pack screen default sort: acquired_at DESC per user
CREATE INDEX idx_v3_items_user_acquired
  ON v3_items(user_id, acquired_at DESC);

-- ============================================================================
-- v3_cell_visits
-- ============================================================================
-- Every visit gets its own row — no UNIQUE constraint.
-- Full history enables fog, counts, streaks, achievements from raw rows.
-- Fog-of-war: EXISTS(user_id, cell_id)
-- Visit count: COUNT(*) WHERE user_id = x AND cell_id = y
-- Streaks: GROUP BY DATE(visited_at)

CREATE TABLE v3_cell_visits (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES auth.users NOT NULL,
  cell_id    TEXT NOT NULL,
  visited_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE v3_cell_visits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "v3_cell_visits_select_own"
  ON v3_cell_visits FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "v3_cell_visits_insert_own"
  ON v3_cell_visits FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Composite index for the most common query: all visits for a user
CREATE INDEX idx_v3_cell_visits_user_id
  ON v3_cell_visits(user_id);

-- Index for fog-of-war and visit count lookups per cell
CREATE INDEX idx_v3_cell_visits_user_cell
  ON v3_cell_visits(user_id, cell_id);

-- ============================================================================
-- v3_write_queue
-- ============================================================================
-- Reserved for offline support. Empty in v3 MVP.

CREATE TABLE v3_write_queue (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users NOT NULL,
  action      TEXT NOT NULL,
  payload     JSONB NOT NULL DEFAULT '{}'::jsonb,
  status      TEXT NOT NULL DEFAULT 'pending',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

ALTER TABLE v3_write_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "v3_write_queue_select_own"
  ON v3_write_queue FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "v3_write_queue_insert_own"
  ON v3_write_queue FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "v3_write_queue_update_own"
  ON v3_write_queue FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "v3_write_queue_delete_own"
  ON v3_write_queue FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- species table: add icon_url_frame2
-- ============================================================================
-- Frame 2 for 2Hz idle animation in the pack grid.
-- Populated by the enrichment pipeline alongside icon_url.
-- NULL = static icon until enriched.

ALTER TABLE species
  ADD COLUMN IF NOT EXISTS icon_url_frame2 TEXT;

-- ============================================================================
-- New user trigger
-- ============================================================================
-- Creates a v3_profiles row on every new auth.users INSERT.
-- Runs alongside the existing v1 trigger (creates profiles row).
-- Both fire — user gets rows in both profiles AND v3_profiles.

CREATE OR REPLACE FUNCTION public.handle_new_user_v3()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.v3_profiles (id, phone, display_name)
  VALUES (
    NEW.id,
    COALESCE(
      NEW.raw_user_meta_data->>'phone_number',
      NEW.phone,
      NEW.email,
      ''
    ),
    COALESCE(NEW.raw_user_meta_data->>'display_name', 'Explorer')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created_v3
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_v3();

-- ============================================================================
-- Data migration: profiles → v3_profiles
-- ============================================================================
-- Copies all existing users. Phone extracted from auth metadata.
-- ON CONFLICT DO NOTHING is safe to re-run.

INSERT INTO v3_profiles (id, phone, display_name, created_at, updated_at)
SELECT
  p.id,
  COALESCE(
    u.raw_user_meta_data->>'phone_number',
    u.phone,
    u.email,
    ''
  ),
  COALESCE(p.display_name, 'Explorer'),
  p.created_at,
  p.updated_at
FROM profiles p
JOIN auth.users u ON u.id = p.id
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- Data migration: item_instances → v3_items
-- ============================================================================
-- Copies all active item instances.
-- Joins species table to fill icon_url/art_url where item_instances has NULLs.
-- Column names verified against migrations 002 + 006 + 023.

INSERT INTO v3_items (
  id,
  user_id,
  definition_id,
  display_name,
  scientific_name,
  category,
  rarity,
  icon_url,
  icon_url_frame2,
  art_url,
  acquired_at,
  acquired_in_cell_id,
  status,
  created_at
)
SELECT
  ii.id,
  ii.user_id,
  ii.definition_id,
  COALESCE(ii.display_name, ii.definition_id),
  ii.scientific_name,
  COALESCE(ii.category_name, 'fauna'),
  ii.rarity_name,
  COALESCE(ii.icon_url, s.icon_url),
  NULL,  -- icon_url_frame2: not yet generated; enrichment pipeline will populate
  COALESCE(ii.art_url, s.art_url),
  ii.acquired_at,
  ii.acquired_in_cell_id,
  COALESCE(ii.status, 'active'),
  ii.created_at
FROM item_instances ii
LEFT JOIN species s ON s.definition_id = ii.definition_id
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- Data migration: cell_progress → v3_cell_visits
-- ============================================================================
-- Creates one visit row per cell where visit_count > 0.
-- visited_at = last_visited if available, else created_at.
-- This seeds the visit history from v1/v2 data.

INSERT INTO v3_cell_visits (user_id, cell_id, visited_at)
SELECT
  user_id,
  cell_id,
  COALESCE(last_visited, created_at)
FROM cell_progress
WHERE visit_count > 0
ON CONFLICT DO NOTHING;
