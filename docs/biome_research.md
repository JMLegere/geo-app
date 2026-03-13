# Global Biome/Ecoregion Datasets Research

## 1. WWF Terrestrial Ecoregions of the World (TEOW)

**Status:** FOUND - Classic dataset, widely used

**Key Facts:**
- **867 terrestrial ecoregions** classified into **14 biomes**
- Published: 2001 (Olson et al.)
- **Download:** Shapefiles available at https://ecoregions.appspot.com/
- **Format:** Shapefile (.shp) + GeoJSON available
- **License:** Varies by source (WWF, RESOLVE, One Earth)
- **Resolution:** Vector polygons (variable size, 6 km² to 3.9M km²)

**14 Biome Types in TEOW:**
1. Tropical & Subtropical Moist Broadleaf Forests
2. Tropical & Subtropical Dry Broadleaf Forests
3. Tropical & Subtropical Coniferous Forests
4. Temperate Broadleaf & Mixed Forests
5. Temperate Coniferous Forests
6. Boreal Forests/Taiga
7. Tropical & Subtropical Grasslands, Savannas & Shrublands
8. Temperate Grasslands, Savannas & Shrublands
9. Flooded Grasslands & Savannas
10. Montane Grasslands & Shrublands
11. Tundra
12. Mediterranean Forests, Woodlands & Scrub
13. Deserts & Xeric Shrublands
14. Mangroves

**Mapping to Your 7 Habitats:**
- Forest: 1-6 (all forest biomes)
- Plains: 7-10 (grasslands, savannas, shrublands)
- Freshwater: 9 (flooded grasslands) + need separate freshwater layer
- Saltwater: 14 (mangroves) + need separate marine layer
- Swamp: 9 (flooded grasslands)
- Mountain: 10 (montane grasslands)
- Desert: 13 (deserts & xeric shrublands)

**Issues:**
- 14 biomes don't map cleanly to 7 habitats
- No explicit freshwater/saltwater polygons
- Tundra (11) and Mediterranean (12) don't fit well

---

## 2. Resolve Ecoregions 2017 (Updated TEOW)

**Status:** FOUND - Successor to TEOW

**Key Facts:**
- Updated version by Dinerstein et al. (RESOLVE)
- More recent biodiversity data
- Available through One Earth Navigator
- Ecoregion Snapshots project (2024)
- **Download:** Shapefiles at https://ecoregions.appspot.com/
- **Format:** Shapefile + GeoJSON
- **License:** CC BY 4.0 (One Earth/RESOLVE)

**Differences from TEOW:**
- Refined boundaries based on newer species distribution data
- Added detailed ecoregion descriptions ("snapshots")
- Better integration with conservation planning
- Same 14 biome structure, but updated classifications

---

## 3. MODIS Land Cover (MCD12Q1)

**Status:** FOUND - Raster, not polygon-based

**Key Facts:**
- **500m resolution** global land cover
- Annual updates
- **17 land cover classes** (IGBP classification)
- **Format:** GeoTIFF raster (NOT polygons)
- **License:** Free (NASA EOSDIS)
- **Size:** ~500MB per year for global coverage
- **Access:** Google Earth Engine, USGS LPDAAC

**Classes (IGBP):**
1. Water
2. Evergreen Needleleaf Forest
3. Evergreen Broadleaf Forest
4. Deciduous Needleleaf Forest
5. Deciduous Broadleaf Forest
6. Mixed Forest
7. Closed Shrublands
8. Open Shrublands
9. Woody Savannas
10. Savannas
11. Grasslands
12. Permanent Wetlands
13. Croplands
14. Urban & Built-up
15. Cropland/Natural Vegetation Mosaic
16. Snow & Ice
17. Barren or Sparsely Vegetated

**Mapping to Your 7 Habitats:**
- Forest: 2-6
- Plains: 7-11
- Freshwater: 1, 12 (water + wetlands)
- Saltwater: 1 (water - need coastal mask)
- Swamp: 12 (wetlands)
- Mountain: 17 (barren - needs elevation data)
- Desert: 17 (barren/sparse)

