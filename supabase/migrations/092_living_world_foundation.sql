-- Migration 092: durable Living World authored content and Player knowledge.
--
-- Venue, Villager, and Service are stable authored identities. Their published
-- versions are immutable, while Player knowledge and Venue Visits preserve the
-- exact version and provenance that first created state. Town is a projection,
-- never a stored geographic or player-owned entity.

CREATE TABLE IF NOT EXISTS public.v3_venues (
  id TEXT PRIMARY KEY CHECK (btrim(id) <> ''),
  current_published_version_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.v3_venue_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id TEXT NOT NULL REFERENCES public.v3_venues(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  revision INTEGER NOT NULL CHECK (revision > 0),
  publication_status TEXT NOT NULL DEFAULT 'draft' CHECK (
    publication_status IN ('draft', 'published', 'retired')
  ),
  published_at TIMESTAMPTZ,
  retired_at TIMESTAMPTZ,
  kind TEXT NOT NULL CHECK (btrim(kind) <> ''),
  display_name TEXT NOT NULL CHECK (btrim(display_name) <> ''),
  city_id TEXT NOT NULL CHECK (btrim(city_id) <> ''),
  anchor_cell_id TEXT NOT NULL CHECK (btrim(anchor_cell_id) <> ''),
  authored_content JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (venue_id, revision),
  UNIQUE (venue_id, id),
  CHECK (
    (publication_status = 'draft' AND published_at IS NULL AND retired_at IS NULL)
    OR (publication_status = 'published' AND published_at IS NOT NULL AND retired_at IS NULL)
    OR (publication_status = 'retired' AND published_at IS NOT NULL AND retired_at IS NOT NULL)
  )
);

CREATE TABLE IF NOT EXISTS public.v3_villagers (
  id TEXT PRIMARY KEY CHECK (btrim(id) <> ''),
  current_published_version_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.v3_villager_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  villager_id TEXT NOT NULL REFERENCES public.v3_villagers(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  revision INTEGER NOT NULL CHECK (revision > 0),
  publication_status TEXT NOT NULL DEFAULT 'draft' CHECK (
    publication_status IN ('draft', 'published', 'retired')
  ),
  published_at TIMESTAMPTZ,
  retired_at TIMESTAMPTZ,
  display_name TEXT NOT NULL CHECK (btrim(display_name) <> ''),
  role_name TEXT NOT NULL CHECK (btrim(role_name) <> ''),
  authored_content JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (villager_id, revision),
  UNIQUE (villager_id, id),
  CHECK (
    (publication_status = 'draft' AND published_at IS NULL AND retired_at IS NULL)
    OR (publication_status = 'published' AND published_at IS NOT NULL AND retired_at IS NULL)
    OR (publication_status = 'retired' AND published_at IS NOT NULL AND retired_at IS NOT NULL)
  )
);

CREATE TABLE IF NOT EXISTS public.v3_services (
  id TEXT PRIMARY KEY CHECK (btrim(id) <> ''),
  current_published_version_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.v3_service_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id TEXT NOT NULL REFERENCES public.v3_services(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  revision INTEGER NOT NULL CHECK (revision > 0),
  publication_status TEXT NOT NULL DEFAULT 'draft' CHECK (
    publication_status IN ('draft', 'published', 'retired')
  ),
  published_at TIMESTAMPTZ,
  retired_at TIMESTAMPTZ,
  display_name TEXT NOT NULL CHECK (btrim(display_name) <> ''),
  description TEXT NOT NULL CHECK (btrim(description) <> ''),
  authored_content JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (service_id, revision),
  UNIQUE (service_id, id),
  CHECK (
    (publication_status = 'draft' AND published_at IS NULL AND retired_at IS NULL)
    OR (publication_status = 'published' AND published_at IS NOT NULL AND retired_at IS NULL)
    OR (publication_status = 'retired' AND published_at IS NOT NULL AND retired_at IS NOT NULL)
  )
);

DO $add_v3_venue_current_version_owner_fk$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'v3_venues_current_version_owner_fk' AND conrelid = 'public.v3_venues'::regclass) THEN
    ALTER TABLE public.v3_venues ADD CONSTRAINT v3_venues_current_version_owner_fk
      FOREIGN KEY (id, current_published_version_id)
      REFERENCES public.v3_venue_versions(venue_id, id)
      DEFERRABLE INITIALLY DEFERRED;
  END IF;
END;
$add_v3_venue_current_version_owner_fk$;

DO $add_v3_villager_current_version_owner_fk$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'v3_villagers_current_version_owner_fk' AND conrelid = 'public.v3_villagers'::regclass) THEN
    ALTER TABLE public.v3_villagers ADD CONSTRAINT v3_villagers_current_version_owner_fk
      FOREIGN KEY (id, current_published_version_id)
      REFERENCES public.v3_villager_versions(villager_id, id)
      DEFERRABLE INITIALLY DEFERRED;
  END IF;
END;
$add_v3_villager_current_version_owner_fk$;

DO $add_v3_service_current_version_owner_fk$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'v3_services_current_version_owner_fk' AND conrelid = 'public.v3_services'::regclass) THEN
    ALTER TABLE public.v3_services ADD CONSTRAINT v3_services_current_version_owner_fk
      FOREIGN KEY (id, current_published_version_id)
      REFERENCES public.v3_service_versions(service_id, id)
      DEFERRABLE INITIALLY DEFERRED;
  END IF;
END;
$add_v3_service_current_version_owner_fk$;

