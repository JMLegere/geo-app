import 'package:drift/native.dart';
import 'package:earth_nova/core/database/app_database.dart';

AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}
