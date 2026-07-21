-- Migration 080: compatibility Encounter catalog for the current map loop.
--
-- This seed mirrors ComputeEncounter's eight ordered catalog entries and the
-- Base Item identities introduced by migration 079. It is additive,
-- repeat-safe, and does not make legacy eligibility or equal weights canonical
-- future product policy.

INSERT INTO public.v3_conditions (
  id,
  condition_schema_version,
  condition_ast
)
VALUES
  (
    'condition:legacy-encounter-eligible',
    1,
    jsonb_build_object(
      'kind', 'leaf',
      'leaf_kind', 'legacy_encounter_eligible',
      'payload', jsonb_build_object('compatibility_only', TRUE)
    )
  ),
  (
    'condition:legacy-encounter-ineligible',
    1,
    jsonb_build_object(
      'kind', 'not',
      'child', jsonb_build_object(
        'kind', 'leaf',
        'leaf_kind', 'legacy_encounter_eligible',
        'payload', jsonb_build_object('compatibility_only', TRUE)
      )
    )
  )
ON CONFLICT DO NOTHING;

-- Candidates may only be authored while their Selector is draft. A successful
-- rerun sees the active row and intentionally skips candidate insertion.
INSERT INTO public.v3_selectors (id, result_type, status)
VALUES (
  'selector:legacy-cell-encounter',
  'encounter_definition',
  'draft'
)
ON CONFLICT DO NOTHING;

WITH catalog(slug) AS (
  VALUES
    ('amberwing_warbler'),
    ('red_fox'),
    ('monarch_butterfly'),
    ('painted_turtle'),
    ('snowshoe_hare'),
    ('brook_trout'),
    ('great_blue_heron'),
    ('eastern_chipmunk')
)
INSERT INTO public.v3_encounter_definitions (id)
SELECT 'encounter:fauna:' || slug
FROM catalog
ON CONFLICT DO NOTHING;

-- Encounter children are immutable after publication, so seed a draft Version,
-- then its Option and Outcome, and only then publish it.
WITH catalog(slug, display_name) AS (
  VALUES
    ('amberwing_warbler', 'Amberwing Warbler Sighting'),
    ('red_fox', 'Red Fox Sighting'),
    ('monarch_butterfly', 'Monarch Butterfly Sighting'),
    ('painted_turtle', 'Painted Turtle Sighting'),
    ('snowshoe_hare', 'Snowshoe Hare Sighting'),
    ('brook_trout', 'Brook Trout Sighting'),
    ('great_blue_heron', 'Great Blue Heron Sighting'),
    ('eastern_chipmunk', 'Eastern Chipmunk Sighting')
)
INSERT INTO public.v3_encounter_definition_versions (
  id,
  encounter_definition_id,
  revision,
  publication_status,
  display_name,
  is_automatic,
  eligibility_condition_id
)
SELECT
  md5('earthnova:legacy-encounter-version:' || slug)::uuid,
  'encounter:fauna:' || slug,
  1,
  'draft',
  display_name,
  TRUE,
  NULL
FROM catalog
ON CONFLICT DO NOTHING;

WITH catalog(slug, display_name) AS (
  VALUES
    ('amberwing_warbler', 'Observe Amberwing Warbler'),
    ('red_fox', 'Observe Red Fox'),
    ('monarch_butterfly', 'Observe Monarch Butterfly'),
    ('painted_turtle', 'Observe Painted Turtle'),
    ('snowshoe_hare', 'Observe Snowshoe Hare'),
    ('brook_trout', 'Observe Brook Trout'),
    ('great_blue_heron', 'Observe Great Blue Heron'),
    ('eastern_chipmunk', 'Observe Eastern Chipmunk')
)
INSERT INTO public.v3_encounter_options (
  id,
  encounter_definition_version_id,
  ordinal,
  display_name,
  condition_id,
  is_implicit
)
SELECT
  md5('earthnova:legacy-encounter-option:' || catalog.slug)::uuid,
  md5('earthnova:legacy-encounter-version:' || catalog.slug)::uuid,
  0,
  catalog.display_name,
  NULL,
  TRUE
