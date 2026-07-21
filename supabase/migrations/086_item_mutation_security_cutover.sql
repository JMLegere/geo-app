-- Migration 086: Close direct Item creation/destruction and limit temporary
-- Identification compatibility writes to their current projection.
--
-- Item rows are never rewritten, deleted, or rebound here. The cutover aborts
-- instead when an existing Item lacks its exact Base Item Version binding.

DO $assert_v3_items_are_bound_for_mutation_cutover$
DECLARE
  v_unbound_count BIGINT;
BEGIN
  SELECT count(*)
  INTO v_unbound_count
  FROM public.v3_items
  WHERE base_item_id IS NULL OR base_item_version_id IS NULL;

  IF v_unbound_count <> 0 THEN
    RAISE EXCEPTION
      'Item mutation security cutover requires zero unbound Item rows; found %',
      v_unbound_count;
  END IF;
END;
$assert_v3_items_are_bound_for_mutation_cutover$;

-- TEMPORARY COMPATIBILITY: Identification still writes this exact projection
-- directly until the transactional Identification command replaces it. Every
-- other current or future Item column is immutable to authenticated updates.
CREATE OR REPLACE FUNCTION public.v3_limit_item_identification_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF (to_jsonb(NEW) - ARRAY[
    'display_name',
    'scientific_name',
    'taxonomic_class',
    'habitats_json',
    'continents_json',
    'identification_state',
    'identified_at'
  ]) IS DISTINCT FROM (to_jsonb(OLD) - ARRAY[
    'display_name',
    'scientific_name',
    'taxonomic_class',
    'habitats_json',
    'continents_json',
    'identification_state',
    'identified_at'
  ]) THEN
    RAISE EXCEPTION
      'Item updates may change only the temporary Identification projection'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS v3_items_identification_projection_only
  ON public.v3_items;

CREATE TRIGGER v3_items_identification_projection_only
BEFORE UPDATE ON public.v3_items
FOR EACH ROW
EXECUTE FUNCTION public.v3_limit_item_identification_mutation();

REVOKE ALL ON FUNCTION public.v3_limit_item_identification_mutation()
  FROM PUBLIC, anon, authenticated;

-- Direct Item creation and destruction are closed. Existing own-row SELECT
-- and the temporary own-row UPDATE policy remain unchanged.
REVOKE INSERT, DELETE ON TABLE public.v3_items FROM PUBLIC, anon, authenticated;

DROP POLICY IF EXISTS "v3_items_insert_own" ON public.v3_items;
DROP POLICY IF EXISTS "v3_items_delete_own" ON public.v3_items;

-- The only authenticated Item creation paths are the legacy/shadow acquisition
-- command and the authoritative Encounter commands. Explicit grants make the
-- ACL cutover independent of prior function privilege state.
REVOKE ALL ON FUNCTION public.acquire_v3_legacy_discovery_item(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, JSONB, TEXT,
  TIMESTAMPTZ, TEXT, TEXT, TEXT, JSONB, JSONB, TEXT
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.acquire_v3_legacy_discovery_item(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, JSONB, TEXT,
  TIMESTAMPTZ, TEXT, TEXT, TEXT, JSONB, JSONB, TEXT
) TO authenticated;

REVOKE ALL ON FUNCTION public.resolve_v3_cell_visit_encounter(UUID, TEXT, UUID, UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolve_v3_cell_visit_encounter(UUID, TEXT, UUID, UUID)
  TO authenticated;

REVOKE ALL ON FUNCTION public.resolve_v3_encounter_outcomes(UUID, UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolve_v3_encounter_outcomes(UUID, UUID)
  TO authenticated;
