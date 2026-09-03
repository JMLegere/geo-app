-- Migration 105: repair Identification Service Villager display projection.
--
-- Stable Villager identity lives on v3_villagers; versioned display content
-- lives on the exact current published v3_villager_versions row. Keep every
-- existing examination, ownership, current-service, and plan check unchanged.

CREATE OR REPLACE FUNCTION public.prepare_v3_item_identification(p_item_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_item public.v3_items%ROWTYPE;
  v_version public.v3_base_item_versions%ROWTYPE;
  v_discovery public.v3_item_discoveries%ROWTYPE;
  v_property_count INTEGER;
  v_property_max_ordinal INTEGER;
  v_properties JSONB;
  v_identification_service_access RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Item Identification preparation requires an authenticated user'
      USING ERRCODE = '28000';
  END IF;

  SELECT item.*
  INTO v_item
  FROM public.v3_items AS item
  WHERE item.id = p_item_id
    AND item.user_id = v_user_id
    AND item.status = 'active'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Owned active Item % was not found', p_item_id USING ERRCODE = 'P0002';
  END IF;

  IF v_item.identification_state IS DISTINCT FROM 'unidentified' THEN
    RAISE EXCEPTION 'Item % is not awaiting explicit Identification', p_item_id
      USING ERRCODE = '23514';
  END IF;

  PERFORM 1
  FROM public.v3_player_base_item_journal_entries AS entry
  WHERE entry.user_id = v_user_id
    AND entry.base_item_id = v_item.base_item_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Owned Item % must be examined before Identification', p_item_id
      USING ERRCODE = '23514';
  END IF;

  SELECT
    villager.id AS villager_id,
    villager_version.display_name AS villager_display_name,
    service.id AS service_id,
    service_version.id AS service_version_id,
    service_version.revision AS service_version_revision,
    service_version.display_name AS service_display_name
  INTO v_identification_service_access
  FROM public.v3_player_known_villagers AS known_villager
  JOIN public.v3_villagers AS villager
    ON villager.id = known_villager.villager_id
  JOIN public.v3_villager_versions AS villager_version
    ON villager_version.id = villager.current_published_version_id
   AND villager_version.villager_id = villager.id
   AND villager_version.publication_status = 'published'
  JOIN public.v3_villager_version_services AS villager_service
    ON villager_service.villager_version_id = villager_version.id
   AND villager_service.service_id = 'service:identify_item_properties'
  JOIN public.v3_services AS service
    ON service.id = villager_service.service_id
  JOIN public.v3_service_versions AS service_version
    ON service_version.id = service.current_published_version_id
   AND service_version.service_id = service.id
   AND service_version.publication_status = 'published'
  WHERE known_villager.user_id = v_user_id
  ORDER BY known_villager.known_at, villager.id
  LIMIT 1
  FOR KEY SHARE OF villager, villager_version, service, service_version;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Item Identification requires current known Identification Service access'
      USING ERRCODE = '23514';
  END IF;

  SELECT version.*
  INTO v_version
  FROM public.v3_base_item_versions AS version
  WHERE version.id = v_item.base_item_version_id
    AND version.base_item_id = v_item.base_item_id
    AND version.publication_status IN ('published', 'retired')
  FOR KEY SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Owned Item % lacks a readable exact Base Item Version', p_item_id
      USING ERRCODE = '23514';
  END IF;

  SELECT count(*), max(assignment.ordinal)
  INTO v_property_count, v_property_max_ordinal
  FROM public.v3_base_item_version_variable_properties AS assignment
  WHERE assignment.base_item_version_id = v_item.base_item_version_id;

  IF v_property_count > 0 AND v_property_max_ordinal <> v_property_count - 1 THEN
    RAISE EXCEPTION 'Exact Base Item Version % has non-dense Variable Property ordinals',
      v_item.base_item_version_id
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.v3_base_item_version_variable_properties AS assignment
    JOIN public.v3_variable_properties AS variable_property
      ON variable_property.id = assignment.variable_property_id
    JOIN public.v3_selector_candidates AS candidate
      ON candidate.selector_id = variable_property.selector_id
    WHERE assignment.base_item_version_id = v_item.base_item_version_id
      AND candidate.condition_id IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'Exact Base Item Version % requires unsupported conditioned Variable Property candidates',
      v_item.base_item_version_id
      USING ERRCODE = '23514';
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'ordinal', assignment.ordinal,
        'variable_property_key', variable_property.id,
        'display_name', variable_property.display_name,
        'selector_id', selector.id,
        'candidates', candidates.candidates,
        'selected_candidate_id', deterministic.selector_candidate_id
      )
      ORDER BY assignment.ordinal
    ),
    '[]'::jsonb
  )
  INTO v_properties
  FROM public.v3_base_item_version_variable_properties AS assignment
  JOIN public.v3_variable_properties AS variable_property
    ON variable_property.id = assignment.variable_property_id
  JOIN public.v3_selectors AS selector
    ON selector.id = variable_property.selector_id
    AND selector.status = 'active'
  CROSS JOIN LATERAL (
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', candidate.id,
        'ordinal', candidate.ordinal,
        'weight', candidate.weight,
        'result_kind', candidate.result_kind,
        'result_id', candidate.result_id
      )
      ORDER BY candidate.ordinal
    ) AS candidates
    FROM public.v3_selector_candidates AS candidate
    WHERE candidate.selector_id = selector.id
      AND candidate.condition_id IS NULL
  ) AS candidates
  CROSS JOIN LATERAL public.v3_deterministic_variable_property_candidate(
    v_item.id,
    variable_property.id,
    selector.id
  ) AS deterministic
  WHERE assignment.base_item_version_id = v_item.base_item_version_id;

  IF v_property_count > 0
     AND (
       jsonb_array_length(v_properties) <> v_property_count
       OR EXISTS (
         SELECT 1
         FROM jsonb_array_elements(v_properties) AS property
         WHERE property -> 'selected_candidate_id' IS NULL
            OR property -> 'candidates' = 'null'::jsonb
       )
     ) THEN
    RAISE EXCEPTION 'Exact Base Item Version % has inactive or empty Variable Property Selectors',
      v_item.base_item_version_id
      USING ERRCODE = '23514';
  END IF;

  SELECT discovery.*
  INTO v_discovery
  FROM public.v3_item_discoveries AS discovery
  WHERE discovery.user_id = v_user_id
    AND discovery.base_item_id = v_item.base_item_id;

  RETURN jsonb_build_object(
    'item', jsonb_build_object(
      'id', v_item.id,
      'user_id', v_item.user_id,
      'base_item_id', v_item.base_item_id,
      'base_item_version_id', v_item.base_item_version_id,
      'base_item_revision', v_version.revision,
      'identification_state', v_item.identification_state
    ),
    'service_access', jsonb_build_object(
      'villager_id', v_identification_service_access.villager_id,
      'villager_display_name', v_identification_service_access.villager_display_name,
      'service_id', v_identification_service_access.service_id,
      'service_version_id', v_identification_service_access.service_version_id,
      'service_version_revision', v_identification_service_access.service_version_revision,
      'service_display_name', v_identification_service_access.service_display_name
    ),
    'properties', v_properties,
    'discovery', CASE
      WHEN v_discovery.user_id IS NULL THEN NULL
      ELSE jsonb_build_object(
        'user_id', v_discovery.user_id,
        'base_item_id', v_discovery.base_item_id,
        'first_identified_item_id', v_discovery.first_identified_item_id,
        'first_base_item_version_id', v_discovery.first_base_item_version_id,
        'provenance', v_discovery.provenance,
        'discovered_at', v_discovery.discovered_at
      )
    END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.prepare_v3_item_identification(UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.prepare_v3_item_identification(UUID)
  TO authenticated;
