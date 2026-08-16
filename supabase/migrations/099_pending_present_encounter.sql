-- Migration 099: authored manual red fox content and player-owned pending reads.
--
-- This seed creates revision 2 while it is draft, adds its visible Option and
-- Outcome, then publishes through the existing guarded publication boundary.

INSERT INTO public.v3_encounter_definition_versions (
  id,
  encounter_definition_id,
  revision,
  publication_status,
  display_name,
  is_automatic,
  eligibility_condition_id
)
VALUES (
  md5('earthnova:pending-present-encounter-version:red_fox:2')::uuid,
  'encounter:fauna:red_fox',
  2,
  'draft',
  'Red Fox',
  FALSE,
  NULL
)
ON CONFLICT DO NOTHING;

INSERT INTO public.v3_encounter_options (
  id,
  encounter_definition_version_id,
  ordinal,
  display_name,
  condition_id,
  is_implicit
)
SELECT
  md5('earthnova:pending-present-encounter-option:red_fox:2:observe-quietly')::uuid,
  version.id,
  0,
  'Observe quietly',
  NULL,
  FALSE
FROM public.v3_encounter_definition_versions AS version
WHERE version.encounter_definition_id = 'encounter:fauna:red_fox'
  AND version.revision = 2
  AND version.publication_status = 'draft'
ON CONFLICT DO NOTHING;

INSERT INTO public.v3_encounter_outcomes (
  id,
  encounter_option_id,
  ordinal,
  kind,
  payload
)
SELECT
  md5('earthnova:pending-present-encounter-outcome:red_fox:2:observe-quietly')::uuid,
  option.id,
  0,
  'generate_item',
  jsonb_build_object('base_item_id', 'fauna:red_fox')
FROM public.v3_encounter_options AS option
JOIN public.v3_encounter_definition_versions AS version
  ON version.id = option.encounter_definition_version_id
WHERE version.encounter_definition_id = 'encounter:fauna:red_fox'
  AND version.revision = 2
  AND version.publication_status = 'draft'
  AND option.ordinal = 0
ON CONFLICT DO NOTHING;

DO $publish_pending_present_red_fox$
DECLARE
  v_version_id UUID;
BEGIN
  SELECT version.id
  INTO v_version_id
  FROM public.v3_encounter_definition_versions AS version
  WHERE version.encounter_definition_id = 'encounter:fauna:red_fox'
    AND version.revision = 2
    AND version.publication_status = 'draft';

  IF FOUND THEN
    PERFORM public.publish_v3_encounter_definition_version(
      'encounter:fauna:red_fox',
      v_version_id
    );
  END IF;
END;
$publish_pending_present_red_fox$;

CREATE OR REPLACE FUNCTION public.read_v3_pending_encounter_for_cell(
  p_cell_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_pending_encounter JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Pending Encounter reads require an authenticated user'
      USING ERRCODE = '28000';
  END IF;

  IF p_cell_id IS NULL
     OR btrim(p_cell_id) = ''
     OR p_cell_id IS DISTINCT FROM btrim(p_cell_id)
     OR char_length(p_cell_id) > 256 THEN
    RAISE EXCEPTION 'Cell id must be nonblank, trimmed, and at most 256 characters'
      USING ERRCODE = '22023';
  END IF;

  SELECT jsonb_build_object(
    'cell_id', cell_visit.cell_id,
    'encounter_id', encounter.id,
    'cell_visit_id', encounter.cell_visit_id,
    'cell_visit_resolution_id', encounter.cell_visit_resolution_id,
    'encounter_definition_id', encounter.encounter_definition_id,
    'encounter_definition_version_id', encounter.encounter_definition_version_id,
    -- The immutable Version 'revision' is exposed under the flat contract name.
    'encounter_definition_revision', encounter_version.revision,
    'definition_display_name', encounter_version.display_name,
    'created_at', encounter.created_at,
    'options', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', option.id,
          'ordinal', option.ordinal,
          'display_name', option.display_name
        )
        ORDER BY option.ordinal
      )
      FROM public.v3_encounter_options AS option
      WHERE option.encounter_definition_version_id = encounter_version.id
        AND option.is_implicit = FALSE
    ), '[]'::jsonb)
  )
  INTO v_pending_encounter
  FROM public.v3_encounters AS encounter
  JOIN public.v3_cell_visits AS cell_visit
    ON cell_visit.id = encounter.cell_visit_id
  JOIN public.v3_encounter_definition_versions AS encounter_version
    ON encounter_version.id = encounter.encounter_definition_version_id
  WHERE cell_visit.user_id = v_user_id
    AND cell_visit.cell_id = p_cell_id
    AND encounter.resolution_status = 'pending'
  ORDER BY cell_visit.visited_at DESC, cell_visit.id DESC
  LIMIT 1;

  RETURN v_pending_encounter;
END;
$$;

REVOKE ALL ON FUNCTION public.read_v3_pending_encounter_for_cell(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.read_v3_pending_encounter_for_cell(TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.read_v3_pending_encounter_for_cell(TEXT) TO authenticated;
