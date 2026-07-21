-- Migration 076: Versioned authored Base Item content foundation.
--
-- Base Items are stable identities. Their authored definitions are immutable
-- versions so new publications affect future generation without rewriting
-- existing player state or legacy v3_items evidence.

CREATE TABLE IF NOT EXISTS v3_base_items (
  id TEXT PRIMARY KEY CHECK (btrim(id) <> ''),
  category TEXT NOT NULL CHECK (
    category IN (
      'fauna',
      'flora',
      'mineral',
      'fossil',
      'artifact',
      'food',
      'orb'
    )
  ),
  current_published_version_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS v3_base_item_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  base_item_id TEXT NOT NULL REFERENCES v3_base_items(id)
    ON UPDATE RESTRICT
    ON DELETE RESTRICT,
  revision INTEGER NOT NULL CHECK (revision > 0),
  publication_status TEXT NOT NULL DEFAULT 'draft' CHECK (
    publication_status IN ('draft', 'published', 'retired')
  ),
  published_at TIMESTAMPTZ,
  retired_at TIMESTAMPTZ,
  display_name TEXT NOT NULL CHECK (btrim(display_name) <> ''),
  scientific_name TEXT,
  authored_content JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (base_item_id, revision),
  UNIQUE (base_item_id, id),
  CHECK (
    (publication_status = 'draft' AND published_at IS NULL AND retired_at IS NULL)
    OR (publication_status = 'published' AND published_at IS NOT NULL AND retired_at IS NULL)
    OR (publication_status = 'retired' AND published_at IS NOT NULL AND retired_at IS NOT NULL)
  )
);

DO $add_current_published_version_owner_fk$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'v3_base_items_current_published_version_owner_fk'
      AND conrelid = 'v3_base_items'::regclass
  ) THEN
    ALTER TABLE v3_base_items
      ADD CONSTRAINT v3_base_items_current_published_version_owner_fk
      FOREIGN KEY (id, current_published_version_id)
      REFERENCES v3_base_item_versions(base_item_id, id)
      DEFERRABLE INITIALLY DEFERRED;
  END IF;
END;
$add_current_published_version_owner_fk$;

CREATE INDEX IF NOT EXISTS idx_v3_base_items_category
  ON v3_base_items(category);

CREATE INDEX IF NOT EXISTS idx_v3_base_items_current_published_version
  ON v3_base_items(current_published_version_id)
  WHERE current_published_version_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_v3_base_item_versions_base_item_publication
  ON v3_base_item_versions(base_item_id, publication_status, revision DESC);

CREATE OR REPLACE FUNCTION public.publish_v3_base_item_version(
  p_base_item_id TEXT,
  p_version_id UUID
)
RETURNS public.v3_base_item_versions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_base_item v3_base_items%ROWTYPE;
  v_candidate_version v3_base_item_versions%ROWTYPE;
  v_published_version v3_base_item_versions%ROWTYPE;
BEGIN
  SELECT *
  INTO v_base_item
  FROM v3_base_items
  WHERE id = p_base_item_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unknown Base Item %', p_base_item_id;
  END IF;

  SELECT *
  INTO v_candidate_version
  FROM v3_base_item_versions
  WHERE id = p_version_id
    AND base_item_id = p_base_item_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Base Item Version % does not belong to Base Item %',
      p_version_id,
      p_base_item_id;
  END IF;

  IF v_candidate_version.publication_status <> 'draft' THEN
    RAISE EXCEPTION 'Only draft Base Item Versions may be published';
  END IF;

  UPDATE v3_base_item_versions
  SET publication_status = 'retired',
      retired_at = now(),
      updated_at = now()
  WHERE base_item_id = p_base_item_id
    AND publication_status = 'published';

  UPDATE v3_base_item_versions
  SET publication_status = 'published',
      published_at = now(),
      retired_at = NULL,
      updated_at = now()
  WHERE id = p_version_id
  RETURNING * INTO v_published_version;

  UPDATE v3_base_items
  SET current_published_version_id = p_version_id,
      updated_at = now()
  WHERE id = p_base_item_id;

  RETURN v_published_version;
END;
$$;

REVOKE ALL ON FUNCTION public.publish_v3_base_item_version(TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.publish_v3_base_item_version(TEXT, UUID) TO service_role;

CREATE OR REPLACE FUNCTION public.prevent_published_v3_base_item_version_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
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
    OR NEW.base_item_id IS DISTINCT FROM OLD.base_item_id
    OR NEW.revision IS DISTINCT FROM OLD.revision
    OR NEW.display_name IS DISTINCT FROM OLD.display_name
    OR NEW.scientific_name IS DISTINCT FROM OLD.scientific_name
    OR NEW.authored_content IS DISTINCT FROM OLD.authored_content
    OR NEW.published_at IS DISTINCT FROM OLD.published_at
    OR (OLD.publication_status = 'published'
      AND NEW.publication_status NOT IN ('published', 'retired'))
    OR (OLD.publication_status = 'retired'
      AND NEW.publication_status <> 'retired')
    OR (OLD.publication_status = 'retired'
      AND NEW.retired_at IS DISTINCT FROM OLD.retired_at) THEN
    RAISE EXCEPTION 'Published Base Item Versions are immutable';
  END IF;

  RETURN NEW;
END;
$$;

DO $add_v3_base_item_version_immutability_trigger$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'v3_base_item_versions_prevent_published_content_mutation'
      AND tgrelid = 'v3_base_item_versions'::regclass
      AND NOT tgisinternal
  ) THEN
    CREATE TRIGGER v3_base_item_versions_prevent_published_content_mutation
      BEFORE UPDATE OR DELETE ON v3_base_item_versions
      FOR EACH ROW
      EXECUTE FUNCTION public.prevent_published_v3_base_item_version_mutation();
  END IF;
END;
$add_v3_base_item_version_immutability_trigger$;

CREATE OR REPLACE FUNCTION public.prevent_v3_base_item_identity_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE'
    OR NEW.id IS DISTINCT FROM OLD.id
    OR NEW.category IS DISTINCT FROM OLD.category THEN
    RAISE EXCEPTION 'Base Item identity and category are immutable';
  END IF;

  RETURN NEW;
END;
$$;

DO $add_v3_base_item_identity_immutability_trigger$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'v3_base_items_prevent_identity_mutation'
      AND tgrelid = 'v3_base_items'::regclass
      AND NOT tgisinternal
  ) THEN
    CREATE TRIGGER v3_base_items_prevent_identity_mutation
      BEFORE UPDATE OR DELETE ON v3_base_items
      FOR EACH ROW
      EXECUTE FUNCTION public.prevent_v3_base_item_identity_mutation();
  END IF;
END;
$add_v3_base_item_identity_immutability_trigger$;

ALTER TABLE v3_base_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE v3_base_item_versions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "v3_base_items_authenticated_read"
  ON v3_base_items
  FOR SELECT
  TO authenticated
  USING (current_published_version_id IS NOT NULL);

CREATE POLICY "v3_base_item_versions_authenticated_read"
  ON v3_base_item_versions
  FOR SELECT
  TO authenticated
  USING (publication_status IN ('published', 'retired'));

COMMENT ON TABLE v3_base_items IS
  'Stable Base Item identities. Selectors and Discovery bind this identity; future generation resolves its current published version.';

COMMENT ON TABLE v3_base_item_versions IS
  'Immutable authored definitions. Each generated Item permanently binds the exact immutable Base Item Version selected at creation.';

COMMENT ON COLUMN v3_base_items.current_published_version_id IS
  'The owned version future Item generation binds; it never changes an Item already bound to an exact version.';
