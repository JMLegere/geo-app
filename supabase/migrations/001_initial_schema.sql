-- Fog of World - Initial Database Schema
-- Created for Wave 1, Task 4

-- Users (handled by Supabase Auth, extend with profile)
CREATE TABLE profiles (
  id UUID REFERENCES auth.users PRIMARY KEY,
  display_name TEXT,
  current_streak INT DEFAULT 0,
  longest_streak INT DEFAULT 0,
  total_distance_km DOUBLE PRECISION DEFAULT 0,
  current_season TEXT DEFAULT 'summer',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Cell progress per user
CREATE TABLE cell_progress (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  cell_id TEXT NOT NULL,
  fog_state TEXT NOT NULL DEFAULT 'undetected',
  distance_walked DOUBLE PRECISION DEFAULT 0,
  visit_count INT DEFAULT 0,
  restoration_level DOUBLE PRECISION DEFAULT 0,
  last_visited TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, cell_id)
);

-- Species catalog (seeded, not user-generated)
CREATE TABLE species (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  biome TEXT NOT NULL,
  rarity TEXT NOT NULL,
  description TEXT,
  season_availability TEXT[] DEFAULT '{summer,winter}',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- User's collected species
CREATE TABLE collected_species (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  species_id TEXT REFERENCES species NOT NULL,
  cell_id TEXT NOT NULL,
  collected_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, species_id)
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE cell_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE species ENABLE ROW LEVEL SECURITY;
ALTER TABLE collected_species ENABLE ROW LEVEL SECURITY;

-- RLS Policies for profiles
CREATE POLICY "Users can read their own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- RLS Policies for cell_progress
CREATE POLICY "Users can read their own cell progress"
  ON cell_progress FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own cell progress"
  ON cell_progress FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own cell progress"
  ON cell_progress FOR UPDATE
  USING (auth.uid() = user_id);

-- RLS Policies for species (public read, no write)
CREATE POLICY "Species table is publicly readable"
  ON species FOR SELECT
  USING (true);

-- RLS Policies for collected_species
CREATE POLICY "Users can read their own collected species"
  ON collected_species FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own collected species"
  ON collected_species FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own collected species"
  ON collected_species FOR DELETE
  USING (auth.uid() = user_id);

-- Create indexes for performance
CREATE INDEX idx_cell_progress_user_id ON cell_progress(user_id);
CREATE INDEX idx_cell_progress_cell_id ON cell_progress(cell_id);
CREATE INDEX idx_collected_species_user_id ON collected_species(user_id);
CREATE INDEX idx_species_biome ON species(biome);
CREATE INDEX idx_species_rarity ON species(rarity);
