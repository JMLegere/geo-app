-- Migration 093: atomically resolve Reveal Venue Outcomes into stable Player knowledge.
--
-- Reveal Venue is an Encounter terminal effect, not a Venue Visit. Each result
-- binds the stable Venue and the exact published Version selected under lock.
-- Player knowledge remains first-write immutable; a later Reveal for an already
-- known Venue contributes its own committed Outcome Result without rewriting the
-- first-known evidence.

ALTER TABLE public.v3_encounter_outcome_results
  ADD COLUMN IF NOT EXISTS resolved_venue_id TEXT,
  ADD COLUMN IF NOT EXISTS resolved_venue_version_id UUID;

DO $add_encounter_outcome_result_resolved_venue_owner_fk$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'v3_encounter_outcome_results_resolved_venue_owner_fk'
      AND conrelid = 'public.v3_encounter_outcome_results'::regclass
  ) THEN
    ALTER TABLE public.v3_encounter_outcome_results
      ADD CONSTRAINT v3_encounter_outcome_results_resolved_venue_owner_fk
      FOREIGN KEY (resolved_venue_id, resolved_venue_version_id)
      REFERENCES public.v3_venue_versions(venue_id, id)
      ON UPDATE RESTRICT
      ON DELETE RESTRICT
      NOT VALID;
  END IF;
END;
$add_encounter_outcome_result_resolved_venue_owner_fk$;

ALTER TABLE public.v3_encounter_outcome_results
  DROP CONSTRAINT IF EXISTS v3_encounter_outcome_results_kind_specific_binding_check;

DO $replace_encounter_outcome_result_kind_specific_binding_check$
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
          AND resolved_venue_id IS NULL
          AND resolved_venue_version_id IS NULL
        )
        OR (
          outcome_kind = 'reveal_venue'
          AND resolved_base_item_version_id IS NULL
          AND generated_item_id IS NULL
          AND resolved_venue_id IS NOT NULL
          AND resolved_venue_version_id IS NOT NULL
        )
      ) NOT VALID;
  END IF;
END;
$replace_encounter_outcome_result_kind_specific_binding_check$;

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
  v_outcome_venue_id TEXT;
  v_resolved_base_item_id TEXT;
  v_encounter_user_id UUID;
  v_item_user_id UUID;
  v_item_base_item_id TEXT;
  v_item_base_item_version_id UUID;
  v_resolved_venue_id TEXT;
BEGIN
  SELECT encounter.selected_option_id, cell_visit.user_id
  INTO v_selected_option_id, v_encounter_user_id
  FROM public.v3_encounters AS encounter
  JOIN public.v3_cell_visits AS cell_visit
    ON cell_visit.id = encounter.cell_visit_id
  WHERE encounter.id = NEW.encounter_id;

  SELECT
    outcome.ordinal,
    outcome.kind,
    outcome.payload ->> 'base_item_id',
    outcome.payload ->> 'venue_id'
  INTO
    v_outcome_ordinal,
    v_outcome_kind,
    v_outcome_base_item_id,
    v_outcome_venue_id
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
  ELSIF NEW.outcome_kind = 'reveal_venue' THEN
    SELECT version.venue_id
    INTO v_resolved_venue_id
    FROM public.v3_venue_versions AS version
    WHERE version.id = NEW.resolved_venue_version_id
      AND version.venue_id = NEW.resolved_venue_id
      AND version.publication_status = 'published';

    IF v_resolved_venue_id IS DISTINCT FROM v_outcome_venue_id THEN
      RAISE EXCEPTION
        'Reveal Venue Outcome Result must preserve its exact published Venue Version'
        USING ERRCODE = '23514';
    END IF;
  ELSE
    RAISE EXCEPTION 'Encounter Outcome Result has an unsupported Outcome kind'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS v3_encounter_outcome_results_validate_binding
  ON public.v3_encounter_outcome_results;

CREATE TRIGGER v3_encounter_outcome_results_validate_binding
BEFORE INSERT OR UPDATE OF encounter_id, outcome_ordinal, encounter_outcome_id,
  outcome_kind, resolved_base_item_version_id, generated_item_id,
  resolved_venue_id, resolved_venue_version_id
ON public.v3_encounter_outcome_results
FOR EACH ROW
EXECUTE FUNCTION public.v3_validate_encounter_outcome_result();

-- Known-Venue provenance must follow the immutable result binding rather than a
-- mutable current-version pointer. This permits historical first-known evidence
-- to remain valid after the Venue publishes a later Version.
CREATE OR REPLACE FUNCTION public.v3_validate_known_venue_reveal_provenance()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_result_kind TEXT;
  v_result_venue_id TEXT;
  v_result_venue_version_id UUID;
  v_result_payload_venue_id TEXT;
  v_result_user_id UUID;
  v_has_reveal_result BOOLEAN;
