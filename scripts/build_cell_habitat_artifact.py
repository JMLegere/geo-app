#!/usr/bin/env python3
"""Normalize OSM / land-cover GeoJSON inputs into a cell habitat artifact.

This keeps transport concerns outside the database. Feed it one or more GeoJSON
FeatureCollections exported from OSM tooling, Overpass, QGIS, or satellite/
land-cover pipelines. The output artifact can then be imported into Supabase and
aggregated against canonical cell geometry in PostGIS.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from collections.abc import Iterable
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 'cell-habitat-artifact/v1'
ALLOWED_HABITATS = (
    'forest',
    'ocean',
    'freshwater',
    'swamp',
    'desert',
    'plains',
    'urban',
    'mountain',
)
ESA_CODE_TO_HABITAT = {
    10: 'forest',
    20: 'plains',
    30: 'plains',
    40: 'plains',
    50: 'urban',
    60: 'desert',
    70: 'mountain',
    80: 'freshwater',
    90: 'swamp',
    95: 'swamp',
    100: 'mountain',
}
URBAN_LANDUSE = {
    'residential',
    'commercial',
    'industrial',
    'retail',
    'garages',
    'brownfield',
    'construction',
    'railway',
}
FRESHWATER_WATER = {
    'lake',
    'reservoir',
    'pond',
    'river',
    'canal',
    'stream',
    'basin',
    'ditch',
}
OCEAN_WATER = {'sea', 'ocean', 'bay', 'strait', 'sound', 'lagoon'}
WETLAND_NATURAL = {'wetland', 'marsh', 'bog', 'fen'}
PLAINS_LANDUSE = {
    'meadow',
    'grass',
    'farmland',
    'orchard',
    'vineyard',
    'plant_nursery',
    'greenfield',
    'allotments',
}
PLAINS_NATURAL = {'grassland', 'heath', 'scrub'}
MOUNTAIN_NATURAL = {'bare_rock', 'scree', 'shingle', 'fell', 'ridge', 'glacier'}
DESERT_NATURAL = {'sand', 'dune'}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description='Build a normalized cell habitat artifact from one or more GeoJSON source layers.',
    )
    parser.add_argument('--output', type=Path, required=True, help='Path to write the artifact JSON.')
    parser.add_argument(
        '--source-version',
        default=None,
        help='Immutable source version. Defaults to habitat-source-<UTC timestamp>.',
    )
    parser.add_argument(
        '--source',
        default='osm-landcover-geojson',
        help='Top-level source identifier stored in the artifact metadata.',
    )
    parser.add_argument(
        '--input',
        nargs=2,
        action='append',
        metavar=('SOURCE_LAYER', 'PATH'),
        required=True,
        help='Repeatable source-layer / GeoJSON-path pair.',
    )
    return parser.parse_args()


def flatten_tags(properties: dict[str, Any]) -> dict[str, str]:
    tags: dict[str, str] = {}
    nested = properties.get('tags')
    if isinstance(nested, dict):
        for key, value in nested.items():
            if value is None:
                continue
            tags[str(key).lower()] = str(value).strip()
    for key, value in properties.items():
        if key == 'tags' or value is None or isinstance(value, (dict, list)):
            continue
        tags.setdefault(str(key).lower(), str(value).strip())
    return tags


def infer_esa_code(properties: dict[str, Any], tags: dict[str, str]) -> int | None:
    for key in ('esa_code', 'class_code', 'map_code', 'value', 'dn'):
        raw = properties.get(key)
        if raw is None:
            raw = tags.get(key)
        if raw is None:
            continue
        try:
            return int(raw)
        except (TypeError, ValueError):
            continue
    return None


def normalized_habitat(source_layer: str, properties: dict[str, Any]) -> str | None:
    direct = properties.get('normalized_habitat') or properties.get('habitat')
    if isinstance(direct, str) and direct.strip().lower() in ALLOWED_HABITATS:
        return direct.strip().lower()

    tags = flatten_tags(properties)
    direct_tag = tags.get('normalized_habitat') or tags.get('habitat')
    if direct_tag and direct_tag.lower() in ALLOWED_HABITATS:
        return direct_tag.lower()

    esa_code = infer_esa_code(properties, tags)
    if esa_code is not None and esa_code in ESA_CODE_TO_HABITAT:
        return ESA_CODE_TO_HABITAT[esa_code]

    landuse = tags.get('landuse', '').lower()
    natural = tags.get('natural', '').lower()
    water = tags.get('water', '').lower()
    waterway = tags.get('waterway', '').lower()
    wetland = tags.get('wetland', '').lower()
    leisure = tags.get('leisure', '').lower()
    amenity = tags.get('amenity', '').lower()
    building = tags.get('building', '').lower()
    surface = tags.get('surface', '').lower()
    place = tags.get('place', '').lower()

    if landuse in URBAN_LANDUSE or amenity == 'parking' or (building and building != 'no'):
        return 'urban'
    if natural == 'wood' or landuse == 'forest':
        return 'forest'
    if natural in WETLAND_NATURAL or wetland:
        return 'swamp'
    if natural == 'water' or water in FRESHWATER_WATER or waterway in {'riverbank', 'canal', 'stream', 'ditch'} or landuse in {'reservoir', 'basin'}:
        if water in OCEAN_WATER or place == 'sea':
            return 'ocean'
        return 'freshwater'
    if natural in DESERT_NATURAL or surface in {'sand', 'dirt'}:
        return 'desert'
    if natural in MOUNTAIN_NATURAL or landuse == 'quarry':
        return 'mountain'
    if landuse in PLAINS_LANDUSE or natural in PLAINS_NATURAL or leisure in {'park', 'garden', 'golf_course', 'pitch'}:
        return 'plains'

    # Layer hints help with source-specific naming where properties are sparse.
    layer_name = source_layer.lower()
    if 'urban' in layer_name:
        return 'urban'
    if 'forest' in layer_name or 'wood' in layer_name:
        return 'forest'
    if 'wetland' in layer_name or 'swamp' in layer_name:
        return 'swamp'
    if 'water' in layer_name or 'freshwater' in layer_name:
        return 'freshwater'
    if 'ocean' in layer_name or 'coastal' in layer_name:
        return 'ocean'
    if 'grass' in layer_name or 'plains' in layer_name or 'farmland' in layer_name:
        return 'plains'
    if 'desert' in layer_name:
        return 'desert'
    if 'mountain' in layer_name or 'rock' in layer_name:
        return 'mountain'
    return None


def to_multipolygon(geometry: dict[str, Any]) -> dict[str, Any] | None:
    geom_type = geometry.get('type')
    coordinates = geometry.get('coordinates')
    if geom_type == 'Polygon' and isinstance(coordinates, list):
        return {'type': 'MultiPolygon', 'coordinates': [coordinates]}
    if geom_type == 'MultiPolygon' and isinstance(coordinates, list):
        return {'type': 'MultiPolygon', 'coordinates': coordinates}
    return None


def iter_positions(coordinates: Any) -> Iterable[tuple[float, float]]:
    if isinstance(coordinates, list):
        if len(coordinates) >= 2 and all(isinstance(v, (int, float)) for v in coordinates[:2]):
            yield float(coordinates[0]), float(coordinates[1])
            return
        for child in coordinates:
            yield from iter_positions(child)


def bbox_polygon(min_lng: float, min_lat: float, max_lng: float, max_lat: float) -> dict[str, Any]:
    return {
        'type': 'MultiPolygon',
        'coordinates': [[[
            [min_lng, min_lat],
            [max_lng, min_lat],
            [max_lng, max_lat],
            [min_lng, max_lat],
            [min_lng, min_lat],
        ]]],
    }


def feature_identifier(source_layer: str, index: int, properties: dict[str, Any], tags: dict[str, str]) -> str:
    for key in ('feature_id', 'id', '@id', 'osm_id', 'fid'):
        if key in properties and properties[key] not in (None, ''):
            return f'{source_layer}:{properties[key]}'
        if key in tags and tags[key] not in ('', 'none'):
            return f'{source_layer}:{tags[key]}'
    return f'{source_layer}:{index}'


def feature_weight(properties: dict[str, Any], tags: dict[str, str]) -> float:
    raw = properties.get('weight')
    if raw is None:
        raw = tags.get('weight')
    if raw is None:
        return 1.0
    try:
        parsed = float(raw)
    except (TypeError, ValueError):
        return 1.0
    return parsed if parsed > 0 else 1.0


def load_features(source_layer: str, path: Path) -> list[dict[str, Any]]:
    data = json.loads(path.read_text())
    if data.get('type') != 'FeatureCollection':
        raise SystemExit(f'{path} must be a GeoJSON FeatureCollection')

    features: list[dict[str, Any]] = []
    for index, feature in enumerate(data.get('features') or []):
        if not isinstance(feature, dict):
            continue
        geometry = feature.get('geometry')
        if not isinstance(geometry, dict):
            continue
        multipolygon = to_multipolygon(geometry)
        if multipolygon is None:
            continue
        properties = feature.get('properties') or {}
        if not isinstance(properties, dict):
            properties = {}
        tags = flatten_tags(properties)
        habitat = normalized_habitat(source_layer, properties)
        if habitat is None:
            continue
        features.append({
            'feature_id': feature_identifier(source_layer, index, properties, tags),
            'habitat': habitat,
            'source_layer': source_layer,
            'weight': feature_weight(properties, tags),
            'geometry': multipolygon,
            'properties': properties,
        })
    return features


def main() -> int:
    args = parse_args()
    generated_at = datetime.now(UTC).replace(microsecond=0).isoformat().replace('+00:00', 'Z')
    source_version = args.source_version or f"habitat-source-{generated_at.replace(':', '').replace('-', '').replace('Z', 'z')}"

    normalized_features: list[dict[str, Any]] = []
    for source_layer, raw_path in args.input:
        path = Path(raw_path)
        if not path.exists():
            raise SystemExit(f'input not found: {path}')
        normalized_features.extend(load_features(source_layer, path))

    if not normalized_features:
        raise SystemExit('No polygon features normalized into habitat categories.')

    min_lng = min_lat = float('inf')
    max_lng = max_lat = float('-inf')
    habitat_counts: Counter[str] = Counter()
    for feature in normalized_features:
        habitat_counts[feature['habitat']] += 1
        for lng, lat in iter_positions(feature['geometry']['coordinates']):
            min_lng = min(min_lng, lng)
            min_lat = min(min_lat, lat)
            max_lng = max(max_lng, lng)
            max_lat = max(max_lat, lat)

    artifact = {
        'schema_version': SCHEMA_VERSION,
        'source': args.source,
        'source_version': source_version,
        'generated_at': generated_at,
        'generator': {
            'name': 'scripts/build_cell_habitat_artifact.py',
            'version': '1.0.0',
            'parameters': {
                'input_count': len(args.input),
                'inputs': [
                    {'source_layer': source_layer, 'path': raw_path}
                    for source_layer, raw_path in args.input
                ],
                'normalized_habitat_counts': dict(sorted(habitat_counts.items())),
            },
        },
        'coverage': {
            'geometry': bbox_polygon(min_lng, min_lat, max_lng, max_lat),
            'properties': {
                'kind': 'bbox_of_source_features',
                'feature_count': len(normalized_features),
            },
        },
        'features': normalized_features,
    }
    args.output.write_text(json.dumps(artifact, indent=2) + '\n')
    print(f'wrote {len(normalized_features)} normalized habitat features to {args.output}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