-- Associations belong to an authored Version, rather than a mutable Venue or
-- Villager identity. Ordinal is domain-significant and supplies stable roster
-- order when a visit introduces a Player to a new Villager.
CREATE TABLE IF NOT EXISTS public.v3_venue_version_villagers (
  venue_version_id UUID NOT NULL REFERENCES public.v3_venue_versions(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  villager_id TEXT NOT NULL REFERENCES public.v3_villagers(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  ordinal INTEGER NOT NULL CHECK (ordinal > 0),
  PRIMARY KEY (venue_version_id, villager_id),
  UNIQUE (venue_version_id, ordinal)
);

CREATE TABLE IF NOT EXISTS public.v3_villager_version_services (
  villager_version_id UUID NOT NULL REFERENCES public.v3_villager_versions(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  service_id TEXT NOT NULL REFERENCES public.v3_services(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  ordinal INTEGER NOT NULL CHECK (ordinal > 0),
  PRIMARY KEY (villager_version_id, service_id),
  UNIQUE (villager_version_id, ordinal)
);

CREATE TABLE IF NOT EXISTS public.v3_venue_legacy_aliases (
  legacy_venue_id TEXT PRIMARY KEY CHECK (btrim(legacy_venue_id) <> ''),
  venue_id TEXT NOT NULL REFERENCES public.v3_venues(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- A known Venue is exclusively provenance from an already committed Reveal
-- Venue Outcome. The trigger below verifies the result, its Player, and its
-- payload target; no seed or Venue Visit inserts a known Venue.
CREATE TABLE IF NOT EXISTS public.v3_player_known_venues (
  user_id UUID NOT NULL REFERENCES auth.users(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  venue_id TEXT NOT NULL REFERENCES public.v3_venues(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  first_venue_version_id UUID NOT NULL,
  reveal_outcome_result_id UUID NOT NULL REFERENCES public.v3_encounter_outcome_results(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  known_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, venue_id),
  CONSTRAINT v3_player_known_venues_first_version_owner_fk
    FOREIGN KEY (venue_id, first_venue_version_id)
    REFERENCES public.v3_venue_versions(venue_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT
);

-- The old Cell Visit key is deliberately augmented, never rewritten, so a
-- Venue Visit can prove its exact owned Cell Visit and anchor Cell in one FK.
DO $add_v3_cell_visits_exact_owned_cell_unique$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'v3_cell_visits_exact_owned_cell_unique' AND conrelid = 'public.v3_cell_visits'::regclass) THEN
    ALTER TABLE public.v3_cell_visits ADD CONSTRAINT v3_cell_visits_exact_owned_cell_unique
      UNIQUE (id, user_id, cell_id);
  END IF;
END;
$add_v3_cell_visits_exact_owned_cell_unique$;

CREATE TABLE IF NOT EXISTS public.v3_venue_visits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  cell_visit_id UUID NOT NULL,
  cell_id TEXT NOT NULL,
  venue_id TEXT NOT NULL,
  venue_version_id UUID NOT NULL,
  visited_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, venue_id, cell_visit_id),
  UNIQUE (id, user_id, venue_id, venue_version_id),
  CONSTRAINT v3_venue_visits_exact_cell_visit_fk
    FOREIGN KEY (cell_visit_id, user_id, cell_id)
    REFERENCES public.v3_cell_visits(id, user_id, cell_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT v3_venue_visits_exact_venue_version_fk
    FOREIGN KEY (venue_id, venue_version_id)
    REFERENCES public.v3_venue_versions(venue_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT v3_venue_visits_known_venue_fk
    FOREIGN KEY (user_id, venue_id)
    REFERENCES public.v3_player_known_venues(user_id, venue_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS public.v3_player_known_villagers (
  user_id UUID NOT NULL REFERENCES auth.users(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  villager_id TEXT NOT NULL REFERENCES public.v3_villagers(id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  first_villager_version_id UUID NOT NULL,
  first_venue_visit_id UUID NOT NULL,
  first_venue_id TEXT NOT NULL,
  first_venue_version_id UUID NOT NULL,
  known_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, villager_id),
  CONSTRAINT v3_player_known_villagers_first_version_owner_fk
    FOREIGN KEY (villager_id, first_villager_version_id)
    REFERENCES public.v3_villager_versions(villager_id, id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT v3_player_known_villagers_first_visit_exact_fk
    FOREIGN KEY (first_venue_visit_id, user_id, first_venue_id, first_venue_version_id)
    REFERENCES public.v3_venue_visits(id, user_id, venue_id, venue_version_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT v3_player_known_villagers_first_venue_roster_fk
    FOREIGN KEY (first_venue_version_id, villager_id)
    REFERENCES public.v3_venue_version_villagers(venue_version_id, villager_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_v3_venue_versions_published
  ON public.v3_venue_versions(venue_id, publication_status, revision DESC);
CREATE INDEX IF NOT EXISTS idx_v3_villager_versions_published
  ON public.v3_villager_versions(villager_id, publication_status, revision DESC);
CREATE INDEX IF NOT EXISTS idx_v3_service_versions_published
  ON public.v3_service_versions(service_id, publication_status, revision DESC);
CREATE INDEX IF NOT EXISTS idx_v3_known_venues_user_known_at
  ON public.v3_player_known_venues(user_id, known_at);
CREATE INDEX IF NOT EXISTS idx_v3_known_villagers_user_known_at
  ON public.v3_player_known_villagers(user_id, known_at);
CREATE INDEX IF NOT EXISTS idx_v3_venue_visits_user_venue_visited_at
  ON public.v3_venue_visits(user_id, venue_id, visited_at);

CREATE OR REPLACE FUNCTION public.v3_prevent_living_world_identity_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' OR NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'Living World stable identities cannot be changed or deleted';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.v3_prevent_published_living_world_version_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF OLD.published_at IS NULL THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'DELETE'
     OR NEW.id IS DISTINCT FROM OLD.id
     OR NEW.revision IS DISTINCT FROM OLD.revision
     OR NEW.display_name IS DISTINCT FROM OLD.display_name
     OR NEW.authored_content IS DISTINCT FROM OLD.authored_content
     OR NEW.published_at IS DISTINCT FROM OLD.published_at THEN
    RAISE EXCEPTION 'Published Living World Versions are immutable';
  END IF;

  IF TG_TABLE_NAME = 'v3_venue_versions' THEN
    IF NEW.venue_id IS DISTINCT FROM OLD.venue_id
       OR NEW.kind IS DISTINCT FROM OLD.kind
       OR NEW.city_id IS DISTINCT FROM OLD.city_id
       OR NEW.anchor_cell_id IS DISTINCT FROM OLD.anchor_cell_id THEN
      RAISE EXCEPTION 'Published Living World Versions are immutable';
    END IF;
  ELSIF TG_TABLE_NAME = 'v3_villager_versions' THEN
    IF NEW.villager_id IS DISTINCT FROM OLD.villager_id
       OR NEW.role_name IS DISTINCT FROM OLD.role_name THEN
      RAISE EXCEPTION 'Published Living World Versions are immutable';
    END IF;
  ELSIF TG_TABLE_NAME = 'v3_service_versions' THEN
    IF NEW.service_id IS DISTINCT FROM OLD.service_id
       OR NEW.description IS DISTINCT FROM OLD.description THEN
      RAISE EXCEPTION 'Published Living World Versions are immutable';
    END IF;
  ELSE
    RAISE EXCEPTION 'Unexpected Living World Version table %', TG_TABLE_NAME;
  END IF;

  IF (OLD.publication_status = 'published' AND NEW.publication_status NOT IN ('published', 'retired'))
     OR (OLD.publication_status = 'retired' AND NEW.publication_status <> 'retired')
     OR (OLD.publication_status = 'retired' AND NEW.retired_at IS DISTINCT FROM OLD.retired_at) THEN
    RAISE EXCEPTION 'Published Living World Versions are immutable';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.v3_require_draft_living_world_association()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_old_status TEXT;
  v_new_status TEXT;
BEGIN
  IF TG_TABLE_NAME = 'v3_venue_version_villagers' THEN
    IF TG_OP <> 'INSERT' THEN
      SELECT publication_status INTO v_old_status FROM public.v3_venue_versions WHERE id = OLD.venue_version_id;
    END IF;
    IF TG_OP <> 'DELETE' THEN
      SELECT publication_status INTO v_new_status FROM public.v3_venue_versions WHERE id = NEW.venue_version_id;
    END IF;
  ELSE
    IF TG_OP <> 'INSERT' THEN
      SELECT publication_status INTO v_old_status FROM public.v3_villager_versions WHERE id = OLD.villager_version_id;
    END IF;
    IF TG_OP <> 'DELETE' THEN
      SELECT publication_status INTO v_new_status FROM public.v3_villager_versions WHERE id = NEW.villager_version_id;
    END IF;
  END IF;

  IF (TG_OP <> 'INSERT' AND v_old_status IS DISTINCT FROM 'draft')
     OR (TG_OP <> 'DELETE' AND v_new_status IS DISTINCT FROM 'draft') THEN
    RAISE EXCEPTION 'Living World Version associations can only change while draft';
  END IF;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.v3_prevent_living_world_state_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'Committed Living World Player state is immutable';
END;
$$;

CREATE OR REPLACE FUNCTION public.v3_validate_known_venue_reveal_provenance()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_result_kind TEXT;
  v_result_venue_id TEXT;
  v_result_user_id UUID;
  v_current_venue_version_id UUID;
  v_has_reveal_result BOOLEAN;
BEGIN
  SELECT
    result.outcome_kind,
    outcome.payload ->> 'venue_id',
    cell_visit.user_id
  INTO v_result_kind, v_result_venue_id, v_result_user_id
  FROM public.v3_encounter_outcome_results AS result
  JOIN public.v3_encounters AS encounter ON encounter.id = result.encounter_id
  JOIN public.v3_cell_visits AS cell_visit ON cell_visit.id = encounter.cell_visit_id
  JOIN public.v3_encounter_outcomes AS outcome ON outcome.id = result.encounter_outcome_id
  WHERE result.id = NEW.reveal_outcome_result_id;
  v_has_reveal_result := FOUND;


  SELECT current_published_version_id
  INTO v_current_venue_version_id
  FROM public.v3_venues
  WHERE id = NEW.venue_id;

  IF NOT v_has_reveal_result
     OR v_result_kind IS DISTINCT FROM 'reveal_venue'
     OR v_result_venue_id IS DISTINCT FROM NEW.venue_id
     OR v_result_user_id IS DISTINCT FROM NEW.user_id
     OR v_current_venue_version_id IS DISTINCT FROM NEW.first_venue_version_id THEN
    RAISE EXCEPTION 'Known Venue must preserve its Player Reveal Venue Outcome provenance'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

DO $living_world_immutability_triggers$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'v3_venues_immutable_identity' AND tgrelid = 'public.v3_venues'::regclass AND NOT tgisinternal) THEN
    CREATE TRIGGER v3_venues_immutable_identity BEFORE UPDATE OR DELETE ON public.v3_venues FOR EACH ROW EXECUTE FUNCTION public.v3_prevent_living_world_identity_mutation();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'v3_villagers_immutable_identity' AND tgrelid = 'public.v3_villagers'::regclass AND NOT tgisinternal) THEN
    CREATE TRIGGER v3_villagers_immutable_identity BEFORE UPDATE OR DELETE ON public.v3_villagers FOR EACH ROW EXECUTE FUNCTION public.v3_prevent_living_world_identity_mutation();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'v3_services_immutable_identity' AND tgrelid = 'public.v3_services'::regclass AND NOT tgisinternal) THEN
    CREATE TRIGGER v3_services_immutable_identity BEFORE UPDATE OR DELETE ON public.v3_services FOR EACH ROW EXECUTE FUNCTION public.v3_prevent_living_world_identity_mutation();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'v3_venue_versions_immutable_published' AND tgrelid = 'public.v3_venue_versions'::regclass AND NOT tgisinternal) THEN
    CREATE TRIGGER v3_venue_versions_immutable_published BEFORE UPDATE OR DELETE ON public.v3_venue_versions FOR EACH ROW EXECUTE FUNCTION public.v3_prevent_published_living_world_version_mutation();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'v3_villager_versions_immutable_published' AND tgrelid = 'public.v3_villager_versions'::regclass AND NOT tgisinternal) THEN
    CREATE TRIGGER v3_villager_versions_immutable_published BEFORE UPDATE OR DELETE ON public.v3_villager_versions FOR EACH ROW EXECUTE FUNCTION public.v3_prevent_published_living_world_version_mutation();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'v3_service_versions_immutable_published' AND tgrelid = 'public.v3_service_versions'::regclass AND NOT tgisinternal) THEN
    CREATE TRIGGER v3_service_versions_immutable_published BEFORE UPDATE OR DELETE ON public.v3_service_versions FOR EACH ROW EXECUTE FUNCTION public.v3_prevent_published_living_world_version_mutation();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'v3_venue_version_villagers_draft_only' AND tgrelid = 'public.v3_venue_version_villagers'::regclass AND NOT tgisinternal) THEN
    CREATE TRIGGER v3_venue_version_villagers_draft_only BEFORE INSERT OR UPDATE OR DELETE ON public.v3_venue_version_villagers FOR EACH ROW EXECUTE FUNCTION public.v3_require_draft_living_world_association();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'v3_villager_version_services_draft_only' AND tgrelid = 'public.v3_villager_version_services'::regclass AND NOT tgisinternal) THEN
    CREATE TRIGGER v3_villager_version_services_draft_only BEFORE INSERT OR UPDATE OR DELETE ON public.v3_villager_version_services FOR EACH ROW EXECUTE FUNCTION public.v3_require_draft_living_world_association();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'v3_player_known_venues_validate_reveal' AND tgrelid = 'public.v3_player_known_venues'::regclass AND NOT tgisinternal) THEN
    CREATE TRIGGER v3_player_known_venues_validate_reveal BEFORE INSERT OR UPDATE ON public.v3_player_known_venues FOR EACH ROW EXECUTE FUNCTION public.v3_validate_known_venue_reveal_provenance();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'v3_player_known_venues_immutable' AND tgrelid = 'public.v3_player_known_venues'::regclass AND NOT tgisinternal) THEN
    CREATE TRIGGER v3_player_known_venues_immutable BEFORE UPDATE OR DELETE ON public.v3_player_known_venues FOR EACH ROW EXECUTE FUNCTION public.v3_prevent_living_world_state_mutation();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'v3_player_known_villagers_immutable' AND tgrelid = 'public.v3_player_known_villagers'::regclass AND NOT tgisinternal) THEN
    CREATE TRIGGER v3_player_known_villagers_immutable BEFORE UPDATE OR DELETE ON public.v3_player_known_villagers FOR EACH ROW EXECUTE FUNCTION public.v3_prevent_living_world_state_mutation();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'v3_venue_visits_immutable' AND tgrelid = 'public.v3_venue_visits'::regclass AND NOT tgisinternal) THEN
    CREATE TRIGGER v3_venue_visits_immutable BEFORE UPDATE OR DELETE ON public.v3_venue_visits FOR EACH ROW EXECUTE FUNCTION public.v3_prevent_living_world_state_mutation();
  END IF;
END;
$living_world_immutability_triggers$;

CREATE OR REPLACE FUNCTION public.publish_v3_venue_version(p_venue_id TEXT, p_version_id UUID)
RETURNS public.v3_venue_versions
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_version public.v3_venue_versions%ROWTYPE;
BEGIN
  PERFORM 1 FROM public.v3_venues WHERE id = p_venue_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unknown Venue %', p_venue_id; END IF;
  SELECT * INTO v_version FROM public.v3_venue_versions WHERE id = p_version_id AND venue_id = p_venue_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Venue Version % does not belong to Venue %', p_version_id, p_venue_id; END IF;
  IF v_version.publication_status <> 'draft' THEN RAISE EXCEPTION 'Only draft Venue Versions may be published'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.v3_venue_version_villagers WHERE venue_version_id = p_version_id) THEN RAISE EXCEPTION 'Published Venue Versions require at least one Villager'; END IF;
  IF EXISTS (
    SELECT 1
    FROM public.v3_venue_version_villagers AS association
    LEFT JOIN public.v3_villagers AS villager
      ON villager.id = association.villager_id
    LEFT JOIN public.v3_villager_versions AS villager_version
      ON villager_version.id = villager.current_published_version_id
     AND villager_version.villager_id = villager.id
     AND villager_version.publication_status = 'published'
    WHERE association.venue_version_id = p_version_id
      AND villager_version.id IS NULL
  ) THEN
    RAISE EXCEPTION 'Published Venue Versions require every roster Villager to have an exact current published Villager Version';
  END IF;
  UPDATE public.v3_venue_versions SET publication_status = 'retired', retired_at = now(), updated_at = now() WHERE venue_id = p_venue_id AND publication_status = 'published';
  UPDATE public.v3_venue_versions SET publication_status = 'published', published_at = now(), updated_at = now() WHERE id = p_version_id RETURNING * INTO v_version;
  UPDATE public.v3_venues SET current_published_version_id = p_version_id, updated_at = now() WHERE id = p_venue_id;
  RETURN v_version;
END;
$$;

CREATE OR REPLACE FUNCTION public.publish_v3_villager_version(p_villager_id TEXT, p_version_id UUID)
RETURNS public.v3_villager_versions
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_version public.v3_villager_versions%ROWTYPE;
BEGIN
  PERFORM 1 FROM public.v3_villagers WHERE id = p_villager_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unknown Villager %', p_villager_id; END IF;
  SELECT * INTO v_version FROM public.v3_villager_versions WHERE id = p_version_id AND villager_id = p_villager_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Villager Version % does not belong to Villager %', p_version_id, p_villager_id; END IF;
  IF v_version.publication_status <> 'draft' THEN RAISE EXCEPTION 'Only draft Villager Versions may be published'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.v3_villager_version_services WHERE villager_version_id = p_version_id) THEN RAISE EXCEPTION 'Published Villager Versions require at least one Service'; END IF;
  IF EXISTS (
    SELECT 1
    FROM public.v3_villager_version_services AS association
    LEFT JOIN public.v3_services AS service
      ON service.id = association.service_id
    LEFT JOIN public.v3_service_versions AS service_version
      ON service_version.id = service.current_published_version_id
     AND service_version.service_id = service.id
     AND service_version.publication_status = 'published'
    WHERE association.villager_version_id = p_version_id
      AND service_version.id IS NULL
  ) THEN
    RAISE EXCEPTION 'Published Villager Versions require every associated Service to have an exact current published Service Version';
  END IF;
  UPDATE public.v3_villager_versions SET publication_status = 'retired', retired_at = now(), updated_at = now() WHERE villager_id = p_villager_id AND publication_status = 'published';
  UPDATE public.v3_villager_versions SET publication_status = 'published', published_at = now(), updated_at = now() WHERE id = p_version_id RETURNING * INTO v_version;
  UPDATE public.v3_villagers SET current_published_version_id = p_version_id, updated_at = now() WHERE id = p_villager_id;
  RETURN v_version;
END;
$$;

CREATE OR REPLACE FUNCTION public.publish_v3_service_version(p_service_id TEXT, p_version_id UUID)
RETURNS public.v3_service_versions
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_version public.v3_service_versions%ROWTYPE;
BEGIN
  PERFORM 1 FROM public.v3_services WHERE id = p_service_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unknown Service %', p_service_id; END IF;
  SELECT * INTO v_version FROM public.v3_service_versions WHERE id = p_version_id AND service_id = p_service_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Service Version % does not belong to Service %', p_version_id, p_service_id; END IF;
  IF v_version.publication_status <> 'draft' THEN RAISE EXCEPTION 'Only draft Service Versions may be published'; END IF;
  UPDATE public.v3_service_versions SET publication_status = 'retired', retired_at = now(), updated_at = now() WHERE service_id = p_service_id AND publication_status = 'published';
  UPDATE public.v3_service_versions SET publication_status = 'published', published_at = now(), updated_at = now() WHERE id = p_version_id RETURNING * INTO v_version;
  UPDATE public.v3_services SET current_published_version_id = p_version_id, updated_at = now() WHERE id = p_service_id;
  RETURN v_version;
END;
$$;

-- Town deliberately reads current authored publication for presentation while
-- retaining first-known exact Version and Reveal/Venue Visit provenance.
CREATE OR REPLACE FUNCTION public.get_v3_town()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_venues JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Town requires an authenticated user' USING ERRCODE = '28000';
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'venue_id', known.venue_id,
    'venue_version_id', version.id,
    'venue_version_revision', version.revision,
    'first_venue_version_id', known.first_venue_version_id,
    'first_venue_version_revision', first_version.revision,
    'reveal_outcome_result_id', known.reveal_outcome_result_id,
    'encounter_id', reveal_result.encounter_id,
    'known_at', known.known_at,
    'kind', version.kind,
    'display_name', version.display_name,
    'city_id', version.city_id,
    'anchor_cell_id', version.anchor_cell_id,
    'villagers', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'villager_id', known_villager.villager_id,
        'villager_version_id', villager_version.id,
        'villager_version_revision', villager_version.revision,
        'first_villager_version_id', known_villager.first_villager_version_id,
        'first_villager_version_revision', first_villager_version.revision,
        'first_venue_visit_id', known_villager.first_venue_visit_id,
        'first_venue_id', known_villager.first_venue_id,
        'first_venue_version_id', known_villager.first_venue_version_id,
        'first_venue_version_revision', first_villager_venue_version.revision,
        'known_at', known_villager.known_at,
        'display_name', villager_version.display_name,
        'role_name', villager_version.role_name,
        'venue_association_ordinal', venue_association.ordinal,
        'services', COALESCE((
          SELECT jsonb_agg(jsonb_build_object(
            'service_id', service.id,
            'service_version_id', service_version.id,
            'service_version_revision', service_version.revision,
            'display_name', service_version.display_name,
            'description', service_version.description,
            'service_association_ordinal', service_association.ordinal
          ) ORDER BY service_association.ordinal)
          FROM public.v3_villager_version_services AS service_association
          JOIN public.v3_services AS service ON service.id = service_association.service_id
          JOIN public.v3_service_versions AS service_version ON service_version.id = service.current_published_version_id
          WHERE service_association.villager_version_id = villager_version.id
        ), '[]'::jsonb)
      ) ORDER BY venue_association.ordinal)
      FROM public.v3_venue_version_villagers AS venue_association
      JOIN public.v3_player_known_villagers AS known_villager
        ON known_villager.user_id = v_user_id
       AND known_villager.villager_id = venue_association.villager_id
      JOIN public.v3_villagers AS villager ON villager.id = known_villager.villager_id
      JOIN public.v3_villager_versions AS villager_version ON villager_version.id = villager.current_published_version_id
      JOIN public.v3_villager_versions AS first_villager_version ON first_villager_version.id = known_villager.first_villager_version_id
      JOIN public.v3_venue_versions AS first_villager_venue_version ON first_villager_venue_version.id = known_villager.first_venue_version_id
      WHERE venue_association.venue_version_id = version.id
        AND EXISTS (
          SELECT 1
          FROM public.v3_venue_visits AS venue_visit
          WHERE venue_visit.user_id = v_user_id
            AND venue_visit.venue_id = known.venue_id
        )
    ), '[]'::jsonb)
  ) ORDER BY version.display_name, known.venue_id), '[]'::jsonb)
  INTO v_venues
  FROM public.v3_player_known_venues AS known
  JOIN public.v3_encounter_outcome_results AS reveal_result ON reveal_result.id = known.reveal_outcome_result_id
  JOIN public.v3_venues AS venue ON venue.id = known.venue_id
  JOIN public.v3_venue_versions AS version ON version.id = venue.current_published_version_id
  JOIN public.v3_venue_versions AS first_version ON first_version.id = known.first_venue_version_id
  WHERE known.user_id = v_user_id;

  RETURN jsonb_build_object('venues', v_venues);
