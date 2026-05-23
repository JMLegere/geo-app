#!/usr/bin/env python3
"""Import a normalized cell habitat artifact into Supabase/PostGIS."""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 'cell-habitat-artifact/v1'


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description='Import a normalized cell habitat artifact into Supabase.',
    )
    parser.add_argument('artifact', type=Path, help='Path to the artifact JSON.')
    parser.add_argument('--dry-run', action='store_true', help='Validate and summarize without executing SQL.')
    parser.add_argument(
        '--emit-sql',
        type=Path,
        default=None,
        help='Write the generated SQL to this path instead of executing it.',
    )
    parser.add_argument(
        '--supabase-args',
        default='--linked',
        help='Arguments passed to `supabase db query`, e.g. "--linked" or "--db-url <url>".',
    )
    return parser.parse_args()


def sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def sql_json(value: Any) -> str:
    return sql_literal(json.dumps(value, separators=(',', ':'))) + '::jsonb'


def build_sql(artifact: dict[str, Any]) -> str:
    if artifact.get('schema_version') != SCHEMA_VERSION:
        raise SystemExit(f"Unsupported schema_version: {artifact.get('schema_version')!r}")

    source = str(artifact['source'])
    source_version = str(artifact['source_version'])
    coverage = artifact['coverage']['geometry']
    features = artifact.get('features') or []
    metadata = {
        'generated_at': artifact.get('generated_at'),
        'generator': artifact.get('generator'),
        'coverage_properties': artifact['coverage'].get('properties') or {},
    }

    lines = [
        'BEGIN;',
        'INSERT INTO cell_habitat_source_versions (',
        '  source_version,',
        '  source,',
        '  coverage_geom,',
        '  feature_count,',
        '  metadata',
        ') VALUES (',
        f'  {sql_literal(source_version)},',
        f'  {sql_literal(source)},',
        f'  ST_Multi(ST_SetSRID(ST_GeomFromGeoJSON({sql_literal(json.dumps(coverage, separators=(",", ":")))}), 4326)),',
        f'  {len(features)},',
        f'  {sql_json(metadata)}',
        ')',
        'ON CONFLICT (source_version) DO UPDATE SET',
        '  source = EXCLUDED.source,',
        '  coverage_geom = EXCLUDED.coverage_geom,',
        '  feature_count = EXCLUDED.feature_count,',
        '  metadata = EXCLUDED.metadata,',
        '  imported_at = now();',
        f'DELETE FROM cell_habitat_source_features WHERE source_version = {sql_literal(source_version)};',
    ]

    if features:
        lines.extend([
            'INSERT INTO cell_habitat_source_features (',
            '  source_version,',
            '  feature_id,',
            '  normalized_habitat,',
            '  source_layer,',
            '  weight,',
            '  source_properties,',
            '  geom',
            ') VALUES',
        ])
        value_rows = []
        for feature in features:
            geometry_json = json.dumps(feature['geometry'], separators=(',', ':'))
            value_rows.append(
                '  ('
                f"{sql_literal(source_version)}, "
                f"{sql_literal(str(feature['feature_id']))}, "
                f"{sql_literal(str(feature['habitat']))}, "
                f"{sql_literal(str(feature['source_layer']))}, "
                f"{float(feature.get('weight', 1.0))}, "
                f"{sql_json(feature.get('properties') or {})}, "
                f"ST_Multi(ST_SetSRID(ST_GeomFromGeoJSON({sql_literal(geometry_json)}), 4326))"
                ')'
            )
        lines.append(',\n'.join(value_rows) + ';')

    lines.extend([
        'UPDATE cell_habitat_source_versions version',
        'SET feature_count = (',
        '  SELECT COUNT(*)::INTEGER',
        '  FROM cell_habitat_source_features feature',
        '  WHERE feature.source_version = version.source_version',
        ')',
        f'WHERE version.source_version = {sql_literal(source_version)};',
        'COMMIT;',
        '',
    ])
    return '\n'.join(lines)


def run_supabase_sql(sql: str, supabase_args: str) -> None:
    with tempfile.NamedTemporaryFile('w', suffix='.sql', delete=False) as handle:
        handle.write(sql)
        sql_path = handle.name
    try:
        cmd = ['supabase', 'db', 'query', *supabase_args.split(), '-f', sql_path, '-o', 'json']
        result = subprocess.run(cmd, text=True, capture_output=True)
        if result.returncode != 0:
            raise SystemExit(
                f'supabase db query failed with exit code {result.returncode}\n'
                f'stdout:\n{result.stdout}\n'
                f'stderr:\n{result.stderr}'
            )
        if result.stdout.strip():
            print(result.stdout.strip())
    finally:
        Path(sql_path).unlink(missing_ok=True)


def main() -> int:
    args = parse_args()
    artifact = json.loads(args.artifact.read_text())
    sql = build_sql(artifact)
    features = artifact.get('features') or []
    print(
        f"artifact {artifact.get('source_version')} → {len(features)} features "
        f"from {artifact.get('source')}"
    )
    if args.dry_run:
        return 0
    if args.emit_sql is not None:
        args.emit_sql.write_text(sql)
        print(f'wrote SQL to {args.emit_sql}')
        return 0
    run_supabase_sql(sql, args.supabase_args)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
