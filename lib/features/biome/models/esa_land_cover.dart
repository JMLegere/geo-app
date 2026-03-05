import 'package:fog_of_world/core/models/habitat.dart';

/// ESA WorldCover v2 land cover classification.
/// See: https://worldcover2021.esa.int/
enum EsaLandCover {
  treeCover(10),
  shrubland(20),
  grassland(30),
  cropland(40),
  builtUp(50),
  bareSparse(60),
  snowIce(70),
  permanentWater(80),
  herbaceousWetland(90),
  mangroves(95),
  mossLichen(100);

  final int code;
  const EsaLandCover(this.code);

  /// Maps this ESA land cover class to the corresponding game habitat.
  Habitat toHabitat() => switch (this) {
        EsaLandCover.treeCover => Habitat.forest,
        EsaLandCover.shrubland => Habitat.plains,
        EsaLandCover.grassland => Habitat.plains,
        EsaLandCover.cropland => Habitat.plains,
        EsaLandCover.builtUp => Habitat.plains,
        EsaLandCover.bareSparse => Habitat.desert,
        EsaLandCover.snowIce => Habitat.mountain,
        EsaLandCover.permanentWater => Habitat.freshwater,
        EsaLandCover.herbaceousWetland => Habitat.swamp,
        EsaLandCover.mangroves => Habitat.swamp,
        EsaLandCover.mossLichen => Habitat.mountain,
      };

  /// Finds an ESA land cover class by its numeric code.
  /// Returns null if the code doesn't match any class.
  static EsaLandCover? fromCode(int code) {
    for (final lc in values) {
      if (lc.code == code) return lc;
    }
    return null;
  }
}
