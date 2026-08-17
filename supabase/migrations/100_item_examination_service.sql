-- Migration 100: durable Item examination and service-bound Identification.
--
-- Examination is Player/Base Item knowledge, deliberately separate from Item
-- state and variable Property Values. Identification requires that knowledge
-- plus current access to Rowan's published Identification Service.

CREATE TABLE IF NOT EXISTS public.v3_player_base_item_journal_entries (
  user_id UUID NOT NULL REFERENCES auth.users(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  base_item_id TEXT NOT NULL REFERENCES public.v3_base_items(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  base_item_version_id UUID NOT NULL,
  examined_item_id UUID NOT NULL,
  examined_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, base_item_id),
  CONSTRAINT v3_player_base_item_journal_entries_exact_item_binding_fk
    FOREIGN KEY (examined_item_id, user_id, base_item_id, base_item_version_id)
    REFERENCES public.v3_items(id, user_id, base_item_id, base_item_version_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT v3_player_base_item_journal_entries_exact_version_owner_fk
    FOREIGN KEY (base_item_id, base_item_version_id)
    REFERENCES public.v3_base_item_versions(base_item_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_v3_player_base_item_journal_entries_user_examined_at
  ON public.v3_player_base_item_journal_entries(user_id, examined_at DESC);

CREATE OR REPLACE FUNCTION public.v3_prevent_player_base_item_journal_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'Player Base Item examination evidence is immutable'
    USING ERRCODE = '23514';
END;
$$;

DO $add_v3_player_base_item_journal_entries_immutable_trigger$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'v3_player_base_item_journal_entries_immutable'
      AND tgrelid = 'public.v3_player_base_item_journal_entries'::regclass
      AND NOT tgisinternal
  ) THEN
    CREATE TRIGGER v3_player_base_item_journal_entries_immutable
    BEFORE UPDATE OR DELETE ON public.v3_player_base_item_journal_entries
    FOR EACH ROW
    EXECUTE FUNCTION public.v3_prevent_player_base_item_journal_mutation();
  END IF;
END;
$add_v3_player_base_item_journal_entries_immutable_trigger$;

-- Identified Items already have stronger durable knowledge. They are the only
-- legacy rows eligible for this additive examination backfill.
INSERT INTO public.v3_player_base_item_journal_entries (
  user_id,
  base_item_id,
  base_item_version_id,
  examined_item_id,
  examined_at
)
SELECT DISTINCT ON (item.user_id, item.base_item_id)
  item.user_id,
  item.base_item_id,
  item.base_item_version_id,
  item.id,
  COALESCE(item.identified_at, item.acquired_at)
FROM public.v3_items AS item
WHERE item.identification_state = 'identified'
ORDER BY item.user_id, item.base_item_id, item.identified_at NULLS LAST, item.acquired_at, item.id
ON CONFLICT (user_id, base_item_id) DO NOTHING;

ALTER TABLE public.v3_player_base_item_journal_entries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.v3_player_base_item_journal_entries
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.examine_v3_item(p_item_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_item public.v3_items%ROWTYPE;
  v_entry public.v3_player_base_item_journal_entries%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Item examination requires an authenticated user'
      USING ERRCODE = '28000';
  END IF;

  IF p_item_id IS NULL THEN
    RAISE EXCEPTION 'Item examination requires an Item identity'
      USING ERRCODE = '22023';
  END IF;

  SELECT item.*
  INTO v_item
  FROM public.v3_items AS item
  WHERE item.id = p_item_id
    AND item.user_id = v_user_id
    AND item.status = 'active'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Owned active Item % was not found', p_item_id
      USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.v3_player_base_item_journal_entries (
    user_id,
    base_item_id,
    base_item_version_id,
    examined_item_id,
    examined_at
  )
  VALUES (
    v_item.user_id,
    v_item.base_item_id,
    v_item.base_item_version_id,
    v_item.id,
    now()
  )
  ON CONFLICT (user_id, base_item_id) DO NOTHING
  RETURNING * INTO v_entry;

  IF NOT FOUND THEN
    SELECT entry.*
    INTO v_entry
    FROM public.v3_player_base_item_journal_entries AS entry
    WHERE entry.user_id = v_item.user_id
      AND entry.base_item_id = v_item.base_item_id;
  END IF;

  RETURN jsonb_build_object(
    'base_item_id', v_entry.base_item_id,
    'base_item_version_id', v_entry.base_item_version_id,
    'examined_item_id', v_entry.examined_item_id,
    'examined_at', v_entry.examined_at
  );
END;
$$;

-- Pack exposes three states. Base Item identity becomes visible on examination;
-- mutable Property Values remain exclusively in the Identification aggregate.
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
        'identified_at', p_item.identified_at,
        'examination_state', 'examined',
        'examined_at', (
          SELECT entry.examined_at
          FROM public.v3_player_base_item_journal_entries AS entry
          WHERE entry.user_id = p_item.user_id
            AND entry.base_item_id = p_item.base_item_id
        )
      ))
    WHEN EXISTS (
      SELECT 1
      FROM public.v3_player_base_item_journal_entries AS entry
      WHERE entry.user_id = p_item.user_id
        AND entry.base_item_id = p_item.base_item_id
    ) THEN
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
        'identification_state', 'unidentified',
        'examination_state', 'examined',
        'examined_at', (
          SELECT entry.examined_at
          FROM public.v3_player_base_item_journal_entries AS entry
          WHERE entry.user_id = p_item.user_id
            AND entry.base_item_id = p_item.base_item_id
        )
      ))
    ELSE
      jsonb_build_object(
        'id', p_item.id,
        'display_name', 'Unidentified ' || lower(p_item.category) || ' specimen',
        'category', p_item.category,
        'acquired_at', p_item.acquired_at,
        'acquired_in_cell_id', p_item.acquired_in_cell_id,
        'status', p_item.status,
        'identification_state', 'unidentified',
        'examination_state', 'unexamined',
        'examined_at', NULL
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
        ORDER BY item.acquired_at DESC, item.id DESC)
      FROM public.v3_items AS item
      WHERE item.user_id = v_user_id
        AND item.status = 'active'
    ), '[]'::jsonb)
  );
