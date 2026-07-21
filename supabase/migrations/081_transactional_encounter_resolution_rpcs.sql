-- Migration 081: transactional Encounter entry and ordered Outcome application.
--
-- Runtime tables remain read-only through RLS. These authenticated command RPCs
-- own authorization, locking, idempotency, exact Version binding, and atomic
-- mutation boundaries.

ALTER TABLE public.v3_encounter_outcome_results
  ADD COLUMN IF NOT EXISTS generated_item_id UUID
    REFERENCES public.v3_items(id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT;

DO $add_generated_item_unique_constraint$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'v3_encounter_outcome_results_generated_item_unique'
      AND conrelid = 'public.v3_encounter_outcome_results'::regclass
  ) THEN
    ALTER TABLE public.v3_encounter_outcome_results
      ADD CONSTRAINT v3_encounter_outcome_results_generated_item_unique
      UNIQUE (generated_item_id);
  END IF;
END;
$add_generated_item_unique_constraint$;

DO $add_outcome_result_kind_specific_binding_check$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'v3_encounter_outcome_results_kind_specific_binding_check'
      AND conrelid = 'public.v3_encounter_outcome_results'::regclass
  ) THEN
    ALTER TABLE public.v3_encounter_outcome_results
      ADD CONSTRAINT v3_encounter_outcome_results_kind_specific_binding_check
      CHECK (
        (
          outcome_kind = 'generate_item'
          AND resolved_base_item_version_id IS NOT NULL
          AND generated_item_id IS NOT NULL
        )
        OR (
          outcome_kind = 'reveal_venue'
          AND resolved_base_item_version_id IS NULL
          AND generated_item_id IS NULL
        )
      ) NOT VALID;
  END IF;
END;
$add_outcome_result_kind_specific_binding_check$;

CREATE OR REPLACE FUNCTION public.v3_validate_encounter_outcome_result()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_selected_option_id UUID;
  v_outcome_ordinal INTEGER;
  v_outcome_kind TEXT;
  v_outcome_base_item_id TEXT;
  v_resolved_base_item_id TEXT;
  v_encounter_user_id UUID;
  v_item_user_id UUID;
  v_item_base_item_id TEXT;
  v_item_base_item_version_id UUID;
BEGIN
  SELECT encounter.selected_option_id, cell_visit.user_id
  INTO v_selected_option_id, v_encounter_user_id
  FROM public.v3_encounters AS encounter
  JOIN public.v3_cell_visits AS cell_visit
    ON cell_visit.id = encounter.cell_visit_id
  WHERE encounter.id = NEW.encounter_id;

  SELECT outcome.ordinal, outcome.kind, outcome.payload ->> 'base_item_id'
  INTO v_outcome_ordinal, v_outcome_kind, v_outcome_base_item_id
  FROM public.v3_encounter_outcomes AS outcome
  WHERE outcome.id = NEW.encounter_outcome_id
    AND outcome.encounter_option_id = v_selected_option_id;

  IF v_selected_option_id IS NULL
     OR NOT FOUND
     OR v_outcome_ordinal <> NEW.outcome_ordinal
     OR v_outcome_kind <> NEW.outcome_kind THEN
    RAISE EXCEPTION
      'Encounter Outcome Result must match the Encounter selected Option ordered Outcome'
      USING ERRCODE = '23514';
  END IF;

  IF NEW.outcome_kind = 'generate_item' THEN
    SELECT version.base_item_id
    INTO v_resolved_base_item_id
    FROM public.v3_base_item_versions AS version
    WHERE version.id = NEW.resolved_base_item_version_id;

    SELECT item.user_id, item.base_item_id, item.base_item_version_id
    INTO v_item_user_id, v_item_base_item_id, v_item_base_item_version_id
    FROM public.v3_items AS item
    WHERE item.id = NEW.generated_item_id;

    IF v_resolved_base_item_id IS DISTINCT FROM v_outcome_base_item_id
       OR v_item_user_id IS DISTINCT FROM v_encounter_user_id
       OR v_item_base_item_id IS DISTINCT FROM v_outcome_base_item_id
       OR v_item_base_item_version_id IS DISTINCT FROM NEW.resolved_base_item_version_id THEN
      RAISE EXCEPTION
        'Generate Item Outcome Result must preserve its owned generated Item and exact Base Item Version'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.v3_validate_encounter_outcome_result() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.v3_limit_encounter_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Encounter occurrences cannot be deleted';
  END IF;

  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.cell_visit_id IS DISTINCT FROM OLD.cell_visit_id
     OR NEW.cell_visit_resolution_id IS DISTINCT FROM OLD.cell_visit_resolution_id
     OR NEW.encounter_definition_id IS DISTINCT FROM OLD.encounter_definition_id
     OR NEW.encounter_definition_version_id IS DISTINCT FROM OLD.encounter_definition_version_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'Encounter occurrence identity and version binding are immutable';
  END IF;

  IF NEW.resolution_status = OLD.resolution_status THEN
    IF NEW.selected_option_id IS DISTINCT FROM OLD.selected_option_id
       OR NEW.resolved_at IS DISTINCT FROM OLD.resolved_at
       OR NEW.failure_code IS DISTINCT FROM OLD.failure_code
       OR NEW.failure_details IS DISTINCT FROM OLD.failure_details THEN
      RAISE EXCEPTION 'Encounter resolution fields require one terminal transition';
    END IF;
    RETURN NEW;
  END IF;

  IF OLD.resolution_status <> 'pending' THEN
    RAISE EXCEPTION 'Encounter terminal states are immutable';
  END IF;

  IF NEW.resolution_status NOT IN ('resolved', 'failed') THEN
    RAISE EXCEPTION 'A pending Encounter may only transition to resolved or failed';
  END IF;

  RETURN NEW;
