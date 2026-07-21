-- Migration 085: authenticated legacy discovery Item acquisition command.
--
-- Legacy discovery evidence remains client-reported during the beta compatibility
-- path. Ownership, Item identity/timestamps/status, stable Base Item identity,
-- and the exact bound current published Version are server-owned.
-- p_map_cell_entry_id is trace-only: it is neither persisted nor authorization evidence.
-- Current ComputeEncounter emits only the eight seeded catalog species. Generic
-- 079 legacy-item identities are historical bindings and are never materialized
-- from a new client request.

CREATE OR REPLACE FUNCTION public.acquire_v3_legacy_discovery_item(
  p_definition_id TEXT,
  p_display_name TEXT,
  p_category TEXT,
  p_acquired_in_cell_id TEXT,
  p_scientific_name TEXT DEFAULT NULL,
  p_rarity TEXT DEFAULT NULL,
  p_taxonomic_class TEXT DEFAULT NULL,
  p_habitats_json JSONB DEFAULT '[]'::jsonb,
  p_continents_json JSONB DEFAULT '[]'::jsonb,
  p_identification_state TEXT DEFAULT 'unidentified',
  p_identified_at TIMESTAMPTZ DEFAULT NULL,
  p_identified_display_name TEXT DEFAULT NULL,
  p_identified_scientific_name TEXT DEFAULT NULL,
  p_identified_taxonomic_class TEXT DEFAULT NULL,
  p_identified_habitats_json JSONB DEFAULT '[]'::jsonb,
  p_identified_continents_json JSONB DEFAULT '[]'::jsonb,
  p_map_cell_entry_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_now TIMESTAMPTZ := now();
  v_definition_id TEXT;
  v_display_name TEXT;
  v_category TEXT;
  v_acquired_in_cell_id TEXT;
  v_scientific_name TEXT;
  v_rarity TEXT;
  v_taxonomic_class TEXT;
  v_identification_state TEXT;
  v_identified_display_name TEXT;
  v_identified_scientific_name TEXT;
  v_identified_taxonomic_class TEXT;
  v_habitats_json JSONB;
  v_continents_json JSONB;
  v_identified_habitats_json JSONB;
  v_identified_continents_json JSONB;
  v_base_item_id TEXT;
  v_item public.v3_items%ROWTYPE;
  v_base_item public.v3_base_items%ROWTYPE;
  v_base_item_version public.v3_base_item_versions%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication is required to acquire a legacy discovery Item'
      USING ERRCODE = '42501';
  END IF;

  IF p_definition_id IS NULL
     OR p_definition_id IS DISTINCT FROM btrim(p_definition_id)
     OR btrim(p_definition_id) = ''
     OR char_length(p_definition_id) > 512 THEN
    RAISE EXCEPTION 'definition_id must be a trimmed nonblank string of at most 512 characters'
      USING ERRCODE = '22023';
  END IF;

  IF p_display_name IS NULL
     OR p_display_name IS DISTINCT FROM btrim(p_display_name)
     OR btrim(p_display_name) = ''
     OR char_length(p_display_name) > 512 THEN
    RAISE EXCEPTION 'display_name must be a trimmed nonblank string of at most 512 characters'
      USING ERRCODE = '22023';
  END IF;

  IF p_category IS NULL
     OR p_category IS DISTINCT FROM btrim(p_category)
     OR btrim(p_category) = ''
     OR char_length(p_category) > 64 THEN
    RAISE EXCEPTION 'category must be a trimmed nonblank string of at most 64 characters'
      USING ERRCODE = '22023';
  END IF;

  IF p_acquired_in_cell_id IS NULL
     OR p_acquired_in_cell_id IS DISTINCT FROM btrim(p_acquired_in_cell_id)
     OR btrim(p_acquired_in_cell_id) = ''
     OR char_length(p_acquired_in_cell_id) > 512 THEN
    RAISE EXCEPTION 'acquired_in_cell_id must be a trimmed nonblank string of at most 512 characters'
      USING ERRCODE = '22023';
  END IF;

  IF p_identification_state IS NULL
     OR p_identification_state IS DISTINCT FROM btrim(p_identification_state)
     OR btrim(p_identification_state) = ''
     OR char_length(p_identification_state) > 64 THEN
    RAISE EXCEPTION 'identification_state must be a trimmed nonblank string of at most 64 characters'
      USING ERRCODE = '22023';
  END IF;

  IF p_map_cell_entry_id IS NOT NULL
     AND (
       p_map_cell_entry_id IS DISTINCT FROM btrim(p_map_cell_entry_id)
       OR btrim(p_map_cell_entry_id) = ''
       OR char_length(p_map_cell_entry_id) > 512
     ) THEN
    RAISE EXCEPTION 'map_cell_entry_id must be a trimmed nonblank string of at most 512 characters when supplied'
      USING ERRCODE = '22023';
  END IF;

  v_definition_id := p_definition_id;
  v_display_name := p_display_name;
  v_category := lower(p_category);
  v_acquired_in_cell_id := p_acquired_in_cell_id;
  v_identification_state := lower(p_identification_state);
  v_scientific_name := NULLIF(btrim(p_scientific_name), '');
  v_rarity := NULLIF(btrim(p_rarity), '');
  v_taxonomic_class := NULLIF(btrim(p_taxonomic_class), '');
  v_identified_display_name := NULLIF(btrim(p_identified_display_name), '');
  v_identified_scientific_name := NULLIF(btrim(p_identified_scientific_name), '');
  v_identified_taxonomic_class := NULLIF(btrim(p_identified_taxonomic_class), '');

  IF (v_scientific_name IS NOT NULL AND char_length(v_scientific_name) > 512)
     OR (v_rarity IS NOT NULL AND char_length(v_rarity) > 128)
     OR (v_taxonomic_class IS NOT NULL AND char_length(v_taxonomic_class) > 512)
     OR (v_identified_display_name IS NOT NULL AND char_length(v_identified_display_name) > 512)
     OR (v_identified_scientific_name IS NOT NULL AND char_length(v_identified_scientific_name) > 512)
     OR (v_identified_taxonomic_class IS NOT NULL AND char_length(v_identified_taxonomic_class) > 512) THEN
    RAISE EXCEPTION 'legacy discovery text evidence exceeds its bounded field length'
      USING ERRCODE = '22023';
  END IF;

  IF v_category NOT IN ('fauna', 'flora', 'mineral', 'fossil', 'artifact', 'food', 'orb') THEN
    RAISE EXCEPTION 'Unsupported Item category %', v_category
      USING ERRCODE = '22023';
  END IF;

  -- New acquisitions always enter the mandatory Discovery lifecycle. Identified
  -- Items and their timestamps are created only by the later server command.
  IF p_identification_state <> 'unidentified' OR p_identified_at IS NOT NULL THEN
    RAISE EXCEPTION 'Legacy discovery acquisition must begin unidentified without identified_at'
      USING ERRCODE = '22023';
  END IF;

  IF p_habitats_json IS NULL
     OR p_continents_json IS NULL
     OR p_identified_habitats_json IS NULL
     OR p_identified_continents_json IS NULL
     OR jsonb_typeof(p_habitats_json) <> 'array'
     OR jsonb_typeof(p_continents_json) <> 'array'
     OR jsonb_typeof(p_identified_habitats_json) <> 'array'
     OR jsonb_typeof(p_identified_continents_json) <> 'array' THEN
    RAISE EXCEPTION 'Item habitat and continent evidence must be JSON arrays'
      USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_habitats_json) AS value
    WHERE jsonb_typeof(value) <> 'string'
      OR value #>> '{}' IS DISTINCT FROM btrim(value #>> '{}')
      OR btrim(value #>> '{}') = ''
      OR char_length(value #>> '{}') > 255
  ) OR EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_continents_json) AS value
    WHERE jsonb_typeof(value) <> 'string'
      OR value #>> '{}' IS DISTINCT FROM btrim(value #>> '{}')
      OR btrim(value #>> '{}') = ''
      OR char_length(value #>> '{}') > 255
  ) OR EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_identified_habitats_json) AS value
    WHERE jsonb_typeof(value) <> 'string'
      OR value #>> '{}' IS DISTINCT FROM btrim(value #>> '{}')
      OR btrim(value #>> '{}') = ''
      OR char_length(value #>> '{}') > 255
  ) OR EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_identified_continents_json) AS value
    WHERE jsonb_typeof(value) <> 'string'
      OR value #>> '{}' IS DISTINCT FROM btrim(value #>> '{}')
      OR btrim(value #>> '{}') = ''
      OR char_length(value #>> '{}') > 255
  ) THEN
    RAISE EXCEPTION 'Item habitat and continent evidence must be bounded trimmed strings'
      USING ERRCODE = '22023';
  END IF;

  v_habitats_json := p_habitats_json;
  v_continents_json := p_continents_json;
  v_identified_habitats_json := p_identified_habitats_json;
  v_identified_continents_json := p_identified_continents_json;

  -- Serialize duplicate requests for this legacy idempotency key. Unlike a
  -- unique index, this is additive even if historical rows contain duplicates.
  PERFORM pg_advisory_xact_lock(hashtextextended(
    v_user_id::text || E'\x1f' || v_definition_id || E'\x1f' || v_acquired_in_cell_id,
    0
  ));

  SELECT item.*
  INTO v_item
  FROM public.v3_items AS item
  WHERE item.user_id = v_user_id
    AND item.definition_id = v_definition_id
    AND item.acquired_in_cell_id = v_acquired_in_cell_id
    AND item.status = 'active'
  ORDER BY item.acquired_at, item.id
  LIMIT 1
  FOR UPDATE;

  IF FOUND THEN
    -- Identification may later update the visible projection and identified_at.
    -- A delayed acquisition retry must return this canonical Item rather than
    -- treating that permitted lifecycle transition as incompatible evidence.
    IF v_item.category IS DISTINCT FROM v_category
       OR v_item.rarity IS DISTINCT FROM v_rarity
       OR v_item.identified_display_name IS DISTINCT FROM v_identified_display_name
       OR v_item.identified_scientific_name IS DISTINCT FROM v_identified_scientific_name
       OR v_item.identified_taxonomic_class IS DISTINCT FROM v_identified_taxonomic_class
       OR v_item.identified_habitats_json::jsonb IS DISTINCT FROM v_identified_habitats_json
       OR v_item.identified_continents_json::jsonb IS DISTINCT FROM v_identified_continents_json THEN
      RAISE EXCEPTION 'Legacy discovery Item retry has incompatible evidence for its active Item'
        USING ERRCODE = '23505';
    END IF;

    RETURN to_jsonb(v_item);
  END IF;

  -- New acquisition can only bind an Item emitted by the current server catalog.
  -- The generic 079 legacy-item hash remains historical backfill evidence only.
  IF v_definition_id !~ '^species\.(amberwing_warbler|red_fox|monarch_butterfly|painted_turtle|snowshoe_hare|brook_trout|great_blue_heron|eastern_chipmunk)\.[0-9a-f]{8}$' THEN
    RAISE EXCEPTION 'Legacy discovery definition is not in the server catalog'
      USING ERRCODE = '23503';
  END IF;

  -- Rarity is legacy evidence only and is never used for identity, selection,
  -- gating, or current-Version resolution.
  v_base_item_id := 'fauna:' || substring(
    v_definition_id FROM '^species\.([a-z_]+)\.[0-9a-f]{8}$'
  );

  SELECT base_item.*
  INTO v_base_item
  FROM public.v3_base_items AS base_item
  WHERE base_item.id = v_base_item_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Legacy discovery Base Item compatibility identity % is unavailable', v_base_item_id
      USING ERRCODE = '23503';
  END IF;

  IF v_base_item.category IS DISTINCT FROM v_category THEN
    RAISE EXCEPTION 'Legacy discovery Item category does not match Base Item compatibility identity'
      USING ERRCODE = '23514';
  END IF;

  SELECT base_item_version.*
  INTO v_base_item_version
  FROM public.v3_base_item_versions AS base_item_version
  WHERE base_item_version.id = v_base_item.current_published_version_id
    AND base_item_version.base_item_id = v_base_item.id
    AND base_item_version.publication_status = 'published'
  FOR KEY SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Legacy discovery Base Item current published Version is unavailable or mismatched'
      USING ERRCODE = '23503';
  END IF;

  INSERT INTO public.v3_items (
    user_id,
    definition_id,
    display_name,
    scientific_name,
    category,
    rarity,
    acquired_at,
    acquired_in_cell_id,
    status,
    created_at,
    taxonomic_class,
    habitats_json,
    continents_json,
    identification_state,
    identified_at,
    identified_display_name,
    identified_scientific_name,
    identified_taxonomic_class,
    identified_habitats_json,
    identified_continents_json,
    base_item_id,
    base_item_version_id
  )
  VALUES (
    v_user_id,
    v_definition_id,
    v_display_name,
    v_scientific_name,
    v_category,
    v_rarity,
    v_now,
    v_acquired_in_cell_id,
    'active',
    v_now,
    v_taxonomic_class,
    v_habitats_json::text,
    v_continents_json::text,
    v_identification_state,
    p_identified_at,
    v_identified_display_name,
    v_identified_scientific_name,
    v_identified_taxonomic_class,
    v_identified_habitats_json::text,
    v_identified_continents_json::text,
    v_base_item.id,
    v_base_item_version.id
  )
  RETURNING * INTO v_item;

  RETURN to_jsonb(v_item);
END;
$$;

REVOKE ALL ON FUNCTION public.acquire_v3_legacy_discovery_item(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, JSONB, TEXT, TIMESTAMPTZ,
  TEXT, TEXT, TEXT, JSONB, JSONB, TEXT
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.acquire_v3_legacy_discovery_item(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, JSONB, TEXT, TIMESTAMPTZ,
  TEXT, TEXT, TEXT, JSONB, JSONB, TEXT
) TO authenticated;
