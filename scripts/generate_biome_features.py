#!/usr/bin/env python3
import json
import math
import sys
import urllib.request
import zipfile
from pathlib import Path

try:
    import geopandas as gpd
    from shapely.ops import unary_union
except ImportError:
    print("ERROR: geopandas not installed.")
    print("Run: python3 -m venv /tmp/biome_venv && source /tmp/biome_venv/bin/activate && pip install geopandas && python3 scripts/generate_biome_features.py")
    sys.exit(1)

REPO_ROOT = Path(__file__).parent.parent
OUTPUT_PATH = REPO_ROOT / "assets" / "biome_features.json"
CACHE_DIR = Path(__file__).parent / ".cache"

LINE_SAMPLE_KM = 2.0
POLYGON_SIMPLIFY_DEG = 0.01

NE_BASE = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson"
NE_SOURCES = {
    "coastline": (f"{NE_BASE}/ne_10m_coastline.geojson", "ne_10m_coastline.geojson"),
    "rivers":    (f"{NE_BASE}/ne_10m_rivers_lake_centerlines.geojson", "ne_10m_rivers.geojson"),
    "lakes":     (f"{NE_BASE}/ne_10m_lakes.geojson", "ne_10m_lakes.geojson"),
}

RESOLVE_URLS = [
    ("https://storage.googleapis.com/teow2016/Ecoregions2017.zip", "Ecoregions2017.zip"),
    ("https://zenodo.org/record/3261807/files/Ecoregions2017.zip?download=1", "Ecoregions2017.zip"),
]

# Plains biomes (7, 8, 12) are omitted — they are the default fallback in BiomeFeatureIndex.
BIOME_HABITAT = {
    1:  "forests",   # Tropical & Subtropical Moist Broadleaf Forests
    2:  "forests",   # Tropical & Subtropical Dry Broadleaf Forests
    3:  "forests",   # Tropical & Subtropical Coniferous Forests
    4:  "forests",   # Temperate Broadleaf & Mixed Forests
    5:  "forests",   # Temperate Conifer Forests
    6:  "forests",   # Boreal Forests/Taiga
    9:  "wetlands",  # Flooded Grasslands & Savannas
    10: "mountains", # Montane Grasslands & Shrublands
    11: "mountains", # Tundra
    13: "deserts",   # Deserts & Xeric Shrublands
    14: "wetlands",  # Mangroves
}


def haversine_km(lat1, lon1, lat2, lon2):
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2
         + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2))
         * math.sin(dlon / 2) ** 2)
    return R * 2 * math.asin(math.sqrt(min(a, 1.0)))


def sample_line_coords(coords, interval_km):
    # coords are (lon, lat) from GeoJSON; output is [[lat, lon], ...] for BiomeFeatureIndex
    if not coords:
        return []
    points = [[round(coords[0][1], 6), round(coords[0][0], 6)]]
    accumulated = 0.0
    prev = coords[0]
    for curr in coords[1:]:
        seg_km = haversine_km(prev[1], prev[0], curr[1], curr[0])
        if seg_km == 0:
            prev = curr
            continue
        if accumulated + seg_km >= interval_km:
            steps = int((accumulated + seg_km) / interval_km)
            for i in range(1, steps + 1):
                t = (i * interval_km - accumulated) / seg_km
                if 0 < t <= 1.0:
                    lat = prev[1] + t * (curr[1] - prev[1])
                    lon = prev[0] + t * (curr[0] - prev[0])
                    points.append([round(lat, 6), round(lon, 6)])
            accumulated = (accumulated + seg_km) % interval_km
        else:
            accumulated += seg_km
        prev = curr
    return points


def geom_to_sample_points(geom, interval_km):
    points = []
    if geom is None:
        return points
    if geom.geom_type == "LineString":
        points.extend(sample_line_coords(list(geom.coords), interval_km))
    elif geom.geom_type == "MultiLineString":
        for line in geom.geoms:
            points.extend(sample_line_coords(list(line.coords), interval_km))
    elif geom.geom_type == "Polygon":
        points.extend(sample_line_coords(list(geom.exterior.coords), interval_km))
    elif geom.geom_type == "MultiPolygon":
        for poly in geom.geoms:
            points.extend(sample_line_coords(list(poly.exterior.coords), interval_km))
    return points


def geom_to_polygon_rings(geom):
    rings = []
    if geom is None or geom.is_empty:
        return rings
    polys = (
        [geom] if geom.geom_type == "Polygon"
        else list(geom.geoms) if geom.geom_type == "MultiPolygon"
        else []
    )
    for poly in polys:
        if poly.is_empty:
            continue
        # GeoJSON coords are (lon, lat); BiomeFeatureIndex expects [lat, lon]
        ring = [[round(lat, 5), round(lon, 5)] for lon, lat in poly.exterior.coords]
        if len(ring) >= 4:
            rings.append(ring)
    return rings


