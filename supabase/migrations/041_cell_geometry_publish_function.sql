-- Cell geometry publish function.
--
-- Publishes a DB-validated source_version by copying staged geometry into the
-- immutable canonical cells table and atomically switching the active pointer.

CREATE TABLE cell_geometry_publish_events (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_version          TEXT NOT NULL REFERENCES cell_geometry_versions(source_version)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  validation_run_id       UUID NOT NULL REFERENCES cell_geometry_validation_runs(id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  previous_source_version TEXT REFERENCES cell_geometry_versions(source_version)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  published_cell_count    INTEGER NOT NULL CHECK (published_cell_count > 0),
  status                  TEXT NOT NULL DEFAULT 'published'
    CHECK (status IN ('published')),
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by              UUID REFERENCES auth.users(id),
  details                 JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX idx_cell_geometry_publish_events_source_version
  ON cell_geometry_publish_events(source_version, created_at DESC);
CREATE INDEX idx_cell_geometry_publish_events_validation_run_id
  ON cell_geometry_publish_events(validation_run_id);

ALTER TABLE cell_geometry_publish_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role can manage geometry publish events"
  ON cell_geometry_publish_events FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE OR REPLACE FUNCTION publish_cell_geometry_source_version(
  p_source_version TEXT,
  p_validation_run_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_id UUID;
  v_validation_run_id UUID;
  v_validation_finished_at TIMESTAMPTZ;
  v_version_status TEXT;
  v_expected_cell_count INTEGER;
  v_staged_valid_count INTEGER;
  v_canonical_existing_count INTEGER;
  v_canonical_final_count INTEGER;
  v_previous_source_version TEXT;
BEGIN
  SELECT status, expected_cell_count
  INTO v_version_status, v_expected_cell_count
  FROM cell_geometry_versions
  WHERE source_version = p_source_version
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unknown cell geometry source_version: %', p_source_version;
  END IF;

  IF v_version_status NOT IN ('validated', 'active') THEN
    RAISE EXCEPTION 'Source_version % must be validated before publish; current status is %',
      p_source_version,
      v_version_status;
  END IF;

  IF p_validation_run_id IS NULL THEN
    SELECT id, finished_at
    INTO v_validation_run_id, v_validation_finished_at
    FROM cell_geometry_validation_runs
    WHERE source_version = p_source_version
      AND status = 'passed'
      AND finished_at IS NOT NULL
    ORDER BY finished_at DESC, started_at DESC
    LIMIT 1;
  ELSE
    SELECT id, finished_at
    INTO v_validation_run_id, v_validation_finished_at
    FROM cell_geometry_validation_runs
    WHERE id = p_validation_run_id
      AND source_version = p_source_version
      AND status = 'passed'
      AND finished_at IS NOT NULL;
  END IF;

  IF v_validation_run_id IS NULL THEN
    RAISE EXCEPTION 'Source_version % has no passed validation run to publish', p_source_version;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM cell_geometry_staging staging
    WHERE staging.source_version = p_source_version
      AND GREATEST(staging.created_at, staging.updated_at) > v_validation_finished_at
  ) THEN
    RAISE EXCEPTION 'Source_version % has staging rows modified after validation run % finished',
      p_source_version,
      v_validation_run_id;
  END IF;

  SELECT source_version
  INTO v_previous_source_version
  FROM cell_geometry_active_version
  WHERE singleton = true
  FOR UPDATE;

  SELECT COUNT(*)::INTEGER
  INTO v_staged_valid_count
  FROM cell_geometry_staging staging
  WHERE staging.source_version = p_source_version
    AND staging.cell_id IS NOT NULL
    AND staging.parsed_geom IS NOT NULL
    AND staging.parsed_centroid IS NOT NULL
    AND staging.parsed_bbox IS NOT NULL
    AND staging.parsed_area_m2 IS NOT NULL
    AND ST_IsValid(staging.parsed_geom)
    AND NOT ST_IsEmpty(staging.parsed_geom);

  IF v_staged_valid_count <> v_expected_cell_count THEN
    RAISE EXCEPTION 'Source_version % staged valid row count % does not match expected count %',
      p_source_version,
      v_staged_valid_count,
      v_expected_cell_count;
  END IF;

  SELECT COUNT(*)::INTEGER
  INTO v_canonical_existing_count
  FROM cell_geometry_cells
  WHERE source_version = p_source_version;

  IF v_canonical_existing_count = 0 THEN
    INSERT INTO cell_geometry_cells (
      source_version,
      cell_id,
      geom,
      centroid,
      bbox,
      area_m2,
      metadata
    )
    SELECT
      staging.source_version,
      staging.cell_id,
      staging.parsed_geom,
      staging.parsed_centroid,
      staging.parsed_bbox,
      staging.parsed_area_m2,
      jsonb_build_object(
        'staging_id', staging.id,
        'validation_run_id', v_validation_run_id,
        'published_from', 'cell_geometry_staging'
      ) || staging.raw_properties
    FROM cell_geometry_staging staging
    WHERE staging.source_version = p_source_version
      AND staging.cell_id IS NOT NULL
      AND staging.parsed_geom IS NOT NULL
      AND staging.parsed_centroid IS NOT NULL
      AND staging.parsed_bbox IS NOT NULL
      AND staging.parsed_area_m2 IS NOT NULL;
  ELSIF v_canonical_existing_count <> v_expected_cell_count THEN
    RAISE EXCEPTION 'Source_version % has partial canonical geometry rows: % of expected %',
      p_source_version,
      v_canonical_existing_count,
      v_expected_cell_count;
  END IF;

  SELECT COUNT(*)::INTEGER
  INTO v_canonical_final_count
  FROM cell_geometry_cells
  WHERE source_version = p_source_version;

  IF v_canonical_final_count <> v_expected_cell_count THEN
    RAISE EXCEPTION 'Source_version % canonical row count % does not match expected count % after publish insert',
      p_source_version,
      v_canonical_final_count,
      v_expected_cell_count;
  END IF;

  INSERT INTO cell_geometry_active_version (
    singleton,
    source_version,
    activated_at,
    activated_by
  )
  VALUES (
    true,
    p_source_version,
    now(),
    auth.uid()
  )
  ON CONFLICT (singleton) DO UPDATE
  SET source_version = EXCLUDED.source_version,
      activated_at = EXCLUDED.activated_at,
      activated_by = EXCLUDED.activated_by;

  IF v_previous_source_version IS NOT NULL AND v_previous_source_version <> p_source_version THEN
    UPDATE cell_geometry_versions
    SET status = 'retired'
    WHERE source_version = v_previous_source_version
      AND status = 'active';
  END IF;

  UPDATE cell_geometry_versions
  SET status = 'active',
      activated_at = now()
  WHERE source_version = p_source_version;

  INSERT INTO cell_geometry_publish_events (
    source_version,
    validation_run_id,
    previous_source_version,
    published_cell_count,
    created_by,
    details
  )
  VALUES (
    p_source_version,
    v_validation_run_id,
    v_previous_source_version,
    v_canonical_final_count,
    auth.uid(),
    jsonb_build_object(
      'staged_valid_count', v_staged_valid_count,
      'canonical_existing_count', v_canonical_existing_count,
      'canonical_final_count', v_canonical_final_count
    )
  )
  RETURNING id INTO v_event_id;

  RETURN v_event_id;
END;
$$;

GRANT ALL ON cell_geometry_publish_events TO service_role;
GRANT EXECUTE ON FUNCTION publish_cell_geometry_source_version(TEXT, UUID) TO service_role;