END;
$$;

CREATE OR REPLACE FUNCTION public.record_v3_venue_visit(
  p_cell_visit_id UUID,
  p_venue_id TEXT,
  p_expected_venue_version_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_cell_visit public.v3_cell_visits%ROWTYPE;
  v_known_venue public.v3_player_known_venues%ROWTYPE;
  v_venue_version public.v3_venue_versions%ROWTYPE;
  v_visit public.v3_venue_visits%ROWTYPE;
  v_introduced JSONB;
  v_town JSONB;
  v_is_idempotent_retry BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Venue Visit requires an authenticated user' USING ERRCODE = '28000';
  END IF;
  IF p_cell_visit_id IS NULL OR p_venue_id IS NULL OR btrim(p_venue_id) = '' OR p_venue_id IS DISTINCT FROM btrim(p_venue_id) OR p_expected_venue_version_id IS NULL THEN
    RAISE EXCEPTION 'Venue Visit requires an exact Cell Visit, Venue, and expected Venue Version' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_cell_visit FROM public.v3_cell_visits
  WHERE id = p_cell_visit_id AND user_id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Venue Visit requires an owned Cell Visit' USING ERRCODE = '42501';
  END IF;


  SELECT * INTO v_known_venue FROM public.v3_player_known_venues
  WHERE user_id = v_user_id AND venue_id = p_venue_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Venue Visit requires a known Venue' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_visit
  FROM public.v3_venue_visits
  WHERE user_id = v_user_id
    AND venue_id = p_venue_id
    AND cell_visit_id = p_cell_visit_id
  FOR UPDATE;
  IF FOUND THEN
    IF v_visit.venue_version_id IS DISTINCT FROM p_expected_venue_version_id THEN
      RAISE EXCEPTION 'Venue Visit expected Venue Version does not match the persisted Visit Version'
        USING ERRCODE = '23514';
    END IF;
    SELECT * INTO v_venue_version
    FROM public.v3_venue_versions
    WHERE id = v_visit.venue_version_id
      AND venue_id = v_visit.venue_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Venue Visit persisted Venue Version is missing'
        USING ERRCODE = '23503';
    END IF;
    v_town := public.get_v3_town();
    RETURN jsonb_build_object(
      'visit', jsonb_build_object(
        'id', v_visit.id,
        'user_id', v_visit.user_id,
        'cell_visit_id', v_visit.cell_visit_id,
        'cell_id', v_visit.cell_id,
        'venue_id', v_visit.venue_id,
        'venue_version_id', v_visit.venue_version_id,
        'venue_version_revision', v_venue_version.revision,
        'visited_at', v_visit.visited_at,
        'is_idempotent_retry', TRUE
      ),
      'introduced_villagers', '[]'::jsonb,
      'town', v_town
    );
  END IF;

  SELECT version.* INTO v_venue_version
  FROM public.v3_venues AS venue
  JOIN public.v3_venue_versions AS version ON version.id = venue.current_published_version_id
  WHERE venue.id = p_venue_id
    AND version.id = p_expected_venue_version_id
    AND version.publication_status = 'published'
  FOR UPDATE OF venue, version;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Venue Visit expected Venue Version is not the current published Version' USING ERRCODE = '23514';
  END IF;
  IF v_cell_visit.cell_id IS DISTINCT FROM v_venue_version.anchor_cell_id THEN
    RAISE EXCEPTION 'Venue Visit Cell Visit does not match the Venue anchor Cell' USING ERRCODE = '23514';
  END IF;

  -- Lock all current Villager and Service publication pointers before creating
  -- Player knowledge, so the introduced roster is one atomic current snapshot.
  PERFORM 1
  FROM public.v3_venue_version_villagers AS association
  JOIN public.v3_villagers AS villager ON villager.id = association.villager_id
  WHERE association.venue_version_id = v_venue_version.id
  FOR UPDATE OF villager;
  PERFORM 1
  FROM public.v3_venue_version_villagers AS venue_association
  JOIN public.v3_villagers AS villager ON villager.id = venue_association.villager_id
  JOIN public.v3_villager_version_services AS service_association ON service_association.villager_version_id = villager.current_published_version_id
  JOIN public.v3_services AS service ON service.id = service_association.service_id
  WHERE venue_association.venue_version_id = v_venue_version.id
  FOR UPDATE OF service;

  INSERT INTO public.v3_venue_visits (user_id, cell_visit_id, cell_id, venue_id, venue_version_id)
  VALUES (v_user_id, v_cell_visit.id, v_cell_visit.cell_id, p_venue_id, v_venue_version.id)
  ON CONFLICT (user_id, venue_id, cell_visit_id) DO NOTHING
  RETURNING * INTO v_visit;
  v_is_idempotent_retry := NOT FOUND;
  IF v_is_idempotent_retry THEN
    SELECT * INTO v_visit
    FROM public.v3_venue_visits
    WHERE user_id = v_user_id
      AND venue_id = p_venue_id
      AND cell_visit_id = p_cell_visit_id
    FOR UPDATE;
    IF v_visit.venue_version_id IS DISTINCT FROM p_expected_venue_version_id THEN
      RAISE EXCEPTION 'Venue Visit expected Venue Version does not match the persisted Visit Version'
        USING ERRCODE = '23514';
    END IF;
    SELECT * INTO v_venue_version
    FROM public.v3_venue_versions
    WHERE id = v_visit.venue_version_id
      AND venue_id = v_visit.venue_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Venue Visit persisted Venue Version is missing'
        USING ERRCODE = '23503';
    END IF;
    v_town := public.get_v3_town();
    RETURN jsonb_build_object(
      'visit', jsonb_build_object(
        'id', v_visit.id,
        'user_id', v_visit.user_id,
        'cell_visit_id', v_visit.cell_visit_id,
        'cell_id', v_visit.cell_id,
        'venue_id', v_visit.venue_id,
        'venue_version_id', v_visit.venue_version_id,
        'venue_version_revision', v_venue_version.revision,
        'visited_at', v_visit.visited_at,
        'is_idempotent_retry', TRUE
      ),
      'introduced_villagers', '[]'::jsonb,
      'town', v_town
    );
  END IF;

  WITH roster AS (
    SELECT association.villager_id, villager.current_published_version_id AS villager_version_id, association.ordinal
    FROM public.v3_venue_version_villagers AS association
    JOIN public.v3_villagers AS villager ON villager.id = association.villager_id
    WHERE association.venue_version_id = v_venue_version.id
  ), introduced AS (
    INSERT INTO public.v3_player_known_villagers (
      user_id, villager_id, first_villager_version_id,
      first_venue_visit_id, first_venue_id, first_venue_version_id
    )
    SELECT v_user_id, roster.villager_id, roster.villager_version_id,
      v_visit.id, v_visit.venue_id, v_visit.venue_version_id
    FROM roster
    ON CONFLICT (user_id, villager_id) DO NOTHING
    RETURNING villager_id, first_villager_version_id, known_at
  )
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'villager_id', introduced.villager_id,
    'villager_version_id', introduced.first_villager_version_id,
    'villager_version_revision', villager_version.revision,
    'known_at', introduced.known_at,
    'display_name', villager_version.display_name,
    'role_name', villager_version.role_name,
    'venue_association_ordinal', roster.ordinal,
    'services', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'service_id', service.id,
        'service_version_id', service_version.id,
        'service_version_revision', service_version.revision,
        'display_name', service_version.display_name,
        'description', service_version.description,
        'service_association_ordinal', service_association.ordinal
      ) ORDER BY service_association.ordinal)
      FROM public.v3_villager_version_services AS service_association
      JOIN public.v3_services AS service ON service.id = service_association.service_id
      JOIN public.v3_service_versions AS service_version ON service_version.id = service.current_published_version_id
      WHERE service_association.villager_version_id = introduced.first_villager_version_id
    ), '[]'::jsonb)
  ) ORDER BY roster.ordinal), '[]'::jsonb)
  INTO v_introduced
  FROM introduced
  JOIN roster ON roster.villager_id = introduced.villager_id
  JOIN public.v3_villager_versions AS villager_version ON villager_version.id = introduced.first_villager_version_id;

  v_town := public.get_v3_town();
  RETURN jsonb_build_object(
    'visit', jsonb_build_object(
      'id', v_visit.id,
      'user_id', v_visit.user_id,
      'cell_visit_id', v_visit.cell_visit_id,
      'cell_id', v_visit.cell_id,
      'venue_id', v_visit.venue_id,
      'venue_version_id', v_visit.venue_version_id,
      'venue_version_revision', v_venue_version.revision,
      'visited_at', v_visit.visited_at,
      'is_idempotent_retry', v_is_idempotent_retry
    ),
    'introduced_villagers', v_introduced,
    'town', v_town
  );
