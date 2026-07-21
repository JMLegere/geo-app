-- Migration 079: Bind existing Items to stable Base Items and immutable snapshots.
--
-- This is an additive compatibility bridge. Existing Item payload, ownership, and
-- lifecycle columns remain the legacy record; only the two new binding columns
-- are populated here. The application write path continues unchanged.

ALTER TABLE v3_items
  ADD COLUMN IF NOT EXISTS base_item_id TEXT,
  ADD COLUMN IF NOT EXISTS base_item_version_id UUID;

DO $add_v3_items_base_item_fk$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'v3_items_base_item_fk'
      AND conrelid = 'v3_items'::regclass
  ) THEN
    ALTER TABLE v3_items
      ADD CONSTRAINT v3_items_base_item_fk
      FOREIGN KEY (base_item_id)
      REFERENCES v3_base_items(id)
      ON UPDATE RESTRICT
      ON DELETE RESTRICT;
  END IF;
END;
$add_v3_items_base_item_fk$;

DO $add_v3_items_base_item_version_owner_fk$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'v3_items_base_item_version_owner_fk'
      AND conrelid = 'v3_items'::regclass
  ) THEN
    ALTER TABLE v3_items
      ADD CONSTRAINT v3_items_base_item_version_owner_fk
      FOREIGN KEY (base_item_id, base_item_version_id)
      REFERENCES v3_base_item_versions(base_item_id, id)
      ON UPDATE RESTRICT
      ON DELETE RESTRICT;
  END IF;
END;
$add_v3_items_base_item_version_owner_fk$;

DO $add_v3_items_complete_base_item_binding_check$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'v3_items_complete_base_item_binding_check'
      AND conrelid = 'v3_items'::regclass
  ) THEN
    ALTER TABLE v3_items
      ADD CONSTRAINT v3_items_complete_base_item_binding_check
      CHECK (
        (base_item_id IS NULL AND base_item_version_id IS NULL)
        OR (base_item_id IS NOT NULL AND base_item_version_id IS NOT NULL)
      );
  END IF;
END;
$add_v3_items_complete_base_item_binding_check$;

CREATE INDEX IF NOT EXISTS idx_v3_items_base_item_version
  ON v3_items(base_item_version_id)
  WHERE base_item_version_id IS NOT NULL;

-- Stable identities for the current deterministic encounter catalog.
INSERT INTO v3_base_items (id, category)
VALUES
  ('fauna:amberwing_warbler', 'fauna'),
  ('fauna:red_fox', 'fauna'),
  ('fauna:monarch_butterfly', 'fauna'),
  ('fauna:painted_turtle', 'fauna'),
  ('fauna:snowshoe_hare', 'fauna'),
  ('fauna:brook_trout', 'fauna'),
  ('fauna:great_blue_heron', 'fauna'),
  ('fauna:eastern_chipmunk', 'fauna')
ON CONFLICT (id) DO NOTHING;

