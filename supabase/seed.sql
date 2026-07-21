-- ============================================================================
-- EarthNova v3 — Seed Data (local development only)
-- ============================================================================
-- Seeds one existing local auth user when present. Fresh local stacks with no
-- auth user intentionally skip this optional fixture instead of failing startup.
-- Item IDs are deterministic, so replaying the seed cannot duplicate rows.
-- ============================================================================

DO $seed_local_pack_fixture$
DECLARE
  test_user_id UUID;
BEGIN
  SELECT auth_user.id
  INTO test_user_id
  FROM auth.users AS auth_user
  ORDER BY auth_user.created_at, auth_user.id
  LIMIT 1;

  IF test_user_id IS NULL THEN
    RAISE NOTICE 'Skipping optional local Pack seed because auth.users is empty';
    RETURN;
  END IF;

  INSERT INTO public.v3_profiles (id, phone, display_name)
  VALUES (test_user_id, '+15551234567', 'TestExplorer')
  ON CONFLICT (id) DO NOTHING;

  -- The varied legacy status field remains local visual compatibility evidence;
  -- every seeded Item is nevertheless bound to an exact current Base Item Version.
  WITH seed_item(base_item_id, legacy_status, acquired_ago, cell_id) AS (
    VALUES
      ('fauna:red_fox', 'leastConcern', interval '5 days', 'v_45_67'),
      ('fauna:amberwing_warbler', 'endangered', interval '4 days', 'v_23_89'),
      ('fauna:monarch_butterfly', 'vulnerable', interval '3 days', 'v_12_34'),
      ('fauna:painted_turtle', 'criticallyEndangered', interval '2 days', 'v_78_90'),
      ('fauna:snowshoe_hare', 'nearThreatened', interval '1 day', 'v_56_12')
  )
  INSERT INTO public.v3_items (
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
    base_item_id,
    base_item_version_id
  )
  SELECT
    md5(test_user_id::text || ':' || seed_item.base_item_id)::uuid,
    test_user_id,
    base_item.id,
    version.display_name,
    version.scientific_name,
    base_item.category,
    seed_item.legacy_status,
    version.icon_url,
    version.icon_url_frame2,
    version.art_url,
    now() - seed_item.acquired_ago,
    seed_item.cell_id,
    'active',
    base_item.id,
    version.id
  FROM seed_item
  JOIN public.v3_base_items AS base_item
    ON base_item.id = seed_item.base_item_id
  JOIN public.v3_base_item_versions AS version
    ON version.id = base_item.current_published_version_id
  ON CONFLICT (id) DO NOTHING;
END;
$seed_local_pack_fixture$;
