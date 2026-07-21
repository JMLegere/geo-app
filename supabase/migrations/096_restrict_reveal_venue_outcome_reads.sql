-- Reveal Venue Outcomes contain a target identity that is player-private until
-- the corresponding Venue is known. Published authored content remains readable
-- for every other Outcome kind, and for Reveal rows only after that exact target
-- is known by the authenticated Player.
DROP POLICY IF EXISTS "v3_encounter_outcomes_authenticated_read"
  ON public.v3_encounter_outcomes;

CREATE POLICY "v3_encounter_outcomes_authenticated_read"
  ON public.v3_encounter_outcomes
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.v3_encounter_options AS option
      JOIN public.v3_encounter_definition_versions AS version
        ON version.id = option.encounter_definition_version_id
      WHERE option.id = encounter_option_id
        AND version.publication_status IN ('published', 'retired')
    )
    AND (
      kind <> 'reveal_venue'
      OR EXISTS (
        SELECT 1
        FROM public.v3_player_known_venues AS known
        WHERE known.user_id = auth.uid()
          AND known.venue_id = payload ->> 'venue_id'
      )
    )
  );