END;
$$;

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
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', result.id,
          'encounter_id', result.encounter_id,
          'outcome_ordinal', result.outcome_ordinal,
          'encounter_outcome_id', result.encounter_outcome_id,
          'outcome_kind', result.outcome_kind,
          'resolved_base_item_version_id', result.resolved_base_item_version_id,
          'resolved_base_item_id', resolved_base_item_version.base_item_id,
          'resolved_base_item_revision', resolved_base_item_version.revision,
          'generated_item_id', result.generated_item_id,
          'created_at', result.created_at
        )
        ORDER BY result.outcome_ordinal
      )
      FROM public.v3_encounter_outcome_results AS result
      JOIN public.v3_encounters AS encounter
        ON encounter.id = result.encounter_id
      LEFT JOIN public.v3_base_item_versions AS resolved_base_item_version
        ON resolved_base_item_version.id = result.resolved_base_item_version_id
      WHERE encounter.cell_visit_id = p_cell_visit_id
    ), '[]'::jsonb),
    'generated_items', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', item.id,
          'user_id', item.user_id,
          'definition_id', item.definition_id,
          'display_name', item.display_name,
          'scientific_name', item.scientific_name,
          'category', item.category,
          'acquired_at', item.acquired_at,
          'acquired_in_cell_id', item.acquired_in_cell_id,
          'status', item.status,
          'base_item_id', item.base_item_id,
          'base_item_version_id', item.base_item_version_id,
          'base_item_revision', item_base_item_version.revision
        )
        ORDER BY result.outcome_ordinal
      )
      FROM public.v3_encounter_outcome_results AS result
      JOIN public.v3_encounters AS encounter
        ON encounter.id = result.encounter_id
      JOIN public.v3_items AS item
        ON item.id = result.generated_item_id
      JOIN public.v3_base_item_versions AS item_base_item_version
        ON item_base_item_version.id = item.base_item_version_id
        AND item_base_item_version.base_item_id = item.base_item_id
      WHERE encounter.cell_visit_id = p_cell_visit_id
    ), '[]'::jsonb)
  );
$$;

