-- Migration 082: repair effective remote function grants.
--
-- Supabase grants newly created public functions directly to anon and
-- authenticated. Revoking PUBLIC alone therefore does not make helper or
-- publication functions private. This migration is grant-only and replay-safe.

REVOKE ALL ON FUNCTION public.publish_v3_base_item_version(TEXT, UUID)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.publish_v3_encounter_definition_version(TEXT, UUID)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.publish_v3_base_item_version(TEXT, UUID)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.publish_v3_encounter_definition_version(TEXT, UUID)
  TO service_role;

REVOKE ALL ON FUNCTION public.resolve_v3_cell_visit_encounter(UUID, TEXT, UUID, UUID)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.resolve_v3_encounter_outcomes(UUID, UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolve_v3_cell_visit_encounter(UUID, TEXT, UUID, UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_v3_encounter_outcomes(UUID, UUID)
  TO authenticated;

REVOKE ALL ON FUNCTION public.v3_encounter_runtime_aggregate(UUID)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_validate_encounter_outcome_result()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_limit_encounter_mutation()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_prevent_cell_visit_resolution_mutation()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_prevent_encounter_outcome_result_mutation()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_validate_cell_visit_resolution()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_validate_encounter_binding()
  FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.prevent_published_v3_base_item_version_mutation()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.prevent_v3_base_item_identity_mutation()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.prevent_published_v3_encounter_definition_version_mutation()
  FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.v3_assert_selector_has_candidates(TEXT)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_condition_ast_contains_executable_key(JSONB)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_encounter_payload_contains_executable_key(JSONB)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_validate_condition_ast(JSONB)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_validate_encounter_outcome_payload(TEXT, JSONB)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_validate_automatic_encounter_options(UUID, BOOLEAN)
  FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.v3_limit_selector_mutation()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_prevent_condition_mutation()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_prevent_property_value_mutation()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_prevent_selector_candidate_mutation()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_prevent_variable_property_mutation()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_require_draft_base_item_version_variable_property()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_require_draft_encounter_option()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_require_draft_encounter_outcome()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_require_draft_selector_candidate()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_validate_encounter_definition_version_options()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_validate_encounter_option_structure()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_validate_encounter_outcome_base_item()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_validate_selector_activation()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_validate_variable_property_selector()
  FROM PUBLIC, anon, authenticated;