END;
$$;

-- Publish the Identification Service before publishing Rowan's revised roster.
INSERT INTO public.v3_services (id)
VALUES ('service:identify_item_properties')
ON CONFLICT DO NOTHING;

INSERT INTO public.v3_service_versions (
  id,
  service_id,
  revision,
  publication_status,
  display_name,
  description
)
VALUES (
  md5('earthnova:service-version:identify_item_properties:1')::uuid,
  'service:identify_item_properties',
  1,
  'draft',
  'Identify Item Properties',
  'Identify an examined Item and reveal its server-derived properties.'
)
ON CONFLICT DO NOTHING;

DO $publish_identification_service_seed$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.v3_service_versions
    WHERE id = md5('earthnova:service-version:identify_item_properties:1')::uuid
      AND publication_status = 'draft'
  ) THEN
    PERFORM public.publish_v3_service_version(
      'service:identify_item_properties',
      md5('earthnova:service-version:identify_item_properties:1')::uuid
    );
  END IF;
END;
$publish_identification_service_seed$;

INSERT INTO public.v3_villager_versions (
  id,
  villager_id,
  revision,
  publication_status,
  display_name,
  role_name
)
VALUES (
  md5('earthnova:villager-version:rowan:2')::uuid,
  'villager:rowan',
  2,
  'draft',
  'Rowan',
  'Wildlife Rehabilitator'
)
ON CONFLICT DO NOTHING;

INSERT INTO public.v3_villager_version_services (
  villager_version_id,
  service_id,
  ordinal
)
SELECT md5('earthnova:villager-version:rowan:2')::uuid, service_id, ordinal
FROM (
  VALUES
    ('service:release_to_wild'::TEXT, 1),
    ('service:identify_item_properties'::TEXT, 2)
) AS service(service_id, ordinal)
WHERE EXISTS (
  SELECT 1
  FROM public.v3_villager_versions AS version
  WHERE version.id = md5('earthnova:villager-version:rowan:2')::uuid
    AND version.publication_status = 'draft'
)
ON CONFLICT DO NOTHING;

