-- Migration 094: require ordered Outcomes for every published Encounter Option.
--
-- Publication remains the sole validation boundary for draft authored content.
-- Existing option-shape validation remains unchanged; this adds the missing
-- requirement that every Option owned by the candidate Version is resolvable.

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
  v_empty_option_id UUID;
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

  IF p_require_options THEN
    SELECT option.id
    INTO v_empty_option_id
    FROM public.v3_encounter_options AS option
    WHERE option.encounter_definition_version_id = p_version_id
      AND NOT EXISTS (
        SELECT 1
        FROM public.v3_encounter_outcomes AS outcome
        WHERE outcome.encounter_option_id = option.id
      )
    ORDER BY option.ordinal
    LIMIT 1;

    IF FOUND THEN
      RAISE EXCEPTION
        'Encounter Definition Version % Option % must have at least one Outcome',
        p_version_id,
        v_empty_option_id
        USING ERRCODE = '23514';
    END IF;
  END IF;
END;
$$;

-- Reassert the existing callable surface after replacing the helper.
REVOKE ALL ON FUNCTION public.v3_validate_automatic_encounter_options(UUID, BOOLEAN)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.publish_v3_encounter_definition_version(TEXT, UUID)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.publish_v3_encounter_definition_version(TEXT, UUID)
  TO service_role;
