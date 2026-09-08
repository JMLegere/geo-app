import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openLocalSaveDatabase() async {
  final directory = await getApplicationSupportDirectory();
  return databaseFactoryIo.openDatabase(
    '${directory.path}/earthnova-player-saves.db',
  );
}
