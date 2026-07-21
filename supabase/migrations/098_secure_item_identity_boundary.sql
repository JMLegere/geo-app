-- Migration 098: server-authoritative Item identity boundary.
--
-- An Item's exact Base Item and Version remain durable server evidence. They are
-- intentionally absent from every authenticated projection until Identification
-- reveals them. Pack is the only authenticated read boundary for owned Items.

REVOKE SELECT ON TABLE public.v3_items FROM PUBLIC, anon, authenticated;

-- The old RPC accepted client-authored canonical and identified evidence. Drop
-- that signature before exposing the reduced command so it cannot be selected
-- through PostgREST overload resolution.
DROP FUNCTION IF EXISTS public.acquire_v3_legacy_discovery_item(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, JSONB, TEXT, TIMESTAMPTZ,
  TEXT, TEXT, TEXT, JSONB, JSONB, TEXT
);

-- This helper is intentionally not granted. It is shared only by authenticated
-- command/read functions after they have established ownership.
CREATE OR REPLACE FUNCTION public.v3_safe_item_projection(p_item public.v3_items)
RETURNS JSONB
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_item.identification_state = 'identified' THEN
      jsonb_strip_nulls(jsonb_build_object(
        'id', p_item.id,
        'definition_id', p_item.definition_id,
        'base_item_id', p_item.base_item_id,
        'base_item_version_id', p_item.base_item_version_id,
        'display_name', p_item.display_name,
        'scientific_name', p_item.scientific_name,
        'category', p_item.category,
        'rarity', p_item.rarity,
        'icon_url', p_item.icon_url,
        'icon_url_frame2', p_item.icon_url_frame2,
        'art_url', p_item.art_url,
        'acquired_at', p_item.acquired_at,
        'acquired_in_cell_id', p_item.acquired_in_cell_id,
        'status', p_item.status,
        'taxonomic_class', p_item.taxonomic_class,
        'habitats_json', p_item.habitats_json,
        'continents_json', p_item.continents_json,
        'identification_state', p_item.identification_state,
        'identified_at', p_item.identified_at
      ))
    ELSE
      jsonb_build_object(
        'id', p_item.id,
        'display_name', 'Unidentified ' || lower(p_item.category) || ' specimen',
        'category', p_item.category,
        'acquired_at', p_item.acquired_at,
        'acquired_in_cell_id', p_item.acquired_in_cell_id,
        'status', p_item.status,
        'identification_state', 'unidentified'
      )
  END;
$$;

CREATE OR REPLACE FUNCTION public.fetch_v3_pack_items()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication is required to fetch Pack Items'
      USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'items', COALESCE((
      SELECT jsonb_agg(public.v3_safe_item_projection(item)
        ORDER BY item.acquired_at DESC, item.id ASC)
      FROM public.v3_items AS item
      WHERE item.user_id = v_user_id
        AND item.status = 'active'
    ), '[]'::jsonb)
  );
END;
$$;

