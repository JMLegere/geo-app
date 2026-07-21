-- Migration 097: durable Home identity and canonical Food and Orb Base Items.
--
-- Home is a single immutable personal-base identity per Player. Food and Orb
-- stay within the existing immutable Base Item publication lifecycle.

CREATE TABLE IF NOT EXISTS public.v3_player_homes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES public.v3_profiles(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.prevent_v3_player_home_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'Home state is immutable';
END;
$$;

CREATE OR REPLACE FUNCTION public.create_v3_home_for_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.v3_player_homes (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DO $create_v3_player_home_triggers$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'v3_player_homes_prevent_mutation'
      AND tgrelid = 'public.v3_player_homes'::regclass
      AND NOT tgisinternal
  ) THEN
    CREATE TRIGGER v3_player_homes_prevent_mutation
      BEFORE UPDATE OR DELETE ON public.v3_player_homes
      FOR EACH ROW EXECUTE FUNCTION public.prevent_v3_player_home_mutation();
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'v3_profiles_create_home'
      AND tgrelid = 'public.v3_profiles'::regclass
      AND NOT tgisinternal
  ) THEN
    CREATE TRIGGER v3_profiles_create_home
      AFTER INSERT ON public.v3_profiles
      FOR EACH ROW EXECUTE FUNCTION public.create_v3_home_for_profile();
  END IF;
END;
$create_v3_player_home_triggers$;

-- Preserve any legacy Food rows while rejecting every new noncanonical Food
-- identity. A NOT VALID check still applies to all future inserts and updates.
DO $add_v3_base_items_food_identity_whitelist$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'v3_base_items_food_identity_whitelist'
      AND conrelid = 'public.v3_base_items'::regclass
  ) THEN
    ALTER TABLE public.v3_base_items
      ADD CONSTRAINT v3_base_items_food_identity_whitelist
      CHECK (
        category <> 'food' OR id IN (
          'food:veg',
          'food:fruit',
          'food:critter',
          'food:fish',
          'food:grub',
          'food:nectar'
        )
      ) NOT VALID;
  END IF;
END;
$add_v3_base_items_food_identity_whitelist$;

-- Validate before any Home backfill or Base Item publication. Unexpected
-- legacy Food identities block cutover without deleting or changing data.
ALTER TABLE public.v3_base_items
  VALIDATE CONSTRAINT v3_base_items_food_identity_whitelist;

CREATE OR REPLACE FUNCTION public.get_v3_home()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_home public.v3_player_homes%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Home requires an authenticated user' USING ERRCODE = '28000';
  END IF;

  SELECT *
  INTO v_home
  FROM public.v3_player_homes
  WHERE user_id = v_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Home is missing for authenticated user' USING ERRCODE = '23503';
  END IF;

  RETURN jsonb_build_object(
    'id', v_home.id,
    'user_id', v_home.user_id,
    'created_at', v_home.created_at
  );
END;
$$;

ALTER TABLE public.v3_player_homes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "v3_player_homes_authenticated_read_own"
  ON public.v3_player_homes
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

REVOKE INSERT, UPDATE, DELETE ON TABLE public.v3_player_homes FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.prevent_v3_player_home_mutation() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.create_v3_home_for_profile() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_v3_home() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_v3_home() TO authenticated;

-- Backfill follows all ALTER and RLS work so it cannot leave deferred trigger
-- events pending ahead of later schema changes.
INSERT INTO public.v3_player_homes (user_id)
SELECT profile.id
FROM public.v3_profiles AS profile
ON CONFLICT (user_id) DO NOTHING;

-- Canonical Food Types and the explicit behavior-free Orb Base Item use stable
-- identities and revision-one published versions. The seed is repeat-safe.
INSERT INTO public.v3_base_items (id, category)
VALUES
  ('food:veg', 'food'),
  ('food:fruit', 'food'),
  ('food:critter', 'food'),
  ('food:fish', 'food'),
  ('food:grub', 'food'),
  ('food:nectar', 'food'),
  ('orb:orb_type', 'orb')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.v3_base_item_versions (
  id,
  base_item_id,
  revision,
  publication_status,
  display_name
)
VALUES
  (md5('earthnova:base-item-version:food:veg:1')::uuid, 'food:veg', 1, 'draft', 'Veg'),
  (md5('earthnova:base-item-version:food:fruit:1')::uuid, 'food:fruit', 1, 'draft', 'Fruit'),
  (md5('earthnova:base-item-version:food:critter:1')::uuid, 'food:critter', 1, 'draft', 'Critter'),
  (md5('earthnova:base-item-version:food:fish:1')::uuid, 'food:fish', 1, 'draft', 'Fish'),
  (md5('earthnova:base-item-version:food:grub:1')::uuid, 'food:grub', 1, 'draft', 'Grub'),
  (md5('earthnova:base-item-version:food:nectar:1')::uuid, 'food:nectar', 1, 'draft', 'Nectar'),
  (md5('earthnova:base-item-version:orb:orb_type:1')::uuid, 'orb:orb_type', 1, 'draft', 'Orb Type')
ON CONFLICT (base_item_id, revision) DO NOTHING;

