import 'package:sembast_web/sembast_web.dart';

Future<Database> openLocalSaveDatabase() =>
    databaseFactoryWeb.openDatabase('earthnova-player-saves');