CREATE FUNCTION public.acquire_v3_legacy_discovery_item(
  p_definition_id TEXT,
  p_acquired_in_cell_id TEXT,
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
  v_base_item_id TEXT;
  v_item public.v3_items%ROWTYPE;
  v_base_item public.v3_base_items%ROWTYPE;
  v_base_item_version public.v3_base_item_versions%ROWTYPE;
  v_taxonomic_class TEXT;
  v_habitats_json TEXT;
  v_continents_json TEXT;
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

  IF p_acquired_in_cell_id IS NULL
     OR p_acquired_in_cell_id IS DISTINCT FROM btrim(p_acquired_in_cell_id)
     OR btrim(p_acquired_in_cell_id) = ''
     OR char_length(p_acquired_in_cell_id) > 512 THEN
    RAISE EXCEPTION 'acquired_in_cell_id must be a trimmed nonblank string of at most 512 characters'
      USING ERRCODE = '22023';
  END IF;

  IF p_map_cell_entry_id IS NOT NULL
     AND (p_map_cell_entry_id IS DISTINCT FROM btrim(p_map_cell_entry_id)
       OR btrim(p_map_cell_entry_id) = ''
       OR char_length(p_map_cell_entry_id) > 512) THEN
    RAISE EXCEPTION 'map_cell_entry_id must be a trimmed nonblank string of at most 512 characters when supplied'
      USING ERRCODE = '22023';
  END IF;

  IF p_definition_id !~ '^species\.(amberwing_warbler|red_fox|monarch_butterfly|painted_turtle|snowshoe_hare|brook_trout|great_blue_heron|eastern_chipmunk)\.[0-9a-f]{8}$' THEN
    RAISE EXCEPTION 'Legacy discovery definition is not in the server catalog'
      USING ERRCODE = '23503';
  END IF;

  -- The discovery identity and Cell provenance are the complete idempotency key.
  -- No client-provided taxonomy, display, habitat, continent, or identified
  -- evidence participates in a retry or can be written to the Item.
  PERFORM pg_advisory_xact_lock(hashtextextended(
    v_user_id::text || E'\x1f' || p_definition_id || E'\x1f' || p_acquired_in_cell_id,
    0
  ));

  SELECT item.*
  INTO v_item
  FROM public.v3_items AS item
  WHERE item.user_id = v_user_id
    AND item.definition_id = p_definition_id
    AND item.acquired_in_cell_id = p_acquired_in_cell_id
    AND item.status = 'active'
  ORDER BY item.acquired_at, item.id
  LIMIT 1
  FOR UPDATE;

  IF FOUND THEN
    RETURN public.v3_safe_item_projection(v_item);
  END IF;

  v_base_item_id := 'fauna:' || substring(
    p_definition_id FROM '^species\.([a-z_]+)\.[0-9a-f]{8}$'
  );

  SELECT base_item.*
  INTO v_base_item
  FROM public.v3_base_items AS base_item
  WHERE base_item.id = v_base_item_id
  FOR UPDATE;

  IF NOT FOUND OR v_base_item.category IS DISTINCT FROM 'fauna' THEN
    RAISE EXCEPTION 'Legacy discovery Base Item compatibility identity is unavailable'
      USING ERRCODE = '23503';
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

  -- Every stored canonical field is derived from this exact immutable Version.
  v_taxonomic_class := COALESCE(
    NULLIF(v_base_item_version.authored_content #>> '{legacy_catalog_snapshot,taxonomic_class}', ''),
    NULLIF(v_base_item_version.authored_content #>> '{legacy_item_snapshot,taxonomic_class}', '')
  );
  v_habitats_json := COALESCE(
    NULLIF(v_base_item_version.authored_content #>> '{legacy_catalog_snapshot,habitats}', ''),
    NULLIF(v_base_item_version.authored_content #>> '{legacy_item_snapshot,habitats_json}', ''),
    '[]'
  );
  v_continents_json := COALESCE(
    NULLIF(v_base_item_version.authored_content #>> '{legacy_catalog_snapshot,continents}', ''),
    NULLIF(v_base_item_version.authored_content #>> '{legacy_item_snapshot,continents_json}', ''),
    '[]'
  );

  INSERT INTO public.v3_items (
    user_id, definition_id, display_name, scientific_name, category, rarity,
    acquired_at, acquired_in_cell_id, status, created_at, taxonomic_class,
    habitats_json, continents_json, identification_state, identified_at,
    identified_display_name, identified_scientific_name,
    identified_taxonomic_class, identified_habitats_json,
    identified_continents_json, base_item_id, base_item_version_id
  ) VALUES (
    v_user_id, p_definition_id, v_base_item_version.display_name,
    v_base_item_version.scientific_name, v_base_item.category, NULL, v_now,
    p_acquired_in_cell_id, 'active', v_now, v_taxonomic_class,
    v_habitats_json, v_continents_json, 'unidentified', NULL, NULL, NULL,
    NULL, NULL, NULL, v_base_item.id, v_base_item_version.id
  )
  RETURNING * INTO v_item;

  RETURN public.v3_safe_item_projection(v_item);
END;
$$;

-- Resolve keeps its exact result rows unchanged. This authenticated aggregate
-- projects exact Base Item evidence only after the generated Item is identified.
CREATE OR REPLACE FUNCTION public.v3_encounter_runtime_aggregate(
  p_cell_visit_id UUID
)
RETURNS JSONB
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'cell_visit_resolution', (
      SELECT jsonb_build_object(
        'id', resolution.id,
        'cell_visit_id', resolution.cell_visit_id,
        'selector_id', resolution.selector_id,
        'selector_candidate_id', resolution.selector_candidate_id,
        'resolution_kind', resolution.resolution_kind,
        'encounter_definition_id', resolution.encounter_definition_id,
        'resolved_at', resolution.resolved_at
      )
      FROM public.v3_cell_visit_resolutions AS resolution
      WHERE resolution.cell_visit_id = p_cell_visit_id
    ),
    'encounter', (
      SELECT jsonb_build_object(
        'id', encounter.id,
        'cell_visit_id', encounter.cell_visit_id,
        'cell_visit_resolution_id', encounter.cell_visit_resolution_id,
        'encounter_definition_id', encounter.encounter_definition_id,
        'encounter_definition_version_id', encounter.encounter_definition_version_id,
        'encounter_definition_revision', encounter_version.revision,
        'selected_option_id', encounter.selected_option_id,
        'resolution_status', encounter.resolution_status,
        'created_at', encounter.created_at,
        'resolved_at', encounter.resolved_at,
        'failure_code', encounter.failure_code,
        'failure_details', encounter.failure_details
      )
      FROM public.v3_encounters AS encounter
      JOIN public.v3_encounter_definition_versions AS encounter_version
        ON encounter_version.id = encounter.encounter_definition_version_id
        AND encounter_version.encounter_definition_id = encounter.encounter_definition_id
      WHERE encounter.cell_visit_id = p_cell_visit_id
    ),
    'outcome_results', COALESCE((
      SELECT jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
        'id', result.id,
        'encounter_id', result.encounter_id,
        'outcome_ordinal', result.outcome_ordinal,
        'encounter_outcome_id', result.encounter_outcome_id,
        'outcome_kind', result.outcome_kind,
        'resolved_base_item_version_id', CASE
          WHEN item.identification_state = 'identified' THEN result.resolved_base_item_version_id
        END,
        'resolved_base_item_id', CASE
          WHEN item.identification_state = 'identified' THEN resolved_base_item_version.base_item_id
        END,
        'resolved_base_item_revision', CASE
          WHEN item.identification_state = 'identified' THEN resolved_base_item_version.revision
        END,
        'generated_item_id', result.generated_item_id,
        'resolved_venue_id', result.resolved_venue_id,
        'resolved_venue_version_id', result.resolved_venue_version_id,
        'resolved_venue_revision', resolved_venue_version.revision,
        'known_at', known.known_at,
        'created_at', result.created_at
      )) ORDER BY result.outcome_ordinal)
      FROM public.v3_encounter_outcome_results AS result
      JOIN public.v3_encounters AS encounter ON encounter.id = result.encounter_id
      LEFT JOIN public.v3_items AS item ON item.id = result.generated_item_id
      LEFT JOIN public.v3_base_item_versions AS resolved_base_item_version
        ON resolved_base_item_version.id = result.resolved_base_item_version_id
      LEFT JOIN public.v3_venue_versions AS resolved_venue_version
        ON resolved_venue_version.id = result.resolved_venue_version_id
        AND resolved_venue_version.venue_id = result.resolved_venue_id
      LEFT JOIN public.v3_cell_visits AS cell_visit ON cell_visit.id = encounter.cell_visit_id
      LEFT JOIN public.v3_player_known_venues AS known
        ON known.user_id = cell_visit.user_id
        AND known.venue_id = result.resolved_venue_id
      WHERE encounter.cell_visit_id = p_cell_visit_id
    ), '[]'::jsonb),
    'generated_items', COALESCE((
      SELECT jsonb_agg(
        CASE
          WHEN item.identification_state = 'identified' THEN
            public.v3_safe_item_projection(item) || jsonb_build_object(
              'base_item_revision', item_base_item_version.revision
            )
          ELSE public.v3_safe_item_projection(item)
        END
        ORDER BY result.outcome_ordinal
      )
      FROM public.v3_encounter_outcome_results AS result
      JOIN public.v3_encounters AS encounter ON encounter.id = result.encounter_id
      JOIN public.v3_items AS item ON item.id = result.generated_item_id
      LEFT JOIN public.v3_base_item_versions AS item_base_item_version
        ON item_base_item_version.id = item.base_item_version_id
        AND item_base_item_version.base_item_id = item.base_item_id
      WHERE encounter.cell_visit_id = p_cell_visit_id
    ), '[]'::jsonb)
  );
$$;

REVOKE ALL ON FUNCTION public.v3_safe_item_projection(public.v3_items)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fetch_v3_pack_items() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.acquire_v3_legacy_discovery_item(TEXT, TEXT, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fetch_v3_pack_items() TO authenticated;
GRANT EXECUTE ON FUNCTION public.acquire_v3_legacy_discovery_item(TEXT, TEXT, TEXT)
  TO authenticated;