DO $publish_home_item_category_seed$
BEGIN
  IF EXISTS (SELECT 1 FROM public.v3_base_item_versions WHERE id = md5('earthnova:base-item-version:food:veg:1')::uuid AND publication_status = 'draft') THEN
    PERFORM public.publish_v3_base_item_version('food:veg', md5('earthnova:base-item-version:food:veg:1')::uuid);
  END IF;
  IF EXISTS (SELECT 1 FROM public.v3_base_item_versions WHERE id = md5('earthnova:base-item-version:food:fruit:1')::uuid AND publication_status = 'draft') THEN
    PERFORM public.publish_v3_base_item_version('food:fruit', md5('earthnova:base-item-version:food:fruit:1')::uuid);
  END IF;
  IF EXISTS (SELECT 1 FROM public.v3_base_item_versions WHERE id = md5('earthnova:base-item-version:food:critter:1')::uuid AND publication_status = 'draft') THEN
    PERFORM public.publish_v3_base_item_version('food:critter', md5('earthnova:base-item-version:food:critter:1')::uuid);
  END IF;
  IF EXISTS (SELECT 1 FROM public.v3_base_item_versions WHERE id = md5('earthnova:base-item-version:food:fish:1')::uuid AND publication_status = 'draft') THEN
    PERFORM public.publish_v3_base_item_version('food:fish', md5('earthnova:base-item-version:food:fish:1')::uuid);
  END IF;
  IF EXISTS (SELECT 1 FROM public.v3_base_item_versions WHERE id = md5('earthnova:base-item-version:food:grub:1')::uuid AND publication_status = 'draft') THEN
    PERFORM public.publish_v3_base_item_version('food:grub', md5('earthnova:base-item-version:food:grub:1')::uuid);
  END IF;
  IF EXISTS (SELECT 1 FROM public.v3_base_item_versions WHERE id = md5('earthnova:base-item-version:food:nectar:1')::uuid AND publication_status = 'draft') THEN
    PERFORM public.publish_v3_base_item_version('food:nectar', md5('earthnova:base-item-version:food:nectar:1')::uuid);
  END IF;
  IF EXISTS (SELECT 1 FROM public.v3_base_item_versions WHERE id = md5('earthnova:base-item-version:orb:orb_type:1')::uuid AND publication_status = 'draft') THEN
    PERFORM public.publish_v3_base_item_version('orb:orb_type', md5('earthnova:base-item-version:orb:orb_type:1')::uuid);
  END IF;
END;
$publish_home_item_category_seed$;


DO $assert_canonical_home_item_category_seed$
DECLARE
  v_food_ids TEXT[];
BEGIN
  SELECT array_agg(base_item.id ORDER BY base_item.id)
  INTO v_food_ids
  FROM public.v3_base_items AS base_item
  WHERE base_item.category = 'food';

  IF v_food_ids IS DISTINCT FROM ARRAY[
    'food:critter',
    'food:fish',
    'food:fruit',
    'food:grub',
    'food:nectar',
    'food:veg'
  ] THEN
    RAISE EXCEPTION 'Food Base Item identities must be exactly the six canonical Food Types'
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM (
      VALUES
        ('food:veg'::TEXT, 'Veg'::TEXT),
        ('food:fruit'::TEXT, 'Fruit'::TEXT),
        ('food:critter'::TEXT, 'Critter'::TEXT),
        ('food:fish'::TEXT, 'Fish'::TEXT),
        ('food:grub'::TEXT, 'Grub'::TEXT),
        ('food:nectar'::TEXT, 'Nectar'::TEXT)
    ) AS expected(id, display_name)
    LEFT JOIN public.v3_base_items AS base_item
      ON base_item.id = expected.id
    LEFT JOIN public.v3_base_item_versions AS version
      ON version.id = base_item.current_published_version_id
    WHERE base_item.category IS DISTINCT FROM 'food'
      OR version.base_item_id IS DISTINCT FROM expected.id
      OR version.revision IS DISTINCT FROM 1
      OR version.publication_status IS DISTINCT FROM 'published'
      OR version.display_name IS DISTINCT FROM expected.display_name
  ) THEN
    RAISE EXCEPTION 'Food Base Item seed is incomplete or not current'
      USING ERRCODE = '23514';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.v3_base_items AS base_item
    JOIN public.v3_base_item_versions AS version
      ON version.id = base_item.current_published_version_id
    WHERE base_item.id = 'orb:orb_type'
      AND base_item.category = 'orb'
      AND version.base_item_id = 'orb:orb_type'
      AND version.revision = 1
      AND version.publication_status = 'published'
      AND version.display_name = 'Orb Type'
  ) THEN
    RAISE EXCEPTION 'Orb Base Item seed is not current and published'
      USING ERRCODE = '23514';
  END IF;
END;
$assert_canonical_home_item_category_seed$;

COMMENT ON TABLE public.v3_player_homes IS
  'One immutable personal-base identity for each Player profile.';
COMMENT ON FUNCTION public.get_v3_home() IS
  'Strict authenticated projection of the caller-owned immutable Home identity.';
