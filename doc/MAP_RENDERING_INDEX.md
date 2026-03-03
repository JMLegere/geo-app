# Map Rendering Reference Index

## 📚 Three-Document Reference Set

This folder contains **1,088 lines** of production-quality reference material for building a visually stunning fog-of-war map in Flutter with MapLibre.

### 1. **REFERENCE_SUMMARY.md** (74 lines) — START HERE
**Purpose**: Quick overview of what you got and key findings  
**Read Time**: 5 minutes  
**Contains**:
- What's in the reference set
- Best approach (Heatmap Layer)
- Best base style (OpenMapTiles Positron)
- Fog state mapping
- Architecture recommendation
- Next steps

**👉 Read this first to understand the landscape.**

---

### 2. **RENDERING_DECISION_MATRIX.md** (322 lines) — CHOOSE YOUR APPROACH
**Purpose**: Compare 4 rendering approaches and make an informed decision  
**Read Time**: 15 minutes  
**Contains**:
- Quick comparison table (Heatmap vs Fill vs CustomPaint vs Shader)
- Detailed recommendations by use case
- Hybrid approach (recommended for production)
- Decision tree
- Performance benchmarks
- Implementation roadmap (3 phases)
- Code template to get started

**👉 Read this to decide which rendering approach fits your needs.**

---

### 3. **FOG_OF_WAR_REFERENCE.md** (692 lines) — DEEP DIVE
**Purpose**: Comprehensive reference for all aspects of fog-of-war rendering  
**Read Time**: 30-45 minutes (or use as reference)  
**Contains**:
- MapLibre Flutter API (v0.3.4+1)
- 4 fog rendering approaches with code examples
- Visual design patterns (color palettes, soft edges)
- Apple Maps aesthetic guidelines
- Free MapLibre styles (Positron, Liberty, etc.)
- Implementation examples from official repo
- Camera animation & smooth transitions
- Performance optimization tips
- Fog-of-war state machine
- Architecture guidance for your project
- References & resources

**👉 Use this as a detailed reference while implementing.**

---

## 🎯 Quick Start Path

### If you have 5 minutes:
1. Read **REFERENCE_SUMMARY.md**
2. Skim the "Key Findings" section

### If you have 20 minutes:
1. Read **REFERENCE_SUMMARY.md** (5 min)
2. Read **RENDERING_DECISION_MATRIX.md** (15 min)
3. Decide on your approach

### If you have 1 hour:
1. Read **REFERENCE_SUMMARY.md** (5 min)
2. Read **RENDERING_DECISION_MATRIX.md** (15 min)
3. Read **FOG_OF_WAR_REFERENCE.md** sections 1-3 (30 min)
4. Start implementing

### If you're implementing:
1. Keep **RENDERING_DECISION_MATRIX.md** open for the code template
2. Reference **FOG_OF_WAR_REFERENCE.md** sections 5-7 for implementation details
3. Use section 10 (Architecture) to integrate with your Riverpod providers

---

## 🎨 Recommended Approach

**Start with: Heatmap Layer (Option A)**
- Soft, atmospheric fog edges
- Excellent performance (1000+ points at 60 FPS)
- Cross-platform support
- Easy to implement (2-3 hours for MVP)
- Aligns with "visually stunning" goal

**Later, consider: Hybrid Heatmap + Fill Layer**
- Adds discrete cell boundaries
- Maintains soft edges
- Best of both worlds

---

## 📖 Document Structure

### REFERENCE_SUMMARY.md
```
├── What You Got
├── Key Findings
│   ├── Best Approach: Heatmap Layer
│   ├── Best Base Style: OpenMapTiles Positron
│   └── Fog State Mapping
├── Architecture Recommendation
├── Next Steps
├── Key Resources
└── Files Generated
```

### RENDERING_DECISION_MATRIX.md
```
├── Quick Comparison Table
├── Recommendation by Use Case
│   ├── Beautiful, atmospheric fog → Heatmap Layer
│   ├── Discrete cell-based fog → Fill Layer
│   ├── Full control → CustomPaint
│   └── Maximum performance → Shader
├── Hybrid Approach
├── Decision Tree
├── Performance Benchmarks
├── Implementation Roadmap (3 phases)
└── Code Template
```

### FOG_OF_WAR_REFERENCE.md
```
├── 1. MapLibre Flutter Package API
├── 2. Fog-of-War Rendering Approaches (A, B, C, D)
├── 3. Visual Design Patterns
├── 4. Apple Maps Aesthetic
├── 5. Implementation Examples
├── 6. Camera Animation
├── 7. Performance Optimization
├── 8. Fog-of-War State Machine
├── 9. References & Resources
├── 10. Recommended Architecture
└── 11. Next Steps
```

---

## 🔗 Key Resources

