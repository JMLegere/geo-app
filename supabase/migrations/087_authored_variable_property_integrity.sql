-- Migration 087: make normalized Variable Property definitions authoritative for
-- published Base Item Versions and committed Item Property Values.
--
-- This migration adds integrity around the existing normalized authored model;
-- it neither duplicates those definitions into version JSON nor rewrites legacy
-- Item or authored rows.

-- A committed Item Property Value must name a Variable Property that the Item's
-- exact Base Item Version actually assigned. The target pair is already unique
-- on the normalized assignment table.
DO $add_v3_item_property_values_exact_definition_assignment_fk$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'v3_item_property_values_exact_definition_assignment_fk'
      AND conrelid = 'public.v3_item_property_values'::regclass
  ) THEN
    ALTER TABLE public.v3_item_property_values
      ADD CONSTRAINT v3_item_property_values_exact_definition_assignment_fk
      FOREIGN KEY (base_item_version_id, variable_property_key)
      REFERENCES public.v3_base_item_version_variable_properties(
        base_item_version_id,
        variable_property_id
      )
      ON UPDATE RESTRICT ON DELETE RESTRICT;
  END IF;
END;
$add_v3_item_property_values_exact_definition_assignment_fk$;

CREATE OR REPLACE FUNCTION public.v3_assert_dense_selector_candidate_ordinals(
  p_selector_id TEXT
)
RETURNS VOID
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_candidate_count BIGINT;
  v_max_ordinal INTEGER;
BEGIN
  SELECT count(*), max(candidate.ordinal)
  INTO v_candidate_count, v_max_ordinal
  FROM public.v3_selector_candidates AS candidate
  WHERE candidate.selector_id = p_selector_id;

  IF v_candidate_count = 0
     OR v_max_ordinal <> v_candidate_count - 1 THEN
    RAISE EXCEPTION
      'Selector % must have dense candidate ordinals beginning at zero',
      p_selector_id
      USING ERRCODE = '23514';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.v3_assert_variable_property_selector_integrity(
  p_variable_property_id TEXT
)
RETURNS VOID
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_selector_id TEXT;
  v_selector_result_type TEXT;
  v_selector_status TEXT;
