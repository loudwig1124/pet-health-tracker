/// Schema v2 removed the append-only triggers. An install that already has a
/// v1 database must lose them on the next open.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/sqlite/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('opening a v1 database drops the append-only triggers', () async {
    final String path = ':memory:';
    // Build the v1 shape by hand: the table plus both triggers.
    final Database v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (Database db, int version) async {
          await db.execute(
            'CREATE TABLE owner (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE pet (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'owner_id INTEGER NOT NULL REFERENCES owner (id) ON DELETE CASCADE)',
          );
          await db.execute(
            'CREATE TABLE health_record (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'pet_id INTEGER NOT NULL REFERENCES pet (id) ON DELETE CASCADE, '
            'recorded_on TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TRIGGER health_record_no_update BEFORE UPDATE ON health_record '
            'BEGIN SELECT RAISE(ABORT, "append-only"); END;',
          );
          await db.execute(
            'CREATE TRIGGER health_record_no_delete BEFORE DELETE ON health_record '
            'BEGIN SELECT RAISE(ABORT, "append-only"); END;',
          );
        },
      ),
    );
    final List<Map<String, Object?>> before = await v1.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'trigger'",
    );
    expect(before, hasLength(2));
    await v1.close();

    // Reopening at the app's version must migrate rather than throw.
    final AppDatabase migrated = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: path,
      schemaLoader: diskSchemaLoader,
    );
    addTearDown(migrated.close);
    final List<Map<String, Object?>> after = await migrated.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'trigger'",
    );
    expect(after, isEmpty);
  });
}