**Issues for Mobile:**
- **Too large for bundling** (500MB+ per year)
- Raster format requires conversion to polygons (complex)
- 500m resolution may be too coarse for local detection
- Would need tiling + caching strategy

---

## 4. Copernicus Global Land Cover (CGLS-LC100)

**Status:** FOUND - Raster, higher resolution than MODIS

**Key Facts:**
- **100m resolution** (5x finer than MODIS)
- **2015-2019 baseline** (v3), 2020+ planned
- **22 land cover classes**
- **Format:** GeoTIFF raster (NOT polygons)
- **License:** Free & Open (Copernicus)
- **Size:** ~2-3GB per year for global coverage
- **Access:** Copernicus Data Space, Google Earth Engine

**Classes:**
0. No Data
1. Shrub
2. Herbaceous vegetation
3. Lichens and mosses
4. Herbaceous wetland
5. Moss and lichen wetland
6. Closed forest, evergreen needle leaf
7. Closed forest, evergreen broad leaf
8. Closed forest, deciduous needle leaf
9. Closed forest, deciduous broad leaf
10. Closed forest, mixed
11. Closed forest, unknown type
12. Open forest, evergreen needle leaf
13. Open forest, evergreen broad leaf
14. Open forest, deciduous needle leaf
15. Open forest, deciduous broad leaf
16. Open forest, mixed
17. Open forest, unknown type
18. Herbaceous vegetation regularly flooded
19. Herbaceous vegetation or tree cover, frequently flooded
20. Bare areas
21. Water
22. Clouds and shadows

**Mapping to Your 7 Habitats:**
- Forest: 6-17 (all forest classes)
- Plains: 1-2 (shrub, herbaceous)
- Freshwater: 4-5, 18-19 (wetlands, flooded)
- Saltwater: 21 (water - need coastal mask)
- Swamp: 4-5, 18-19 (wetlands)
- Mountain: 20 (bare areas - needs elevation)
- Desert: 20 (bare areas)

**Issues for Mobile:**
- **Even larger than MODIS** (2-3GB per year)
- Raster format requires conversion to polygons
- 100m resolution better, but still requires processing
- Not suitable for bundling in app

---

## 5. Köppen-Geiger Climate Zones

**Status:** FOUND - Raster + vector available

**Key Facts:**
- **1 km resolution** global climate classification
- **1901-2099** coverage (historical + future projections)
- **~30 climate classes** (e.g., Af, Am, Aw, BWh, BWk, Csa, Cfb, Dfc, ET)
- **Format:** GeoTIFF raster + KMZ + netCDF
- **License:** CC BY 4.0 (Beck et al. 2023)
- **Size:** ~500MB-1GB for global coverage
- **Download:** https://www.gloh2o.org/koppen/ (V3 latest)
- **Access:** Direct download, Google Earth Engine

**Climate Classes (Köppen-Geiger):**
- A: Tropical (Af, Am, As, Aw)
- B: Arid (BWh, BWk, BSh, BSk)
- C: Temperate (Csa, Csb, Cwa, Cwb, Cfa, Cfb)
- D: Cold (Dfa, Dfb, Dfc, Dfd, Dw*)
- E: Polar (ET, EF)

**Mapping to Your 7 Habitats:**
- Forest: A (tropical), C/D (temperate/cold) + need vegetation data
- Plains: B (arid) + A (tropical savanna)
- Freshwater: Need separate layer
- Saltwater: Need separate layer
- Swamp: A (tropical) + need vegetation data
- Mountain: E (polar) + high elevation
- Desert: B (arid/xeric)

**Issues:**
- Climate ≠ biome (need vegetation data too)
- Raster format, not polygons
- ~1GB for global coverage
- Better for climate-based filtering than primary classification

---

## 6. GMBA Mountain Inventory v2

**Status:** FOUND - Polygon-based

**Key Facts:**
- **Global mountain boundaries** (polygon dataset)
- **Version 2** (2023 update)
- **~1.5M km²** of mountain area mapped
- **Format:** Shapefile + GeoJSON
- **License:** CC BY 4.0
- **Size:** ~50-100MB (manageable)
- **Download:** https://www.gmba.unibas.ch/
- **Resolution:** Vector polygons

