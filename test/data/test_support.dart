/// Shared test support: a real SQLite database through `sqflite_common_ffi`,
/// the shipped DDL read from disk (not a copy), an in-memory settings store and
/// a fixed clock.
library;

import 'dart:io';

import 'package:pet_health_tracker/app/app_services.dart';
import 'package:pet_health_tracker/app/app_settings.dart';
import 'package:pet_health_tracker/data/settings/settings_store.dart';
import 'package:pet_health_tracker/data/sqlite/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fixed clock for the data tests: Saturday 21 November 2026, 09:30 UTC.
DateTime fixedNow() => DateTime.utc(2026, 11, 21, 9, 30);

/// Reads the committed DDL: the test proves the artifact, not a copy of it.
Future<String> diskSchemaLoader() => File('db/schema.sql').readAsString();

/// Settings store for tests; nothing touches the file system.
class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([Map<String, Object?>? values])
    : _values = <String, Object?>{...?values};

  Map<String, Object?> _values;

  Map<String, Object?> get values => Map<String, Object?>.unmodifiable(_values);

  @override
  Future<Map<String, Object?>> read() async => <String, Object?>{..._values};

  @override
  Future<void> write(Map<String, Object?> values) async {
    _values = <String, Object?>{...values};
  }
}

/// One open database plus the services bound to it.
class SqliteHarness {
  SqliteHarness._({
    required this.directory,
    required this.database,
    required this.settings,
    required this.services,
  });

  final Directory directory;
  final AppDatabase database;
  final AppSettings settings;
  final AppServices services;

  Database get db => database.database;

  Future<void> dispose() async {
    await services.dispose();
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  }
}

/// Opens a fresh database, runs the app bootstrap (owner + catalog, and the
/// demo household when [seedDemo]) and returns the harness.
Future<SqliteHarness> openHarness({
  bool seedDemo = false,
  bool inMemory = false,
  DateTime Function()? clock,
}) async {
  sqfliteFfiInit();
  final Directory directory = Directory.systemTemp.createTempSync(
    'pet_health_tracker_test_',
  );
  final String path = inMemory
      ? inMemoryDatabasePath
      : '${directory.path}/${AppDatabase.fileName}';
  final AppDatabase database = await AppDatabase.open(
    factory: databaseFactoryFfi,
    path: path,
    schemaLoader: diskSchemaLoader,
  );
  final AppSettings settings = AppSettings(
    settingsStore: MemorySettingsStore(<String, Object?>{
      'sampleDataEnabled': seedDemo,
    }),
  );
  await settings.load();
  final AppServices services = AppServices(
    database: database,
    settings: settings,
    clock: clock ?? fixedNow,
  );
  await services.bootstrap();
  return SqliteHarness._(
    directory: directory,
    database: database,
    settings: settings,
    services: services,
  );
}