-- These are deterministic published snapshots of the catalog currently used by
-- compute_encounter.dart. Rarity is intentionally absent: it remains legacy
-- evidence on old Items and is not authored selection, gating, or progression.
WITH legacy_catalog_snapshot (
  base_item_id,
  id,
  display_name,
  scientific_name,
  taxonomic_class,
  habitats,
  continents
) AS (
  VALUES
    ('fauna:amberwing_warbler', '5101f74b-0b39-4cb9-a4df-f18bc319bf11'::uuid, 'Amberwing Warbler', 'Setophaga aestiva', 'Aves', '["forest", "wetland"]'::jsonb, '["North America"]'::jsonb),
    ('fauna:red_fox', '76bdc387-0b1a-4220-961e-924f7d99ecfe'::uuid, 'Red Fox', 'Vulpes vulpes', 'Mammalia', '["forest", "grassland", "urban"]'::jsonb, '["North America", "Europe", "Asia"]'::jsonb),
    ('fauna:monarch_butterfly', '7ab0d7ac-b791-4054-92bf-17f4e620e482'::uuid, 'Monarch Butterfly', 'Danaus plexippus', 'Insecta', '["grassland", "urban"]'::jsonb, '["North America"]'::jsonb),
    ('fauna:painted_turtle', 'e5244f45-d147-452d-a549-23f5ad6e26c7'::uuid, 'Painted Turtle', 'Chrysemys picta', 'Reptilia', '["freshwater", "wetland"]'::jsonb, '["North America"]'::jsonb),
    ('fauna:snowshoe_hare', 'ca6814f2-83c2-4238-9935-cc57d7ae951c'::uuid, 'Snowshoe Hare', 'Lepus americanus', 'Mammalia', '["forest"]'::jsonb, '["North America"]'::jsonb),
    ('fauna:brook_trout', '38c5d428-a41f-43f0-98a8-1e3bb4e4411b'::uuid, 'Brook Trout', 'Salvelinus fontinalis', 'Actinopterygii', '["freshwater"]'::jsonb, '["North America"]'::jsonb),
    ('fauna:great_blue_heron', 'b7a7e916-0e09-4be9-8f1e-9990d7596789'::uuid, 'Great Blue Heron', 'Ardea herodias', 'Aves', '["freshwater", "wetland", "coastal"]'::jsonb, '["North America"]'::jsonb),
    ('fauna:eastern_chipmunk', 'c0714304-7ff1-44f8-8194-914b3c1ee1c5'::uuid, 'Eastern Chipmunk', 'Tamias striatus', 'Mammalia', '["forest", "urban"]'::jsonb, '["North America"]'::jsonb)
)
INSERT INTO v3_base_item_versions (
  id,
  base_item_id,
  revision,
  publication_status,
  published_at,
  display_name,
  scientific_name,
  authored_content
)
SELECT
  id,
  base_item_id,
  1,
  'published',
  TIMESTAMPTZ '2026-07-20 00:00:00+00',
  display_name,
  scientific_name,
  jsonb_build_object(
    'legacy_catalog_snapshot',
    jsonb_build_object(
      'taxonomic_class', taxonomic_class,
      'habitats', habitats,
      'continents', continents
    )
  )
FROM legacy_catalog_snapshot
ON CONFLICT (id) DO NOTHING;

WITH canonical_versions (base_item_id, version_id) AS (
  VALUES
    ('fauna:amberwing_warbler', '5101f74b-0b39-4cb9-a4df-f18bc319bf11'::uuid),
    ('fauna:red_fox', '76bdc387-0b1a-4220-961e-924f7d99ecfe'::uuid),
    ('fauna:monarch_butterfly', '7ab0d7ac-b791-4054-92bf-17f4e620e482'::uuid),
    ('fauna:painted_turtle', 'e5244f45-d147-452d-a549-23f5ad6e26c7'::uuid),
    ('fauna:snowshoe_hare', 'ca6814f2-83c2-4238-9935-cc57d7ae951c'::uuid),
    ('fauna:brook_trout', '38c5d428-a41f-43f0-98a8-1e3bb4e4411b'::uuid),
    ('fauna:great_blue_heron', 'b7a7e916-0e09-4be9-8f1e-9990d7596789'::uuid),
    ('fauna:eastern_chipmunk', 'c0714304-7ff1-44f8-8194-914b3c1ee1c5'::uuid)
)
UPDATE v3_base_items AS base_item
SET current_published_version_id = canonical.version_id
FROM canonical_versions AS canonical
WHERE base_item.id = canonical.base_item_id
  AND base_item.current_published_version_id IS NULL;

