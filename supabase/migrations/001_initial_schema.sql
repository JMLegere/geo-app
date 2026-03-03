-- Fog of World — Initial Schema
-- 3 tables: profiles, cell_progress, collected_species
-- Species data stays client-side (33k IUCN records bundled as JSON asset)

-- Player profiles (extends Supabase auth.users)
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

-- Per-cell exploration progress
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

-- Collected species per user per cell
CREATE TABLE collected_species (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  species_id TEXT NOT NULL,
  cell_id TEXT NOT NULL,
  collected_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, species_id, cell_id)
);

-- Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE cell_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE collected_species ENABLE ROW LEVEL SECURITY;

-- Profiles: users can only access their own
CREATE POLICY "profiles_select_own" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "profiles_insert_own" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Cell progress: users can only access their own
CREATE POLICY "cell_progress_select_own" ON cell_progress FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "cell_progress_insert_own" ON cell_progress FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "cell_progress_update_own" ON cell_progress FOR UPDATE USING (auth.uid() = user_id);

-- Collected species: users can only access their own
CREATE POLICY "collected_species_select_own" ON collected_species FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "collected_species_insert_own" ON collected_species FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "collected_species_delete_own" ON collected_species FOR DELETE USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX idx_cell_progress_user_id ON cell_progress(user_id);
CREATE INDEX idx_cell_progress_cell_id ON cell_progress(cell_id);
CREATE INDEX idx_collected_species_user_id ON collected_species(user_id);

-- Auto-create profile on user signup (including anonymous)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'display_name', 'Explorer'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
