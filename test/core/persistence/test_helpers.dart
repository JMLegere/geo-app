import 'package:drift/native.dart';
import 'package:fog_of_world/core/database/app_database.dart';

AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}