**Features:**
- Mountain classification by elevation + slope
- Elevation ranges (e.g., 1500-2500m, 2500m+)
- Useful for Mountain habitat detection

**Mapping to Your 7 Habitats:**
- Mountain: Direct match (all GMBA polygons)
- Can combine with other datasets for forest/plains in mountains

---

## 7. Global Biome Dataset Under 50MB

**Status:** PARTIALLY FOUND - No single dataset <50MB covers all biomes

**Candidates:**

### A. Natural Earth Raster Data
- **10m Natural Earth I with Shaded Relief and Water**
- ~50MB GeoTIFF
- Land cover classes: forest, grassland, shrubland, barren, ice
- **Format:** Raster (not polygons)
- **License:** Public Domain
- **Issue:** Simplified classes, not detailed enough

### B. ESA WorldCover 10m
- **10m resolution** land cover (2020, 2021)
- **11 classes** (trees, shrubland, herbaceous, crops, built-up, bare, water, clouds)
- **Format:** GeoTIFF raster
- **License:** CC BY 4.0
- **Size:** ~1-2GB per year (too large)
- **Access:** Google Earth Engine, Copernicus

### C. GEBCO Bathymetry + Land Elevation
- **15 arc-second resolution** (global elevation)
- **Format:** GeoTIFF raster
- **License:** CC BY 4.0
- **Size:** ~500MB
- **Use:** Combine with climate/vegetation for habitat classification
- **Download:** https://www.gebco.net/

### D. OpenStreetMap Water Polygons
- **Global water bodies** (oceans, lakes, rivers)
- **Format:** Shapefile + GeoJSON
- **License:** ODbL
- **Size:** ~50-100MB
- **Download:** https://osmdata.openstreetmap.de/
- **Use:** Freshwater/Saltwater detection

---

## Recommendation Summary

### For Mobile App (EarthNova):

**Best Approach: Hybrid Multi-Layer**

1. **Primary Layer: TEOW/Resolve Ecoregions 2017**
   - Download shapefile, convert to GeoJSON
   - Compress to ~20-30MB (with simplification)
   - Point-in-polygon test for ecoregion
   - Map 14 biomes → 7 habitats (with rules)

2. **Secondary Layer: GMBA Mountains**
   - Download shapefile, convert to GeoJSON
   - Compress to ~10-15MB
   - Override habitat to "Mountain" if player in GMBA polygon

3. **Tertiary Layer: OSM Water Polygons**
   - Download water bodies, convert to GeoJSON
   - Compress to ~15-20MB
   - Override habitat to "Freshwater" or "Saltwater" if in water polygon

4. **Climate Context: Köppen-Geiger (optional)**
   - Download 1km raster, tile for mobile
   - Use for seasonal species filtering (not primary habitat)
   - ~50-100MB if tiled

**Total Bundle Size:** ~50-80MB (manageable for mobile)

**Mapping Logic:**
```
if (point in GMBA) → Mountain
else if (point in OSM water) → Freshwater or Saltwater
else if (point in TEOW) → Map ecoregion biome to habitat
else → Default to Plains (fallback)
```

---

## Download Links Summary

| Dataset | URL | Format | License |
|---------|-----|--------|---------|
| TEOW/Resolve Ecoregions | https://ecoregions.appspot.com/ | Shapefile, GeoJSON | CC BY 4.0 |
| Köppen-Geiger | https://www.gloh2o.org/koppen/ | GeoTIFF, KMZ, netCDF | CC BY 4.0 |
| GMBA Mountains | https://www.gmba.unibas.ch/ | Shapefile, GeoJSON | CC BY 4.0 |
| OSM Water Polygons | https://osmdata.openstreetmap.de/ | Shapefile, GeoJSON | ODbL |
| Copernicus Land Cover | https://land.copernicus.eu/ | GeoTIFF | CC BY 4.0 |
| MODIS Land Cover | https://lpdaac.usgs.gov/ | GeoTIFF | Free |
| Natural Earth | https://www.naturalearthdata.com/ | Shapefile, GeoTIFF | Public Domain |

