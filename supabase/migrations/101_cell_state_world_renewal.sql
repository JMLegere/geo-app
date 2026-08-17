-- Migration 101: private Cell State and deterministic shared World renewal.
--
-- Opportunities and their refresh evidence are append-only.  The current
-- pointer is the sole mutable shared World projection; player knowledge and
-- visit bindings remain private command-owned state.

CREATE TABLE IF NOT EXISTS public.v3_world_days (
  world_day DATE PRIMARY KEY,
  world_seed BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.v3_cell_opportunities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  world_day DATE NOT NULL REFERENCES public.v3_world_days(world_day)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  cell_id TEXT NOT NULL REFERENCES public.cell_properties(cell_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  encounter_definition_version_id UUID NOT NULL
    REFERENCES public.v3_encounter_definition_versions(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  category TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (world_day, cell_id),
  UNIQUE (cell_id, id)
);

CREATE TABLE IF NOT EXISTS public.v3_cell_current_opportunities (
  cell_id TEXT PRIMARY KEY REFERENCES public.cell_properties(cell_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  cell_opportunity_id UUID NOT NULL REFERENCES public.v3_cell_opportunities(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (cell_id, cell_opportunity_id)
    REFERENCES public.v3_cell_opportunities(cell_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS public.v3_player_cell_knowledge (
  user_id UUID NOT NULL REFERENCES auth.users(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  cell_id TEXT NOT NULL REFERENCES public.cell_properties(cell_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  knowledge_state TEXT NOT NULL CHECK (knowledge_state IN ('explored', 'informed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, cell_id)
);

DO $add_v3_cell_visits_identity_key$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'v3_cell_visits_id_user_cell_unique'
      AND conrelid = 'public.v3_cell_visits'::regclass
  ) THEN
    ALTER TABLE public.v3_cell_visits
      ADD CONSTRAINT v3_cell_visits_id_user_cell_unique UNIQUE (id, user_id, cell_id);
  END IF;
END;
$add_v3_cell_visits_identity_key$;

CREATE TABLE IF NOT EXISTS public.v3_cell_visit_opportunities (
  cell_visit_id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  cell_id TEXT NOT NULL REFERENCES public.cell_properties(cell_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  cell_opportunity_id UUID NOT NULL REFERENCES public.v3_cell_opportunities(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (cell_visit_id, user_id, cell_id) REFERENCES public.v3_cell_visits(id, user_id, cell_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  FOREIGN KEY (cell_id, cell_opportunity_id)
    REFERENCES public.v3_cell_opportunities(cell_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS public.v3_cell_opportunity_refreshes (
  world_day DATE NOT NULL REFERENCES public.v3_world_days(world_day)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  cell_id TEXT NOT NULL REFERENCES public.cell_properties(cell_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  cell_opportunity_id UUID REFERENCES public.v3_cell_opportunities(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  refreshed BOOLEAN NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (world_day, cell_id),
  CHECK (
    (refreshed AND cell_opportunity_id IS NOT NULL)
    OR (NOT refreshed AND cell_opportunity_id IS NULL)
  )
);
ALTER TABLE public.v3_encounters
  ADD COLUMN IF NOT EXISTS cell_opportunity_id UUID
    REFERENCES public.v3_cell_opportunities(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT;

CREATE OR REPLACE FUNCTION public.v3_bind_encounter_cell_opportunity()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_cell_opportunity_id UUID;
  v_encounter_definition_id TEXT;
  v_encounter_definition_version_id UUID;
BEGIN
  SELECT
    opportunity.id,
    version.encounter_definition_id,
    opportunity.encounter_definition_version_id
  INTO
    v_cell_opportunity_id,
    v_encounter_definition_id,
    v_encounter_definition_version_id
  FROM public.v3_cell_visit_opportunities AS binding
  JOIN public.v3_cell_opportunities AS opportunity
    ON opportunity.id = binding.cell_opportunity_id
  JOIN public.v3_encounter_definition_versions AS version
    ON version.id = opportunity.encounter_definition_version_id
  WHERE binding.cell_visit_id = NEW.cell_visit_id;

  IF FOUND THEN
    IF NEW.cell_opportunity_id IS NULL THEN
      NEW.cell_opportunity_id := v_cell_opportunity_id;
    ELSIF NEW.cell_opportunity_id IS DISTINCT FROM v_cell_opportunity_id THEN
      RAISE EXCEPTION 'Encounter must retain its Cell Visit Opportunity'
        USING ERRCODE = '23514';
    END IF;

    IF NEW.encounter_definition_id IS DISTINCT FROM v_encounter_definition_id
       OR NEW.encounter_definition_version_id IS DISTINCT FROM v_encounter_definition_version_id THEN
      RAISE EXCEPTION 'Encounter must match its Cell Visit Opportunity Definition and Version'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER v3_encounters_bind_cell_opportunity
BEFORE INSERT ON public.v3_encounters
FOR EACH ROW
EXECUTE FUNCTION public.v3_bind_encounter_cell_opportunity();

CREATE OR REPLACE FUNCTION public.v3_validate_encounter_binding()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_resolution_definition_id TEXT;
  v_current_version_id UUID;
  v_bound_opportunity_id UUID;
  v_bound_version_id UUID;
  v_has_bound_opportunity BOOLEAN;
  v_has_resolution BOOLEAN;
BEGIN
  SELECT
    binding.cell_opportunity_id,
    opportunity.encounter_definition_version_id
  INTO v_bound_opportunity_id, v_bound_version_id
  FROM public.v3_cell_visit_opportunities AS binding
  JOIN public.v3_cell_opportunities AS opportunity
    ON opportunity.id = binding.cell_opportunity_id
  WHERE binding.cell_visit_id = NEW.cell_visit_id;
  v_has_bound_opportunity := FOUND;

  SELECT resolution.encounter_definition_id,
         definition.current_published_version_id
  INTO v_resolution_definition_id, v_current_version_id
  FROM public.v3_cell_visit_resolutions AS resolution
  JOIN public.v3_encounter_definitions AS definition
    ON definition.id = resolution.encounter_definition_id
  WHERE resolution.id = NEW.cell_visit_resolution_id
    AND resolution.cell_visit_id = NEW.cell_visit_id
    AND resolution.resolution_kind = 'encounter';
  v_has_resolution := FOUND;

  IF v_has_bound_opportunity THEN
    IF NOT v_has_resolution
       OR NEW.cell_opportunity_id IS DISTINCT FROM v_bound_opportunity_id
       OR NEW.encounter_definition_id IS DISTINCT FROM v_resolution_definition_id
       OR NEW.encounter_definition_version_id IS DISTINCT FROM v_bound_version_id THEN
      RAISE EXCEPTION 'Encounter must match its Cell Visit Opportunity'
        USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
  END IF;

  IF NOT v_has_resolution
     OR v_resolution_definition_id IS DISTINCT FROM NEW.encounter_definition_id
     OR v_current_version_id IS DISTINCT FROM NEW.encounter_definition_version_id THEN
    RAISE EXCEPTION 'Encounter must bind the Cell Visit selected Definition current published Version'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

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
     OR NEW.cell_opportunity_id IS DISTINCT FROM OLD.cell_opportunity_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'Encounter occurrence identity and version binding are immutable';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.v3_prevent_world_day_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'World Days are immutable' USING ERRCODE = '23514';
END;
$$;

CREATE OR REPLACE FUNCTION public.v3_prevent_cell_opportunity_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'Cell Opportunities are immutable' USING ERRCODE = '23514';
END;
$$;

CREATE OR REPLACE FUNCTION public.v3_prevent_cell_visit_opportunity_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'Cell Visit Opportunity bindings are immutable' USING ERRCODE = '23514';
END;
$$;

CREATE OR REPLACE FUNCTION public.v3_prevent_cell_opportunity_refresh_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'Cell Opportunity refresh evidence is immutable' USING ERRCODE = '23514';
END;
$$;

CREATE TRIGGER v3_world_days_immutable
BEFORE UPDATE OR DELETE ON public.v3_world_days
FOR EACH ROW EXECUTE FUNCTION public.v3_prevent_world_day_mutation();

CREATE TRIGGER v3_cell_opportunities_immutable
BEFORE UPDATE OR DELETE ON public.v3_cell_opportunities
FOR EACH ROW EXECUTE FUNCTION public.v3_prevent_cell_opportunity_mutation();

CREATE TRIGGER v3_cell_visit_opportunities_immutable
BEFORE UPDATE OR DELETE ON public.v3_cell_visit_opportunities
FOR EACH ROW EXECUTE FUNCTION public.v3_prevent_cell_visit_opportunity_mutation();

CREATE TRIGGER v3_cell_opportunity_refreshes_immutable
BEFORE UPDATE OR DELETE ON public.v3_cell_opportunity_refreshes
FOR EACH ROW EXECUTE FUNCTION public.v3_prevent_cell_opportunity_refresh_mutation();

ALTER TABLE public.v3_world_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_cell_opportunities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_cell_current_opportunities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_player_cell_knowledge ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_cell_visit_opportunities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_cell_opportunity_refreshes ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.v3_world_days FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.v3_cell_opportunities FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.v3_cell_current_opportunities FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.v3_player_cell_knowledge FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.v3_cell_visit_opportunities FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.v3_cell_opportunity_refreshes FROM PUBLIC, anon, authenticated;

INSERT INTO public.v3_player_cell_knowledge (user_id, cell_id, knowledge_state)
SELECT DISTINCT cell_visit.user_id, cell_visit.cell_id, 'explored'
FROM public.v3_cell_visits AS cell_visit
JOIN public.cell_properties AS cell
  ON cell.cell_id = cell_visit.cell_id
ON CONFLICT (user_id, cell_id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.refresh_v3_cell_opportunities(
  p_cell_ids TEXT[],
  p_world_day DATE DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_world_day DATE := COALESCE(p_world_day, (now() AT TIME ZONE 'UTC')::date);
  v_cell_id TEXT;
  v_current_world_day DATE;
  v_last_processed_world_day DATE;
  v_next_world_day DATE;
  v_processed_world_day DATE;
  v_has_current_opportunity BOOLEAN;
  v_roll_bucket BIGINT;
  v_content_bucket BIGINT;
  v_opportunity_id UUID;
  v_encounter_definition_version_id UUID;
  v_category TEXT;
BEGIN
  IF p_cell_ids IS NULL
     OR cardinality(p_cell_ids) = 0
     OR cardinality(p_cell_ids) > 256 THEN
    RAISE EXCEPTION 'Cell ids must contain between one and 256 cells'
      USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM unnest(p_cell_ids) AS requested(cell_id)
    WHERE requested.cell_id IS NULL
      OR btrim(requested.cell_id) = ''
      OR requested.cell_id IS DISTINCT FROM btrim(requested.cell_id)
      OR char_length(requested.cell_id) > 256
  ) THEN
    RAISE EXCEPTION 'Cell ids must be nonblank, trimmed, and at most 256 characters'
      USING ERRCODE = '22023';
  END IF;

  IF cardinality(p_cell_ids) <> (
    SELECT COUNT(DISTINCT requested.cell_id)
    FROM unnest(p_cell_ids) AS requested(cell_id)
  ) THEN
    RAISE EXCEPTION 'Cell ids must be unique' USING ERRCODE = '22023';
  END IF;

  IF (
    SELECT COUNT(*)
    FROM public.cell_properties AS cell
    WHERE cell.cell_id = ANY (p_cell_ids)
  ) <> cardinality(p_cell_ids) THEN
    RAISE EXCEPTION 'Cell ids must be known' USING ERRCODE = '22023';
  END IF;

  IF v_world_day > (now() AT TIME ZONE 'UTC')::date THEN
    RAISE EXCEPTION 'World Day cannot be in the future' USING ERRCODE = '22023';
  END IF;

  FOR v_cell_id IN
    SELECT cell.cell_id
    FROM public.cell_properties AS cell
    WHERE cell.cell_id = ANY (p_cell_ids)
    ORDER BY cell.cell_id
  LOOP
    PERFORM pg_advisory_xact_lock(
      hashtextextended(concat_ws(':', 'v3-cell-current-opportunity', v_cell_id), 0)
    );

    SELECT opportunity.world_day
    INTO v_current_world_day
    FROM public.v3_cell_current_opportunities AS current_opportunity
    JOIN public.v3_cell_opportunities AS opportunity
      ON opportunity.id = current_opportunity.cell_opportunity_id
    WHERE current_opportunity.cell_id = v_cell_id
    FOR UPDATE OF current_opportunity;

    v_has_current_opportunity := FOUND;
    IF v_has_current_opportunity THEN
      SELECT GREATEST(
        v_current_world_day,
        COALESCE(MAX(refresh.world_day), v_current_world_day)
      )
      INTO v_last_processed_world_day
      FROM public.v3_cell_opportunity_refreshes AS refresh
      WHERE refresh.cell_id = v_cell_id;
      v_next_world_day := v_last_processed_world_day + 1;
    ELSE
      v_next_world_day := v_world_day;
    END IF;

    FOR v_processed_world_day IN
      SELECT series.world_day::date
      FROM generate_series(
        v_next_world_day,
        v_world_day,
        INTERVAL '1 day'
      ) AS series(world_day)
    LOOP
      INSERT INTO public.v3_world_days (world_day, world_seed)
      VALUES (
        v_processed_world_day,
        hashtextextended(v_processed_world_day::text, 0)
      )
      ON CONFLICT (world_day) DO NOTHING;

      v_roll_bucket := (
        ('x00000000' || substring(
          encode(extensions.digest(
            'refresh_' || format(
              'seed_%s',
              to_char(v_processed_world_day, 'YYYY_MM_DD')
            ) || '_' || v_cell_id,
            'sha256'
          ), 'hex')
          FROM 1 FOR 8
        ))::bit(64)::bigint
      ) % 10000;

      IF NOT v_has_current_opportunity OR v_roll_bucket < 500 THEN
        v_content_bucket := (
          ('x00000000' || substring(
            encode(extensions.digest(
              format('seed_%s', to_char(v_processed_world_day, 'YYYY_MM_DD'))
                || '_' || v_cell_id,
              'sha256'
            ), 'hex')
            FROM 1 FOR 8
          ))::bit(64)::bigint
        );

        WITH candidates AS (
          SELECT
            selector_candidate.ordinal,
            selector_candidate.result_id,
            version.id AS encounter_definition_version_id,
            generated_item.category
          FROM public.v3_selector_candidates AS selector_candidate
          JOIN public.v3_encounter_definitions AS definition
            ON definition.id = selector_candidate.result_id
          JOIN public.v3_encounter_definition_versions AS version
            ON version.id = definition.current_published_version_id
            AND version.publication_status = 'published'
          JOIN LATERAL (
            SELECT base_item.category
            FROM public.v3_encounter_options AS option
            JOIN public.v3_encounter_outcomes AS outcome
              ON outcome.encounter_option_id = option.id
              AND outcome.kind = 'generate_item'
            JOIN public.v3_base_items AS base_item
              ON base_item.id = outcome.payload ->> 'base_item_id'
            WHERE option.encounter_definition_version_id = version.id
            ORDER BY option.ordinal, outcome.ordinal
            LIMIT 1
          ) AS generated_item ON TRUE
          WHERE selector_candidate.selector_id = 'selector:legacy-cell-encounter'
            AND selector_candidate.result_kind = 'value'
        ), numbered_candidates AS (
          SELECT
            candidate.*,
            row_number() OVER (
              ORDER BY candidate.ordinal, candidate.result_id
            ) - 1 AS candidate_ordinal,
            count(*) OVER () AS candidate_count
          FROM candidates AS candidate
        )
        SELECT candidate.encounter_definition_version_id, candidate.category
        INTO v_encounter_definition_version_id, v_category
        FROM numbered_candidates AS candidate
        WHERE candidate.candidate_ordinal = v_content_bucket % candidate.candidate_count;

        IF v_encounter_definition_version_id IS NULL THEN
          RAISE EXCEPTION 'No published legacy Cell Encounter candidate is available'
            USING ERRCODE = '23514';
        END IF;

        INSERT INTO public.v3_cell_opportunities (
          world_day,
          cell_id,
          encounter_definition_version_id,
          category
        )
        VALUES (
          v_processed_world_day,
          v_cell_id,
          v_encounter_definition_version_id,
          v_category
        )
        RETURNING id INTO v_opportunity_id;

        INSERT INTO public.v3_cell_current_opportunities (
          cell_id,
          cell_opportunity_id
        )
        VALUES (v_cell_id, v_opportunity_id)
        ON CONFLICT (cell_id) DO UPDATE
          SET cell_opportunity_id = EXCLUDED.cell_opportunity_id;

        IF v_has_current_opportunity THEN
          INSERT INTO public.v3_cell_opportunity_refreshes (
            world_day,
            cell_id,
            cell_opportunity_id,
            refreshed
          )
          VALUES (v_processed_world_day, v_cell_id, v_opportunity_id, TRUE);

          UPDATE public.v3_player_cell_knowledge
          SET knowledge_state = 'informed', updated_at = now()
          WHERE cell_id = v_cell_id
            AND knowledge_state = 'explored';
        ELSE
          v_has_current_opportunity := TRUE;
        END IF;
      ELSE
        INSERT INTO public.v3_cell_opportunity_refreshes (
          world_day,
          cell_id,
          cell_opportunity_id,
          refreshed
        )
        VALUES (v_processed_world_day, v_cell_id, NULL, FALSE);
      END IF;
    END LOOP;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.fetch_v3_player_cell_states(
  p_cell_ids TEXT[],
  p_world_day DATE DEFAULT NULL
)
RETURNS TABLE (
  cell_id TEXT,
  state TEXT,
  opportunity_category TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_world_day DATE := COALESCE(p_world_day, (now() AT TIME ZONE 'UTC')::date);
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Cell State fetch requires an authenticated user'
      USING ERRCODE = '28000';
  END IF;

  IF p_cell_ids IS NULL
     OR cardinality(p_cell_ids) = 0
     OR cardinality(p_cell_ids) > 256 THEN
    RAISE EXCEPTION 'Cell ids must contain between one and 256 cells'
      USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM unnest(p_cell_ids) AS requested(requested_cell_id)
    WHERE requested.requested_cell_id IS NULL
      OR btrim(requested.requested_cell_id) = ''
      OR requested.requested_cell_id IS DISTINCT FROM btrim(requested.requested_cell_id)
      OR char_length(requested.requested_cell_id) > 256
  ) THEN
    RAISE EXCEPTION 'Cell ids must be nonblank, trimmed, and at most 256 characters'
      USING ERRCODE = '22023';
  END IF;

  IF cardinality(p_cell_ids) <> (
    SELECT COUNT(DISTINCT requested.requested_cell_id)
    FROM unnest(p_cell_ids) AS requested(requested_cell_id)
  ) THEN
    RAISE EXCEPTION 'Cell ids must be unique' USING ERRCODE = '22023';
  END IF;

  IF (
    SELECT COUNT(*)
    FROM public.cell_properties AS cell
    WHERE cell.cell_id = ANY (p_cell_ids)
  ) <> cardinality(p_cell_ids) THEN
    RAISE EXCEPTION 'Cell ids must be known' USING ERRCODE = '22023';
  END IF;

  IF p_world_day IS NOT NULL
     AND p_world_day IS DISTINCT FROM (now() AT TIME ZONE 'UTC')::date THEN
    RAISE EXCEPTION 'World Day must be today' USING ERRCODE = '22023';
  END IF;

  PERFORM public.refresh_v3_cell_opportunities(p_cell_ids, v_world_day);

  RETURN QUERY
  SELECT
    requested.requested_cell_id AS cell_id,
    COALESCE(knowledge.knowledge_state, 'shrouded') AS state,
    CASE
      WHEN knowledge.knowledge_state = 'informed' THEN opportunity.category
      ELSE NULL
    END AS opportunity_category
  FROM unnest(p_cell_ids) AS requested(requested_cell_id)
  LEFT JOIN public.v3_player_cell_knowledge AS knowledge
    ON knowledge.user_id = v_user_id
    AND knowledge.cell_id = requested.requested_cell_id
  LEFT JOIN public.v3_cell_current_opportunities AS current_opportunity
    ON current_opportunity.cell_id = requested.requested_cell_id
  LEFT JOIN public.v3_cell_opportunities AS opportunity
    ON opportunity.id = current_opportunity.cell_opportunity_id
  ORDER BY requested.requested_cell_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.record_v3_cell_visit(
  p_cell_id TEXT,
  p_client_event_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_visited_at TIMESTAMPTZ := now();
  v_visit public.v3_cell_visits%ROWTYPE;
  v_existing public.v3_cell_visits%ROWTYPE;
  v_current_opportunity_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Cell Visit recording requires an authenticated user'
      USING ERRCODE = '28000';
  END IF;

  IF p_cell_id IS NULL
     OR btrim(p_cell_id) = ''
     OR p_cell_id IS DISTINCT FROM btrim(p_cell_id)
     OR char_length(p_cell_id) > 256 THEN
    RAISE EXCEPTION 'Cell Visit cell id must be nonblank, trimmed, and at most 256 characters'
      USING ERRCODE = '22023';
  END IF;

  IF p_client_event_id IS NULL
     OR btrim(p_client_event_id) = ''
     OR p_client_event_id IS DISTINCT FROM btrim(p_client_event_id)
     OR char_length(p_client_event_id) > 128 THEN
    RAISE EXCEPTION 'Cell Visit client event id must be nonblank, trimmed, and at most 128 characters'
      USING ERRCODE = '22023';
  END IF;

  PERFORM public.refresh_v3_cell_opportunities(ARRAY[p_cell_id]);

  SELECT current_opportunity.cell_opportunity_id
  INTO v_current_opportunity_id
  FROM public.v3_cell_current_opportunities AS current_opportunity
  WHERE current_opportunity.cell_id = p_cell_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cell Opportunity is unavailable' USING ERRCODE = '23514';
  END IF;

  SELECT cell_visit.*
  INTO v_existing
  FROM public.v3_cell_visits AS cell_visit
  WHERE cell_visit.user_id = v_user_id
    AND cell_visit.client_event_id = p_client_event_id
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing.cell_id IS DISTINCT FROM p_cell_id THEN
      RAISE EXCEPTION 'Cell Visit client event belongs to a different cell'
        USING ERRCODE = '23505';
    END IF;
    v_visit := v_existing;
  ELSE
    INSERT INTO public.v3_cell_visits (
      user_id,
      cell_id,
      client_event_id,
      visited_at
    )
    VALUES (
      v_user_id,
      p_cell_id,
      p_client_event_id,
      v_visited_at
    )
    ON CONFLICT (user_id, client_event_id)
      WHERE client_event_id IS NOT NULL
      DO NOTHING
    RETURNING * INTO v_visit;

    IF NOT FOUND THEN
      SELECT cell_visit.*
      INTO v_existing
      FROM public.v3_cell_visits AS cell_visit
      WHERE cell_visit.user_id = v_user_id
        AND cell_visit.client_event_id = p_client_event_id
      FOR UPDATE;

      IF v_existing.cell_id IS DISTINCT FROM p_cell_id THEN
        RAISE EXCEPTION 'Cell Visit client event belongs to a different cell'
          USING ERRCODE = '23505';
      END IF;
      v_visit := v_existing;
    END IF;
  END IF;

  INSERT INTO public.v3_cell_visit_opportunities (
    cell_visit_id,
    user_id,
    cell_id,
    cell_opportunity_id
  )
  VALUES (
    v_visit.id,
    v_visit.user_id,
    v_visit.cell_id,
    v_current_opportunity_id
  )
  ON CONFLICT (cell_visit_id) DO NOTHING;

  INSERT INTO public.v3_player_cell_knowledge (user_id, cell_id, knowledge_state)
  VALUES (v_user_id, p_cell_id, 'explored')
  ON CONFLICT (user_id, cell_id) DO NOTHING;

  RETURN jsonb_build_object(
    'id', v_visit.id,
    'user_id', v_visit.user_id,
    'cell_id', v_visit.cell_id,
    'client_event_id', v_visit.client_event_id,
    'visited_at', v_visit.visited_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.refresh_v3_cell_opportunities(TEXT[], DATE) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fetch_v3_player_cell_states(TEXT[], DATE) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fetch_v3_player_cell_states(TEXT[], DATE) TO authenticated;
REVOKE ALL ON FUNCTION public.record_v3_cell_visit(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_v3_cell_visit(TEXT, TEXT) TO authenticated;
REVOKE ALL ON FUNCTION public.v3_prevent_world_day_mutation() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_prevent_cell_opportunity_mutation() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_prevent_cell_visit_opportunity_mutation() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_prevent_cell_opportunity_refresh_mutation() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_bind_encounter_cell_opportunity() FROM PUBLIC, anon, authenticated;
