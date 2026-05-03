#!/usr/bin/env python3
"""Generate a custom cell geometry artifact from existing encoded cell IDs.

Current beta/prod cell IDs use v_<x>_<y>, where the center is:
  lat = x / 500
  lng = y / 500

Because these centers live on a uniform latitude/longitude lattice, each bounded
point-Voronoi cell is the half-step square around its center:
  lat in [(x - 0.5) / 500, (x + 0.5) / 500]
  lng in [(y - 0.5) / 500, (y + 0.5) / 500]

This avoids remote ST_Voronoi timeouts while preserving the same local Voronoi
geometry implied by the encoded cell IDs.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
from collections.abc import Iterable
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, NamedTuple


SCHEMA_VERSION = 'cell-geometry-artifact/v1'
GRID_SCALE = 500.0
HALF_STEP = 0.5 / GRID_SCALE


class CellPoint(NamedTuple):
    cell_id: str
    grid_x: int
    grid_y: int

    @property
    def lat(self) -> float:
        return self.grid_x / GRID_SCALE

    @property
    def lng(self) -> float:
        return self.grid_y / GRID_SCALE


class Component(NamedTuple):
    index: int
    points: list[CellPoint]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description='Generate a cell geometry artifact from v_<x>_<y> cell_properties IDs using lattice Voronoi cells.',
    )
    parser.add_argument('--output', type=Path, required=True, help='Path to write the generated artifact JSON.')
    parser.add_argument(
        '--source-version',
        default=None,
        help='Immutable source_version. Defaults to lattice-voronoi-cell-id-centers-<UTC timestamp>.',
    )
    parser.add_argument('--source', default='lattice-voronoi-from-cell-id-centers', help='Artifact source identifier.')
    parser.add_argument(
        '--supabase-args',
        default='--linked',
        help='Arguments passed to `supabase db query`, for example "--linked" or "--db-url <url>".',
    )
    return parser.parse_args()


def run_supabase_query(sql: str, supabase_args: str, timeout_seconds: int = 60) -> list[dict[str, Any]]:
    with tempfile.NamedTemporaryFile('w', suffix='.sql', delete=False) as handle:
        handle.write(sql)
        sql_path = handle.name
    try:
        cmd = ['supabase', 'db', 'query', *supabase_args.split(), '-f', sql_path, '-o', 'json']
        result = subprocess.run(cmd, text=True, capture_output=True, timeout=timeout_seconds)
        if result.returncode != 0:
            raise SystemExit(
                f'supabase db query failed with exit code {result.returncode}\n'
                f'stdout:\n{result.stdout}\n'
                f'stderr:\n{result.stderr}'
            )
        data = json.loads(result.stdout)
        rows = data.get('rows') if isinstance(data, dict) else data
        if not isinstance(rows, list):
            raise SystemExit(f'Unexpected supabase query output: {data!r}')
        return rows
    finally:
        try:
            Path(sql_path).unlink()
        except FileNotFoundError:
            pass


def fetch_cell_points(supabase_args: str) -> list[CellPoint]:
    rows = run_supabase_query(
        """
SELECT cell_id
FROM cell_properties
WHERE cell_id ~ '^v_-?[0-9]+_-?[0-9]+$'
ORDER BY cell_id;
""",
        supabase_args,
    )
    points: list[CellPoint] = []
    for row in rows:
        raw = row['cell_id']
        _, x_text, y_text = raw.split('_')
        points.append(CellPoint(raw, int(x_text), int(y_text)))
    if not points:
        raise SystemExit('No v_<x>_<y> cell_properties rows found.')
    return points


def connected_components(points: Iterable[CellPoint]) -> list[Component]:
    by_xy = {(p.grid_x, p.grid_y): p for p in points}
    seen: set[tuple[int, int]] = set()
    raw_components: list[list[CellPoint]] = []

    for xy, point in by_xy.items():
        if xy in seen:
            continue
        seen.add(xy)
        stack = [xy]
        component = [point]
        while stack:
            x, y = stack.pop()
            for neighbor in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if neighbor in by_xy and neighbor not in seen:
                    seen.add(neighbor)
                    stack.append(neighbor)
                    component.append(by_xy[neighbor])
        component.sort(key=lambda p: p.cell_id)
        raw_components.append(component)

    raw_components.sort(key=lambda c: (-len(c), c[0].cell_id))
    return [Component(index=index, points=component) for index, component in enumerate(raw_components)]


def square_coordinates(point: CellPoint) -> list[list[list[float]]]:
    min_lat = point.lat - HALF_STEP
    max_lat = point.lat + HALF_STEP
    min_lng = point.lng - HALF_STEP
    max_lng = point.lng + HALF_STEP
    return [[
        [min_lng, min_lat],
        [max_lng, min_lat],
        [max_lng, max_lat],
        [min_lng, max_lat],
        [min_lng, min_lat],
    ]]


def build_cell(point: CellPoint, component: Component) -> dict[str, Any]:
    return {
        'cell_id': point.cell_id,
        'geometry': {
            'type': 'Polygon',
            'coordinates': square_coordinates(point),
        },
        'properties': {
            'grid_x': point.grid_x,
            'grid_y': point.grid_y,
            'center_lat': point.lat,
            'center_lng': point.lng,
            'component_index': component.index,
            'component_size': len(component.points),
            'generation_mode': 'uniform-lattice-bounded-voronoi',
        },
    }


def build_coverage_geometry(points: list[CellPoint]) -> dict[str, Any]:
    # Use one polygon per cell as the authoritative coverage MultiPolygon. This
    # is intentionally verbose but guarantees no artificial coverage over sparse
    # gaps between disconnected/diagonal cells. PostGIS validation can dissolve it.
    return {
        'type': 'MultiPolygon',
        'coordinates': [square_coordinates(point) for point in sorted(points, key=lambda p: p.cell_id)],
    }


def main() -> int:
    args = parse_args()
    generated_at = datetime.now(UTC).replace(microsecond=0).isoformat().replace('+00:00', 'Z')
    source_version = args.source_version or f"lattice-voronoi-cell-id-centers-{generated_at.replace(':', '').replace('-', '').replace('Z', 'z')}"

    points = fetch_cell_points(args.supabase_args)
    components = connected_components(points)
    print(f'fetched {len(points)} cells in {len(components)} connected components')

    cells = [build_cell(point, component) for component in components for point in component.points]
    cells.sort(key=lambda cell: cell['cell_id'])

    artifact = {
        'schema_version': SCHEMA_VERSION,
        'source': args.source,
        'source_version': source_version,
        'generated_at': generated_at,
        'generator': {
            'name': 'scripts/generate_cell_geometry_artifact_from_cell_ids.py',
            'version': '3.0.0',
            'parameters': {
                'cell_id_format': 'v_<round(lat*500)>_<round(lng*500)>',
                'grid_scale': GRID_SCALE,
                'half_step_degrees': HALF_STEP,
                'component_count': len(components),
                'geometry_strategy': 'uniform-lattice-bounded-voronoi',
            },
        },
        'coverage': {
            'geometry': build_coverage_geometry(points),
            'properties': {
                'kind': 'union_of_lattice_voronoi_cell_squares',
                'component_count': len(components),
                'grid_scale': GRID_SCALE,
                'half_step_degrees': HALF_STEP,
            },
        },
        'cells': cells,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(artifact, indent=2, sort_keys=True) + '\n')
    print(f'wrote {args.output}: source_version={source_version} cells={len(cells)} components={len(components)}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
