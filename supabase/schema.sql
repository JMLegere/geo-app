-- ============================================================================
-- EarthNova — Schema Snapshot
-- ============================================================================
-- Human-readable reference. NOT executable — run migrations instead.
-- Generated from 31 migrations (001–031) + planned v3 tables (032).
-- Last updated: 2026-04-03
--
-- TABLE OF CONTENTS
-- ─────────────────────────────────────────────────────────────────────────────
-- LEGACY (v1/v2) — untouched, data preserved
--   profiles            — user profiles (v1)
--   cell_progress       — per-cell fog state + visit count (v1)
--   collected_species   — discovered species per user per cell (v1)
--   item_instances      — collected item instances, heavily denormalized (v2)
--   daily_seeds         — server-side daily encounter seed (v2)
--   species             — 32,752 IUCN species catalogue (v2)
--   claimed_species     — first-global-discoverer tracking (v2)
--   countries           — geo hierarchy level 1 (v2)
--   states              — geo hierarchy level 2 (v2)
--   cities              — geo hierarchy level 3 (v2)
--   districts           — geo hierarchy level 4 (v2)
--
-- OBSERVABILITY
--   app_logs            — all client events, errors, lifecycle (unified in 024)
--
-- V3 (new, alongside legacy)
--   v3_profiles         — clean user profiles for v3
--   v3_items            — clean item instances for v3
--   v3_cell_visits      — all cell visits, full history
--   v3_write_queue      — offline write queue (reserved, empty in MVP)
-- ============================================================================

-- ============================================================================
-- LEGACY TABLES (migrations 001–031)
-- ============================================================================

-- profiles (001)
-- User profile, one row per auth.users entry. Created by trigger on signup.
CREATE TABLE profiles (
  id            UUID REFERENCES auth.users PRIMARY KEY,
  display_name  TEXT,
  current_streak     INT DEFAULT 0,
  longest_streak     INT DEFAULT 0,
  last_active_date   DATE,
  total_distance     DOUBLE PRECISION DEFAULT 0,
  onboarding_complete BOOLEAN DEFAULT false,  -- added 005
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);

-- cell_progress (001)
-- Per-cell fog state and visit tracking per user.
CREATE TABLE cell_progress (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id      UUID REFERENCES auth.users NOT NULL,
  cell_id      TEXT NOT NULL,
  fog_state    TEXT NOT NULL DEFAULT 'undetected',
  distance_walked DOUBLE PRECISION DEFAULT 0,
  visit_count  INT DEFAULT 0,
  restoration_level DOUBLE PRECISION DEFAULT 0,
  last_visited TIMESTAMPTZ,
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, cell_id)
);

-- collected_species (001)
-- Pre-item-system: species discovered per user per cell.
CREATE TABLE collected_species (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    UUID REFERENCES auth.users NOT NULL,
  species_id TEXT NOT NULL,
  cell_id    TEXT NOT NULL,
  collected_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, species_id, cell_id)
);

