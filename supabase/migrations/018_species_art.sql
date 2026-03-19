-- Add icon_url column to species_enrichment table for chibi sprite icons.
-- art_url already exists for watercolor illustrations.
ALTER TABLE species_enrichment ADD COLUMN IF NOT EXISTS icon_url text;

-- Create public storage bucket for species art assets.
-- Files: {definitionId}_icon.webp (96x96 chibi) and {definitionId}.webp (512x512 watercolor)
INSERT INTO storage.buckets (id, name, public)
VALUES ('species-art', 'species-art', true)
ON CONFLICT (id) DO NOTHING;

-- Allow public reads (no auth needed for viewing art)
CREATE POLICY "Public read access" ON storage.objects
  FOR SELECT USING (bucket_id = 'species-art');

-- Allow service role to upload art (Edge Functions use service role)
CREATE POLICY "Service role upload" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'species-art');

-- Allow service role to update/overwrite art
CREATE POLICY "Service role update" ON storage.objects
  FOR UPDATE USING (bucket_id = 'species-art');