REVOKE ALL ON FUNCTION public.v3_encounter_runtime_aggregate(UUID) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.resolve_v3_cell_visit_encounter(
  p_cell_visit_id UUID,
  p_selector_id TEXT,
  p_selector_candidate_id UUID,
  p_expected_encounter_definition_version_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_cell_visit public.v3_cell_visits%ROWTYPE;
  v_candidate public.v3_selector_candidates%ROWTYPE;
  v_definition public.v3_encounter_definitions%ROWTYPE;
  v_version public.v3_encounter_definition_versions%ROWTYPE;
  v_existing_resolution public.v3_cell_visit_resolutions%ROWTYPE;
  v_existing_encounter public.v3_encounters%ROWTYPE;
  v_resolution public.v3_cell_visit_resolutions%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Encounter resolution requires an authenticated user'
      USING ERRCODE = '28000';
  END IF;

  SELECT cell_visit.*
  INTO v_cell_visit
  FROM public.v3_cell_visits AS cell_visit
  WHERE cell_visit.id = p_cell_visit_id
    AND cell_visit.user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cell Visit is unavailable to the authenticated user'
      USING ERRCODE = '42501';
  END IF;

  SELECT candidate.*
  INTO v_candidate
  FROM public.v3_selector_candidates AS candidate
  JOIN public.v3_selectors AS selector
    ON selector.id = candidate.selector_id
  WHERE selector.id = p_selector_id
    AND selector.status = 'active'
    AND selector.result_type = 'encounter_definition'
    AND candidate.id = p_selector_candidate_id
    AND candidate.selector_id = p_selector_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Selector candidate is not an active Encounter Definition candidate'
      USING ERRCODE = '22023';
  END IF;

  SELECT resolution.*
  INTO v_existing_resolution
  FROM public.v3_cell_visit_resolutions AS resolution
  WHERE resolution.cell_visit_id = p_cell_visit_id;

  IF FOUND THEN
    IF v_existing_resolution.selector_id IS DISTINCT FROM p_selector_id
       OR v_existing_resolution.selector_candidate_id IS DISTINCT FROM p_selector_candidate_id THEN
      RAISE EXCEPTION 'Cell Visit resolution retry input differs from the persisted resolution'
        USING ERRCODE = 'P0001';
    END IF;

    IF v_existing_resolution.resolution_kind = 'none' THEN
      IF p_expected_encounter_definition_version_id IS NOT NULL
         OR v_candidate.result_kind <> 'none' THEN
        RAISE EXCEPTION 'Cell Visit resolution retry input differs from the persisted resolution'
          USING ERRCODE = 'P0001';
      END IF;
      RETURN public.v3_encounter_runtime_aggregate(p_cell_visit_id);
    END IF;

    SELECT encounter.*
    INTO v_existing_encounter
    FROM public.v3_encounters AS encounter
    WHERE encounter.cell_visit_id = p_cell_visit_id;

    IF NOT FOUND
       OR v_candidate.result_kind <> 'value'
       OR v_candidate.result_id IS DISTINCT FROM v_existing_resolution.encounter_definition_id
       OR p_expected_encounter_definition_version_id IS NULL
       OR v_existing_encounter.encounter_definition_version_id
          IS DISTINCT FROM p_expected_encounter_definition_version_id THEN
      RAISE EXCEPTION 'Cell Visit resolution retry input differs from the persisted resolution'
        USING ERRCODE = 'P0001';
    END IF;

    RETURN public.v3_encounter_runtime_aggregate(p_cell_visit_id);
  END IF;

  IF v_candidate.result_kind = 'none' THEN
    IF p_expected_encounter_definition_version_id IS NOT NULL THEN
      RAISE EXCEPTION
        'None Cell Visit resolution must not provide an expected Encounter Definition Version'
        USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.v3_cell_visit_resolutions (
      cell_visit_id,
      selector_id,
      selector_candidate_id,
      resolution_kind,
      encounter_definition_id
    )
    VALUES (
      p_cell_visit_id,
      p_selector_id,
      p_selector_candidate_id,
      'none',
      NULL
    )
    RETURNING * INTO v_resolution;

    RETURN public.v3_encounter_runtime_aggregate(p_cell_visit_id);
  END IF;

  IF v_candidate.result_kind <> 'value'
     OR p_expected_encounter_definition_version_id IS NULL THEN
    RAISE EXCEPTION 'Encounter selection requires an expected current Definition Version'
      USING ERRCODE = '22023';
  END IF;

  SELECT definition.*
  INTO v_definition
  FROM public.v3_encounter_definitions AS definition
  WHERE definition.id = v_candidate.result_id
  FOR UPDATE;

  IF NOT FOUND
     OR v_definition.current_published_version_id IS NULL
     OR v_definition.current_published_version_id
        IS DISTINCT FROM p_expected_encounter_definition_version_id THEN
    RAISE EXCEPTION 'Encounter Definition current published Version changed; recompute the plan'
      USING ERRCODE = '40001';
  END IF;

  SELECT version.*
  INTO v_version
  FROM public.v3_encounter_definition_versions AS version
  WHERE version.id = p_expected_encounter_definition_version_id
    AND version.encounter_definition_id = v_definition.id
    AND version.publication_status = 'published';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Expected Encounter Definition Version is not currently published'
      USING ERRCODE = '40001';
  END IF;

  INSERT INTO public.v3_cell_visit_resolutions (
    cell_visit_id,
    selector_id,
    selector_candidate_id,
    resolution_kind,
    encounter_definition_id
  )
  VALUES (
    p_cell_visit_id,
    p_selector_id,
    p_selector_candidate_id,
    'encounter',
    v_definition.id
  )
  RETURNING * INTO v_resolution;

  INSERT INTO public.v3_encounters (
    cell_visit_id,
    cell_visit_resolution_id,
    encounter_definition_id,
    encounter_definition_version_id
  )
  VALUES (
    p_cell_visit_id,
    v_resolution.id,
    v_definition.id,
    v_version.id
  );

  RETURN public.v3_encounter_runtime_aggregate(p_cell_visit_id);
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_v3_cell_visit_encounter(UUID, TEXT, UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_v3_cell_visit_encounter(UUID, TEXT, UUID, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.resolve_v3_encounter_outcomes(
  p_encounter_id UUID,
  p_selected_option_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_encounter public.v3_encounters%ROWTYPE;
  v_version public.v3_encounter_definition_versions%ROWTYPE;
  v_option public.v3_encounter_options%ROWTYPE;
  v_outcome RECORD;
  v_base_item public.v3_base_items%ROWTYPE;
  v_base_item_version public.v3_base_item_versions%ROWTYPE;
  v_generated_item public.v3_items%ROWTYPE;
  v_cell_id TEXT;
  v_option_count INTEGER;
  v_outcome_count INTEGER;
  v_result_count INTEGER;
  v_failure_code TEXT;
  v_failure_details JSONB;
  v_sqlstate TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Encounter Outcome resolution requires an authenticated user'
      USING ERRCODE = '28000';
  END IF;

  SELECT encounter.*
  INTO v_encounter
  FROM public.v3_encounters AS encounter
  JOIN public.v3_cell_visits AS cell_visit
    ON cell_visit.id = encounter.cell_visit_id
  WHERE encounter.id = p_encounter_id
    AND cell_visit.user_id = v_user_id
  FOR UPDATE OF encounter;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Encounter is unavailable to the authenticated user'
      USING ERRCODE = '42501';
  END IF;

  SELECT cell_visit.cell_id
  INTO v_cell_id
  FROM public.v3_cell_visits AS cell_visit
  WHERE cell_visit.id = v_encounter.cell_visit_id;

  IF v_encounter.resolution_status = 'resolved' THEN
    IF p_selected_option_id IS NOT NULL
       AND p_selected_option_id IS DISTINCT FROM v_encounter.selected_option_id THEN
      RAISE EXCEPTION 'Resolved Encounter retry selected Option differs from the persisted Option'
        USING ERRCODE = 'P0001';
    END IF;
    RETURN public.v3_encounter_runtime_aggregate(v_encounter.cell_visit_id);
  END IF;

  IF v_encounter.resolution_status = 'failed' THEN
    IF v_encounter.selected_option_id IS NOT NULL
       AND p_selected_option_id IS NOT NULL
       AND p_selected_option_id IS DISTINCT FROM v_encounter.selected_option_id THEN
      RAISE EXCEPTION 'Failed Encounter retry selected Option differs from the persisted Option'
        USING ERRCODE = 'P0001';
    END IF;
    RETURN public.v3_encounter_runtime_aggregate(v_encounter.cell_visit_id);
  END IF;

  SELECT version.*
  INTO v_version
  FROM public.v3_encounter_definition_versions AS version
  WHERE version.id = v_encounter.encounter_definition_version_id
    AND version.encounter_definition_id = v_encounter.encounter_definition_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Encounter exact Definition Version is unavailable'
      USING ERRCODE = '23503';
  END IF;

  IF v_version.is_automatic THEN
    SELECT count(*)
    INTO v_option_count
    FROM public.v3_encounter_options AS option
    WHERE option.encounter_definition_version_id = v_version.id
      AND option.is_implicit;

    IF v_option_count <> 1 THEN
      RAISE EXCEPTION 'Automatic Encounter requires exactly one implicit Option'
        USING ERRCODE = '23514';
    END IF;

    SELECT option.*
    INTO v_option
    FROM public.v3_encounter_options AS option
    WHERE option.encounter_definition_version_id = v_version.id
      AND option.is_implicit;

    IF p_selected_option_id IS NOT NULL
       AND p_selected_option_id IS DISTINCT FROM v_option.id THEN
      RAISE EXCEPTION 'Automatic Encounter retry selected Option differs from its implicit Option'
        USING ERRCODE = 'P0001';
    END IF;
  ELSE
    IF p_selected_option_id IS NULL THEN
      RAISE EXCEPTION 'Manual Encounter requires an explicit Option'
        USING ERRCODE = '22023';
    END IF;

    SELECT option.*
    INTO v_option
    FROM public.v3_encounter_options AS option
    WHERE option.id = p_selected_option_id;

    IF NOT FOUND
       OR v_option.encounter_definition_version_id IS DISTINCT FROM v_version.id THEN
      RAISE EXCEPTION
        'Manual Encounter Option belongs to a different Encounter Definition Version'
        USING ERRCODE = '22023';
    END IF;
  END IF;

  IF v_option.condition_id IS NOT NULL THEN
    v_failure_code := 'unsupported_option_condition';
    v_failure_details := jsonb_build_object(
      'reason', 'Unsupported Encounter Option Condition',
      'condition_id', v_option.condition_id
    );
  END IF;

  SELECT count(*)
  INTO v_outcome_count
  FROM public.v3_encounter_outcomes AS outcome
  WHERE outcome.encounter_option_id = v_option.id;

  IF v_failure_code IS NULL AND v_outcome_count = 0 THEN
    v_failure_code := 'missing_outcomes';
    v_failure_details := jsonb_build_object(
      'reason', 'Encounter Option has no Outcomes'
    );
  END IF;

  IF v_failure_code IS NULL AND EXISTS (
    SELECT 1
    FROM public.v3_encounter_outcomes AS outcome
    WHERE outcome.encounter_option_id = v_option.id
      AND outcome.kind = 'reveal_venue'
  ) THEN
    v_failure_code := 'unsupported_reveal_venue';
    v_failure_details := jsonb_build_object(
      'reason', 'Unsupported Reveal Venue Outcome'
    );
  END IF;

  IF v_failure_code IS NULL THEN
    PERFORM base_item.id
    FROM public.v3_base_items AS base_item
    WHERE base_item.id IN (
      SELECT outcome.payload ->> 'base_item_id'
      FROM public.v3_encounter_outcomes AS outcome
      WHERE outcome.encounter_option_id = v_option.id
        AND outcome.kind = 'generate_item'
    )
    ORDER BY base_item.id
    FOR UPDATE OF base_item;

    FOR v_outcome IN
      SELECT outcome.*
      FROM public.v3_encounter_outcomes AS outcome
      WHERE outcome.encounter_option_id = v_option.id
      ORDER BY outcome.ordinal
    LOOP
      IF v_outcome.kind <> 'generate_item' THEN
        v_failure_code := 'unsupported_outcome_kind';
        v_failure_details := jsonb_build_object(
          'outcome_id', v_outcome.id,
          'kind', v_outcome.kind
        );
        EXIT;
      END IF;

      SELECT base_item.*
      INTO v_base_item
      FROM public.v3_base_items AS base_item
      WHERE base_item.id = v_outcome.payload ->> 'base_item_id';

      IF NOT FOUND OR v_base_item.current_published_version_id IS NULL THEN
        v_failure_code := 'missing_current_base_item_version';
        v_failure_details := jsonb_build_object(
          'outcome_id', v_outcome.id,
          'base_item_id', v_outcome.payload ->> 'base_item_id'
        );
        EXIT;
      END IF;

      SELECT base_item_version.*
      INTO v_base_item_version
      FROM public.v3_base_item_versions AS base_item_version
      WHERE base_item_version.id = v_base_item.current_published_version_id
        AND base_item_version.base_item_id = v_base_item.id
        AND base_item_version.publication_status = 'published';

      IF NOT FOUND THEN
        v_failure_code := 'missing_current_base_item_version';
        v_failure_details := jsonb_build_object(
          'outcome_id', v_outcome.id,
          'base_item_id', v_base_item.id
        );
        EXIT;
      END IF;
    END LOOP;
  END IF;

  IF v_failure_code IS NOT NULL THEN
    UPDATE public.v3_encounters
    SET resolution_status = 'failed',
        selected_option_id = v_option.id,
        failure_code = v_failure_code,
        failure_details = v_failure_details
    WHERE id = v_encounter.id;

    RETURN public.v3_encounter_runtime_aggregate(v_encounter.cell_visit_id);
  END IF;

  BEGIN
    -- The nested exception block rolls back every Item and Outcome Result
    -- before the outer block stores terminal failure evidence.
    UPDATE public.v3_encounters
    SET resolution_status = 'resolved',
        selected_option_id = v_option.id,
        resolved_at = now(),
        failure_code = NULL,
        failure_details = NULL
    WHERE id = v_encounter.id;

    FOR v_outcome IN
      SELECT outcome.*
      FROM public.v3_encounter_outcomes AS outcome
      WHERE outcome.encounter_option_id = v_option.id
      ORDER BY outcome.ordinal
    LOOP
      SELECT base_item.*
      INTO STRICT v_base_item
      FROM public.v3_base_items AS base_item
      WHERE base_item.id = v_outcome.payload ->> 'base_item_id';

      SELECT base_item_version.*
      INTO STRICT v_base_item_version
      FROM public.v3_base_item_versions AS base_item_version
      WHERE base_item_version.id = v_base_item.current_published_version_id
        AND base_item_version.base_item_id = v_base_item.id
        AND base_item_version.publication_status = 'published';

      INSERT INTO public.v3_items (
        user_id,
        definition_id,
        display_name,
        scientific_name,
        category,
        acquired_in_cell_id,
        status,
        base_item_id,
        base_item_version_id
      )
      VALUES (
        v_user_id,
        v_base_item.id,
        v_base_item_version.display_name,
        v_base_item_version.scientific_name,
        v_base_item.category,
        v_cell_id,
        'active',
        v_base_item.id,
        v_base_item_version.id
      )
      RETURNING * INTO v_generated_item;

      INSERT INTO public.v3_encounter_outcome_results (
        encounter_id,
        outcome_ordinal,
        encounter_outcome_id,
        outcome_kind,
        resolved_base_item_version_id,
        generated_item_id
      )
      VALUES (
        v_encounter.id,
        v_outcome.ordinal,
        v_outcome.id,
        v_outcome.kind,
        v_base_item_version.id,
        v_generated_item.id
      );
    END LOOP;

    SELECT count(*)
    INTO v_result_count
    FROM public.v3_encounter_outcome_results AS result
    WHERE result.encounter_id = v_encounter.id;

    IF v_result_count <> v_outcome_count
       OR EXISTS (
         SELECT outcome.ordinal
         FROM public.v3_encounter_outcomes AS outcome
         WHERE outcome.encounter_option_id = v_option.id
         EXCEPT
         SELECT result.outcome_ordinal
         FROM public.v3_encounter_outcome_results AS result
         WHERE result.encounter_id = v_encounter.id
       ) THEN
      RAISE EXCEPTION 'Encounter Outcome Result set is incomplete'
        USING ERRCODE = '23514';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_sqlstate = RETURNED_SQLSTATE;
    v_failure_code := 'outcome_commit_failed';
    v_failure_details := jsonb_build_object(
      'sqlstate', v_sqlstate
    );
  END;

  IF v_failure_code IS NOT NULL THEN
    UPDATE public.v3_encounters
    SET resolution_status = 'failed',
        selected_option_id = v_option.id,
        resolved_at = NULL,
        failure_code = v_failure_code,
        failure_details = v_failure_details
    WHERE id = v_encounter.id;
  END IF;

  RETURN public.v3_encounter_runtime_aggregate(v_encounter.cell_visit_id);
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_v3_encounter_outcomes(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_v3_encounter_outcomes(UUID, UUID) TO authenticated;

COMMENT ON FUNCTION public.resolve_v3_cell_visit_encounter(UUID, TEXT, UUID, UUID) IS
  'Atomically persists one explicit Cell Visit Selector result and, for a selected Definition, one pending exact-Version-bound Encounter.';

COMMENT ON FUNCTION public.resolve_v3_encounter_outcomes(UUID, UUID) IS
  'Atomically applies all ordered supported Outcomes for one owned pending Encounter, or stores terminal failure evidence after rolling back partial effects.';
