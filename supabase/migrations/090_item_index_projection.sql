-- Migration 090: authenticated Item Index read projection.
--
-- Discovery is the durable, one-per-Player/stable-Base-Item Index identity.
-- This read path deliberately projects the first identified Item's exact immutable
-- Base Item Version, never a later current publication, Item Property Value, or
-- Pack Item count.

CREATE OR REPLACE FUNCTION public.fetch_v3_item_index()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication is required to fetch the Item Index'
      USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'entries',
    COALESCE(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'base_item_id', discovery.base_item_id,
            'category', base_item.category,
            'first_identified_item_id', first_item.id,
            'base_item_version_id', base_item_version.id,
            'base_item_revision', base_item_version.revision,
            'display_name', COALESCE(
              NULLIF(
                base_item_version.authored_content #>> '{legacy_item_snapshot,identified_display_name}',
                ''
              ),
              base_item_version.display_name
            ),
            'scientific_name', COALESCE(
              NULLIF(
                base_item_version.authored_content #>> '{legacy_item_snapshot,identified_scientific_name}',
                ''
              ),
              base_item_version.scientific_name
            ),
            'discovery_provenance', discovery.provenance,
            'discovered_at', discovery.discovered_at
          )
          ORDER BY discovery.discovered_at DESC, discovery.base_item_id ASC
        )
        FROM public.v3_item_discoveries AS discovery
        JOIN public.v3_items AS first_item
          ON first_item.id = discovery.first_identified_item_id
          AND first_item.user_id = discovery.user_id
          AND first_item.base_item_id = discovery.base_item_id
          AND first_item.base_item_version_id = discovery.first_base_item_version_id
        JOIN public.v3_base_items AS base_item
          ON base_item.id = discovery.base_item_id
        JOIN public.v3_base_item_versions AS base_item_version
          ON base_item_version.id = discovery.first_base_item_version_id
          AND base_item_version.base_item_id = discovery.base_item_id
        WHERE discovery.user_id = v_user_id
      ),
      '[]'::jsonb
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fetch_v3_item_index() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fetch_v3_item_index() TO authenticated;
