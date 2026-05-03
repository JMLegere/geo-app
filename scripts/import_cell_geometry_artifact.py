#!/usr/bin/env python3
"""Import an EarthNova cell geometry artifact into Supabase staging.

The artifact contract is defined in supabase/cell_geometry_artifact.schema.json.
This script intentionally owns file parsing/basic shape checks; PostGIS validation
and publishability remain DB-owned via validate_cell_geometry_source_version().
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import secrets
import subprocess
import tempfile
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 'cell-geometry-artifact/v1'


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description='Stage a cell geometry artifact into cell_geometry_versions + cell_geometry_staging.',
    )
    parser.add_argument('artifact', type=Path, help='Path to custom cell geometry artifact JSON bundle.')
    parser.add_argument(
        '--db-url',
        default=os.environ.get('CELL_GEOMETRY_DB_URL') or os.environ.get('DATABASE_URL') or os.environ.get('BETA_DB_URL'),
        help='Postgres connection string. Defaults to CELL_GEOMETRY_DB_URL, DATABASE_URL, then BETA_DB_URL.',
    )
    parser.add_argument(
        '--artifact-uri',
        default=None,
        help='Optional stable URI recorded on cell_geometry_versions.artifact_uri. Defaults to file://<resolved artifact path>.',
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Run the staging SQL inside a rollback transaction.',
    )
    parser.add_argument(
        '--emit-sql',
        action='store_true',
        help='Print generated SQL to stdout instead of executing psql. Useful for supabase db query --linked validation.',
    )
    return parser.parse_args()


def load_artifact(path: Path) -> dict[str, Any]:
    with path.open('rb') as handle:
        raw = handle.read()
    try:
        artifact = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise SystemExit(f'Invalid JSON artifact: {exc}') from exc
    if not isinstance(artifact, dict):
        raise SystemExit('Artifact root must be a JSON object.')
    return artifact


def require_object(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise SystemExit(f'{label} must be an object.')
    return value


def require_string(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise SystemExit(f'{label} must be a non-empty string.')
    return value


def require_geometry(value: Any, label: str, *, allow_polygon: bool) -> dict[str, Any]:
    geometry = require_object(value, label)
    allowed = {'MultiPolygon', 'Polygon'} if allow_polygon else {'MultiPolygon'}
    geometry_type = geometry.get('type')
    if geometry_type not in allowed:
        allowed_text = ', '.join(sorted(allowed))
        raise SystemExit(f'{label}.type must be one of: {allowed_text}.')
    if 'coordinates' not in geometry:
        raise SystemExit(f'{label}.coordinates is required.')
    return geometry


def validate_artifact_shape(artifact: dict[str, Any]) -> tuple[str, str, list[dict[str, Any]]]:
    schema_version = require_string(artifact.get('schema_version'), 'schema_version')
    if schema_version != SCHEMA_VERSION:
        raise SystemExit(f'Unsupported schema_version {schema_version!r}; expected {SCHEMA_VERSION!r}.')

    require_string(artifact.get('source'), 'source')
    source_version = require_string(artifact.get('source_version'), 'source_version')

    coverage = require_object(artifact.get('coverage'), 'coverage')
    require_geometry(coverage.get('geometry'), 'coverage.geometry', allow_polygon=False)

    cells = artifact.get('cells')
    if not isinstance(cells, list) or not cells:
        raise SystemExit('cells must be a non-empty array.')

    seen: set[str] = set()
    duplicate_ids: set[str] = set()
    for index, cell_value in enumerate(cells):
        cell = require_object(cell_value, f'cells[{index}]')
        cell_id = require_string(cell.get('cell_id'), f'cells[{index}].cell_id')
        if cell_id in seen:
            duplicate_ids.add(cell_id)
        seen.add(cell_id)
        require_geometry(cell.get('geometry'), f'cells[{index}].geometry', allow_polygon=True)
        if 'properties' in cell and not isinstance(cell['properties'], dict):
            raise SystemExit(f'cells[{index}].properties must be an object when present.')

    if duplicate_ids:
        sample = ', '.join(sorted(duplicate_ids)[:10])
        raise SystemExit(f'Artifact contains duplicate cell_id values before staging: {sample}')

    return source_version, artifact['source'], cells


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def sql_literal_json(value: Any) -> str:
    # Use a randomized dollar-quote tag so large JSON can be embedded without
    # escaping every quote. Regenerate if the tag appears in the payload.
    payload = json.dumps(value, separators=(',', ':'))
    while True:
        tag = f'earthnova_{secrets.token_hex(8)}'
        delimiter = f'${tag}$'
        if delimiter not in payload:
            return f'{delimiter}{payload}{delimiter}'


def build_sql(artifact: dict[str, Any], artifact_uri: str, artifact_sha256: str, *, dry_run: bool) -> str:
    payload = sql_literal_json(artifact)
    source_version = require_string(artifact.get('source_version'), 'source_version')
    source_version_expr = f"{sql_literal_json(source_version)}::jsonb #>> '{{}}'"
    transaction_end = 'ROLLBACK;' if dry_run else 'COMMIT;'
    return f"""
BEGIN;

DO $$
DECLARE
  v_source_version TEXT := {source_version_expr};
