# TEOW Biome → EarthNova Habitat Mapping

## Detailed Mapping Rules

### TEOW 14 Biomes → Your 7 Habitats

| TEOW Biome | Your Habitat | Mapping Logic | Notes |
|-----------|--------------|---------------|-------|
| 1. Tropical & Subtropical Moist Broadleaf Forests | **Forest** | Direct | Rainforests, tropical wet forests |
| 2. Tropical & Subtropical Dry Broadleaf Forests | **Forest** | Direct | Seasonal tropical forests |
| 3. Tropical & Subtropical Coniferous Forests | **Forest** | Direct | Pine, cypress forests in tropics |
| 4. Temperate Broadleaf & Mixed Forests | **Forest** | Direct | Oak, beech, maple forests |
| 5. Temperate Coniferous Forests | **Forest** | Direct | Pine, spruce, fir forests |
| 6. Boreal Forests/Taiga | **Forest** | Direct | Subarctic coniferous forests |
| 7. Tropical & Subtropical Grasslands, Savannas & Shrublands | **Plains** | Direct | Savanna, grassland with scattered trees |
| 8. Temperate Grasslands, Savannas & Shrublands | **Plains** | Direct | Steppe, prairie, temperate grassland |
| 9. Flooded Grasslands & Savannas | **Swamp** | Direct | Wetlands, marshes, seasonally flooded |
| 10. Montane Grasslands & Shrublands | **Mountain** | Direct | Alpine meadows, high-elevation grasslands |
| 11. Tundra | **Mountain** | Elevation-based | Arctic/subarctic, treat as mountain-like |
| 12. Mediterranean Forests, Woodlands & Scrub | **Plains** | Fallback | Shrubland-dominant; could be Forest if dense |
| 13. Deserts & Xeric Shrublands | **Desert** | Direct | Arid, sparse vegetation |
| 14. Mangroves | **Saltwater** | Coastal override | Coastal wetlands, salt-tolerant |

### Override Rules (Priority Order)

```
1. If point in GMBA Mountain polygon → Mountain (override TEOW)
2. Else if point in OSM water polygon:
   - If coastal (within 50km of ocean) → Saltwater
   - Else → Freshwater
3. Else if point in TEOW ecoregion:
   - Apply biome → habitat mapping above
4. Else → Plains (default fallback)
```

### Special Cases

**Tundra (TEOW 11):**
- Mostly high-latitude, but not always high-elevation
- Recommendation: Treat as Mountain if elevation > 1500m, else Plains
- Alternative: Always treat as Mountain (conservative)

**Mediterranean (TEOW 12):**
- Shrubland-dominant, but some forests
- Recommendation: Check forest density; if >40% forest → Forest, else Plains
- Alternative: Always Plains (conservative)

**Mangroves (TEOW 14):**
- Always coastal, always saltwater
- Recommendation: Override to Saltwater regardless of TEOW classification

---

## File Size Estimates (After Compression)

### Shapefile → GeoJSON Conversion

**TEOW Ecoregions:**
- Raw shapefile: ~50-100MB
- GeoJSON (uncompressed): ~150-200MB
- GeoJSON (gzip): ~20-30MB
- GeoJSON (simplified 10%): ~15-20MB

**GMBA Mountains:**
- Raw shapefile: ~50-100MB
- GeoJSON (uncompressed): ~80-120MB
- GeoJSON (gzip): ~10-15MB
- GeoJSON (simplified 10%): ~8-12MB

**OSM Water Polygons:**
- Raw shapefile: ~100-150MB
- GeoJSON (uncompressed): ~200-300MB
- GeoJSON (gzip): ~15-25MB
- GeoJSON (simplified 10%): ~12-18MB

**Total Bundle (gzipped):** ~45-70MB

### Simplification Strategy

Use `mapshaper` or `simplify-geojson` to reduce polygon complexity:
```bash
# Simplify to 10% of original vertices
mapshaper input.geojson -simplify 10% -o output.geojson

# Or use Douglas-Peucker with tolerance
mapshaper input.geojson -simplify dp 0.01 -o output.geojson
```

**Trade-off:** 10% simplification loses ~1-2km accuracy at local scale, but saves 30-40% file size.

---

## Implementation Checklist

### Phase 1: Data Acquisition
- [ ] Download TEOW shapefile from https://ecoregions.appspot.com/
- [ ] Download GMBA v2 shapefile from https://www.gmba.unibas.ch/
- [ ] Download OSM water polygons from https://osmdata.openstreetmap.de/
- [ ] Verify licenses (all CC BY 4.0 or compatible)

### Phase 2: Data Processing
- [ ] Convert shapefiles to GeoJSON
- [ ] Simplify polygons to 10% (mapshaper)
- [ ] Gzip compress each layer
- [ ] Verify total size < 80MB
- [ ] Create attribution file (cite all sources)

