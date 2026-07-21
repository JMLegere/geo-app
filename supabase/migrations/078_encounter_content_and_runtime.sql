-- Migration 078: authored Encounter content and player-owned Encounter runtime.
--
-- This migration is additive. It preserves legacy Items, Cell Visits, geometry,
-- and all pre-v3 data while adding version-bound content and runtime evidence.

CREATE TABLE IF NOT EXISTS public.v3_variable_properties (
  id TEXT PRIMARY KEY CHECK (btrim(id) <> ''),
  display_name TEXT NOT NULL CHECK (btrim(display_name) <> ''),
  category TEXT CHECK (category IN ( 'fauna', 'flora', 'mineral', 'fossil', 'artifact', 'food', 'orb' )),
  selector_id TEXT NOT NULL REFERENCES public.v3_selectors(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.v3_property_values (
  id TEXT PRIMARY KEY CHECK (btrim(id) <> ''),
  variable_property_id TEXT NOT NULL REFERENCES public.v3_variable_properties(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  display_name TEXT NOT NULL CHECK (btrim(display_name) <> ''),
  value_data JSONB NOT NULL DEFAULT '{}'::jsonb
    CHECK (jsonb_typeof(value_data) = 'object'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_v3_property_values_variable_property
  ON public.v3_property_values(variable_property_id);

CREATE OR REPLACE FUNCTION public.v3_validate_variable_property_selector()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_result_type TEXT;
BEGIN
  SELECT result_type
  INTO v_result_type
  FROM public.v3_selectors
  WHERE id = NEW.selector_id;

  IF v_result_type IS DISTINCT FROM 'property_value' THEN
    RAISE EXCEPTION 'Variable Property Selector % must return property_value', NEW.selector_id
      USING ERRCODE = '23514';
  END IF;

  PERFORM public.v3_assert_selector_has_candidates(NEW.selector_id);

  IF EXISTS (
    SELECT 1
    FROM public.v3_selector_candidates candidate
    LEFT JOIN public.v3_property_values property_value
      ON property_value.id = candidate.result_id
    WHERE candidate.selector_id = NEW.selector_id
      AND candidate.result_kind = 'value'
      AND property_value.variable_property_id IS DISTINCT FROM NEW.id
  ) THEN
    RAISE EXCEPTION 'Variable Property Selector % has a value outside Variable Property %',
      NEW.selector_id,
      NEW.id
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

CREATE CONSTRAINT TRIGGER v3_variable_properties_validate_selector
AFTER INSERT OR UPDATE OF selector_id ON public.v3_variable_properties
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.v3_validate_variable_property_selector();

CREATE OR REPLACE FUNCTION public.v3_prevent_variable_property_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'v3_variable_properties are immutable';
END;
$$;

CREATE TRIGGER v3_variable_properties_immutable
BEFORE UPDATE OR DELETE ON public.v3_variable_properties
FOR EACH ROW
EXECUTE FUNCTION public.v3_prevent_variable_property_mutation();

CREATE OR REPLACE FUNCTION public.v3_prevent_property_value_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'v3_property_values are immutable';
END;
$$;

CREATE TRIGGER v3_property_values_immutable
BEFORE UPDATE OR DELETE ON public.v3_property_values
FOR EACH ROW
EXECUTE FUNCTION public.v3_prevent_property_value_mutation();

CREATE TABLE IF NOT EXISTS public.v3_base_item_version_variable_properties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  base_item_version_id UUID NOT NULL REFERENCES public.v3_base_item_versions(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  variable_property_id TEXT NOT NULL REFERENCES public.v3_variable_properties(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (base_item_version_id, variable_property_id),
  UNIQUE (base_item_version_id, ordinal)
);


CREATE OR REPLACE FUNCTION public.v3_require_draft_base_item_version_variable_property()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_has_published_version BOOLEAN;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT COALESCE(BOOL_OR(published_at IS NOT NULL), FALSE)
    INTO v_has_published_version
    FROM public.v3_base_item_versions
    WHERE id = NEW.base_item_version_id;
  ELSIF TG_OP = 'DELETE' THEN
    SELECT COALESCE(BOOL_OR(published_at IS NOT NULL), FALSE)
    INTO v_has_published_version
    FROM public.v3_base_item_versions
    WHERE id = OLD.base_item_version_id;
  ELSE
    SELECT COALESCE(BOOL_OR(published_at IS NOT NULL), FALSE)
    INTO v_has_published_version
    FROM public.v3_base_item_versions
    WHERE id = OLD.base_item_version_id
       OR id = NEW.base_item_version_id;
  END IF;

  IF v_has_published_version THEN
    RAISE EXCEPTION 'Published Base Item Version Variable Properties are immutable';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER v3_base_item_version_variable_properties_require_draft_version
BEFORE INSERT OR UPDATE OR DELETE ON public.v3_base_item_version_variable_properties
FOR EACH ROW
EXECUTE FUNCTION public.v3_require_draft_base_item_version_variable_property();

CREATE TABLE IF NOT EXISTS public.v3_encounter_definitions (
  id TEXT PRIMARY KEY CHECK (btrim(id) <> ''),
  current_published_version_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.v3_encounter_definition_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  encounter_definition_id TEXT NOT NULL REFERENCES public.v3_encounter_definitions(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  revision INTEGER NOT NULL CHECK (revision > 0),
  publication_status TEXT NOT NULL DEFAULT 'draft' CHECK (
    publication_status IN ('draft', 'published', 'retired')
  ),
  published_at TIMESTAMPTZ,
  retired_at TIMESTAMPTZ,
  display_name TEXT NOT NULL CHECK (btrim(display_name) <> ''),
  eligibility_condition_id TEXT REFERENCES public.v3_conditions(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  is_automatic BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (encounter_definition_id, revision),
  UNIQUE (encounter_definition_id, id),
  CHECK (
    (publication_status = 'draft' AND published_at IS NULL AND retired_at IS NULL)
    OR (publication_status = 'published' AND published_at IS NOT NULL AND retired_at IS NULL)
    OR (publication_status = 'retired' AND published_at IS NOT NULL AND retired_at IS NOT NULL)
  )
);

DO $add_current_published_encounter_version_owner_fk$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'v3_encounter_definitions_current_published_version_owner_fk'
      AND conrelid = 'public.v3_encounter_definitions'::regclass
  ) THEN
    ALTER TABLE public.v3_encounter_definitions
      ADD CONSTRAINT v3_encounter_definitions_current_published_version_owner_fk
      FOREIGN KEY (id, current_published_version_id)
      REFERENCES public.v3_encounter_definition_versions(encounter_definition_id, id)
      DEFERRABLE INITIALLY DEFERRED;
  END IF;
END;
$add_current_published_encounter_version_owner_fk$;

CREATE INDEX IF NOT EXISTS idx_v3_encounter_definitions_current_published_version
  ON public.v3_encounter_definitions(current_published_version_id)
  WHERE current_published_version_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_v3_encounter_definition_versions_definition_publication
  ON public.v3_encounter_definition_versions(
    encounter_definition_id,
    publication_status,
    revision DESC
  );

CREATE TABLE IF NOT EXISTS public.v3_encounter_options (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  encounter_definition_version_id UUID NOT NULL
    REFERENCES public.v3_encounter_definition_versions(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
  display_name TEXT NOT NULL CHECK (btrim(display_name) <> ''),
  condition_id TEXT REFERENCES public.v3_conditions(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  is_implicit BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (encounter_definition_version_id, id),
  UNIQUE (encounter_definition_version_id, ordinal)
);

CREATE INDEX IF NOT EXISTS idx_v3_encounter_options_condition
  ON public.v3_encounter_options(condition_id)
  WHERE condition_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.v3_encounter_payload_contains_executable_key(
  p_value JSONB
)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  v_child JSONB;
BEGIN
  CASE jsonb_typeof(p_value)
    WHEN 'object' THEN
      IF p_value ?| ARRAY['script', 'code', 'function', 'expression'] THEN
        RETURN true;
      END IF;
      FOR v_child IN SELECT value FROM jsonb_each(p_value)
      LOOP
        IF public.v3_encounter_payload_contains_executable_key(v_child) THEN
          RETURN true;
        END IF;
      END LOOP;
    WHEN 'array' THEN
      FOR v_child IN SELECT value FROM jsonb_array_elements(p_value)
      LOOP
        IF public.v3_encounter_payload_contains_executable_key(v_child) THEN
          RETURN true;
        END IF;
      END LOOP;
    ELSE
      NULL;
  END CASE;

  RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public.v3_validate_encounter_outcome_payload(
  p_kind TEXT,
  p_payload JSONB
)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
BEGIN
  IF jsonb_typeof(p_payload) <> 'object'
     OR public.v3_encounter_payload_contains_executable_key(p_payload) THEN
    RETURN false;
  END IF;

  IF p_kind = 'generate_item' THEN
    RETURN (p_payload - 'base_item_id') = '{}'::jsonb
      AND p_payload ? 'base_item_id'
      AND jsonb_typeof(p_payload -> 'base_item_id') = 'string'
      AND btrim(p_payload ->> 'base_item_id') <> '';
  END IF;

  IF p_kind = 'reveal_venue' THEN
    RETURN (p_payload - 'venue_id') = '{}'::jsonb
      AND p_payload ? 'venue_id'
      AND jsonb_typeof(p_payload -> 'venue_id') = 'string'
      AND btrim(p_payload ->> 'venue_id') <> '';
  END IF;

  RETURN false;
END;
$$;

CREATE TABLE IF NOT EXISTS public.v3_encounter_outcomes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  encounter_option_id UUID NOT NULL REFERENCES public.v3_encounter_options(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
  kind TEXT NOT NULL CHECK (kind IN ('generate_item', 'reveal_venue')),
  payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (encounter_option_id, id),
  UNIQUE (encounter_option_id, ordinal),
  CHECK (public.v3_validate_encounter_outcome_payload(kind, payload))
);

CREATE INDEX IF NOT EXISTS idx_v3_encounter_outcomes_option_ordinal
  ON public.v3_encounter_outcomes(encounter_option_id, ordinal);

CREATE OR REPLACE FUNCTION public.v3_validate_encounter_outcome_base_item()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.kind = 'generate_item' AND NOT EXISTS (
    SELECT 1
    FROM public.v3_base_items
    WHERE id = NEW.payload ->> 'base_item_id'
  ) THEN
    RAISE EXCEPTION 'Generate Item Outcome must reference an existing Base Item %',
      NEW.payload ->> 'base_item_id'
      USING ERRCODE = '23503';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER v3_encounter_outcomes_validate_base_item
BEFORE INSERT OR UPDATE OF kind, payload ON public.v3_encounter_outcomes
FOR EACH ROW
EXECUTE FUNCTION public.v3_validate_encounter_outcome_base_item();

CREATE OR REPLACE FUNCTION public.v3_validate_automatic_encounter_options(
  p_version_id UUID,
  p_require_options BOOLEAN DEFAULT FALSE
)
RETURNS VOID
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_is_automatic BOOLEAN;
  v_publication_status TEXT;
  v_option_count INTEGER;
  v_implicit_count INTEGER;
BEGIN
  SELECT is_automatic, publication_status
  INTO v_is_automatic, v_publication_status
  FROM public.v3_encounter_definition_versions
  WHERE id = p_version_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF NOT p_require_options AND v_publication_status = 'draft' THEN
    RETURN;
  END IF;

  SELECT COUNT(*), COUNT(*) FILTER (WHERE is_implicit)
  INTO v_option_count, v_implicit_count
  FROM public.v3_encounter_options
  WHERE encounter_definition_version_id = p_version_id;

  IF v_option_count < 1 THEN
    RAISE EXCEPTION 'Encounter Definition Version % must have at least one Option', p_version_id
      USING ERRCODE = '23514';
  END IF;

  IF v_is_automatic AND (v_option_count <> 1 OR v_implicit_count <> 1) THEN
    RAISE EXCEPTION 'Automatic Encounter Definition Version % requires exactly one implicit Option',
      p_version_id
      USING ERRCODE = '23514';
  END IF;

  IF NOT v_is_automatic AND v_implicit_count <> 0 THEN
    RAISE EXCEPTION 'Only automatic Encounter Definition Versions may have implicit Options'
      USING ERRCODE = '23514';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.v3_validate_encounter_definition_version_options()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  PERFORM public.v3_validate_automatic_encounter_options(NEW.id);
  RETURN NEW;
END;
$$;

CREATE CONSTRAINT TRIGGER v3_encounter_definition_versions_validate_options
AFTER INSERT OR UPDATE OF publication_status, is_automatic
ON public.v3_encounter_definition_versions
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.v3_validate_encounter_definition_version_options();

CREATE OR REPLACE FUNCTION public.v3_validate_encounter_option_structure()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_version_id UUID;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_version_id := OLD.encounter_definition_version_id;
  ELSE
    v_version_id := NEW.encounter_definition_version_id;
  END IF;

  PERFORM public.v3_validate_automatic_encounter_options(v_version_id);

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

CREATE CONSTRAINT TRIGGER v3_encounter_options_validate_structure
AFTER INSERT OR UPDATE OR DELETE ON public.v3_encounter_options
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.v3_validate_encounter_option_structure();

CREATE OR REPLACE FUNCTION public.v3_require_draft_encounter_option()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_has_published_version BOOLEAN;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT COALESCE(BOOL_OR(version.published_at IS NOT NULL), FALSE)
    INTO v_has_published_version
    FROM public.v3_encounter_definition_versions version
    WHERE version.id = NEW.encounter_definition_version_id;
  ELSIF TG_OP = 'DELETE' THEN
    SELECT COALESCE(BOOL_OR(version.published_at IS NOT NULL), FALSE)
    INTO v_has_published_version
    FROM public.v3_encounter_definition_versions version
    WHERE version.id = OLD.encounter_definition_version_id;
  ELSE
    SELECT COALESCE(BOOL_OR(version.published_at IS NOT NULL), FALSE)
    INTO v_has_published_version
    FROM public.v3_encounter_definition_versions version
    WHERE version.id = OLD.encounter_definition_version_id
       OR version.id = NEW.encounter_definition_version_id;
  END IF;

  IF v_has_published_version THEN
    RAISE EXCEPTION 'Published Encounter Definition Version Options are immutable';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER v3_encounter_options_require_draft_version
BEFORE INSERT OR UPDATE OR DELETE ON public.v3_encounter_options
FOR EACH ROW
EXECUTE FUNCTION public.v3_require_draft_encounter_option();

CREATE OR REPLACE FUNCTION public.v3_require_draft_encounter_outcome()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_has_published_version BOOLEAN;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT COALESCE(BOOL_OR(version.published_at IS NOT NULL), FALSE)
    INTO v_has_published_version
    FROM public.v3_encounter_options option
    JOIN public.v3_encounter_definition_versions version
      ON version.id = option.encounter_definition_version_id
    WHERE option.id = NEW.encounter_option_id;
  ELSIF TG_OP = 'DELETE' THEN
    SELECT COALESCE(BOOL_OR(version.published_at IS NOT NULL), FALSE)
    INTO v_has_published_version
    FROM public.v3_encounter_options option
    JOIN public.v3_encounter_definition_versions version
      ON version.id = option.encounter_definition_version_id
    WHERE option.id = OLD.encounter_option_id;
  ELSE
    SELECT COALESCE(BOOL_OR(version.published_at IS NOT NULL), FALSE)
    INTO v_has_published_version
    FROM public.v3_encounter_options option
    JOIN public.v3_encounter_definition_versions version
      ON version.id = option.encounter_definition_version_id
    WHERE option.id = OLD.encounter_option_id
       OR option.id = NEW.encounter_option_id;
  END IF;

  IF v_has_published_version THEN
    RAISE EXCEPTION 'Published Encounter Definition Version Outcomes are immutable';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER v3_encounter_outcomes_require_draft_version
BEFORE INSERT OR UPDATE OR DELETE ON public.v3_encounter_outcomes
FOR EACH ROW
EXECUTE FUNCTION public.v3_require_draft_encounter_outcome();

CREATE OR REPLACE FUNCTION public.publish_v3_encounter_definition_version(
  p_encounter_definition_id TEXT,
  p_version_id UUID
)
RETURNS public.v3_encounter_definition_versions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_definition public.v3_encounter_definitions%ROWTYPE;
  v_candidate_version public.v3_encounter_definition_versions%ROWTYPE;
  v_published_version public.v3_encounter_definition_versions%ROWTYPE;
BEGIN
  SELECT *
  INTO v_definition
  FROM public.v3_encounter_definitions
  WHERE id = p_encounter_definition_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unknown Encounter Definition %', p_encounter_definition_id;
  END IF;

  SELECT *
  INTO v_candidate_version
  FROM public.v3_encounter_definition_versions
  WHERE id = p_version_id
    AND encounter_definition_id = p_encounter_definition_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Encounter Definition Version % does not belong to Encounter Definition %',
      p_version_id,
      p_encounter_definition_id;
  END IF;

  IF v_candidate_version.publication_status <> 'draft' THEN
    RAISE EXCEPTION 'Only draft Encounter Definition Versions may be published';
  END IF;

  PERFORM public.v3_validate_automatic_encounter_options(p_version_id, TRUE);

  UPDATE public.v3_encounter_definition_versions
  SET publication_status = 'retired',
      retired_at = now(),
      updated_at = now()
  WHERE encounter_definition_id = p_encounter_definition_id
    AND publication_status = 'published';

  UPDATE public.v3_encounter_definition_versions
  SET publication_status = 'published',
      published_at = now(),
      retired_at = NULL,
      updated_at = now()
  WHERE id = p_version_id
  RETURNING * INTO v_published_version;

  UPDATE public.v3_encounter_definitions
  SET current_published_version_id = p_version_id,
      updated_at = now()
  WHERE id = p_encounter_definition_id;

  RETURN v_published_version;
END;
$$;

REVOKE ALL ON FUNCTION public.publish_v3_encounter_definition_version(TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.publish_v3_encounter_definition_version(TEXT, UUID) TO service_role;

CREATE OR REPLACE FUNCTION public.prevent_published_v3_encounter_definition_version_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF OLD.published_at IS NULL THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'DELETE'
    OR NEW.id IS DISTINCT FROM OLD.id
    OR NEW.encounter_definition_id IS DISTINCT FROM OLD.encounter_definition_id
    OR NEW.revision IS DISTINCT FROM OLD.revision
    OR NEW.display_name IS DISTINCT FROM OLD.display_name
    OR NEW.eligibility_condition_id IS DISTINCT FROM OLD.eligibility_condition_id
    OR NEW.is_automatic IS DISTINCT FROM OLD.is_automatic
    OR NEW.published_at IS DISTINCT FROM OLD.published_at
    OR (OLD.publication_status = 'published'
      AND NEW.publication_status NOT IN ('published', 'retired'))
    OR (OLD.publication_status = 'retired'
      AND NEW.publication_status <> 'retired')
    OR (OLD.publication_status = 'retired'
      AND NEW.retired_at IS DISTINCT FROM OLD.retired_at) THEN
    RAISE EXCEPTION 'Published Encounter Definition Versions are immutable';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER v3_encounter_definition_versions_prevent_published_content_mutation
BEFORE UPDATE OR DELETE ON public.v3_encounter_definition_versions
FOR EACH ROW
EXECUTE FUNCTION public.prevent_published_v3_encounter_definition_version_mutation();

CREATE OR REPLACE FUNCTION public.prevent_v3_encounter_definition_identity_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' OR NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'Encounter Definition identity is immutable';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER v3_encounter_definitions_prevent_identity_mutation
BEFORE UPDATE OR DELETE ON public.v3_encounter_definitions
FOR EACH ROW
EXECUTE FUNCTION public.prevent_v3_encounter_definition_identity_mutation();

CREATE TABLE IF NOT EXISTS public.v3_cell_visit_resolutions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cell_visit_id UUID NOT NULL UNIQUE REFERENCES public.v3_cell_visits(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  selector_id TEXT NOT NULL REFERENCES public.v3_selectors(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  selector_candidate_id UUID NOT NULL REFERENCES public.v3_selector_candidates(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  resolution_kind TEXT NOT NULL CHECK (resolution_kind IN ('none', 'encounter')),
  encounter_definition_id TEXT REFERENCES public.v3_encounter_definitions(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  resolved_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (cell_visit_id, id),
  CHECK (
    (resolution_kind = 'none' AND encounter_definition_id IS NULL)
    OR (resolution_kind = 'encounter' AND encounter_definition_id IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_v3_cell_visit_resolutions_selector
  ON public.v3_cell_visit_resolutions(selector_id);

CREATE OR REPLACE FUNCTION public.v3_validate_cell_visit_resolution()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_result_type TEXT;
  v_result_kind TEXT;
  v_result_id TEXT;
BEGIN
  SELECT selector.result_type, candidate.result_kind, candidate.result_id
  INTO v_result_type, v_result_kind, v_result_id
  FROM public.v3_selector_candidates candidate
  JOIN public.v3_selectors selector ON selector.id = candidate.selector_id
  WHERE candidate.id = NEW.selector_candidate_id
    AND candidate.selector_id = NEW.selector_id;

  IF NOT FOUND OR v_result_type <> 'encounter_definition' THEN
    RAISE EXCEPTION 'Cell Visit Resolution must use an encounter_definition Selector candidate'
      USING ERRCODE = '23514';
  END IF;

  IF (NEW.resolution_kind = 'none' AND v_result_kind <> 'none')
     OR (NEW.resolution_kind = 'encounter'
       AND (v_result_kind <> 'value' OR v_result_id IS DISTINCT FROM NEW.encounter_definition_id)) THEN
    RAISE EXCEPTION 'Cell Visit Resolution must match its selected Selector Candidate'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER v3_cell_visit_resolutions_validate_selected_candidate
BEFORE INSERT OR UPDATE OF selector_id, selector_candidate_id, resolution_kind, encounter_definition_id
ON public.v3_cell_visit_resolutions
FOR EACH ROW
EXECUTE FUNCTION public.v3_validate_cell_visit_resolution();

CREATE OR REPLACE FUNCTION public.v3_prevent_cell_visit_resolution_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'v3_cell_visit_resolutions are immutable';
END;
$$;

CREATE TRIGGER v3_cell_visit_resolutions_immutable
BEFORE UPDATE OR DELETE ON public.v3_cell_visit_resolutions
FOR EACH ROW
EXECUTE FUNCTION public.v3_prevent_cell_visit_resolution_mutation();

CREATE TABLE IF NOT EXISTS public.v3_encounters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cell_visit_id UUID NOT NULL UNIQUE,
  cell_visit_resolution_id UUID NOT NULL UNIQUE,
  encounter_definition_id TEXT NOT NULL,
  encounter_definition_version_id UUID NOT NULL,
  selected_option_id UUID,
  resolution_status TEXT NOT NULL DEFAULT 'pending' CHECK (
    resolution_status IN ('pending', 'resolved', 'failed')
  ),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ,
  failure_code TEXT CHECK (failure_code IS NULL OR btrim(failure_code) <> ''),
  failure_details JSONB CHECK (
    failure_details IS NULL OR jsonb_typeof(failure_details) = 'object'
  ),
  FOREIGN KEY (cell_visit_id, cell_visit_resolution_id)
    REFERENCES public.v3_cell_visit_resolutions(cell_visit_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  FOREIGN KEY (encounter_definition_id, encounter_definition_version_id)
    REFERENCES public.v3_encounter_definition_versions(encounter_definition_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  FOREIGN KEY (encounter_definition_version_id, selected_option_id)
    REFERENCES public.v3_encounter_options(encounter_definition_version_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CHECK (
    (resolution_status = 'pending'
      AND selected_option_id IS NULL
      AND resolved_at IS NULL
      AND failure_code IS NULL
      AND failure_details IS NULL)
    OR (resolution_status = 'resolved'
      AND selected_option_id IS NOT NULL
      AND resolved_at IS NOT NULL
      AND failure_code IS NULL
      AND failure_details IS NULL)
    OR (resolution_status = 'failed'
      AND resolved_at IS NULL
      AND failure_code IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_v3_encounters_definition_version
  ON public.v3_encounters(encounter_definition_id, encounter_definition_version_id);

CREATE OR REPLACE FUNCTION public.v3_validate_encounter_binding()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_resolution_definition_id TEXT;
  v_current_version_id UUID;
BEGIN
  SELECT resolution.encounter_definition_id,
         definition.current_published_version_id
  INTO v_resolution_definition_id, v_current_version_id
  FROM public.v3_cell_visit_resolutions resolution
  JOIN public.v3_encounter_definitions definition
    ON definition.id = resolution.encounter_definition_id
  WHERE resolution.id = NEW.cell_visit_resolution_id
    AND resolution.cell_visit_id = NEW.cell_visit_id
    AND resolution.resolution_kind = 'encounter';

  IF NOT FOUND
     OR v_resolution_definition_id IS DISTINCT FROM NEW.encounter_definition_id
     OR v_current_version_id IS DISTINCT FROM NEW.encounter_definition_version_id THEN
    RAISE EXCEPTION 'Encounter must bind the Cell Visit selected Definition current published Version'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER v3_encounters_validate_version_binding
BEFORE INSERT OR UPDATE OF cell_visit_id, cell_visit_resolution_id,
  encounter_definition_id, encounter_definition_version_id
ON public.v3_encounters
FOR EACH ROW
EXECUTE FUNCTION public.v3_validate_encounter_binding();

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

  RETURN NEW;
END;
$$;

CREATE TRIGGER v3_encounters_limit_identity_mutation
BEFORE UPDATE OR DELETE ON public.v3_encounters
FOR EACH ROW
EXECUTE FUNCTION public.v3_limit_encounter_mutation();

CREATE TABLE IF NOT EXISTS public.v3_encounter_outcome_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  encounter_id UUID NOT NULL REFERENCES public.v3_encounters(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  outcome_ordinal INTEGER NOT NULL CHECK (outcome_ordinal >= 0),
  encounter_outcome_id UUID NOT NULL REFERENCES public.v3_encounter_outcomes(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  outcome_kind TEXT NOT NULL CHECK (outcome_kind IN ('generate_item', 'reveal_venue')),
  resolved_base_item_version_id UUID REFERENCES public.v3_base_item_versions(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (encounter_id, outcome_ordinal),
  UNIQUE (encounter_id, encounter_outcome_id),
  CHECK (
    (outcome_kind = 'generate_item' AND resolved_base_item_version_id IS NOT NULL)
    OR (outcome_kind = 'reveal_venue' AND resolved_base_item_version_id IS NULL)
  )
);

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
BEGIN
  SELECT selected_option_id
  INTO v_selected_option_id
  FROM public.v3_encounters
  WHERE id = NEW.encounter_id;

  SELECT ordinal, kind, payload ->> 'base_item_id'
  INTO v_outcome_ordinal, v_outcome_kind, v_outcome_base_item_id
  FROM public.v3_encounter_outcomes
  WHERE id = NEW.encounter_outcome_id
    AND encounter_option_id = v_selected_option_id;

  IF v_selected_option_id IS NULL
     OR NOT FOUND
     OR v_outcome_ordinal <> NEW.outcome_ordinal
     OR v_outcome_kind <> NEW.outcome_kind THEN
    RAISE EXCEPTION 'Encounter Outcome Result must match the Encounter selected Option ordered Outcome'
      USING ERRCODE = '23514';
  END IF;

  IF NEW.outcome_kind = 'generate_item' THEN
    SELECT base_item_id
    INTO v_resolved_base_item_id
    FROM public.v3_base_item_versions
    WHERE id = NEW.resolved_base_item_version_id;

    IF v_resolved_base_item_id IS DISTINCT FROM v_outcome_base_item_id THEN
      RAISE EXCEPTION 'Generate Item Outcome Result must preserve the selected Base Item Version'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER v3_encounter_outcome_results_validate_binding
BEFORE INSERT OR UPDATE OF encounter_id, outcome_ordinal, encounter_outcome_id,
  outcome_kind, resolved_base_item_version_id
ON public.v3_encounter_outcome_results
FOR EACH ROW
EXECUTE FUNCTION public.v3_validate_encounter_outcome_result();

CREATE OR REPLACE FUNCTION public.v3_prevent_encounter_outcome_result_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'v3_encounter_outcome_results are immutable';
END;
$$;

CREATE TRIGGER v3_encounter_outcome_results_immutable
BEFORE UPDATE OR DELETE ON public.v3_encounter_outcome_results
FOR EACH ROW
EXECUTE FUNCTION public.v3_prevent_encounter_outcome_result_mutation();

ALTER TABLE public.v3_variable_properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_property_values ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_base_item_version_variable_properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_encounter_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_encounter_definition_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_encounter_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_encounter_outcomes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_cell_visit_resolutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_encounters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_encounter_outcome_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "v3_variable_properties_authenticated_read"
  ON public.v3_variable_properties
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "v3_property_values_authenticated_read"
  ON public.v3_property_values
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "v3_base_item_version_variable_properties_authenticated_read"
  ON public.v3_base_item_version_variable_properties
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.v3_base_item_versions version
      WHERE version.id = base_item_version_id
        AND version.publication_status IN ('published', 'retired')
    )
  );

CREATE POLICY "v3_encounter_definitions_authenticated_read"
  ON public.v3_encounter_definitions
  FOR SELECT TO authenticated
  USING (current_published_version_id IS NOT NULL);

CREATE POLICY "v3_encounter_definition_versions_authenticated_read"
  ON public.v3_encounter_definition_versions
  FOR SELECT TO authenticated
  USING (publication_status IN ('published', 'retired'));

CREATE POLICY "v3_encounter_options_authenticated_read"
  ON public.v3_encounter_options
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.v3_encounter_definition_versions version
      WHERE version.id = encounter_definition_version_id
        AND version.publication_status IN ('published', 'retired')
    )
  );

CREATE POLICY "v3_encounter_outcomes_authenticated_read"
  ON public.v3_encounter_outcomes
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.v3_encounter_options option
      JOIN public.v3_encounter_definition_versions version
        ON version.id = option.encounter_definition_version_id
      WHERE option.id = encounter_option_id
        AND version.publication_status IN ('published', 'retired')
    )
  );

CREATE POLICY "v3_cell_visit_resolutions_select_own"
  ON public.v3_cell_visit_resolutions
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.v3_cell_visits cell_visit
      WHERE cell_visit.id = cell_visit_id
        AND cell_visit.user_id = auth.uid()
    )
  );

CREATE POLICY "v3_encounters_select_own"
  ON public.v3_encounters
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.v3_cell_visits cell_visit
      WHERE cell_visit.id = cell_visit_id
        AND cell_visit.user_id = auth.uid()
    )
  );

CREATE POLICY "v3_encounter_outcome_results_select_own"
  ON public.v3_encounter_outcome_results
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.v3_encounters encounter
      JOIN public.v3_cell_visits cell_visit ON cell_visit.id = encounter.cell_visit_id
      WHERE encounter.id = encounter_id
        AND cell_visit.user_id = auth.uid()
    )
  );

COMMENT ON TABLE public.v3_encounter_definitions IS
  'Stable authored Encounter identities. Selector candidates name this identity; occurrence creation binds its then-current published Version.';

COMMENT ON TABLE public.v3_encounter_definition_versions IS
  'Immutable Encounter content Versions. Publishing affects future occurrences without changing an existing Encounter.';

COMMENT ON TABLE public.v3_cell_visit_resolutions IS
  'One explicit Selector resolution per Cell Visit: a selected None candidate or a selected stable Encounter Definition candidate.';

COMMENT ON TABLE public.v3_encounters IS
  'A player-owned Encounter occurrence bound permanently to the selected immutable Encounter Definition Version.';
