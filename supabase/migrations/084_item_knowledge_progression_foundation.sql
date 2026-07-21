-- Migration 084: additive Item knowledge and Discipline Progress storage foundation.
--
-- This migration deliberately stores durable knowledge without activating the
-- Identification or Discipline runtime paths. Existing Item identity, ownership,
-- acquisition state, legacy payload, rarity evidence, and exact Base Item
-- bindings remain untouched.

-- A composite target key lets downstream committed rows prove that their Item,
-- Player, stable Base Item, and exact immutable Base Item Version are one owned
-- binding instead of independent references that could be mixed accidentally.
DO $add_v3_items_exact_owned_binding_unique$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'v3_items_exact_owned_binding_unique'
      AND conrelid = 'public.v3_items'::regclass
  ) THEN
    ALTER TABLE public.v3_items
      ADD CONSTRAINT v3_items_exact_owned_binding_unique
      UNIQUE (id, user_id, base_item_id, base_item_version_id);
  END IF;
END;
$add_v3_items_exact_owned_binding_unique$;

-- A Selector/candidate pair has the same ownership shape: a candidate must be
-- recorded with the Selector that owns it, not merely with any candidate UUID.
DO $add_v3_selector_candidates_exact_selector_candidate_unique$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'v3_selector_candidates_exact_selector_candidate_unique'
      AND conrelid = 'public.v3_selector_candidates'::regclass
  ) THEN
    ALTER TABLE public.v3_selector_candidates
      ADD CONSTRAINT v3_selector_candidates_exact_selector_candidate_unique
      UNIQUE (selector_id, id);
  END IF;
END;
$add_v3_selector_candidates_exact_selector_candidate_unique$;

