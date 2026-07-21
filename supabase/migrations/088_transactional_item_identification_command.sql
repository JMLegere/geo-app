-- Migration 088: authoritative transactional Item Identification command.
--
-- Identification is a single owned, exact-Version command. It never consults a
-- Base Item's current published Version: an Item's permanent binding is the
-- source for its ordered Variable Properties, normalized candidate selection,
-- projection evidence, Discovery, and durable command receipt.

CREATE TABLE IF NOT EXISTS public.v3_item_identification_commits (
  item_id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  base_item_id TEXT NOT NULL REFERENCES public.v3_base_items(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  base_item_version_id UUID NOT NULL,
  identification_kind TEXT NOT NULL CHECK (
    identification_kind IN ('explicit', 'automatic')
  ),
  resolution_plan JSONB NOT NULL CHECK (
    jsonb_typeof(resolution_plan) = 'array'
  ),
  committed_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT v3_item_identification_commits_exact_item_binding_fk
    FOREIGN KEY (item_id, user_id, base_item_id, base_item_version_id)
    REFERENCES public.v3_items(id, user_id, base_item_id, base_item_version_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT v3_item_identification_commits_exact_version_owner_fk
    FOREIGN KEY (base_item_id, base_item_version_id)
    REFERENCES public.v3_base_item_versions(base_item_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE OR REPLACE FUNCTION public.v3_prevent_item_identification_commit_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'Item Identification command receipts are immutable'
    USING ERRCODE = '23514';
END;
$$;

DO $add_v3_item_identification_commits_immutable_trigger$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'v3_item_identification_commits_immutable'
      AND tgrelid = 'public.v3_item_identification_commits'::regclass
      AND NOT tgisinternal
  ) THEN
    CREATE TRIGGER v3_item_identification_commits_immutable
    BEFORE UPDATE OR DELETE ON public.v3_item_identification_commits
    FOR EACH ROW
    EXECUTE FUNCTION public.v3_prevent_item_identification_commit_mutation();
  END IF;
END;
$add_v3_item_identification_commits_immutable_trigger$;

ALTER TABLE public.v3_item_identification_commits ENABLE ROW LEVEL SECURITY;

-- This helper deliberately derives a candidate from immutable server content.
-- The client only echoes its identity; identify_v3_item verifies that echo.
CREATE OR REPLACE FUNCTION public.v3_deterministic_variable_property_candidate(
  p_item_id UUID,
  p_variable_property_id TEXT,
  p_selector_id TEXT
)
RETURNS TABLE (
  selector_candidate_id UUID,
  resolution_kind TEXT,
  resolved_value_id TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH eligible_candidates AS (
    SELECT
      candidate.id,
      candidate.ordinal,
      candidate.result_kind,
      candidate.result_id,
      sum(candidate.weight) OVER (
        ORDER BY candidate.ordinal
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ) AS cumulative_weight,
      sum(candidate.weight) OVER () AS total_weight
    FROM public.v3_selector_candidates AS candidate
    JOIN public.v3_selectors AS selector
      ON selector.id = candidate.selector_id
    WHERE candidate.selector_id = p_selector_id
      AND selector.status = 'active'
      AND candidate.condition_id IS NULL
  ), deterministic_roll AS (
    SELECT
      (
        ('x00000000' || substring(
          encode(
            extensions.digest(
              p_item_id::TEXT || E'\x1f' || p_variable_property_id,
              'sha256'
            ),
            'hex'
          )
          FROM 1 FOR 8
        ))::bit(64)::bigint
      )::numeric / 4294967296::numeric AS unit_roll
  )
  SELECT
    candidate.id,
    candidate.result_kind,
    candidate.result_id
  FROM eligible_candidates AS candidate
  CROSS JOIN deterministic_roll AS roll
  WHERE candidate.cumulative_weight > roll.unit_roll * candidate.total_weight
  ORDER BY candidate.ordinal
  LIMIT 1;
$$;

-- Return the canonical aggregate only. This function has no public grant: the
-- authenticated command functions use it after ownership and lifecycle checks.
CREATE OR REPLACE FUNCTION public.v3_item_identification_aggregate(p_item_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item public.v3_items%ROWTYPE;
  v_version public.v3_base_item_versions%ROWTYPE;
  v_discovery public.v3_item_discoveries%ROWTYPE;
  v_receipt public.v3_item_identification_commits%ROWTYPE;
  v_property_values JSONB;
BEGIN
  SELECT item.*
  INTO v_item
  FROM public.v3_items AS item
  WHERE item.id = p_item_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unknown Item %', p_item_id USING ERRCODE = 'P0002';
  END IF;

  SELECT version.*
  INTO v_version
  FROM public.v3_base_item_versions AS version
  WHERE version.id = v_item.base_item_version_id
    AND version.base_item_id = v_item.base_item_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Item % has no exact Base Item Version binding', p_item_id
      USING ERRCODE = '23514';
  END IF;

  SELECT receipt.*
  INTO v_receipt
  FROM public.v3_item_identification_commits AS receipt
  WHERE receipt.item_id = v_item.id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Item % has no immutable Identification receipt', p_item_id
      USING ERRCODE = '23514';
  END IF;

  SELECT discovery.*
  INTO v_discovery
  FROM public.v3_item_discoveries AS discovery
  WHERE discovery.user_id = v_item.user_id
    AND discovery.base_item_id = v_item.base_item_id;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'ordinal', assignment.ordinal,
        'variable_property_key', property_value.variable_property_key,
        'selector_id', property_value.selector_id,
        'selector_candidate_id', property_value.selector_candidate_id,
        'resolution_kind', property_value.resolution_kind,
        'resolved_value_id', property_value.resolved_value_id,
        'resolved_at', property_value.resolved_at
      )
      ORDER BY assignment.ordinal
    ),
    '[]'::jsonb
  )
  INTO v_property_values
  FROM public.v3_item_property_values AS property_value
  JOIN public.v3_base_item_version_variable_properties AS assignment
    ON assignment.base_item_version_id = v_item.base_item_version_id
    AND assignment.variable_property_id = property_value.variable_property_key
  WHERE property_value.item_id = v_item.id
    AND property_value.user_id = v_item.user_id
    AND property_value.base_item_id = v_item.base_item_id
    AND property_value.base_item_version_id = v_item.base_item_version_id;

  RETURN jsonb_build_object(
    'item', jsonb_build_object(
      'id', v_item.id,
      'user_id', v_item.user_id,
      'definition_id', v_item.definition_id,
      'display_name', v_item.display_name,
      'scientific_name', v_item.scientific_name,
      'category', v_item.category,
      'rarity', v_item.rarity,
      'icon_url', v_item.icon_url,
      'icon_url_frame2', v_item.icon_url_frame2,
      'art_url', v_item.art_url,
      'acquired_at', v_item.acquired_at,
      'acquired_in_cell_id', v_item.acquired_in_cell_id,
      'status', v_item.status,
      'taxonomic_class', v_item.taxonomic_class,
      'habitats_json', v_item.habitats_json,
      'continents_json', v_item.continents_json,
      'identification_state', v_item.identification_state,
      'identified_at', v_item.identified_at,
      'base_item_id', v_item.base_item_id,
      'base_item_version_id', v_item.base_item_version_id,
      'base_item_revision', v_version.revision
    ),
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
    END,
    'property_values', v_property_values,
    'identification', jsonb_build_object(
      'kind', v_receipt.identification_kind,
      'committed_at', v_receipt.committed_at
    )
  );
END;
$$;

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
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Owned Item % was not found', p_item_id USING ERRCODE = 'P0002';
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

  -- New Condition inputs cannot authorize an Identification outcome before a
  -- server evaluator/context exists. Do not hide such candidates from a plan.
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
  v_item public.v3_items%ROWTYPE;
  v_version public.v3_base_item_versions%ROWTYPE;
  v_receipt public.v3_item_identification_commits%ROWTYPE;
  v_discovery public.v3_item_discoveries%ROWTYPE;
  v_selected_candidate RECORD;
  v_assignment RECORD;
  v_expected_count INTEGER;
  v_expected_max_ordinal INTEGER;
  v_committed_at TIMESTAMPTZ := now();
  v_display_name TEXT;
  v_scientific_name TEXT;
  v_taxonomic_class TEXT;
  v_habitats_json TEXT;
  v_continents_json TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Item Identification requires an authenticated user'
      USING ERRCODE = '28000';
  END IF;

  IF p_item_id IS NULL
     OR p_expected_base_item_id IS NULL
     OR btrim(p_expected_base_item_id) = ''
     OR p_expected_base_item_id IS DISTINCT FROM btrim(p_expected_base_item_id)
     OR char_length(p_expected_base_item_id) > 256
     OR p_expected_base_item_version_id IS NULL
     OR p_property_resolutions IS NULL
     OR jsonb_typeof(p_property_resolutions) <> 'array' THEN
    RAISE EXCEPTION 'Item Identification input has an invalid Item or exact binding'
      USING ERRCODE = '22023';
  END IF;

  -- Validate JSON shape before any derived write. Command rows are deliberately
  -- constrained to exactly the four plan identity fields; result values remain
  -- server-derived.
  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_property_resolutions) AS input_row
    WHERE jsonb_typeof(input_row) <> 'object'
       OR NOT (input_row ?& ARRAY[
         'ordinal',
         'variable_property_key',
         'selector_id',
         'selector_candidate_id'
       ])
       OR (input_row - ARRAY[
         'ordinal',
         'variable_property_key',
         'selector_id',
         'selector_candidate_id'
       ]) <> '{}'::jsonb
       OR jsonb_typeof(input_row -> 'ordinal') <> 'number'
       OR (input_row ->> 'ordinal') !~ '^(0|[1-9][0-9]*)$'
       OR (input_row ->> 'ordinal')::numeric > 2147483647::numeric
       OR jsonb_typeof(input_row -> 'variable_property_key') <> 'string'
       OR btrim(input_row ->> 'variable_property_key') = ''
       OR input_row ->> 'variable_property_key' IS DISTINCT FROM btrim(input_row ->> 'variable_property_key')
       OR char_length(input_row ->> 'variable_property_key') > 256
       OR jsonb_typeof(input_row -> 'selector_id') <> 'string'
       OR btrim(input_row ->> 'selector_id') = ''
       OR input_row ->> 'selector_id' IS DISTINCT FROM btrim(input_row ->> 'selector_id')
       OR char_length(input_row ->> 'selector_id') > 256
       OR jsonb_typeof(input_row -> 'selector_candidate_id') <> 'string'
       OR input_row ->> 'selector_candidate_id' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  ) THEN
    RAISE EXCEPTION 'Item Identification property resolutions must contain exactly valid plan identities'
      USING ERRCODE = '22023';
  END IF;

  -- Ordinal means both array position and authored assignment ordinal. Reject
  -- duplicate, sparse, reordered, or merely membership-valid client plans.
  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_property_resolutions) WITH ORDINALITY AS input_row(value, position)
    WHERE (input_row.value ->> 'ordinal')::INTEGER <> input_row.position - 1
  ) THEN
    RAISE EXCEPTION 'Item Identification property resolutions must use dense ordered ordinals'
      USING ERRCODE = '22023';
  END IF;

  SELECT item.*
  INTO v_item
  FROM public.v3_items AS item
  WHERE item.id = p_item_id
    AND item.user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Owned Item % was not found', p_item_id USING ERRCODE = 'P0002';
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

  IF v_item.base_item_id IS DISTINCT FROM p_expected_base_item_id
     OR v_item.base_item_version_id IS DISTINCT FROM p_expected_base_item_version_id THEN
    RAISE EXCEPTION 'Item Identification expected binding does not match the owned exact Item binding'
      USING ERRCODE = '23514';
  END IF;

  SELECT receipt.*
  INTO v_receipt
  FROM public.v3_item_identification_commits AS receipt
  WHERE receipt.item_id = v_item.id
  FOR UPDATE;

  IF FOUND THEN
    IF v_receipt.user_id = v_user_id
       AND v_receipt.identification_kind = 'explicit'
       AND v_receipt.resolution_plan = p_property_resolutions THEN
      RETURN public.v3_item_identification_aggregate(v_item.id);
    END IF;

    RAISE EXCEPTION 'Item Identification command replay conflicts with its immutable receipt'
      USING ERRCODE = '23505';
  END IF;

  IF v_item.identification_state IS DISTINCT FROM 'unidentified' THEN
    RAISE EXCEPTION 'Item % is not awaiting explicit Identification', p_item_id
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.v3_item_property_values AS property_value
    WHERE property_value.item_id = v_item.id
  ) THEN
    RAISE EXCEPTION 'Unidentified Item % already has committed Property Values', p_item_id
      USING ERRCODE = '23514';
  END IF;

  SELECT count(*), max(assignment.ordinal)
  INTO v_expected_count, v_expected_max_ordinal
  FROM public.v3_base_item_version_variable_properties AS assignment
  WHERE assignment.base_item_version_id = v_item.base_item_version_id;

  IF v_expected_count > 0 AND v_expected_max_ordinal <> v_expected_count - 1 THEN
    RAISE EXCEPTION 'Exact Base Item Version % has non-dense Variable Property ordinals',
      v_item.base_item_version_id
      USING ERRCODE = '23514';
  END IF;

  IF jsonb_array_length(p_property_resolutions) <> v_expected_count THEN
    RAISE EXCEPTION 'Item Identification property resolutions are not a complete exact plan'
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.v3_base_item_version_variable_properties AS expected_assignment
    JOIN public.v3_variable_properties AS variable_property
      ON variable_property.id = expected_assignment.variable_property_id
    JOIN public.v3_selector_candidates AS candidate
      ON candidate.selector_id = variable_property.selector_id
    WHERE expected_assignment.base_item_version_id = v_item.base_item_version_id
      AND candidate.condition_id IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'Exact Base Item Version % requires unsupported conditioned Variable Property candidates',
      v_item.base_item_version_id
      USING ERRCODE = '23514';
  END IF;

  FOR v_assignment IN
    SELECT
      expected_assignment.ordinal,
      variable_property.id AS variable_property_key,
      variable_property.selector_id,
      (input_row.value ->> 'selector_candidate_id')::UUID AS supplied_selector_candidate_id
    FROM public.v3_base_item_version_variable_properties AS expected_assignment
    JOIN public.v3_variable_properties AS variable_property
      ON variable_property.id = expected_assignment.variable_property_id
    JOIN jsonb_array_elements(p_property_resolutions) WITH ORDINALITY AS input_row(value, position)
      ON input_row.position - 1 = expected_assignment.ordinal
    WHERE expected_assignment.base_item_version_id = v_item.base_item_version_id
    ORDER BY expected_assignment.ordinal
  LOOP
    IF v_assignment.variable_property_key IS DISTINCT FROM (
      p_property_resolutions -> v_assignment.ordinal ->> 'variable_property_key'
    )
       OR v_assignment.selector_id IS DISTINCT FROM (
         p_property_resolutions -> v_assignment.ordinal ->> 'selector_id'
       ) THEN
      RAISE EXCEPTION 'Item Identification property resolution does not match the exact Version assignment at ordinal %',
        v_assignment.ordinal
        USING ERRCODE = '23514';
    END IF;

    SELECT *
    INTO v_selected_candidate
    FROM public.v3_deterministic_variable_property_candidate(
      v_item.id,
      v_assignment.variable_property_key,
      v_assignment.selector_id
    );

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Variable Property Selector % has no active unconditional candidate',
        v_assignment.selector_id
        USING ERRCODE = '23514';
    END IF;

    IF v_selected_candidate.selector_candidate_id IS DISTINCT FROM v_assignment.supplied_selector_candidate_id THEN
      RAISE EXCEPTION 'Item Identification selector candidate does not match the deterministic server result at ordinal %',
        v_assignment.ordinal
        USING ERRCODE = '23514';
    END IF;

    INSERT INTO public.v3_item_property_values (
      item_id,
      user_id,
      base_item_id,
      base_item_version_id,
      variable_property_key,
      selector_id,
      selector_candidate_id,
      resolution_kind,
      resolved_value_id,
      resolved_at
    )
    VALUES (
      v_item.id,
      v_item.user_id,
      v_item.base_item_id,
      v_item.base_item_version_id,
      v_assignment.variable_property_key,
      v_assignment.selector_id,
      v_selected_candidate.selector_candidate_id,
      v_selected_candidate.resolution_kind,
      v_selected_candidate.resolved_value_id,
      v_committed_at
    );
  END LOOP;

  -- Projection continuity uses only evidence bound to this exact immutable
  -- Version, then hidden legacy evidence on this Item, then that exact Version
  -- or existing projection. It intentionally never reads a Base Item current pointer.
  v_display_name := COALESCE(
    NULLIF(v_version.authored_content #>> '{legacy_item_snapshot,identified_display_name}', ''),
    NULLIF(v_item.identified_display_name, ''),
    v_version.display_name,
    v_item.display_name
  );
  v_scientific_name := COALESCE(
    NULLIF(v_version.authored_content #>> '{legacy_item_snapshot,identified_scientific_name}', ''),
    NULLIF(v_item.identified_scientific_name, ''),
    v_version.scientific_name,
    v_item.scientific_name
  );
  v_taxonomic_class := COALESCE(
    NULLIF(v_version.authored_content #>> '{legacy_item_snapshot,identified_taxonomic_class}', ''),
    NULLIF(v_item.identified_taxonomic_class, ''),
    NULLIF(v_version.authored_content #>> '{legacy_catalog_snapshot,taxonomic_class}', ''),
    NULLIF(v_version.authored_content #>> '{legacy_item_snapshot,taxonomic_class}', ''),
    v_item.taxonomic_class
  );
  v_habitats_json := COALESCE(
    NULLIF(v_version.authored_content #>> '{legacy_item_snapshot,identified_habitats_json}', ''),
    NULLIF(v_item.identified_habitats_json, ''),
    NULLIF(v_version.authored_content #>> '{legacy_catalog_snapshot,habitats}', ''),
    NULLIF(v_version.authored_content #>> '{legacy_item_snapshot,habitats_json}', ''),
    v_item.habitats_json
  );
  v_continents_json := COALESCE(
    NULLIF(v_version.authored_content #>> '{legacy_item_snapshot,identified_continents_json}', ''),
    NULLIF(v_item.identified_continents_json, ''),
    NULLIF(v_version.authored_content #>> '{legacy_catalog_snapshot,continents}', ''),
    NULLIF(v_version.authored_content #>> '{legacy_item_snapshot,continents_json}', ''),
    v_item.continents_json
  );

  UPDATE public.v3_items
  SET display_name = v_display_name,
      scientific_name = v_scientific_name,
      taxonomic_class = v_taxonomic_class,
      habitats_json = v_habitats_json,
      continents_json = v_continents_json,
      identification_state = 'identified',
      identified_at = v_committed_at
  WHERE id = v_item.id
    AND user_id = v_user_id;

  SELECT discovery.*
  INTO v_discovery
  FROM public.v3_item_discoveries AS discovery
  WHERE discovery.user_id = v_item.user_id
    AND discovery.base_item_id = v_item.base_item_id
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.v3_item_discoveries (
      user_id,
      base_item_id,
      first_identified_item_id,
      first_base_item_version_id,
      provenance,
      discovered_at
    )
    VALUES (
      v_item.user_id,
      v_item.base_item_id,
      v_item.id,
      v_item.base_item_version_id,
      'explicit_identification',
      v_committed_at
    )
    ON CONFLICT (user_id, base_item_id) DO NOTHING
    RETURNING * INTO v_discovery;

    IF NOT FOUND THEN
      SELECT discovery.*
      INTO v_discovery
      FROM public.v3_item_discoveries AS discovery
      WHERE discovery.user_id = v_item.user_id
        AND discovery.base_item_id = v_item.base_item_id
      FOR UPDATE;
    END IF;
  END IF;


  INSERT INTO public.v3_item_identification_commits (
    item_id,
    user_id,
    base_item_id,
    base_item_version_id,
    identification_kind,
    resolution_plan,
    committed_at
  )
  VALUES (
    v_item.id,
    v_item.user_id,
    v_item.base_item_id,
    v_item.base_item_version_id,
    'explicit',
    p_property_resolutions,
    v_committed_at
  );

  RETURN public.v3_item_identification_aggregate(v_item.id);
END;
$$;

-- Direct client receipt/knowledge writes are closed. Existing own-row reads on
-- durable Discovery and Property Values remain governed by their 084 RLS policies.
REVOKE ALL ON TABLE public.v3_item_identification_commits
  FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.v3_item_discoveries
  FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.v3_item_property_values
  FROM PUBLIC, anon, authenticated;


REVOKE ALL ON FUNCTION public.v3_prevent_item_identification_commit_mutation()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_deterministic_variable_property_candidate(UUID, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_item_identification_aggregate(UUID)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.prepare_v3_item_identification(UUID)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.identify_v3_item(UUID, TEXT, UUID, JSONB)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.prepare_v3_item_identification(UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.identify_v3_item(UUID, TEXT, UUID, JSONB)
  TO authenticated;