DO $publish_rowan_identification_revision$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.v3_villager_versions
    WHERE id = md5('earthnova:villager-version:rowan:2')::uuid
      AND publication_status = 'draft'
  ) THEN
    PERFORM public.publish_v3_villager_version(
      'villager:rowan',
      md5('earthnova:villager-version:rowan:2')::uuid
    );
  END IF;
END;
$publish_rowan_identification_revision$;

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
    villager.display_name AS villager_display_name,
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

-- Retain the proven 088 transaction privately. Both public signatures below
-- now establish the examination and current service access boundary first.
ALTER FUNCTION public.identify_v3_item(UUID, TEXT, UUID, JSONB)
  RENAME TO v3_identify_v3_item_core;

CREATE OR REPLACE FUNCTION public.identify_v3_item(
  p_item_id UUID,
  p_expected_base_item_id TEXT,
  p_expected_base_item_version_id UUID,
  p_expected_service_id TEXT,
  p_expected_service_version_id UUID,
  p_expected_villager_id TEXT,
  p_property_resolutions JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_item public.v3_items%ROWTYPE;
  v_identification_service_access RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Item Identification requires an authenticated user'
      USING ERRCODE = '28000';
  END IF;

  IF p_item_id IS NULL
     OR p_expected_service_id IS NULL
     OR btrim(p_expected_service_id) = ''
     OR p_expected_service_id IS DISTINCT FROM btrim(p_expected_service_id)
     OR p_expected_service_version_id IS NULL
     OR p_expected_villager_id IS NULL
     OR btrim(p_expected_villager_id) = ''
     OR p_expected_villager_id IS DISTINCT FROM btrim(p_expected_villager_id) THEN
    RAISE EXCEPTION 'Item Identification service access input is invalid'
      USING ERRCODE = '22023';
  END IF;

  SELECT item.*
  INTO v_item
  FROM public.v3_items AS item
  WHERE item.id = p_item_id
    AND item.user_id = v_user_id
    AND item.status = 'active'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Owned active Item % was not found', p_item_id
      USING ERRCODE = 'P0002';
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
    service.id AS service_id,
    service_version.id AS service_version_id,
    villager.id AS villager_id
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
    AND service.id = p_expected_service_id
    AND service_version.id = p_expected_service_version_id
    AND villager.id = p_expected_villager_id
  FOR KEY SHARE OF villager, villager_version, service, service_version;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Item Identification prepared service access is no longer current'
      USING ERRCODE = '23514';
  END IF;

  -- The private core writes the immutable v3_item_identification_commits receipt
  -- only after this exact current service access check succeeds.
  RETURN public.v3_identify_v3_item_core(
    p_item_id,
    p_expected_base_item_id,
    p_expected_base_item_version_id,
    p_property_resolutions
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.identify_v3_item(
  p_item_id UUID,
  p_expected_base_item_id TEXT,
  p_expected_base_item_version_id UUID,
  p_property_resolutions JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_identification_service_access RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Item Identification requires an authenticated user'
      USING ERRCODE = '28000';
  END IF;

  SELECT
    service.id AS service_id,
    service_version.id AS service_version_id,
    villager.id AS villager_id
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

  RETURN public.identify_v3_item(
    p_item_id,
    p_expected_base_item_id,
    p_expected_base_item_version_id,
    v_identification_service_access.service_id,
    v_identification_service_access.service_version_id,
    v_identification_service_access.villager_id,
    p_property_resolutions
  );
END;
$$;

REVOKE ALL ON FUNCTION public.v3_prevent_player_base_item_journal_mutation()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_identify_v3_item_core(UUID, TEXT, UUID, JSONB)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.examine_v3_item(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.prepare_v3_item_identification(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.identify_v3_item(UUID, TEXT, UUID, JSONB)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.identify_v3_item(
  UUID, TEXT, UUID, TEXT, UUID, TEXT, JSONB
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.examine_v3_item(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.prepare_v3_item_identification(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.identify_v3_item(UUID, TEXT, UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.identify_v3_item(
  UUID, TEXT, UUID, TEXT, UUID, TEXT, JSONB
) TO authenticated;