def download_file(url, dest):
    print(f"    Downloading {dest.name}...")
    try:
        urllib.request.urlretrieve(url, dest)
        print(f"    OK {dest.stat().st_size / 1_000_000:.1f} MB")
        return True
    except Exception as e:
        print(f"    Failed: {e}")
        if dest.exists():
            dest.unlink()
        return False


def ensure_cached(url_filename_pairs):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    for url, filename in url_filename_pairs:
        path = CACHE_DIR / filename
        if path.exists():
            print(f"    Cached: {path.name} ({path.stat().st_size / 1_000_000:.1f} MB)")
            return path
        if download_file(url, path):
            return path
    raise RuntimeError("All download attempts failed")


def process_ne_line_feature(url, filename, label):
    print(f"  [{label}]")
    path = ensure_cached([(url, filename)])
    gdf = gpd.read_file(path)
    points = []
    for _, row in gdf.iterrows():
        points.extend(geom_to_sample_points(row.geometry, LINE_SAMPLE_KM))
    print(f"    -> {len(points):,} points")
    return points


def process_resolve_ecoregions():
    print("  [ecoregions]")
    zip_path = ensure_cached(RESOLVE_URLS)

    extract_dir = CACHE_DIR / "ecoregions_extracted"
    if not extract_dir.exists():
        print("    Extracting...")
        with zipfile.ZipFile(zip_path) as z:
            z.extractall(extract_dir)

    shp_files = list(extract_dir.rglob("*.shp"))
    if not shp_files:
        raise FileNotFoundError(f"No .shp file found in {extract_dir}")

    gdf = gpd.read_file(shp_files[0])
    print(f"    Loaded {len(gdf):,} ecoregions")

    biome_col = next(
        (c for c in ["BIOME_NUM", "BIOME", "biome_num", "biome"] if c in gdf.columns),
        None,
    )
    if biome_col is None:
        raise ValueError(f"Cannot find biome column. Available: {list(gdf.columns)}")

    gdf[biome_col] = gdf[biome_col].astype(float).astype(int)

    habitat_rings = {h: [] for h in ["forests", "deserts", "wetlands", "mountains"]}

    for biome_num, habitat in BIOME_HABITAT.items():
        subset = gdf[gdf[biome_col] == biome_num]
        if subset.empty:
            continue
        merged = unary_union(subset.geometry)
        if merged.is_empty:
            continue
        simplified = merged.simplify(POLYGON_SIMPLIFY_DEG, preserve_topology=True)
        rings = geom_to_polygon_rings(simplified)
        habitat_rings[habitat].extend(rings)
        print(f"    Biome {biome_num} -> {habitat}: {len(rings)} rings")

    for habitat, rings in habitat_rings.items():
        print(f"    {habitat}: {len(rings)} total rings")

    return habitat_rings


def point_in_polygon(lat, lon, ring):
    inside = False
    n = len(ring)
    for i in range(n):
        j = (i - 1) % n
        i_lat, i_lon = ring[i]
        j_lat, j_lon = ring[j]
        if ((i_lon > lon) != (j_lon > lon)) and (
            lat < (j_lat - i_lat) * (lon - i_lon) / (j_lon - i_lon) + i_lat
        ):
            inside = not inside
    return inside


def verify_location(result, lat, lon, label):
    print(f"\n  {label} ({lat}, {lon}):")
    for key in ["coastline", "rivers", "lakes"]:
        pts = result[key]
        if not pts:
            print(f"    {key}: NO DATA")
            continue
        dist = min(haversine_km(lat, lon, p[0], p[1]) for p in pts)
        hit = "HIT" if dist <= 5.0 else f"nearest {dist:.1f} km"
        print(f"    {key}: {hit}")
    for key in ["forests", "deserts", "wetlands", "mountains"]:
        inside = any(point_in_polygon(lat, lon, r) for r in result[key])
        print(f"    {key}: {'INSIDE' if inside else 'outside'}")


def main():
    print("Generating biome_features.json\n")

    result = {
        "coastline": [], "rivers": [], "lakes": [],
        "forests": [], "deserts": [], "wetlands": [], "mountains": [],
    }

    for key in ["coastline", "rivers", "lakes"]:
        url, filename = NE_SOURCES[key]
        result[key] = process_ne_line_feature(url, filename, key)

    print()
    habitat_rings = process_resolve_ecoregions()
    for key in ["forests", "deserts", "wetlands", "mountains"]:
        result[key] = habitat_rings[key]

    print(f"\nWriting {OUTPUT_PATH}...")
    with open(OUTPUT_PATH, "w") as f:
        json.dump(result, f, separators=(",", ":"))

    size_mb = OUTPUT_PATH.stat().st_size / 1_000_000
    print(f"Done! {size_mb:.1f} MB")

    verify_location(result, 45.96, -66.64, "Fredericton NB")
    verify_location(result, -3.0, -60.0, "Amazon Rainforest")
    verify_location(result, 23.0, 13.0, "Sahara Desert")
    verify_location(result, 78.0, 15.0, "Svalbard Arctic")


if __name__ == "__main__":
    main()
