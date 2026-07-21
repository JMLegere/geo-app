-- Migration 089: derive every newly created Item's Identification lifecycle from
-- durable Player knowledge and its exact immutable Base Item Version.
--
-- This migration never rewrites an existing Item.  The trigger is shared by the
-- legacy compatibility acquisition command and authoritative Encounter outcome
-- creation, so callers cannot choose an Identification lifecycle.

CREATE OR REPLACE FUNCTION public.v3_item_identification_required(
  p_user_id UUID,
  p_base_item_id TEXT,
  p_base_item_version_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
BEGIN
  -- An Item's bound Version is authoritative.  In particular, never consult the
  -- Base Item's current publication pointer here: it can change after an Item
  -- was created.
  PERFORM 1
  FROM public.v3_base_item_versions AS base_item_version
  WHERE base_item_version.id = p_base_item_version_id
    AND base_item_version.base_item_id = p_base_item_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'Item must bind an exact Base Item Version owned by its Base Item'
      USING ERRCODE = '23503';
  END IF;

  RETURN NOT EXISTS (
    SELECT 1
    FROM public.v3_item_discoveries AS discovery
    WHERE discovery.user_id = p_user_id
      AND discovery.base_item_id = p_base_item_id
  ) OR EXISTS (
    SELECT 1
    FROM public.v3_base_item_version_variable_properties AS assignment
    WHERE assignment.base_item_version_id = p_base_item_version_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.v3_derive_item_identification_on_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_base_item_category TEXT;
  v_base_item_version public.v3_base_item_versions%ROWTYPE;
  v_snapshot JSONB;
  v_requires_identification BOOLEAN;
  v_canonical_display_name TEXT;
  v_canonical_scientific_name TEXT;
  v_canonical_taxonomic_class TEXT;
  v_canonical_habitats_json TEXT;
  v_canonical_continents_json TEXT;
BEGIN
  SELECT base_item.category
  INTO v_base_item_category
  FROM public.v3_base_items AS base_item
  WHERE base_item.id = NEW.base_item_id;

  SELECT base_item_version.*
  INTO v_base_item_version
  FROM public.v3_base_item_versions AS base_item_version
  WHERE base_item_version.id = NEW.base_item_version_id
    AND base_item_version.base_item_id = NEW.base_item_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'Item must bind an exact Base Item Version owned by its Base Item'
      USING ERRCODE = '23503';
  END IF;

  v_requires_identification := public.v3_item_identification_required(
    NEW.user_id,
    NEW.base_item_id,
    NEW.base_item_version_id
  );
  v_snapshot := v_base_item_version.authored_content -> 'legacy_item_snapshot';

  -- Legacy authored Identification evidence wins, followed by hidden pending
  -- Item evidence.  Exact Version evidence is next, then the incoming Item
  -- projection is only a last-resort compatibility fallback.
  v_canonical_display_name := COALESCE(
    NULLIF(v_snapshot ->> 'identified_display_name', ''),
    NULLIF(NEW.identified_display_name, ''),
    NULLIF(v_base_item_version.display_name, ''),
    NULLIF(NEW.display_name, '')
  );
  v_canonical_scientific_name := COALESCE(
    NULLIF(v_snapshot ->> 'identified_scientific_name', ''),
    NULLIF(NEW.identified_scientific_name, ''),
    NULLIF(v_base_item_version.scientific_name, ''),
    NULLIF(NEW.scientific_name, '')
  );
  v_canonical_taxonomic_class := COALESCE(
    NULLIF(v_snapshot ->> 'identified_taxonomic_class', ''),
    NULLIF(NEW.identified_taxonomic_class, ''),
    NULLIF(v_base_item_version.authored_content #>> '{legacy_catalog_snapshot,taxonomic_class}', ''),
    NULLIF(v_base_item_version.authored_content #>> '{legacy_item_snapshot,taxonomic_class}', ''),
    NULLIF(NEW.taxonomic_class, '')
  );
  v_canonical_habitats_json := COALESCE(
    NULLIF(v_snapshot ->> 'identified_habitats_json', ''),
    NULLIF(NEW.identified_habitats_json, ''),
    NULLIF(v_base_item_version.authored_content #>> '{legacy_catalog_snapshot,habitats}', ''),
    NULLIF(v_base_item_version.authored_content #>> '{legacy_item_snapshot,habitats_json}', ''),
    NULLIF(NEW.habitats_json, '')
  );
  v_canonical_continents_json := COALESCE(
    NULLIF(v_snapshot ->> 'identified_continents_json', ''),
    NULLIF(NEW.identified_continents_json, ''),
    NULLIF(v_base_item_version.authored_content #>> '{legacy_catalog_snapshot,continents}', ''),
    NULLIF(v_base_item_version.authored_content #>> '{legacy_item_snapshot,continents_json}', ''),
    NULLIF(NEW.continents_json, '')
  );

  -- The exact Base Item binding owns category too.  This lets the hidden state
  -- expose a useful category without trusting a command's display projection.
  NEW.category := v_base_item_category;
  NEW.identified_display_name := v_canonical_display_name;
  NEW.identified_scientific_name := v_canonical_scientific_name;
  NEW.identified_taxonomic_class := v_canonical_taxonomic_class;
  NEW.identified_habitats_json := v_canonical_habitats_json;
  NEW.identified_continents_json := v_canonical_continents_json;

  IF v_requires_identification THEN
    -- Do not leak the canonical projection before the Identification command.
    NEW.identification_state := 'unidentified';
    NEW.identified_at := NULL;
    NEW.display_name := 'Unidentified ' || v_base_item_category || ' specimen';
    NEW.scientific_name := NULL;
    NEW.taxonomic_class := NULL;
    NEW.habitats_json := '[]';
    NEW.continents_json := '[]';
  ELSE
    NEW.identification_state := 'identified';
    NEW.identified_at := now();
    NEW.display_name := COALESCE(
      v_canonical_display_name,
      'Identified ' || initcap(v_base_item_category)
    );
    NEW.scientific_name := v_canonical_scientific_name;
    NEW.taxonomic_class := v_canonical_taxonomic_class;
    NEW.habitats_json := COALESCE(v_canonical_habitats_json, '[]');
    NEW.continents_json := COALESCE(v_canonical_continents_json, '[]');
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS v3_items_derive_identification_on_insert
  ON public.v3_items;

CREATE TRIGGER v3_items_derive_identification_on_insert
BEFORE INSERT ON public.v3_items
FOR EACH ROW
EXECUTE FUNCTION public.v3_derive_item_identification_on_insert();

CREATE OR REPLACE FUNCTION public.v3_commit_automatic_item_identification()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.identification_state <> 'identified' THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.v3_item_identification_commits (
    item_id,
    user_id,
    base_item_id,
    base_item_version_id,
    identification_kind,
    resolution_plan,
    committed_at
  )
  VALUES (
    NEW.id,
    NEW.user_id,
    NEW.base_item_id,
    NEW.base_item_version_id,
    'automatic',
    '[]'::jsonb,
    NEW.identified_at
  )
  ON CONFLICT (item_id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS v3_items_commit_automatic_identification_on_insert
  ON public.v3_items;

CREATE TRIGGER v3_items_commit_automatic_identification_on_insert
AFTER INSERT ON public.v3_items
FOR EACH ROW
EXECUTE FUNCTION public.v3_commit_automatic_item_identification();

-- Keep this private read-side aggregate unchanged except for the generated Item
-- lifecycle fields.  Its joins retain each generated Item's exact Version and
-- revision rather than resolving a current Base Item Version.
CREATE OR REPLACE FUNCTION public.v3_encounter_runtime_aggregate(
  p_cell_visit_id UUID
)
RETURNS JSONB
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'cell_visit_resolution', (
      SELECT jsonb_build_object(
        'id', resolution.id,
        'cell_visit_id', resolution.cell_visit_id,
        'selector_id', resolution.selector_id,
        'selector_candidate_id', resolution.selector_candidate_id,
        'resolution_kind', resolution.resolution_kind,
        'encounter_definition_id', resolution.encounter_definition_id,
        'resolved_at', resolution.resolved_at
      )
      FROM public.v3_cell_visit_resolutions AS resolution
      WHERE resolution.cell_visit_id = p_cell_visit_id
    ),
    'encounter', (
      SELECT jsonb_build_object(
        'id', encounter.id,
        'cell_visit_id', encounter.cell_visit_id,
        'cell_visit_resolution_id', encounter.cell_visit_resolution_id,
        'encounter_definition_id', encounter.encounter_definition_id,
        'encounter_definition_version_id', encounter.encounter_definition_version_id,
        'encounter_definition_revision', encounter_version.revision,
        'selected_option_id', encounter.selected_option_id,
        'resolution_status', encounter.resolution_status,
        'created_at', encounter.created_at,
        'resolved_at', encounter.resolved_at,
        'failure_code', encounter.failure_code,
        'failure_details', encounter.failure_details
      )
      FROM public.v3_encounters AS encounter
      JOIN public.v3_encounter_definition_versions AS encounter_version
        ON encounter_version.id = encounter.encounter_definition_version_id
        AND encounter_version.encounter_definition_id = encounter.encounter_definition_id
      WHERE encounter.cell_visit_id = p_cell_visit_id
    ),
    'outcome_results', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', result.id,
          'encounter_id', result.encounter_id,
          'outcome_ordinal', result.outcome_ordinal,
          'encounter_outcome_id', result.encounter_outcome_id,
          'outcome_kind', result.outcome_kind,
          'resolved_base_item_version_id', result.resolved_base_item_version_id,
          'resolved_base_item_id', resolved_base_item_version.base_item_id,
          'resolved_base_item_revision', resolved_base_item_version.revision,
          'generated_item_id', result.generated_item_id,
          'created_at', result.created_at
        )
        ORDER BY result.outcome_ordinal
      )
      FROM public.v3_encounter_outcome_results AS result
      JOIN public.v3_encounters AS encounter
        ON encounter.id = result.encounter_id
      LEFT JOIN public.v3_base_item_versions AS resolved_base_item_version
        ON resolved_base_item_version.id = result.resolved_base_item_version_id
      WHERE encounter.cell_visit_id = p_cell_visit_id
    ), '[]'::jsonb),
    'generated_items', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', item.id,
          'user_id', item.user_id,
          'definition_id', item.definition_id,
          'display_name', item.display_name,
          'scientific_name', item.scientific_name,
          'category', item.category,
          'acquired_at', item.acquired_at,
          'acquired_in_cell_id', item.acquired_in_cell_id,
          'status', item.status,
          'identification_state', item.identification_state,
          'identified_at', item.identified_at,
          'base_item_id', item.base_item_id,
          'base_item_version_id', item.base_item_version_id,
          'base_item_revision', item_base_item_version.revision
        )
        ORDER BY result.outcome_ordinal
      )
      FROM public.v3_encounter_outcome_results AS result
      JOIN public.v3_encounters AS encounter
        ON encounter.id = result.encounter_id
      JOIN public.v3_items AS item
        ON item.id = result.generated_item_id
      JOIN public.v3_base_item_versions AS item_base_item_version
        ON item_base_item_version.id = item.base_item_version_id
        AND item_base_item_version.base_item_id = item.base_item_id
      WHERE encounter.cell_visit_id = p_cell_visit_id
    ), '[]'::jsonb)
  );
$$;

REVOKE ALL ON FUNCTION public.v3_item_identification_required(UUID, TEXT, UUID)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_derive_item_identification_on_insert()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_commit_automatic_item_identification()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_encounter_runtime_aggregate(UUID)
  FROM PUBLIC, anon, authenticated;
