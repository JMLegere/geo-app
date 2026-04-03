import 'dart:convert';

import 'package:earth_nova/data/database.dart';

class SpeciesRepo {
  final AppDatabase _db;
  SpeciesRepo(this._db);

  Future<Species?> getById(String definitionId) => (_db.select(_db.speciesTable)
        ..where((t) => t.definitionId.equals(definitionId)))
      .getSingleOrNull();

  Future<List<Species>> getAll() => _db.select(_db.speciesTable).get();

  Future<int> count() async {
    final rows = await _db.select(_db.speciesTable).get();
    return rows.length;
  }

  /// Returns species matching any of [habitats] AND matching [continent].
  /// Filters in Dart because JSON array matching in SQLite is complex.
  Future<List<Species>> getCandidates({
    required List<String> habitats,
    required String continent,
  }) async {
    final all = await getAll();
    return all.where((s) {
      final sHabitats = (jsonDecode(s.habitatsJson) as List).cast<String>();
      final sContinents = (jsonDecode(s.continentsJson) as List).cast<String>();
      final habitatMatch = habitats.any((h) => sHabitats.contains(h));
      final continentMatch = sContinents.contains(continent);
      return habitatMatch && continentMatch;
    }).toList();
  }
}
