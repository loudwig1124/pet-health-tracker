/// Native platforms: a real file next to the app's database directory.
library;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens in the platform database directory through sqflite's own factory.
Future<({DatabaseFactory factory, String path})> platformDatabase() async {
  final String basePath = await getDatabasesPath();
  return (factory: databaseFactory, path: p.join(basePath, 'pet_health_tracker.db'));
}

/// Directory holding `settings.json` and `pet_photos/`.
String platformDataDirectory(String databasePath) => p.dirname(databasePath);