### Phase 3: Integration
- [ ] Create `BiomeService` with point-in-polygon logic
- [ ] Load GeoJSON layers into memory (or lazy-load by tile)
- [ ] Implement override rules (Mountain > Water > TEOW > Plains)
- [ ] Add unit tests for edge cases (boundaries, overlaps)

### Phase 4: Testing
- [ ] Test point-in-polygon at known locations (e.g., Amazon = Forest, Sahara = Desert)
- [ ] Test boundary cases (ecoregion edges, water/land transitions)
- [ ] Test performance (query time for 1000 random points)
- [ ] Verify habitat distribution matches real-world expectations

---

## Dart/Flutter Implementation Sketch

```dart
// lib/core/biome/biome_service.dart

class BiomeService {
  final Map<String, GeoJsonFeatureCollection> layers = {};
  
  Future<void> loadLayers() async {
    // Load gzipped GeoJSON files
    layers['teow'] = await _loadGeoJson('assets/teow.geojson.gz');
    layers['gmba'] = await _loadGeoJson('assets/gmba.geojson.gz');
    layers['water'] = await _loadGeoJson('assets/osm_water.geojson.gz');
  }
  
  Habitat classifyPoint(Geographic point) {
    // 1. Check GMBA (mountains)
    if (_pointInPolygons(point, layers['gmba']!)) {
      return Habitat.mountain;
    }
    
    // 2. Check water
    if (_pointInPolygons(point, layers['water']!)) {
      final isCoastal = _isCoastal(point);
      return isCoastal ? Habitat.saltwater : Habitat.freshwater;
    }
    
    // 3. Check TEOW ecoregion
    final ecoregion = _findEcoregion(point, layers['teow']!);
    if (ecoregion != null) {
      return _mapBiomeToHabitat(ecoregion.biome);
    }
    
    // 4. Default fallback
    return Habitat.plains;
  }
  
  bool _pointInPolygons(Geographic point, GeoJsonFeatureCollection fc) {
    // Use turf.js or similar for point-in-polygon
    // Dart package: `geobase` has Geographic type
    // For polygons, use `point_in_polygon` algorithm
    return fc.features.any((feature) {
      return _pointInFeature(point, feature);
    });
  }
  
  Habitat _mapBiomeToHabitat(String biome) {
    return switch (biome) {
      'Tropical & Subtropical Moist Broadleaf Forests' => Habitat.forest,
      'Tropical & Subtropical Dry Broadleaf Forests' => Habitat.forest,
      'Tropical & Subtropical Coniferous Forests' => Habitat.forest,
      'Temperate Broadleaf & Mixed Forests' => Habitat.forest,
      'Temperate Coniferous Forests' => Habitat.forest,
      'Boreal Forests/Taiga' => Habitat.forest,
      'Tropical & Subtropical Grasslands, Savannas & Shrublands' => Habitat.plains,
      'Temperate Grasslands, Savannas & Shrublands' => Habitat.plains,
      'Flooded Grasslands & Savannas' => Habitat.swamp,
      'Montane Grasslands & Shrublands' => Habitat.mountain,
      'Tundra' => Habitat.mountain, // or elevation-based
      'Mediterranean Forests, Woodlands & Scrub' => Habitat.plains,
      'Deserts & Xeric Shrublands' => Habitat.desert,
      'Mangroves' => Habitat.saltwater,
      _ => Habitat.plains,
    };
  }
}
```

---

## Performance Considerations

### Point-in-Polygon Algorithm

**Options:**
1. **Ray Casting** (O(n) per query, simple)
   - Shoot ray from point to infinity, count edge crossings
   - Dart: `geobase` package has utilities

2. **Winding Number** (O(n) per query, more robust)
   - Count how many times polygon winds around point
   - Better for complex polygons

3. **Spatial Indexing** (O(log n) per query, complex)
   - Build R-tree or quadtree on load
   - Dart: `spatial_index` package (if available)

**Recommendation for mobile:**
- Use Ray Casting for simplicity
- Cache results in SQLite (per-cell, per-day)
- Lazy-load GeoJSON by tile (don't load all at once)

### Caching Strategy

```dart
// Cache habitat classification per cell
class CellHabitatCache {
  final Map<String, Habitat> cache = {};
  
  Habitat getOrCompute(String cellId, Geographic cellCenter) {
    return cache.putIfAbsent(cellId, () {
      return biomeService.classifyPoint(cellCenter);
    });
  }
}
```

---

## Data Attribution

**Required in app:**

```
Biome data sources:
- Terrestrial Ecoregions of the World (TEOW): 
  Olson et al. (2001), CC BY 4.0
  https://ecoregions.appspot.com/
  
- Global Mountain Biodiversity Assessment (GMBA) v2:
  Körner et al. (2023), CC BY 4.0
  https://www.gmba.unibas.ch/
  
- OpenStreetMap Water Polygons:
  OpenStreetMap contributors, ODbL
  https://osmdata.openstreetmap.de/
```