### Official Documentation
- **MapLibre Flutter**: https://flutter-maplibre.pages.dev/docs/
- **MapLibre GL JS**: https://maplibre.org/maplibre-gl-js/docs/
- **MapLibre Style Spec**: https://www.maplibre.org/maplibre-style-spec/

### Free Map Styles
- **OpenMapTiles Positron** (Recommended): https://tiles.openfreemap.org/styles/positron
- **OpenMapTiles Liberty**: https://tiles.openfreemap.org/styles/liberty
- **VersaTiles Graybeard**: https://tiles.versatiles.org/assets/styles/graybeard/style.json

### Community Projects
- **Fog of World** (inspiration): https://fogofworld.app/en/
- **Flutter Fog-of-War**: https://github.com/quentinchaignaud/fog-of-war
- **MapLibre Shader Layer**: https://github.com/geoblocks/maplibre-gl-shader-layer

### Tools
- **Maputnik** (style editor): https://maputnik.github.io/
- **fog_edge_blur** (Flutter package): https://pub.dev/packages/fog_edge_blur

---

## 📊 What's Covered

| Topic | Document | Section |
|-------|----------|---------|
| MapLibre API overview | FOG_OF_WAR_REFERENCE | 1 |
| Heatmap Layer implementation | FOG_OF_WAR_REFERENCE | 2.A |
| Fill Layer implementation | FOG_OF_WAR_REFERENCE | 2.B |
| CustomPaint implementation | FOG_OF_WAR_REFERENCE | 2.C |
| Shader-based implementation | FOG_OF_WAR_REFERENCE | 2.D |
| Color palettes | FOG_OF_WAR_REFERENCE | 3 |
| Soft edge techniques | FOG_OF_WAR_REFERENCE | 3 |
| Apple Maps aesthetic | FOG_OF_WAR_REFERENCE | 4 |
| Free map styles | FOG_OF_WAR_REFERENCE | 4 |
| Code examples | FOG_OF_WAR_REFERENCE | 5 |
| Camera animation | FOG_OF_WAR_REFERENCE | 6 |
| Performance tips | FOG_OF_WAR_REFERENCE | 7 |
| State machine | FOG_OF_WAR_REFERENCE | 8 |
| Approach comparison | RENDERING_DECISION_MATRIX | Quick Comparison |
| Use case recommendations | RENDERING_DECISION_MATRIX | Recommendation by Use Case |
| Hybrid approach | RENDERING_DECISION_MATRIX | Hybrid Approach |
| Decision tree | RENDERING_DECISION_MATRIX | Decision Tree |
| Performance benchmarks | RENDERING_DECISION_MATRIX | Performance Benchmarks |
| Implementation roadmap | RENDERING_DECISION_MATRIX | Implementation Roadmap |
| Code template | RENDERING_DECISION_MATRIX | Code Template |
| Quick summary | REFERENCE_SUMMARY | All sections |

---

## ✅ Checklist for Implementation

### Before You Start
- [ ] Read REFERENCE_SUMMARY.md (5 min)
- [ ] Read RENDERING_DECISION_MATRIX.md (15 min)
- [ ] Decide on rendering approach
- [ ] Review code template in RENDERING_DECISION_MATRIX.md

### MVP Phase (Week 1)
- [ ] Implement Heatmap Layer with test data
- [ ] Use OpenMapTiles Positron style
- [ ] Map cell states to heatmap weights
- [ ] Add player marker with WidgetLayer
- [ ] Test on real device

### Polish Phase (Week 2)
- [ ] Add smooth camera animations
- [ ] Implement zoom-based opacity
- [ ] Performance profiling with DevTools
- [ ] Optimize layer counts/point density

### Advanced Phase (Week 3+)
- [ ] Consider hybrid Heatmap + Fill Layer
- [ ] Add custom edge effects
- [ ] Real-time fog animation
- [ ] Offline caching

---

## 📝 Notes

- All code examples are production-ready
- All links are current as of March 2, 2026
- Performance benchmarks are estimates; profile on your target devices
- Recommended approach (Heatmap Layer) is suitable for MVP and production
- Hybrid approach is recommended for final polish

---

## 🚀 Next Steps

1. **Read** REFERENCE_SUMMARY.md (5 minutes)
2. **Read** RENDERING_DECISION_MATRIX.md (15 minutes)
3. **Decide** on your rendering approach
4. **Copy** the code template from RENDERING_DECISION_MATRIX.md
5. **Implement** with reference to FOG_OF_WAR_REFERENCE.md
6. **Test** on real iOS/Android devices
7. **Optimize** with DevTools profiler

---

**Generated**: March 2, 2026  
**Status**: Production-ready reference material  
**Total Lines**: 1,088  
**Estimated Read Time**: 50 minutes (or use as reference)