-- daily_seeds (003)
-- Server-side encounter seeds. One row per calendar day (UTC).
-- Edge Function generates seed; client caches for deterministic encounters.
CREATE TABLE daily_seeds (
  seed_date   DATE PRIMARY KEY,
  seed_value  TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- item_instances (002 + 004 + 006 + 007 + 023)
-- Collected item instances. Heavily denormalized — species fields snapshotted
-- at discovery time. 40+ columns after enrichment migrations.
-- Core columns only listed here; see migrations 006 + 023 for full list.
CREATE TABLE item_instances (
  id                   UUID PRIMARY KEY,
  user_id              UUID REFERENCES auth.users NOT NULL,
  definition_id        TEXT NOT NULL,
  affixes              TEXT DEFAULT '[]',
  parent_a_id          UUID,
  parent_b_id          UUID,
  acquired_at          TIMESTAMPTZ NOT NULL,
  acquired_in_cell_id  TEXT,
  daily_seed           TEXT,
  status               TEXT DEFAULT 'active',
  -- Denormalized identity (006):
  display_name         TEXT,
  scientific_name      TEXT,
  category_name        TEXT,
  rarity_name          TEXT,
  habitats_json        TEXT,
  continents_json      TEXT,
  taxonomic_class      TEXT,
  -- Badges (004):
  badge_first_discoverer BOOLEAN DEFAULT false,
  badge_pioneer          BOOLEAN DEFAULT false,
  badge_artist           BOOLEAN DEFAULT false,
  -- Size (007):
  size_name            TEXT,
  -- Enrichment denorm (023): icon_url, art_url, animal_class_name,
  -- food_preference_name, climate_name, brawn, wit, speed,
  -- location_district/city/state/country/country_code,
  -- cell_habitat_name, cell_climate_name, cell_continent_name,
  -- plus *_enrichver stamps for all above
  created_at           TIMESTAMPTZ DEFAULT now(),
  updated_at           TIMESTAMPTZ DEFAULT now()
);

-- species (019)
-- 32,752 IUCN species catalogue. Seeded from assets/species_data.json.
-- Enrichment pipeline writes icon_url, art_url, and enriched fields.
CREATE TABLE species (
  definition_id      TEXT PRIMARY KEY,
  scientific_name    TEXT NOT NULL DEFAULT '',
  common_name        TEXT NOT NULL DEFAULT '',
  taxonomic_class    TEXT NOT NULL DEFAULT '',
  iucn_status        TEXT NOT NULL DEFAULT '',
  habitats_json      TEXT,
  continents_json    TEXT,
  animal_class       TEXT,
  food_preference    TEXT,
  climate            TEXT,
  brawn              INTEGER,
  wit                INTEGER,
  speed              INTEGER,
  size               TEXT,
  icon_url           TEXT,
  icon_url_frame2    TEXT,   -- v3: frame 2 for 2Hz idle animation
  icon_url_enrichver TEXT,
  art_url            TEXT,
  art_url_enrichver  TEXT,
  enriched_at        TIMESTAMPTZ,
  created_at         TIMESTAMPTZ DEFAULT now()
);

-- claimed_species (030)
-- Tracks first global discoverer of each species.
CREATE TABLE claimed_species (
  definition_id  TEXT PRIMARY KEY,
  claimed_by     UUID NOT NULL REFERENCES auth.users(id),
  claimed_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Geo hierarchy (027): countries, states, cities, districts
-- Used for location display on species cards (e.g. "Halifax, NS 🇨🇦")
CREATE TABLE countries  ( id TEXT PRIMARY KEY, name TEXT, code TEXT );
CREATE TABLE states     ( id TEXT PRIMARY KEY, country_id TEXT REFERENCES countries(id), name TEXT );
CREATE TABLE cities     ( id TEXT PRIMARY KEY, state_id TEXT REFERENCES states(id), name TEXT );
CREATE TABLE districts  ( id TEXT PRIMARY KEY, city_id TEXT REFERENCES cities(id), name TEXT );

-- ============================================================================
-- OBSERVABILITY (migrations 010–024)
-- ============================================================================

-- app_logs (010 + 011 + 013 + 024)
-- All client observability. Auth events, lifecycle, errors, data events.
-- Structured events use category + event + data columns.
-- Retention: 7 days (pg_cron purge at 3am UTC daily).
CREATE TABLE app_logs (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     UUID,
  session_id  UUID NOT NULL,
  lines       TEXT,              -- legacy: raw debugPrint output (v3: unused)
  app_version TEXT,
  platform    TEXT,
  device_id   TEXT,              -- SHA-256 hash of device info (first 12 chars)
  phone_number TEXT,             -- deprecated in v3 (never log raw phone)
  category    TEXT,              -- lifecycle | infrastructure | auth | data | network | error
  event       TEXT,              -- e.g. auth.sign_in_success
  data        JSONB,             -- event-specific payload
  created_at  TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ============================================================================
-- V3 TABLES (migration 032 — planned)
-- ============================================================================

-- v3_profiles
-- Clean user profile for v3. Created by trigger on auth.users INSERT.
CREATE TABLE v3_profiles (
  id            UUID REFERENCES auth.users PRIMARY KEY,
  phone         TEXT NOT NULL DEFAULT '',
  display_name  TEXT NOT NULL DEFAULT 'Explorer',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- v3_items
-- Collected item instances for v3. Denormalized from species at discovery.
-- Minimal denorm — only fields needed for pack display.
CREATE TABLE v3_items (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID REFERENCES auth.users NOT NULL,
  definition_id       TEXT NOT NULL,
  display_name        TEXT NOT NULL,
  scientific_name     TEXT,
  category            TEXT NOT NULL DEFAULT 'fauna',
  rarity              TEXT,
  icon_url            TEXT,         -- frame 1 — default pose
  icon_url_frame2     TEXT,         -- frame 2 — 2Hz idle animation (null until enriched)
  art_url             TEXT,
  acquired_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  acquired_in_cell_id TEXT,
  status              TEXT NOT NULL DEFAULT 'active',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- v3_cell_visits
-- Every cell visit gets its own row. No UNIQUE constraint.
-- Fog-of-war: EXISTS(user_id, cell_id)
-- Visit count: COUNT(*) WHERE user_id = x AND cell_id = y
-- Streaks: GROUP BY DATE(visited_at)
CREATE TABLE v3_cell_visits (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES auth.users NOT NULL,
  cell_id    TEXT NOT NULL,
  visited_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- v3_write_queue
-- Offline write queue. Reserved for post-MVP offline support. Empty in v3 MVP.
CREATE TABLE v3_write_queue (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users NOT NULL,
  action      TEXT NOT NULL,
  payload     JSONB NOT NULL DEFAULT '{}'::jsonb,
  status      TEXT NOT NULL DEFAULT 'pending',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ
);
