import 'package:drift/drift.dart';

import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/models/hierarchy.dart';

/// Repository wrapping the 4 hierarchy Drift tables.
/// Provides tree-structured queries for the geographic hierarchy.
class HierarchyRepository {
  HierarchyRepository(this._db);
  final AppDatabase _db;

  // -- Countries --
  Future<List<HCountry>> getAllCountries() async {
    final rows = await _db.getAllCountries();
    return rows.map(HCountry.fromDrift).toList();
  }

  Future<HCountry?> getCountry(String id) async {
    final row = await _db.getCountry(id);
    return row == null ? null : HCountry.fromDrift(row);
  }

  // -- States --
  Future<List<HState>> getStatesForCountry(String countryId) async {
    final rows = await _db.getStatesForCountry(countryId);
    return rows.map(HState.fromDrift).toList();
  }

  Future<HState?> getState(String id) async {
    final row = await _db.getState(id);
    return row == null ? null : HState.fromDrift(row);
  }

  // -- Cities --
  Future<List<HCity>> getCitiesForState(String stateId) async {
    final rows = await _db.getCitiesForState(stateId);
    return rows.map(HCity.fromDrift).toList();
  }

  Future<HCity?> getCity(String id) async {
    final row = await _db.getCity(id);
    return row == null ? null : HCity.fromDrift(row);
  }

  // -- Districts --
  Future<List<HDistrict>> getDistrictsForCity(String cityId) async {
    final rows = await _db.getDistrictsForCity(cityId);
    return rows.map(HDistrict.fromDrift).toList();
  }

  Future<HDistrict?> getDistrict(String id) async {
    final row = await _db.getDistrict(id);
    return row == null ? null : HDistrict.fromDrift(row);
  }

  // -- Upserts (for sync from Supabase) --
  Future<void> upsertCountry(HCountry country) async {
    await _db.upsertCountry(LocalCountryTableCompanion.insert(
      id: country.id,
      name: country.name,
      centroidLat: country.centroidLat,
      centroidLon: country.centroidLon,
      continent: country.continent,
      boundaryJson: Value(country.boundaryJson),
    ));
  }

  Future<void> upsertState(HState state) async {
    await _db.upsertState(LocalStateTableCompanion.insert(
      id: state.id,
      name: state.name,
      centroidLat: state.centroidLat,
      centroidLon: state.centroidLon,
      countryId: state.countryId,
      boundaryJson: Value(state.boundaryJson),
    ));
  }

  Future<void> upsertCity(HCity city) async {
    await _db.upsertCity(LocalCityTableCompanion.insert(
      id: city.id,
      name: city.name,
      centroidLat: city.centroidLat,
      centroidLon: city.centroidLon,
      stateId: city.stateId,
      boundaryJson: Value(city.boundaryJson),
      cellsTotal: Value(city.cellsTotal),
    ));
  }

  Future<void> upsertDistrict(HDistrict district) async {
    await _db.upsertDistrict(LocalDistrictTableCompanion.insert(
      id: district.id,
      name: district.name,
      centroidLat: district.centroidLat,
      centroidLon: district.centroidLon,
      cityId: district.cityId,
      boundaryJson: Value(district.boundaryJson),
      cellsTotal: Value(district.cellsTotal),
      sourceId: Value(district.sourceId),
    ));
  }
}
