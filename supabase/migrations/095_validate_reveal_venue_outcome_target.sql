-- Migration 095: validate authored Outcome stable targets.
--
-- Draft Encounter Outcomes may reference a Venue before it has a published
-- Version, but they must never reference a nonexistent stable Venue identity.
-- Keep the existing Generate Item identity validation byte-for-byte equivalent.

CREATE OR REPLACE FUNCTION public.v3_validate_encounter_outcome_base_item()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.kind = 'generate_item' AND NOT EXISTS (
    SELECT 1
    FROM public.v3_base_items
    WHERE id = NEW.payload ->> 'base_item_id'
  ) THEN
    RAISE EXCEPTION 'Generate Item Outcome must reference an existing Base Item %',
      NEW.payload ->> 'base_item_id'
      USING ERRCODE = '23503';
  END IF;

  IF NEW.kind = 'reveal_venue' AND NOT EXISTS (
    SELECT 1
    FROM public.v3_venues
    WHERE id = NEW.payload ->> 'venue_id'
  ) THEN
    RAISE EXCEPTION 'Reveal Venue Outcome must reference an existing Venue %',
      NEW.payload ->> 'venue_id'
      USING ERRCODE = '23503';
  END IF;

  RETURN NEW;
END;
$$;

-- Trigger helpers remain internal; encounter publication remains an authoring
-- command available only to the trusted server role.
REVOKE ALL ON FUNCTION public.v3_validate_encounter_outcome_base_item()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.publish_v3_encounter_definition_version(TEXT, UUID)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.publish_v3_encounter_definition_version(TEXT, UUID)
  TO service_role;
