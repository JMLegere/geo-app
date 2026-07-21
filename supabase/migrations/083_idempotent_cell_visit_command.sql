-- Migration 083: idempotent Cell Visit command boundary.
--
-- This is additive: pre-existing Cell Visits retain a NULL client_event_id and
-- remain valid. Ownership, cell identity, and client event identity are still
-- client reported; physical presence is not established by this beta command.
-- That remains an explicit beta limitation.

ALTER TABLE public.v3_cell_visits
  ADD COLUMN IF NOT EXISTS client_event_id TEXT;

DO $add_v3_cell_visits_client_event_id_check$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'v3_cell_visits_client_event_id_nonblank_bounded'
      AND conrelid = 'public.v3_cell_visits'::regclass
  ) THEN
    ALTER TABLE public.v3_cell_visits
      ADD CONSTRAINT v3_cell_visits_client_event_id_nonblank_bounded
      CHECK (
        client_event_id IS NULL
        OR (
          btrim(client_event_id) <> ''
          AND char_length(client_event_id) <= 128
        )
      ) NOT VALID;
  END IF;
END;
$add_v3_cell_visits_client_event_id_check$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_v3_cell_visits_user_client_event_id
  ON public.v3_cell_visits(user_id, client_event_id)
  WHERE client_event_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.v3_prevent_cell_visit_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Cell Visits cannot be deleted'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.id IS NOT DISTINCT FROM OLD.id
     AND NEW.user_id IS NOT DISTINCT FROM OLD.user_id
     AND NEW.cell_id IS NOT DISTINCT FROM OLD.cell_id
     AND NEW.client_event_id IS NOT DISTINCT FROM OLD.client_event_id
     AND NEW.visited_at IS NOT DISTINCT FROM OLD.visited_at THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Cell Visit rows are immutable'
    USING ERRCODE = '23514';
END;
$$;

DO $create_v3_cell_visits_immutable_trigger$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'v3_cell_visits_immutable'
      AND tgrelid = 'public.v3_cell_visits'::regclass
      AND NOT tgisinternal
  ) THEN
    EXECUTE
      'CREATE TRIGGER v3_cell_visits_immutable '
      'BEFORE UPDATE OR DELETE ON public.v3_cell_visits '
      'FOR EACH ROW EXECUTE FUNCTION public.v3_prevent_cell_visit_mutation()';
  END IF;
END;
$create_v3_cell_visits_immutable_trigger$;

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

  RETURN jsonb_build_object(
    'id', v_visit.id,
    'user_id', v_visit.user_id,
    'cell_id', v_visit.cell_id,
    'client_event_id', v_visit.client_event_id,
    'visited_at', v_visit.visited_at
  );
END;
$$;

DROP POLICY IF EXISTS "v3_cell_visits_insert_own" ON public.v3_cell_visits;

REVOKE ALL ON FUNCTION public.record_v3_cell_visit(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_v3_cell_visit(TEXT, TEXT) TO authenticated;
REVOKE ALL ON FUNCTION public.v3_prevent_cell_visit_mutation() FROM PUBLIC, anon, authenticated;
