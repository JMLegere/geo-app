-- ============================================================================
-- EarthNova v3 — Seed Data (local dev only)
-- ============================================================================
-- Creates one test user profile and 5 fauna items for pack screen testing.
-- Replace {{TEST_USER_ID}} with a real auth.users UUID before running.
--
-- Usage:
--   export TEST_USER_ID=$(supabase db query --linked \
--     "SELECT id FROM auth.users LIMIT 1" | tail -1 | tr -d ' ')
--   sed "s/{{TEST_USER_ID}}/$TEST_USER_ID/g" supabase/seed.sql | \
--     supabase db query --linked
--
-- Or via just:
--   just seed
-- ============================================================================

-- v3_profiles
INSERT INTO v3_profiles (id, phone, display_name)
VALUES ('{{TEST_USER_ID}}', '+15551234567', 'TestExplorer')
ON CONFLICT (id) DO NOTHING;

-- v3_items — 5 fauna across different rarities for visual testing
INSERT INTO v3_items (
  id, user_id, definition_id,
  display_name, scientific_name,
  category, rarity,
  icon_url, icon_url_frame2, art_url,
  acquired_at, acquired_in_cell_id, status
) VALUES

-- Red Fox — Least Concern (white border)
(
  gen_random_uuid(), '{{TEST_USER_ID}}', 'fauna_vulpes_vulpes',
  'Red Fox', 'Vulpes vulpes',
  'fauna', 'leastConcern',
  NULL, NULL, NULL,
  now() - interval '5 days', 'v_45_67', 'active'
),

-- Bengal Tiger — Endangered (gold border)
(
  gen_random_uuid(), '{{TEST_USER_ID}}', 'fauna_panthera_tigris_tigris',
  'Bengal Tiger', 'Panthera tigris tigris',
  'fauna', 'endangered',
  NULL, NULL, NULL,
  now() - interval '4 days', 'v_23_89', 'active'
),

-- Giant Panda — Vulnerable (blue border)
(
  gen_random_uuid(), '{{TEST_USER_ID}}', 'fauna_ailuropoda_melanoleuca',
  'Giant Panda', 'Ailuropoda melanoleuca',
  'fauna', 'vulnerable',
  NULL, NULL, NULL,
  now() - interval '3 days', 'v_12_34', 'active'
),

-- Western Gorilla — Critically Endangered (purple border)
(
  gen_random_uuid(), '{{TEST_USER_ID}}', 'fauna_gorilla_gorilla',
  'Western Gorilla', 'Gorilla gorilla',
  'fauna', 'criticallyEndangered',
  NULL, NULL, NULL,
  now() - interval '2 days', 'v_78_90', 'active'
),

-- Steller''s Sea Eagle — Near Threatened (green border)
(
  gen_random_uuid(), '{{TEST_USER_ID}}', 'fauna_haliaeetus_pelagicus',
  'Steller''s Sea Eagle', 'Haliaeetus pelagicus',
  'fauna', 'nearThreatened',
  NULL, NULL, NULL,
  now() - interval '1 day', 'v_56_12', 'active'
)

ON CONFLICT (id) DO NOTHING;