BEGIN
  IF EXISTS (
    SELECT 1
    FROM cell_geometry_active_version active
    WHERE active.source_version = v_source_version
  ) OR EXISTS (
    SELECT 1
    FROM cell_geometry_cells cells
    WHERE cells.source_version = v_source_version
  ) THEN
    RAISE EXCEPTION 'Cannot restage source_version % with active or canonical geometry rows', v_source_version;
  END IF;
END;
$$;

WITH artifact AS (
  SELECT {payload}::jsonb AS payload
), version_payload AS (
  SELECT
    payload->>'source_version' AS source_version,
    payload->>'source' AS source,
    ST_Multi(ST_SetSRID(ST_GeomFromGeoJSON((payload->'coverage'->'geometry')::text), 4326))::geometry(MultiPolygon, 4326) AS coverage_geom,
    jsonb_array_length(payload->'cells') AS expected_cell_count
  FROM artifact
), upsert_version AS (
  INSERT INTO cell_geometry_versions (
    source_version,
    source,
    status,
    expected_cell_count,
    coverage_geom,
    coverage_area_m2,
    artifact_uri,
    artifact_sha256,
    validation_summary
  )
  SELECT
    version_payload.source_version,
    version_payload.source,
    'staged',
    version_payload.expected_cell_count,
    version_payload.coverage_geom,
    ST_Area(version_payload.coverage_geom::geography),
    {sql_literal_json(artifact_uri)}::jsonb #>> '{{}}',
    {sql_literal_json(artifact_sha256)}::jsonb #>> '{{}}',
    '{{}}'::jsonb
  FROM version_payload
  ON CONFLICT (source_version) DO UPDATE
  SET source = EXCLUDED.source,
      status = 'staged',
      expected_cell_count = EXCLUDED.expected_cell_count,
      coverage_geom = EXCLUDED.coverage_geom,
      coverage_area_m2 = EXCLUDED.coverage_area_m2,
      artifact_uri = EXCLUDED.artifact_uri,
      artifact_sha256 = EXCLUDED.artifact_sha256,
      validation_summary = '{{}}'::jsonb,
      validated_at = NULL,
      activated_at = NULL
  RETURNING source_version
), clear_staging AS (
  DELETE FROM cell_geometry_staging staging
  USING upsert_version
  WHERE staging.source_version = upsert_version.source_version
), staged_cells AS (
  SELECT
    upsert_version.source_version,
    cell.value AS raw_payload,
    cell.value->>'cell_id' AS cell_id,
    cell.value->'geometry' AS raw_geometry,
    COALESCE(cell.value->'properties', '{{}}'::jsonb) AS raw_properties,
    ST_Multi(ST_SetSRID(ST_GeomFromGeoJSON((cell.value->'geometry')::text), 4326))::geometry(MultiPolygon, 4326) AS parsed_geom
  FROM artifact
  JOIN upsert_version ON true
  CROSS JOIN LATERAL jsonb_array_elements(artifact.payload->'cells') AS cell(value)
), inserted AS (
  INSERT INTO cell_geometry_staging (
    source_version,
    cell_id,
    raw_payload,
    raw_geometry,
    raw_properties,
    parsed_geom,
    parsed_centroid,
    parsed_bbox,
    parsed_area_m2,
    validation_status,
    validation_errors
  )
  SELECT
    source_version,
    cell_id,
    raw_payload,
    raw_geometry,
    raw_properties,
    parsed_geom,
    ST_PointOnSurface(parsed_geom)::geometry(Point, 4326),
    ST_Envelope(parsed_geom)::geometry(Polygon, 4326),
    ST_Area(parsed_geom::geography),
    'pending',
    '[]'::jsonb
  FROM staged_cells
  RETURNING id
)
SELECT
  (SELECT source_version FROM upsert_version) AS source_version,
  (SELECT COUNT(*) FROM inserted) AS staged_cell_count;

{transaction_end}
"""


def run_psql(db_url: str, sql: str) -> None:
    with tempfile.NamedTemporaryFile('w', suffix='.sql', delete=False) as handle:
        handle.write(sql)
        sql_path = handle.name
    try:
        subprocess.run(
            ['psql', db_url, '-v', 'ON_ERROR_STOP=1', '-f', sql_path],
            text=True,
            check=True,
        )
    finally:
        try:
            Path(sql_path).unlink()
        except FileNotFoundError:
            pass


def main() -> int:
    args = parse_args()
    if not args.db_url and not args.emit_sql:
        raise SystemExit('Missing DB URL. Provide --db-url or set CELL_GEOMETRY_DB_URL, DATABASE_URL, or BETA_DB_URL.')

    artifact_path = args.artifact.resolve()
    artifact = load_artifact(artifact_path)
    source_version, source, cells = validate_artifact_shape(artifact)
    artifact_uri = args.artifact_uri or artifact_path.as_uri()
    artifact_sha256 = file_sha256(artifact_path)

    sql = build_sql(artifact, artifact_uri, artifact_sha256, dry_run=args.dry_run)
    if args.emit_sql:
        print(sql)
        return 0

    run_psql(args.db_url, sql)

    action = 'validated staging SQL with rollback' if args.dry_run else 'staged artifact'
    print(f'{action}: source_version={source_version} source={source} cells={len(cells)} sha256={artifact_sha256}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