FROM catalog
JOIN public.v3_encounter_definition_versions AS version
  ON version.id = md5('earthnova:legacy-encounter-version:' || catalog.slug)::uuid
 AND version.publication_status = 'draft'
ON CONFLICT DO NOTHING;

WITH catalog(slug, base_item_id) AS (
  VALUES
    ('amberwing_warbler', 'fauna:amberwing_warbler'),
    ('red_fox', 'fauna:red_fox'),
    ('monarch_butterfly', 'fauna:monarch_butterfly'),
    ('painted_turtle', 'fauna:painted_turtle'),
    ('snowshoe_hare', 'fauna:snowshoe_hare'),
    ('brook_trout', 'fauna:brook_trout'),
    ('great_blue_heron', 'fauna:great_blue_heron'),
    ('eastern_chipmunk', 'fauna:eastern_chipmunk')
)
INSERT INTO public.v3_encounter_outcomes (
  id,
  encounter_option_id,
  ordinal,
  kind,
  payload
)
SELECT
  md5('earthnova:legacy-encounter-outcome:' || catalog.slug)::uuid,
  md5('earthnova:legacy-encounter-option:' || catalog.slug)::uuid,
  0,
  'generate_item',
  jsonb_build_object('base_item_id', catalog.base_item_id)
FROM catalog
JOIN public.v3_encounter_definition_versions AS version
  ON version.id = md5('earthnova:legacy-encounter-version:' || catalog.slug)::uuid
 AND version.publication_status = 'draft'
ON CONFLICT DO NOTHING;

DO $publish_legacy_encounter_versions$
DECLARE
  catalog_entry RECORD;
BEGIN
  FOR catalog_entry IN
    SELECT definition.id AS encounter_definition_id, version.id AS version_id
    FROM public.v3_encounter_definitions AS definition
    JOIN public.v3_encounter_definition_versions AS version
      ON version.encounter_definition_id = definition.id
    WHERE definition.id IN (
      'encounter:fauna:amberwing_warbler',
      'encounter:fauna:red_fox',
      'encounter:fauna:monarch_butterfly',
      'encounter:fauna:painted_turtle',
      'encounter:fauna:snowshoe_hare',
      'encounter:fauna:brook_trout',
      'encounter:fauna:great_blue_heron',
      'encounter:fauna:eastern_chipmunk'
    )
      AND version.revision = 1
      AND version.publication_status = 'draft'
  LOOP
    PERFORM public.publish_v3_encounter_definition_version(
      catalog_entry.encounter_definition_id,
      catalog_entry.version_id
    );
  END LOOP;
END;
$publish_legacy_encounter_versions$;

WITH catalog(slug, ordinal) AS (
  VALUES
    ('amberwing_warbler', 0),
    ('red_fox', 1),
    ('monarch_butterfly', 2),
    ('painted_turtle', 3),
    ('snowshoe_hare', 4),
    ('brook_trout', 5),
    ('great_blue_heron', 6),
    ('eastern_chipmunk', 7)
)
INSERT INTO public.v3_selector_candidates (
  id,
  selector_id,
  ordinal,
  weight,
  condition_id,
  result_kind,
  result_id
)
SELECT
  md5('earthnova:legacy-encounter-selector-candidate:' || catalog.slug)::uuid,
  'selector:legacy-cell-encounter',
  catalog.ordinal,
  1,
  'condition:legacy-encounter-eligible',
  'value',
  'encounter:fauna:' || catalog.slug
FROM catalog
JOIN public.v3_selectors AS selector
  ON selector.id = 'selector:legacy-cell-encounter'
 AND selector.status = 'draft'
ON CONFLICT DO NOTHING;

INSERT INTO public.v3_selector_candidates (
  id,
  selector_id,
  ordinal,
  weight,
  condition_id,
  result_kind,
  result_id
)
SELECT
  md5('earthnova:legacy-encounter-selector-candidate:none')::uuid,
  'selector:legacy-cell-encounter',
  8,
  1,
  'condition:legacy-encounter-ineligible',
  'none',
  NULL
