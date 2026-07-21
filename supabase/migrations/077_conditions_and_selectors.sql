-- Migration 077: reusable, immutable Conditions and generalized Selectors.
-- These v3 tables are additive and deliberately do not alter legacy exploration,
-- player, geometry, Item, or Cell Visit records.
--
-- The Condition AST is data only. Its leaves are typed predicates, while concrete
-- leaf kinds are approved separately as product rules become explicit; this
-- migration deliberately provides no executable-code escape hatch.

CREATE OR REPLACE FUNCTION public.v3_condition_ast_contains_executable_key(
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
        IF public.v3_condition_ast_contains_executable_key(v_child) THEN
          RETURN true;
        END IF;
      END LOOP;
    WHEN 'array' THEN
      FOR v_child IN SELECT value FROM jsonb_array_elements(p_value)
      LOOP
        IF public.v3_condition_ast_contains_executable_key(v_child) THEN
          RETURN true;
        END IF;
      END LOOP;
    ELSE
      NULL;
  END CASE;

  RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public.v3_validate_condition_ast(p_node JSONB)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  v_kind TEXT;
  v_child JSONB;
BEGIN
  IF jsonb_typeof(p_node) <> 'object'
     OR public.v3_condition_ast_contains_executable_key(p_node) THEN
    RETURN false;
  END IF;

  v_kind := p_node ->> 'kind';
  IF v_kind NOT IN ('all', 'any', 'not', 'leaf') THEN
    RETURN false;
  END IF;

  IF v_kind IN ('all', 'any') THEN
    IF jsonb_typeof(p_node -> 'children') <> 'array'
       OR jsonb_array_length(p_node -> 'children') = 0 THEN
      RETURN false;
    END IF;

    FOR v_child IN
      SELECT value FROM jsonb_array_elements(p_node -> 'children')
    LOOP
      IF NOT public.v3_validate_condition_ast(v_child) THEN
        RETURN false;
      END IF;
    END LOOP;

    RETURN true;
  END IF;

  IF v_kind = 'not' THEN
    RETURN jsonb_typeof(p_node -> 'child') = 'object'
      AND public.v3_validate_condition_ast(p_node -> 'child');
  END IF;

  RETURN jsonb_typeof(p_node -> 'leaf_kind') = 'string'
    AND btrim(p_node ->> 'leaf_kind') <> ''
    AND jsonb_typeof(p_node -> 'payload') = 'object';
END;
$$;

CREATE TABLE IF NOT EXISTS public.v3_conditions (
  id TEXT PRIMARY KEY CHECK (btrim(id) <> ''),
  condition_schema_version INTEGER NOT NULL CHECK (condition_schema_version > 0),
  condition_ast JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT v3_conditions_top_level_ast_check CHECK (
    jsonb_typeof(condition_ast) = 'object'
    AND condition_ast ? 'kind'
    AND condition_ast ->> 'kind' IN ('all', 'any', 'not', 'leaf')
    AND public.v3_validate_condition_ast(condition_ast)
  )
);

CREATE TABLE IF NOT EXISTS public.v3_selectors (
  id TEXT PRIMARY KEY CHECK (btrim(id) <> ''),
  result_type TEXT NOT NULL CHECK (btrim(result_type) <> ''),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.v3_selector_candidates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  selector_id TEXT NOT NULL REFERENCES public.v3_selectors(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
  weight NUMERIC NOT NULL CHECK (
    weight > 0
    AND weight::TEXT NOT IN ('NaN', 'Infinity', '-Infinity')
  ),
  condition_id TEXT REFERENCES public.v3_conditions(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  result_kind TEXT NOT NULL CHECK (result_kind IN ('value', 'none')),
  result_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT v3_selector_candidates_result_check CHECK (
    (result_kind = 'none' AND result_id IS NULL)
      OR (
        result_kind = 'value'
        AND btrim(COALESCE(result_id, '')) <> ''
      )
  ),
  UNIQUE (selector_id, ordinal)
);

CREATE INDEX IF NOT EXISTS idx_v3_selectors_result_type_status
  ON public.v3_selectors(result_type, status);

CREATE INDEX IF NOT EXISTS idx_v3_selector_candidates_selector_ordinal
  ON public.v3_selector_candidates(selector_id, ordinal);

CREATE INDEX IF NOT EXISTS idx_v3_selector_candidates_condition
  ON public.v3_selector_candidates(condition_id)
  WHERE condition_id IS NOT NULL;

-- Owning immutable versions call this function when they reference a Selector.
-- A polymorphic result_id is resolved by that owner, rather than by specialized
-- selector tables or a foreign key to a future content table.
CREATE OR REPLACE FUNCTION public.v3_assert_selector_has_candidates(
  p_selector_id TEXT
)
RETURNS VOID
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.v3_selector_candidates
    WHERE selector_id = p_selector_id
  ) THEN
    RAISE EXCEPTION 'Selector % must have at least one candidate', p_selector_id
      USING ERRCODE = '23514';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.v3_validate_selector_activation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'active' THEN
    PERFORM public.v3_assert_selector_has_candidates(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

CREATE CONSTRAINT TRIGGER v3_selectors_require_candidates
AFTER INSERT OR UPDATE OF status ON public.v3_selectors
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.v3_validate_selector_activation();

CREATE OR REPLACE FUNCTION public.v3_prevent_condition_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'v3_conditions are immutable';
END;
$$;

CREATE TRIGGER v3_conditions_immutable
BEFORE UPDATE OR DELETE ON public.v3_conditions
FOR EACH ROW
EXECUTE FUNCTION public.v3_prevent_condition_mutation();

CREATE OR REPLACE FUNCTION public.v3_prevent_selector_candidate_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'v3_selector_candidates are immutable';
END;
$$;

CREATE TRIGGER v3_selector_candidates_immutable
BEFORE UPDATE OR DELETE ON public.v3_selector_candidates
FOR EACH ROW
EXECUTE FUNCTION public.v3_prevent_selector_candidate_mutation();

CREATE OR REPLACE FUNCTION public.v3_require_draft_selector_candidate()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_status TEXT;
BEGIN
  SELECT status
  INTO v_status
  FROM public.v3_selectors
  WHERE id = NEW.selector_id;

  IF v_status IS DISTINCT FROM 'draft' THEN
    RAISE EXCEPTION 'Candidates can only be added to a draft Selector';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER v3_selector_candidates_require_draft_selector
BEFORE INSERT ON public.v3_selector_candidates
FOR EACH ROW
EXECUTE FUNCTION public.v3_require_draft_selector_candidate();

CREATE OR REPLACE FUNCTION public.v3_limit_selector_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'v3_selectors are immutable';
  END IF;

  IF OLD.id IS DISTINCT FROM NEW.id
     OR OLD.result_type IS DISTINCT FROM NEW.result_type
     OR OLD.created_at IS DISTINCT FROM NEW.created_at THEN
    RAISE EXCEPTION 'A Selector identity is immutable';
  END IF;

  IF OLD.status = 'draft' AND NEW.status IN ('draft', 'active') THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'An active Selector cannot be changed';
END;
$$;

CREATE TRIGGER v3_selectors_immutable
BEFORE UPDATE OR DELETE ON public.v3_selectors
FOR EACH ROW
EXECUTE FUNCTION public.v3_limit_selector_mutation();

ALTER TABLE public.v3_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_selectors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_selector_candidates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "v3_conditions_authenticated_read"
  ON public.v3_conditions
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "v3_selectors_authenticated_read"
  ON public.v3_selectors
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "v3_selector_candidates_authenticated_read"
  ON public.v3_selector_candidates
  FOR SELECT TO authenticated
  USING (true);
