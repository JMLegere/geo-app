-- Migration 107: let examined legacy Item snapshots use newly enriched species media.
--
-- Encounter Item rows may retain a generic acquisition snapshot. Examination
-- reveals the immutable Base Item Version identity without exposing Variable
-- Property Values owned by the separate Identification Service.

CREATE OR REPLACE FUNCTION public.v3_safe_item_projection(p_item public.v3_items)
RETURNS JSONB
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_item.identification_state = 'identified' THEN
      jsonb_strip_nulls(jsonb_build_object(
        'id', p_item.id,
        'definition_id', p_item.definition_id,
        'base_item_id', p_item.base_item_id,
        'base_item_version_id', p_item.base_item_version_id,
        'display_name', p_item.display_name,
        'scientific_name', p_item.scientific_name,
        'category', p_item.category,
        'rarity', p_item.rarity,
        'icon_url', COALESCE(p_item.icon_url, (SELECT species.icon_url FROM public.species AS species WHERE species.definition_id = p_item.definition_id)),
        'icon_url_frame2', COALESCE(p_item.icon_url_frame2, (SELECT species.icon_url_frame2 FROM public.species AS species WHERE species.definition_id = p_item.definition_id)),
        'art_url', COALESCE(p_item.art_url, (SELECT species.art_url FROM public.species AS species WHERE species.definition_id = p_item.definition_id)),
        'acquired_at', p_item.acquired_at,
        'acquired_in_cell_id', p_item.acquired_in_cell_id,
        'status', p_item.status,
        'taxonomic_class', p_item.taxonomic_class,
        'habitats_json', p_item.habitats_json,
        'continents_json', p_item.continents_json,
        'identification_state', p_item.identification_state,
        'identified_at', p_item.identified_at,
        'examination_state', 'examined',
        'examined_at', (
          SELECT entry.examined_at
          FROM public.v3_player_base_item_journal_entries AS entry
          WHERE entry.user_id = p_item.user_id
            AND entry.base_item_id = p_item.base_item_id
        )
      ))
    WHEN EXISTS (
      SELECT 1
      FROM public.v3_player_base_item_journal_entries AS entry
      WHERE entry.user_id = p_item.user_id
        AND entry.base_item_id = p_item.base_item_id
    ) THEN
      jsonb_strip_nulls(jsonb_build_object(
        'id', p_item.id,
        'definition_id', p_item.definition_id,
        'base_item_id', p_item.base_item_id,
        'base_item_version_id', p_item.base_item_version_id,
        'display_name', (
          SELECT version.display_name
          FROM public.v3_base_item_versions AS version
          WHERE version.id = p_item.base_item_version_id
            AND version.base_item_id = p_item.base_item_id
        ),
        'scientific_name', (
          SELECT version.scientific_name
          FROM public.v3_base_item_versions AS version
          WHERE version.id = p_item.base_item_version_id
            AND version.base_item_id = p_item.base_item_id
        ),
        'category', p_item.category,
        'rarity', p_item.rarity,
        'icon_url', COALESCE(p_item.icon_url, (SELECT species.icon_url FROM public.species AS species WHERE species.definition_id = p_item.definition_id)),
        'icon_url_frame2', COALESCE(p_item.icon_url_frame2, (SELECT species.icon_url_frame2 FROM public.species AS species WHERE species.definition_id = p_item.definition_id)),
        'art_url', COALESCE(p_item.art_url, (SELECT species.art_url FROM public.species AS species WHERE species.definition_id = p_item.definition_id)),
        'acquired_at', p_item.acquired_at,
        'acquired_in_cell_id', p_item.acquired_in_cell_id,
        'status', p_item.status,
        'taxonomic_class', p_item.taxonomic_class,
        'habitats_json', p_item.habitats_json,
        'continents_json', p_item.continents_json,
        'identification_state', 'unidentified',
        'examination_state', 'examined',
        'examined_at', (
          SELECT entry.examined_at
          FROM public.v3_player_base_item_journal_entries AS entry
          WHERE entry.user_id = p_item.user_id
            AND entry.base_item_id = p_item.base_item_id
        )
      ))
    ELSE
      jsonb_build_object(
        'id', p_item.id,
        'display_name', 'Unidentified ' || lower(p_item.category) || ' specimen',
        'category', p_item.category,
        'acquired_at', p_item.acquired_at,
        'acquired_in_cell_id', p_item.acquired_in_cell_id,
        'status', p_item.status,
        'identification_state', 'unidentified',
        'examination_state', 'unexamined',
        'examined_at', NULL
      )
  END;
$$;

REVOKE ALL ON FUNCTION public.v3_safe_item_projection(public.v3_items)
  FROM PUBLIC, anon, authenticated;