END;
$$;

ALTER TABLE public.v3_venues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_venue_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_villagers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_villager_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_service_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_venue_version_villagers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_villager_version_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_venue_legacy_aliases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_player_known_venues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_player_known_villagers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v3_venue_visits ENABLE ROW LEVEL SECURITY;


CREATE POLICY "v3_player_known_venues_authenticated_read_own" ON public.v3_player_known_venues FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "v3_player_known_villagers_authenticated_read_own" ON public.v3_player_known_villagers FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "v3_venue_visits_authenticated_read_own" ON public.v3_venue_visits FOR SELECT TO authenticated USING (auth.uid() = user_id);

REVOKE INSERT, UPDATE, DELETE ON TABLE public.v3_venues, public.v3_venue_versions, public.v3_villagers, public.v3_villager_versions, public.v3_services, public.v3_service_versions, public.v3_venue_version_villagers, public.v3_villager_version_services, public.v3_venue_legacy_aliases, public.v3_player_known_venues, public.v3_player_known_villagers, public.v3_venue_visits FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.publish_v3_venue_version(TEXT, UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.publish_v3_villager_version(TEXT, UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.publish_v3_service_version(TEXT, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.publish_v3_venue_version(TEXT, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.publish_v3_villager_version(TEXT, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.publish_v3_service_version(TEXT, UUID) TO service_role;
REVOKE ALL ON FUNCTION public.record_v3_venue_visit(UUID, TEXT, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_v3_venue_visit(UUID, TEXT, UUID) TO authenticated;
REVOKE ALL ON FUNCTION public.get_v3_town() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_v3_town() TO authenticated;
REVOKE ALL ON FUNCTION public.v3_prevent_living_world_identity_mutation() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_prevent_published_living_world_version_mutation() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_require_draft_living_world_association() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_prevent_living_world_state_mutation() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.v3_validate_known_venue_reveal_provenance() FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE public.v3_player_known_venues IS 'One Player-known Venue per stable Venue identity, created only from the exact Reveal Venue Outcome result that first revealed it.';
COMMENT ON TABLE public.v3_player_known_villagers IS 'One Player-known Villager per stable Villager identity, preserving the first Venue Visit and exact Villager Version that introduced them.';
COMMENT ON TABLE public.v3_venue_visits IS 'Immutable Player Venue Visit occurrences bound to an exact owned Cell Visit, Venue, and immutable Venue Version.';
COMMENT ON FUNCTION public.get_v3_town() IS 'Player Town projection over current authored publication and durable first-known provenance; Town has no table.';
-- Rowan compatibility content is stable, repeat-safe, and intentionally does
-- not seed Player knowledge. The legacy in-memory identity remains an alias.
INSERT INTO public.v3_venues (id)
VALUES ('venue:rowans_rehab_center')
ON CONFLICT DO NOTHING;
INSERT INTO public.v3_villagers (id)
VALUES ('villager:rowan')
ON CONFLICT DO NOTHING;
INSERT INTO public.v3_services (id)
VALUES ('service:release_to_wild')
ON CONFLICT DO NOTHING;

INSERT INTO public.v3_service_versions (id, service_id, revision, publication_status, display_name, description)
VALUES (md5('earthnova:service-version:release_to_wild:1')::uuid, 'service:release_to_wild', 1, 'draft', 'Release to Wild', 'Release rehabilitated wildlife back into the wild.')
ON CONFLICT DO NOTHING;

INSERT INTO public.v3_villager_versions (id, villager_id, revision, publication_status, display_name, role_name)
VALUES (md5('earthnova:villager-version:rowan:1')::uuid, 'villager:rowan', 1, 'draft', 'Rowan', 'Wildlife Rehabilitator')
ON CONFLICT DO NOTHING;

INSERT INTO public.v3_venue_versions (id, venue_id, revision, publication_status, kind, display_name, city_id, anchor_cell_id)
VALUES (md5('earthnova:venue-version:rowans_rehab_center:1')::uuid, 'venue:rowans_rehab_center', 1, 'draft', 'wildlife_rehabilitation_center', 'Rowan''s Rehab Center', 'city_fredericton', 'v_22982_-33322')
ON CONFLICT DO NOTHING;

INSERT INTO public.v3_villager_version_services (villager_version_id, service_id, ordinal)
SELECT md5('earthnova:villager-version:rowan:1')::uuid, 'service:release_to_wild', 1
WHERE EXISTS (SELECT 1 FROM public.v3_villager_versions WHERE id = md5('earthnova:villager-version:rowan:1')::uuid AND publication_status = 'draft')
ON CONFLICT DO NOTHING;

INSERT INTO public.v3_venue_version_villagers (venue_version_id, villager_id, ordinal)
SELECT md5('earthnova:venue-version:rowans_rehab_center:1')::uuid, 'villager:rowan', 1
WHERE EXISTS (SELECT 1 FROM public.v3_venue_versions WHERE id = md5('earthnova:venue-version:rowans_rehab_center:1')::uuid AND publication_status = 'draft')
ON CONFLICT DO NOTHING;

DO $publish_rowan_living_world_seed$
BEGIN
  IF EXISTS (SELECT 1 FROM public.v3_service_versions WHERE id = md5('earthnova:service-version:release_to_wild:1')::uuid AND publication_status = 'draft') THEN
    PERFORM public.publish_v3_service_version('service:release_to_wild', md5('earthnova:service-version:release_to_wild:1')::uuid);
  END IF;
  IF EXISTS (SELECT 1 FROM public.v3_villager_versions WHERE id = md5('earthnova:villager-version:rowan:1')::uuid AND publication_status = 'draft') THEN
    PERFORM public.publish_v3_villager_version('villager:rowan', md5('earthnova:villager-version:rowan:1')::uuid);
  END IF;
  IF EXISTS (SELECT 1 FROM public.v3_venue_versions WHERE id = md5('earthnova:venue-version:rowans_rehab_center:1')::uuid AND publication_status = 'draft') THEN
    PERFORM public.publish_v3_venue_version('venue:rowans_rehab_center', md5('earthnova:venue-version:rowans_rehab_center:1')::uuid);
  END IF;
END;
$publish_rowan_living_world_seed$;

INSERT INTO public.v3_venue_legacy_aliases (legacy_venue_id, venue_id)
VALUES ('wildlife-rehabilitation-center:city_fredericton', 'venue:rowans_rehab_center')
ON CONFLICT DO NOTHING;