FROM public.v3_selectors AS selector
WHERE selector.id = 'selector:legacy-cell-encounter'
  AND selector.status = 'draft'
ON CONFLICT DO NOTHING;

UPDATE public.v3_selectors
SET status = 'active'
WHERE id = 'selector:legacy-cell-encounter'
  AND status = 'draft';

DO $validate_legacy_encounter_catalog$
DECLARE
  definition_count INTEGER;
  version_count INTEGER;
  option_count INTEGER;
  outcome_count INTEGER;
  candidate_count INTEGER;
BEGIN
  PERFORM public.v3_assert_selector_has_candidates(
    'selector:legacy-cell-encounter'
  );

  SELECT count(*)
  INTO definition_count
  FROM public.v3_encounter_definitions
  WHERE id IN (
    'encounter:fauna:amberwing_warbler',
    'encounter:fauna:red_fox',
    'encounter:fauna:monarch_butterfly',
    'encounter:fauna:painted_turtle',
    'encounter:fauna:snowshoe_hare',
    'encounter:fauna:brook_trout',
    'encounter:fauna:great_blue_heron',
    'encounter:fauna:eastern_chipmunk'
  );

  SELECT count(*)
  INTO version_count
  FROM public.v3_encounter_definition_versions
  WHERE encounter_definition_id IN (
    'encounter:fauna:amberwing_warbler',
    'encounter:fauna:red_fox',
    'encounter:fauna:monarch_butterfly',
    'encounter:fauna:painted_turtle',
    'encounter:fauna:snowshoe_hare',
    'encounter:fauna:brook_trout',
    'encounter:fauna:great_blue_heron',
    'encounter:fauna:eastern_chipmunk'
  )
    AND revision = 1
    AND publication_status = 'published';

  SELECT count(*)
  INTO option_count
  FROM public.v3_encounter_options
  WHERE id IN (
    md5('earthnova:legacy-encounter-option:amberwing_warbler')::uuid,
    md5('earthnova:legacy-encounter-option:red_fox')::uuid,
    md5('earthnova:legacy-encounter-option:monarch_butterfly')::uuid,
    md5('earthnova:legacy-encounter-option:painted_turtle')::uuid,
    md5('earthnova:legacy-encounter-option:snowshoe_hare')::uuid,
    md5('earthnova:legacy-encounter-option:brook_trout')::uuid,
    md5('earthnova:legacy-encounter-option:great_blue_heron')::uuid,
    md5('earthnova:legacy-encounter-option:eastern_chipmunk')::uuid
  )
    AND ordinal = 0
    AND is_implicit = TRUE;

  SELECT count(*)
  INTO outcome_count
  FROM public.v3_encounter_outcomes
  WHERE id IN (
    md5('earthnova:legacy-encounter-outcome:amberwing_warbler')::uuid,
    md5('earthnova:legacy-encounter-outcome:red_fox')::uuid,
    md5('earthnova:legacy-encounter-outcome:monarch_butterfly')::uuid,
    md5('earthnova:legacy-encounter-outcome:painted_turtle')::uuid,
    md5('earthnova:legacy-encounter-outcome:snowshoe_hare')::uuid,
    md5('earthnova:legacy-encounter-outcome:brook_trout')::uuid,
    md5('earthnova:legacy-encounter-outcome:great_blue_heron')::uuid,
    md5('earthnova:legacy-encounter-outcome:eastern_chipmunk')::uuid
  )
    AND ordinal = 0
    AND kind = 'generate_item';

  SELECT count(*)
  INTO candidate_count
  FROM public.v3_selector_candidates
  WHERE selector_id = 'selector:legacy-cell-encounter';

  IF definition_count <> 8
     OR version_count <> 8
     OR option_count <> 8
     OR outcome_count <> 8
     OR candidate_count <> 9 THEN
    RAISE EXCEPTION
      'Legacy Encounter compatibility seed incomplete: definitions %, versions %, options %, outcomes %, candidates %',
      definition_count,
      version_count,
      option_count,
      outcome_count,
      candidate_count;
  END IF;
END;
$validate_legacy_encounter_catalog$;