-- Build a definition-level compatibility snapshot for each unbound Item. The
-- legacy_rarity field is retained solely as evidence; it is not new content
-- semantics and is never used for selection, gating, or progression.
WITH item_snapshots AS (
  SELECT DISTINCT
    CASE
      WHEN item.definition_id ~ '^species\.(amberwing_warbler|red_fox|monarch_butterfly|painted_turtle|snowshoe_hare|brook_trout|great_blue_heron|eastern_chipmunk)\.[0-9a-f]{8}$'
        THEN 'fauna:' || substring(item.definition_id FROM '^species\.([a-z_]+)\.[0-9a-f]{8}$')
      ELSE 'legacy-item:' || md5(item.definition_id || E'\x1f' || lower(item.category))
    END AS base_item_id,
    CASE
      WHEN lower(item.category) IN ('fauna', 'flora', 'mineral', 'fossil', 'artifact', 'food', 'orb')
        THEN lower(item.category)
      ELSE 'fauna'
    END AS base_item_category,
    jsonb_build_object(
      'legacy_item_snapshot',
      jsonb_strip_nulls(
        jsonb_build_object(
          'definition_id', item.definition_id,
          'display_name', item.display_name,
          'scientific_name', item.scientific_name,
          'legacy_category', item.category,
          'legacy_rarity', item.rarity,
          'icon_url', item.icon_url,
          'icon_url_frame2', item.icon_url_frame2,
          'art_url', item.art_url,
          'taxonomic_class', item.taxonomic_class,
          'habitats_json', item.habitats_json,
          'continents_json', item.continents_json,
          'identified_display_name', item.identified_display_name,
          'identified_scientific_name', item.identified_scientific_name,
          'identified_taxonomic_class', item.identified_taxonomic_class,
          'identified_habitats_json', item.identified_habitats_json,
          'identified_continents_json', item.identified_continents_json
        )
      )
    ) AS authored_content
  FROM v3_items AS item
  WHERE item.base_item_id IS NULL OR item.base_item_version_id IS NULL
), compatibility_base_items AS (
  SELECT DISTINCT base_item_id, base_item_category
  FROM item_snapshots
)
INSERT INTO v3_base_items (id, category)
SELECT base_item_id, base_item_category
FROM compatibility_base_items
ON CONFLICT (id) DO NOTHING;