BEGIN
  SELECT
    variable_property.selector_id,
    selector.result_type,
    selector.status
  INTO v_selector_id, v_selector_result_type, v_selector_status
  FROM public.v3_variable_properties AS variable_property
  JOIN public.v3_selectors AS selector
    ON selector.id = variable_property.selector_id
  WHERE variable_property.id = p_variable_property_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unknown Variable Property %', p_variable_property_id
      USING ERRCODE = '23514';
  END IF;

  IF v_selector_result_type IS DISTINCT FROM 'property_value'
     OR v_selector_status IS DISTINCT FROM 'active' THEN
    RAISE EXCEPTION
      'Variable Property % requires an active property_value Selector',
      p_variable_property_id
      USING ERRCODE = '23514';
  END IF;

  PERFORM public.v3_assert_dense_selector_candidate_ordinals(v_selector_id);

  -- Identification has no server Condition evaluator/context yet. An assigned
  -- property therefore fails closed rather than allowing a client to choose
  -- which conditional candidate becomes valuable.
  IF EXISTS (
    SELECT 1
    FROM public.v3_selector_candidates AS candidate
    WHERE candidate.selector_id = v_selector_id
      AND candidate.condition_id IS NOT NULL
  ) THEN
    RAISE EXCEPTION
      'Variable Property % cannot use conditional Selector candidates',
      p_variable_property_id
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.v3_selector_candidates AS candidate
    LEFT JOIN public.v3_property_values AS property_value
      ON property_value.id = candidate.result_id
    WHERE candidate.selector_id = v_selector_id
      AND (
        candidate.result_kind <> 'none'
        AND (
          candidate.result_kind <> 'value'
          OR property_value.id IS NULL
          OR property_value.variable_property_id IS DISTINCT FROM p_variable_property_id
        )
      )
  ) THEN
    RAISE EXCEPTION
      'Variable Property % Selector candidates must resolve only owned Property Values or explicit None',
      p_variable_property_id
      USING ERRCODE = '23514';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.v3_assert_base_item_version_variable_property_integrity(
  p_base_item_version_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_base_item_category TEXT;
  v_assignment_count BIGINT;
  v_assignment_max_ordinal INTEGER;
  v_assignment RECORD;
  v_variable_property_category TEXT;
BEGIN
  SELECT base_item.category
  INTO v_base_item_category
  FROM public.v3_base_item_versions AS base_item_version
  JOIN public.v3_base_items AS base_item
    ON base_item.id = base_item_version.base_item_id
  WHERE base_item_version.id = p_base_item_version_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unknown Base Item Version %', p_base_item_version_id
      USING ERRCODE = '23514';
  END IF;

  SELECT count(*), max(assignment.ordinal)
  INTO v_assignment_count, v_assignment_max_ordinal
  FROM public.v3_base_item_version_variable_properties AS assignment
  WHERE assignment.base_item_version_id = p_base_item_version_id;

  -- An empty assignment set is valid; otherwise ordinals define the complete,
  -- deterministic Variable Property resolution order.
  IF v_assignment_count <> 0
     AND v_assignment_max_ordinal <> v_assignment_count - 1 THEN
    RAISE EXCEPTION
      'Base Item Version % must have dense Variable Property assignment ordinals beginning at zero',
      p_base_item_version_id
      USING ERRCODE = '23514';
  END IF;

  FOR v_assignment IN
    SELECT assignment.variable_property_id
    FROM public.v3_base_item_version_variable_properties AS assignment
    WHERE assignment.base_item_version_id = p_base_item_version_id
    ORDER BY assignment.ordinal
  LOOP
    SELECT variable_property.category
    INTO v_variable_property_category
    FROM public.v3_variable_properties AS variable_property
    WHERE variable_property.id = v_assignment.variable_property_id;

    IF v_variable_property_category IS NOT NULL
       AND v_variable_property_category IS DISTINCT FROM v_base_item_category THEN
      RAISE EXCEPTION
        'Variable Property % category is incompatible with Base Item Version %',
        v_assignment.variable_property_id,
        p_base_item_version_id
        USING ERRCODE = '23514';
    END IF;

    PERFORM public.v3_assert_variable_property_selector_integrity(
      v_assignment.variable_property_id
    );
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.v3_validate_base_item_version_variable_property_integrity()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.publication_status = 'published'
     AND (TG_OP = 'INSERT' OR OLD.publication_status IS DISTINCT FROM 'published') THEN
    PERFORM public.v3_assert_base_item_version_variable_property_integrity(NEW.id);
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER v3_base_item_versions_validate_variable_property_integrity
BEFORE INSERT OR UPDATE OF publication_status ON public.v3_base_item_versions
FOR EACH ROW
EXECUTE FUNCTION public.v3_validate_base_item_version_variable_property_integrity();

-- Tighten the 084 committed-row trigger. In addition to the generic candidate
-- identity check, a committed value must use the exact Selector assigned by its
-- Item's exact Base Item Version and preserve its owned value (or explicit None).
CREATE OR REPLACE FUNCTION public.v3_validate_item_property_value_resolution()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_variable_property_id TEXT;
  v_expected_selector_id TEXT;
  v_selector_result_type TEXT;
  v_selector_status TEXT;
  v_candidate_kind TEXT;
  v_candidate_result_id TEXT;
  v_candidate_condition_id TEXT;
  v_candidate_value_property_id TEXT;
BEGIN
  PERFORM public.v3_assert_base_item_version_variable_property_integrity(
    NEW.base_item_version_id
  );

  SELECT
    assignment.variable_property_id,
    variable_property.selector_id,
    selector.result_type,
    selector.status
  INTO
    v_variable_property_id,
    v_expected_selector_id,
    v_selector_result_type,
    v_selector_status
  FROM public.v3_base_item_version_variable_properties AS assignment
  JOIN public.v3_variable_properties AS variable_property
    ON variable_property.id = assignment.variable_property_id
  JOIN public.v3_selectors AS selector
    ON selector.id = variable_property.selector_id
  WHERE assignment.base_item_version_id = NEW.base_item_version_id
    AND assignment.variable_property_id = NEW.variable_property_key;

  IF NOT FOUND
     OR v_selector_result_type IS DISTINCT FROM 'property_value'
     OR v_selector_status IS DISTINCT FROM 'active'
     OR v_expected_selector_id IS DISTINCT FROM NEW.selector_id THEN
    RAISE EXCEPTION
      'Item Property Value must use its exact assigned active property_value Selector'
      USING ERRCODE = '23514';
  END IF;

  SELECT
    candidate.result_kind,
    candidate.result_id,
    candidate.condition_id,
    property_value.variable_property_id
  INTO
    v_candidate_kind,
    v_candidate_result_id,
    v_candidate_condition_id,
    v_candidate_value_property_id
  FROM public.v3_selector_candidates AS candidate
  LEFT JOIN public.v3_property_values AS property_value
    ON property_value.id = candidate.result_id
  WHERE candidate.selector_id = v_expected_selector_id
    AND candidate.id = NEW.selector_candidate_id;

  IF NOT FOUND OR v_candidate_condition_id IS NOT NULL THEN
    RAISE EXCEPTION
      'Item Property Value must use an unconditional candidate of its assigned Selector'
      USING ERRCODE = '23514';
  END IF;

  IF v_candidate_kind = 'none' THEN
    IF NEW.resolution_kind IS DISTINCT FROM 'none'
       OR NEW.resolved_value_id IS NOT NULL THEN
      RAISE EXCEPTION
        'Item Property Value explicit None must preserve its exact Selector candidate result'
        USING ERRCODE = '23514';
    END IF;
  ELSIF v_candidate_kind = 'value' THEN
    IF NEW.resolution_kind IS DISTINCT FROM 'value'
       OR v_candidate_result_id IS DISTINCT FROM NEW.resolved_value_id
       OR v_candidate_value_property_id IS DISTINCT FROM v_variable_property_id THEN
      RAISE EXCEPTION
        'Item Property Value must preserve its exact owned Selector candidate value'
        USING ERRCODE = '23514';
    END IF;
  ELSE
    RAISE EXCEPTION
      'Item Property Value Selector candidate has an invalid result kind'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

-- Fail the migration rather than silently allowing a pre-existing published
-- definition to bypass the publication trigger added above.
DO $assert_published_v3_base_item_version_variable_property_integrity$
DECLARE
  v_base_item_version_id UUID;
BEGIN
  FOR v_base_item_version_id IN
    SELECT id
    FROM public.v3_base_item_versions
    WHERE publication_status IN ('published', 'retired')
  LOOP
    PERFORM public.v3_assert_base_item_version_variable_property_integrity(
      v_base_item_version_id
    );
  END LOOP;
END;
$assert_published_v3_base_item_version_variable_property_integrity$;

REVOKE ALL ON FUNCTION public.v3_assert_dense_selector_candidate_ordinals(TEXT)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_assert_variable_property_selector_integrity(TEXT)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_assert_base_item_version_variable_property_integrity(UUID)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_validate_base_item_version_variable_property_integrity()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_validate_item_property_value_resolution()
  FROM PUBLIC, anon, authenticated;
