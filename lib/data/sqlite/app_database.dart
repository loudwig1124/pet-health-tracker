/// SQLite bootstrap: open the database, set the pragmas the schema relies on,
/// apply the bundled DDL once and expose the connection.
///
/// Takes an injected [DatabaseFactory] so the app passes sqflite's factory and
/// tests pass `databaseFactoryFfi`; only this directory imports sqflite.
library;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'schema_asset.dart';

/// One opened application database.
class AppDatabase {
  AppDatabase._(this.database, this.path);

  final Database database;
  final String path;

  /// File name inside the platform's database directory.
  static const String fileName = 'pet_health_tracker.db';

  /// Hand-written migrations: bump this and add an `onUpgrade` step when the
  /// DDL changes (the MVP ships schema version 1 only).
  static const int schemaVersion = 1;

  /// Opens (and creates) the database at [path].
  ///
  /// `onConfigure` enables foreign keys and a busy timeout on every connection;
  /// `onCreate` applies `db/schema.sql` from the bundle. Migrations are
  /// deliberately unimplemented: shipping a version 1 app has nothing to
  /// migrate from, and silently doing nothing would hide a real bug.
  static Future<AppDatabase> open({
    required DatabaseFactory factory,
    required String path,
    SchemaLoader schemaLoader = loadSchemaAsset,
  }) async {
    final Database database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (Database db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('PRAGMA busy_timeout = 5000');
        },
        onCreate: (Database db, int version) async {
          final String script = await schemaLoader();
          for (final String statement in schemaStatements(script)) {
            await db.execute(statement);
          }
        },
        onUpgrade: (Database db, int oldVersion, int newVersion) {
          throw StateError(
            'No migration from schema $oldVersion to $newVersion. '
            'Add one in lib/data/sqlite/app_database.dart before shipping.',
          );
        },
      ),
    );
    return AppDatabase._(database, path);
  }

  /// Opens the app's real database in the platform database directory.
  static Future<AppDatabase> openDefault({
    SchemaLoader schemaLoader = loadSchemaAsset,
  }) async {
    final String basePath = await getDatabasesPath();
    return open(
      factory: databaseFactory,
      path: p.join(basePath, fileName),
      schemaLoader: schemaLoader,
    );
  }

  Future<void> close() => database.close();
}