WITH item_snapshots AS (
  SELECT DISTINCT
    CASE
      WHEN item.definition_id ~ '^species\.(amberwing_warbler|red_fox|monarch_butterfly|painted_turtle|snowshoe_hare|brook_trout|great_blue_heron|eastern_chipmunk)\.[0-9a-f]{8}$'
        THEN 'fauna:' || substring(item.definition_id FROM '^species\.([a-z_]+)\.[0-9a-f]{8}$')
      ELSE 'legacy-item:' || md5(item.definition_id || E'\x1f' || lower(item.category))
    END AS base_item_id,
    jsonb_build_object(
      'legacy_item_snapshot',
      jsonb_strip_nulls(
        jsonb_build_object(
          'definition_id', item.definition_id,
          'display_name', item.display_name,
          'scientific_name', item.scientific_name,
          'legacy_category', item.category,
          'legacy_rarity', item.rarity,
          'icon_url', item.icon_url,
          'icon_url_frame2', item.icon_url_frame2,
          'art_url', item.art_url,
          'taxonomic_class', item.taxonomic_class,
          'habitats_json', item.habitats_json,
          'continents_json', item.continents_json,
          'identified_display_name', item.identified_display_name,
          'identified_scientific_name', item.identified_scientific_name,
          'identified_taxonomic_class', item.identified_taxonomic_class,
          'identified_habitats_json', item.identified_habitats_json,
          'identified_continents_json', item.identified_continents_json
        )
      )
    ) AS authored_content
  FROM v3_items AS item
  WHERE item.base_item_id IS NULL OR item.base_item_version_id IS NULL
), hashed_snapshots AS (
  SELECT
    base_item_id,
    authored_content,
    md5(base_item_id || ':' || authored_content::text) AS version_hash
  FROM item_snapshots
), versioned_snapshots AS (
  SELECT
    snapshot.base_item_id,
    (
      substring(snapshot.version_hash FROM 1 FOR 8) || '-' ||
      substring(snapshot.version_hash FROM 9 FOR 4) || '-' ||
      substring(snapshot.version_hash FROM 13 FOR 4) || '-' ||
      substring(snapshot.version_hash FROM 17 FOR 4) || '-' ||
      substring(snapshot.version_hash FROM 21 FOR 12)
    )::uuid AS id,
    snapshot.authored_content,
    row_number() OVER (
      PARTITION BY snapshot.base_item_id
      ORDER BY snapshot.version_hash
    ) + COALESCE(existing.max_revision, 0) AS revision
  FROM hashed_snapshots AS snapshot
  LEFT JOIN (
    SELECT base_item_id, max(revision) AS max_revision
    FROM v3_base_item_versions
    GROUP BY base_item_id
  ) AS existing ON existing.base_item_id = snapshot.base_item_id
)
INSERT INTO v3_base_item_versions (
  id,
  base_item_id,
  revision,
  publication_status,
  published_at,
  display_name,
  scientific_name,
  authored_content
)
SELECT
  snapshot.id,
  snapshot.base_item_id,
  snapshot.revision,
  'published',
  TIMESTAMPTZ '2026-07-20 00:00:00+00',
  COALESCE(snapshot.authored_content #>> '{legacy_item_snapshot,display_name}', 'Legacy Item'),
  snapshot.authored_content #>> '{legacy_item_snapshot,scientific_name}',
  snapshot.authored_content
FROM versioned_snapshots AS snapshot
ON CONFLICT (base_item_id, revision) DO NOTHING;
-- Compatibility identities need a readable current Version just like authored
-- catalog identities. Preserve a future published pointer if one already exists.
WITH compatibility_current_versions AS (
  SELECT DISTINCT ON (version.base_item_id)
    version.base_item_id,
    version.id AS version_id
  FROM v3_base_item_versions AS version
  JOIN v3_base_items AS base_item
    ON base_item.id = version.base_item_id
  WHERE base_item.id LIKE 'legacy-item:%'
    AND version.publication_status IN ('published', 'retired')
  ORDER BY
    version.base_item_id,
    version.revision DESC,
    CASE version.publication_status WHEN 'published' THEN 0 ELSE 1 END,
    version.id DESC
)
UPDATE v3_base_items AS base_item
SET current_published_version_id = compatibility.version_id
FROM compatibility_current_versions AS compatibility
WHERE base_item.id = compatibility.base_item_id
  AND base_item.id LIKE 'legacy-item:%'
  AND base_item.current_published_version_id IS NULL;


WITH item_snapshots AS (
  SELECT
    item.id AS item_id,
    CASE
      WHEN item.definition_id ~ '^species\.(amberwing_warbler|red_fox|monarch_butterfly|painted_turtle|snowshoe_hare|brook_trout|great_blue_heron|eastern_chipmunk)\.[0-9a-f]{8}$'
        THEN 'fauna:' || substring(item.definition_id FROM '^species\.([a-z_]+)\.[0-9a-f]{8}$')
      ELSE 'legacy-item:' || md5(item.definition_id || E'\x1f' || lower(item.category))
    END AS base_item_id,
    jsonb_build_object(
      'legacy_item_snapshot',
      jsonb_strip_nulls(
        jsonb_build_object(
          'definition_id', item.definition_id,
          'display_name', item.display_name,
          'scientific_name', item.scientific_name,
          'legacy_category', item.category,
          'legacy_rarity', item.rarity,
          'icon_url', item.icon_url,
          'icon_url_frame2', item.icon_url_frame2,
          'art_url', item.art_url,
          'taxonomic_class', item.taxonomic_class,
          'habitats_json', item.habitats_json,
          'continents_json', item.continents_json,
          'identified_display_name', item.identified_display_name,
          'identified_scientific_name', item.identified_scientific_name,
          'identified_taxonomic_class', item.identified_taxonomic_class,
          'identified_habitats_json', item.identified_habitats_json,
          'identified_continents_json', item.identified_continents_json
        )
      )
    ) AS authored_content
  FROM v3_items AS item
  WHERE item.base_item_id IS NULL OR item.base_item_version_id IS NULL
)
UPDATE v3_items AS item
SET base_item_id = snapshot.base_item_id,
    base_item_version_id = version.id
FROM item_snapshots AS snapshot
JOIN v3_base_item_versions AS version
  ON version.base_item_id = snapshot.base_item_id
  AND version.authored_content = snapshot.authored_content
WHERE item.id = snapshot.item_id
  AND (item.base_item_id IS NULL OR item.base_item_version_id IS NULL);

DO $assert_v3_items_are_bound$
DECLARE
  v_unbound_count BIGINT;
BEGIN
  SELECT count(*)
  INTO v_unbound_count
  FROM v3_items
  WHERE base_item_id IS NULL OR base_item_version_id IS NULL;

  IF v_unbound_count <> 0 THEN
    RAISE EXCEPTION 'Legacy Item backfill left % unbound Item rows', v_unbound_count;
  END IF;
END;
$assert_v3_items_are_bound$;