BEGIN
  SELECT
    result.outcome_kind,
    result.resolved_venue_id,
    result.resolved_venue_version_id,
    outcome.payload ->> 'venue_id',
    cell_visit.user_id
  INTO
    v_result_kind,
    v_result_venue_id,
    v_result_venue_version_id,
    v_result_payload_venue_id,
    v_result_user_id
  FROM public.v3_encounter_outcome_results AS result
  JOIN public.v3_encounter_outcomes AS outcome
    ON outcome.id = result.encounter_outcome_id
  JOIN public.v3_encounters AS encounter
    ON encounter.id = result.encounter_id
  JOIN public.v3_cell_visits AS cell_visit
    ON cell_visit.id = encounter.cell_visit_id
  WHERE result.id = NEW.reveal_outcome_result_id;
  v_has_reveal_result := FOUND;

  IF NOT v_has_reveal_result
     OR v_result_kind IS DISTINCT FROM 'reveal_venue'
     OR v_result_payload_venue_id IS DISTINCT FROM NEW.venue_id
     OR v_result_venue_id IS DISTINCT FROM NEW.venue_id
     OR v_result_venue_version_id IS DISTINCT FROM NEW.first_venue_version_id
     OR v_result_user_id IS DISTINCT FROM NEW.user_id THEN
    RAISE EXCEPTION 'Known Venue must preserve its Player Reveal Venue Outcome provenance'
      USING ERRCODE = '23514';
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
          'resolved_venue_id', result.resolved_venue_id,
          'resolved_venue_version_id', result.resolved_venue_version_id,
          'resolved_venue_revision', resolved_venue_version.revision,
          'known_at', known.known_at,
          'created_at', result.created_at
        )
        ORDER BY result.outcome_ordinal
      )
      FROM public.v3_encounter_outcome_results AS result
      JOIN public.v3_encounters AS encounter
        ON encounter.id = result.encounter_id
      JOIN public.v3_cell_visits AS cell_visit
        ON cell_visit.id = encounter.cell_visit_id
      LEFT JOIN public.v3_base_item_versions AS resolved_base_item_version
        ON resolved_base_item_version.id = result.resolved_base_item_version_id
      LEFT JOIN public.v3_venue_versions AS resolved_venue_version
        ON resolved_venue_version.id = result.resolved_venue_version_id
        AND resolved_venue_version.venue_id = result.resolved_venue_id
      LEFT JOIN public.v3_player_known_venues AS known
        ON known.user_id = cell_visit.user_id
        AND known.venue_id = result.resolved_venue_id
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
  v_venue public.v3_venues%ROWTYPE;
  v_venue_version public.v3_venue_versions%ROWTYPE;
  v_generated_item public.v3_items%ROWTYPE;
  v_result_id UUID;
  v_plan JSONB := '{}'::jsonb;
  v_plan_entry JSONB;
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

  -- Lock every selected ordered Outcome first. Then lock stable identities in a
  -- deterministic order and build a complete immutable execution plan before
  -- mutating the Encounter, Items, Outcome Results, or Player knowledge.
  IF v_failure_code IS NULL THEN
    PERFORM outcome.id
    FROM public.v3_encounter_outcomes AS outcome
    WHERE outcome.encounter_option_id = v_option.id
    ORDER BY outcome.ordinal
    FOR UPDATE OF outcome;

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

    PERFORM venue.id
    FROM public.v3_venues AS venue
    WHERE venue.id IN (
      SELECT outcome.payload ->> 'venue_id'
      FROM public.v3_encounter_outcomes AS outcome
      WHERE outcome.encounter_option_id = v_option.id
        AND outcome.kind = 'reveal_venue'
    )
    ORDER BY venue.id
    FOR UPDATE OF venue;

    FOR v_outcome IN
      SELECT outcome.*
      FROM public.v3_encounter_outcomes AS outcome
      WHERE outcome.encounter_option_id = v_option.id
      ORDER BY outcome.ordinal
    LOOP
      IF v_outcome.kind = 'generate_item' THEN
        SELECT base_item.*
        INTO v_base_item
        FROM public.v3_base_items AS base_item
        WHERE base_item.id = v_outcome.payload ->> 'base_item_id'
        FOR UPDATE;

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
          AND base_item_version.publication_status = 'published'
        FOR UPDATE;

        IF NOT FOUND THEN
          v_failure_code := 'missing_current_base_item_version';
          v_failure_details := jsonb_build_object(
            'outcome_id', v_outcome.id,
            'base_item_id', v_base_item.id
          );
          EXIT;
        END IF;

        v_plan := v_plan || jsonb_build_object(
          v_outcome.ordinal::TEXT,
          jsonb_build_object(
            'outcome_id', v_outcome.id,
            'kind', v_outcome.kind,
            'base_item_id', v_base_item.id,
            'base_item_version_id', v_base_item_version.id
          )
        );
      ELSIF v_outcome.kind = 'reveal_venue' THEN
        SELECT venue.*
        INTO v_venue
        FROM public.v3_venues AS venue
        WHERE venue.id = v_outcome.payload ->> 'venue_id'
        FOR UPDATE;

        IF NOT FOUND OR v_venue.current_published_version_id IS NULL THEN
          v_failure_code := 'missing_current_venue_version';
          v_failure_details := jsonb_build_object(
            'outcome_id', v_outcome.id,
            'venue_id', v_outcome.payload ->> 'venue_id'
          );
          EXIT;
        END IF;

        SELECT venue_version.*
        INTO v_venue_version
        FROM public.v3_venue_versions AS venue_version
        WHERE venue_version.id = v_venue.current_published_version_id
          AND venue_version.venue_id = v_venue.id
          AND venue_version.publication_status = 'published'
        FOR UPDATE;

        IF NOT FOUND THEN
          v_failure_code := 'missing_current_venue_version';
          v_failure_details := jsonb_build_object(
            'outcome_id', v_outcome.id,
            'venue_id', v_venue.id
          );
          EXIT;
        END IF;

        v_plan := v_plan || jsonb_build_object(
          v_outcome.ordinal::TEXT,
          jsonb_build_object(
            'outcome_id', v_outcome.id,
            'kind', v_outcome.kind,
            'venue_id', v_venue.id,
            'venue_version_id', v_venue_version.id
          )
        );
      ELSE
        v_failure_code := 'unsupported_outcome_kind';
        v_failure_details := jsonb_build_object(
          'outcome_id', v_outcome.id,
          'kind', v_outcome.kind
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
    -- The nested exception block rolls back every Item, Outcome Result, and
    -- known Venue before the outer block stores terminal failure evidence.
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
      v_plan_entry := v_plan -> (v_outcome.ordinal::TEXT);

      IF v_plan_entry IS NULL THEN
        RAISE EXCEPTION 'Encounter Outcome execution plan is incomplete'
          USING ERRCODE = '23514';
      END IF;

      IF v_outcome.kind = 'generate_item' THEN
        SELECT base_item.*
        INTO STRICT v_base_item
        FROM public.v3_base_items AS base_item
        WHERE base_item.id = (v_plan_entry ->> 'base_item_id');

        SELECT base_item_version.*
        INTO STRICT v_base_item_version
        FROM public.v3_base_item_versions AS base_item_version
        WHERE base_item_version.id = (v_plan_entry ->> 'base_item_version_id')::UUID
          AND base_item_version.base_item_id = v_base_item.id;

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
          generated_item_id,
          resolved_venue_id,
          resolved_venue_version_id
        )
        VALUES (
          v_encounter.id,
          v_outcome.ordinal,
          v_outcome.id,
          v_outcome.kind,
          v_base_item_version.id,
          v_generated_item.id,
          NULL,
          NULL
        );
      ELSIF v_outcome.kind = 'reveal_venue' THEN
        INSERT INTO public.v3_encounter_outcome_results (
          encounter_id,
          outcome_ordinal,
          encounter_outcome_id,
          outcome_kind,
          resolved_base_item_version_id,
          generated_item_id,
          resolved_venue_id,
          resolved_venue_version_id
        )
        VALUES (
          v_encounter.id,
          v_outcome.ordinal,
          v_outcome.id,
          v_outcome.kind,
          NULL,
          NULL,
          (v_plan_entry ->> 'venue_id'),
          (v_plan_entry ->> 'venue_version_id')::UUID
        )
        RETURNING id INTO v_result_id;

        INSERT INTO public.v3_player_known_venues (
          user_id,
          venue_id,
          first_venue_version_id,
          reveal_outcome_result_id
        )
        VALUES (
          v_user_id,
          (v_plan_entry ->> 'venue_id'),
          (v_plan_entry ->> 'venue_version_id')::UUID,
          v_result_id
        )
        ON CONFLICT (user_id, venue_id) DO NOTHING;
      ELSE
        RAISE EXCEPTION 'Encounter Outcome execution plan has an unsupported Outcome kind'
          USING ERRCODE = '23514';
      END IF;
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

-- Helpers remain private despite Supabase's direct default grants. The command
-- remains the only authenticated mutation entrypoint.
REVOKE ALL ON FUNCTION public.v3_validate_encounter_outcome_result()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_validate_known_venue_reveal_provenance()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_encounter_runtime_aggregate(UUID)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.resolve_v3_encounter_outcomes(UUID, UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolve_v3_encounter_outcomes(UUID, UUID)
  TO authenticated;

COMMENT ON FUNCTION public.resolve_v3_encounter_outcomes(UUID, UUID) IS
  'Atomically plans all ordered Generate Item and Reveal Venue Outcomes against locked exact published Versions, or stores terminal failure evidence after rolling back every partial effect.';