CREATE TABLE IF NOT EXISTS public.v3_item_discoveries (
  user_id UUID NOT NULL REFERENCES auth.users(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  base_item_id TEXT NOT NULL REFERENCES public.v3_base_items(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  first_identified_item_id UUID NOT NULL,
  first_base_item_version_id UUID NOT NULL,
  provenance TEXT NOT NULL CHECK (
    provenance IN (
      'legacy_backfill',
      'explicit_identification',
      'automatic_identification'
    )
  ),
  discovered_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, base_item_id),
  CONSTRAINT v3_item_discoveries_first_item_exact_binding_fk
    FOREIGN KEY (
      first_identified_item_id,
      user_id,
      base_item_id,
      first_base_item_version_id
    )
    REFERENCES public.v3_items(
      id,
      user_id,
      base_item_id,
      base_item_version_id
    )
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT v3_item_discoveries_first_version_owner_fk
    FOREIGN KEY (base_item_id, first_base_item_version_id)
    REFERENCES public.v3_base_item_versions(base_item_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_v3_item_discoveries_user_discovered_at
  ON public.v3_item_discoveries(user_id, discovered_at DESC);

CREATE TABLE IF NOT EXISTS public.v3_item_property_values (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id UUID NOT NULL,
  user_id UUID NOT NULL,
  base_item_id TEXT NOT NULL,
  base_item_version_id UUID NOT NULL,
  variable_property_key TEXT NOT NULL CHECK (btrim(variable_property_key) <> ''),
  selector_id TEXT NOT NULL REFERENCES public.v3_selectors(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  selector_candidate_id UUID NOT NULL,
  resolution_kind TEXT NOT NULL CHECK (resolution_kind IN ('value', 'none')),
  resolved_value_id TEXT,
  resolved_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT v3_item_property_values_item_property_unique
    UNIQUE (item_id, variable_property_key),
  CONSTRAINT v3_item_property_values_exact_item_binding_fk
    FOREIGN KEY (item_id, user_id, base_item_id, base_item_version_id)
    REFERENCES public.v3_items(id, user_id, base_item_id, base_item_version_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT v3_item_property_values_exact_candidate_binding_fk
    FOREIGN KEY (selector_id, selector_candidate_id)
    REFERENCES public.v3_selector_candidates(selector_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT v3_item_property_values_resolution_shape_check CHECK (
    (resolution_kind = 'none' AND resolved_value_id IS NULL)
    OR (
      resolution_kind = 'value'
      AND btrim(COALESCE(resolved_value_id, '')) <> ''
    )
  )
);

CREATE INDEX IF NOT EXISTS idx_v3_item_property_values_item
  ON public.v3_item_property_values(item_id);

CREATE TABLE IF NOT EXISTS public.v3_discipline_progress (
  user_id UUID NOT NULL REFERENCES auth.users(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  discipline TEXT NOT NULL CHECK (
    discipline IN (
      'zoology',
      'botany',
      'geology',
      'paleontology',
      'archaeology'
    )
  ),
  xp BIGINT NOT NULL CHECK (xp >= 0),
  level INTEGER NOT NULL CHECK (level > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, discipline)
);

CREATE INDEX IF NOT EXISTS idx_v3_discipline_progress_user
  ON public.v3_discipline_progress(user_id);

-- Legacy identified Items become one durable Index milestone per Player and
-- stable Base Item. The ordering intentionally uses a trustworthy identification
-- timestamp first, then acquisition time, then Item UUID as a deterministic
-- final tie-breaker. This records no Property Values and creates no Discipline
-- Progress rows, preserving legacy data without inventing new mechanics.
WITH ranked_identified_items AS (
  SELECT
    item.id,
    item.user_id,
    item.base_item_id,
    item.base_item_version_id,
    item.identified_at,
    item.acquired_at,
    row_number() OVER (
      PARTITION BY item.user_id, item.base_item_id
      ORDER BY
        item.identified_at ASC NULLS LAST,
        item.acquired_at ASC,
        item.id ASC
    ) AS discovery_rank
  FROM public.v3_items AS item
  WHERE item.identification_state = 'identified'
    AND item.base_item_id IS NOT NULL
    AND item.base_item_version_id IS NOT NULL
)
INSERT INTO public.v3_item_discoveries (
  user_id,
  base_item_id,
  first_identified_item_id,
  first_base_item_version_id,
  provenance,
  discovered_at
)
SELECT
  item.user_id,
  item.base_item_id,
  item.id,
  item.base_item_version_id,
  'legacy_backfill',
  COALESCE(item.identified_at, item.acquired_at)
FROM ranked_identified_items AS item
WHERE item.discovery_rank = 1
ON CONFLICT (user_id, base_item_id) DO NOTHING;

-- These checks are intentionally repeat-safe: they make migration ordering or
-- partial data failures explicit while leaving all existing Item rows intact.
DO $assert_v3_items_have_exact_base_item_bindings$
DECLARE
  v_unbound_count BIGINT;
BEGIN
  SELECT count(*)
  INTO v_unbound_count
  FROM public.v3_items
  WHERE base_item_id IS NULL OR base_item_version_id IS NULL;

  IF v_unbound_count <> 0 THEN
    RAISE EXCEPTION 'Item knowledge foundation requires zero unbound Item rows; found %',
      v_unbound_count;
  END IF;
END;
$assert_v3_items_have_exact_base_item_bindings$;

DO $assert_v3_item_discoveries_are_backfilled$
DECLARE
  v_missing_discovery_count BIGINT;
BEGIN
  SELECT count(*)
  INTO v_missing_discovery_count
  FROM (
    SELECT DISTINCT item.user_id, item.base_item_id
    FROM public.v3_items AS item
    WHERE item.identification_state = 'identified'
      AND item.base_item_id IS NOT NULL
      AND item.base_item_version_id IS NOT NULL
  ) AS identified_base_items
  LEFT JOIN public.v3_item_discoveries AS discovery
    ON discovery.user_id = identified_base_items.user_id
    AND discovery.base_item_id = identified_base_items.base_item_id
  WHERE discovery.user_id IS NULL;

  IF v_missing_discovery_count <> 0 THEN
    RAISE EXCEPTION 'Item knowledge backfill left % identified Player/Base Item discoveries missing',
      v_missing_discovery_count;
  END IF;
END;
$assert_v3_item_discoveries_are_backfilled$;

CREATE OR REPLACE FUNCTION public.v3_validate_item_property_value_resolution()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_candidate_kind TEXT;
  v_candidate_result_id TEXT;
BEGIN
  SELECT candidate.result_kind, candidate.result_id
  INTO v_candidate_kind, v_candidate_result_id
  FROM public.v3_selector_candidates AS candidate
  WHERE candidate.id = NEW.selector_candidate_id
    AND candidate.selector_id = NEW.selector_id;

  IF NOT FOUND
     OR v_candidate_kind IS DISTINCT FROM NEW.resolution_kind
     OR v_candidate_result_id IS DISTINCT FROM NEW.resolved_value_id THEN
    RAISE EXCEPTION
      'Item Property Value must preserve its exact Selector candidate result'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

DO $add_v3_item_property_values_resolution_trigger$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'v3_item_property_values_validate_resolution'
      AND tgrelid = 'public.v3_item_property_values'::regclass
      AND NOT tgisinternal
  ) THEN
    CREATE TRIGGER v3_item_property_values_validate_resolution
      BEFORE INSERT OR UPDATE ON public.v3_item_property_values
      FOR EACH ROW
      EXECUTE FUNCTION public.v3_validate_item_property_value_resolution();
  END IF;
END;
$add_v3_item_property_values_resolution_trigger$;

CREATE OR REPLACE FUNCTION public.v3_prevent_item_discovery_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'Committed Item Discoveries are immutable';
END;
$$;

DO $add_v3_item_discoveries_immutability_trigger$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'v3_item_discoveries_immutable'
      AND tgrelid = 'public.v3_item_discoveries'::regclass
      AND NOT tgisinternal
  ) THEN
    CREATE TRIGGER v3_item_discoveries_immutable
      BEFORE UPDATE OR DELETE ON public.v3_item_discoveries
      FOR EACH ROW
      EXECUTE FUNCTION public.v3_prevent_item_discovery_mutation();
  END IF;
END;
$add_v3_item_discoveries_immutability_trigger$;

CREATE OR REPLACE FUNCTION public.v3_prevent_item_property_value_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'Committed Item Property Values are immutable';
END;
$$;

DO $add_v3_item_property_values_immutability_trigger$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'v3_item_property_values_immutable'
      AND tgrelid = 'public.v3_item_property_values'::regclass
      AND NOT tgisinternal
  ) THEN
    CREATE TRIGGER v3_item_property_values_immutable
      BEFORE UPDATE OR DELETE ON public.v3_item_property_values
      FOR EACH ROW
      EXECUTE FUNCTION public.v3_prevent_item_property_value_mutation();
  END IF;
END;
$add_v3_item_property_values_immutability_trigger$;

ALTER TABLE public.v3_item_discoveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_item_property_values ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_discipline_progress ENABLE ROW LEVEL SECURITY;

DO $add_v3_item_discoveries_authenticated_read_own_policy$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'v3_item_discoveries'
      AND policyname = 'v3_item_discoveries_authenticated_read_own'
  ) THEN
    CREATE POLICY "v3_item_discoveries_authenticated_read_own"
      ON public.v3_item_discoveries
      FOR SELECT TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END;
$add_v3_item_discoveries_authenticated_read_own_policy$;

DO $add_v3_item_property_values_authenticated_read_own_policy$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'v3_item_property_values'
      AND policyname = 'v3_item_property_values_authenticated_read_own'
  ) THEN
    CREATE POLICY "v3_item_property_values_authenticated_read_own"
      ON public.v3_item_property_values
      FOR SELECT TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END;
$add_v3_item_property_values_authenticated_read_own_policy$;

DO $add_v3_discipline_progress_authenticated_read_own_policy$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'v3_discipline_progress'
      AND policyname = 'v3_discipline_progress_authenticated_read_own'
  ) THEN
    CREATE POLICY "v3_discipline_progress_authenticated_read_own"
      ON public.v3_discipline_progress
      FOR SELECT TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END;
$add_v3_discipline_progress_authenticated_read_own_policy$;

COMMENT ON TABLE public.v3_item_discoveries IS
  'One immutable Player knowledge milestone per stable Base Item; the first identified Item preserves its exact Base Item Version and provenance.';

COMMENT ON TABLE public.v3_item_property_values IS
  'Immutable Item-specific Variable Property resolutions bound to the Item exact Version and the exact Selector candidate, including explicit None.';

COMMENT ON TABLE public.v3_discipline_progress IS
  'Schema-only Player progression storage for the five canonical Disciplines; no XP grants, thresholds, advancement, unlocks, or events are defined here.';

REVOKE ALL ON FUNCTION public.v3_validate_item_property_value_resolution()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_prevent_item_discovery_mutation()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_prevent_item_property_value_mutation()
  FROM PUBLIC, anon, authenticated;
