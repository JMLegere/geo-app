import 'package:earth_nova/data/database.dart';
import 'package:earth_nova/models/hierarchy.dart';

class HierarchyRepo {
  HierarchyRepo(this._db);
  final AppDatabase _db;

  // Countries
  Future<List<HCountry>> getAllCountries() async =>
      (await _db.getAllCountries()).map(HCountry.fromDrift).toList();

  Future<HCountry?> getCountry(String id) async {
    final row = await _db.getCountry(id);
    return row == null ? null : HCountry.fromDrift(row);
  }

  Future<void> upsertCountry(CountriesTableCompanion entry) =>
      _db.upsertCountry(entry);

  // States
  Future<List<HState>> getStatesForCountry(String countryId) async =>
      (await _db.getStatesForCountry(countryId)).map(HState.fromDrift).toList();

  Future<HState?> getState(String id) async {
    final row = await _db.getState(id);
    return row == null ? null : HState.fromDrift(row);
  }

  Future<void> upsertState(StatesTableCompanion entry) =>
      _db.upsertState(entry);

  // Cities
  Future<List<HCity>> getCitiesForState(String stateId) async =>
      (await _db.getCitiesForState(stateId)).map(HCity.fromDrift).toList();

  Future<HCity?> getCity(String id) async {
    final row = await _db.getCity(id);
    return row == null ? null : HCity.fromDrift(row);
  }

  Future<void> upsertCity(CitiesTableCompanion entry) => _db.upsertCity(entry);

  // Districts
  Future<List<HDistrict>> getDistrictsForCity(String cityId) async =>
      (await _db.getDistrictsForCity(cityId)).map(HDistrict.fromDrift).toList();

  Future<List<HDistrict>> getAllDistricts() async =>
      (await _db.getAllDistricts()).map(HDistrict.fromDrift).toList();

  Future<HDistrict?> getDistrict(String id) async {
    final row = await _db.getDistrict(id);
    return row == null ? null : HDistrict.fromDrift(row);
  }

  Future<void> upsertDistrict(DistrictsTableCompanion entry) =>
      _db.upsertDistrict(entry);
}
