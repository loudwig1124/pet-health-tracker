import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/app/app_settings.dart';
import 'package:pet_health_tracker/app/di.dart';
import 'package:pet_health_tracker/data/settings/settings_store_io.dart';
import 'package:pet_health_tracker/data/sqlite/app_database.dart';
import 'package:pet_health_tracker/domain/models/pet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(sqfliteFfiInit);

  late Directory directory;
  late String databasePath;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('pet_health_tracker_boot_');
    databasePath = '${directory.path}/${AppDatabase.fileName}';
  });

  tearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });

  Future<AppDatabase> openFileDatabase(String path) {
    return AppDatabase.open(
      factory: databaseFactoryFfi,
      path: path,
      schemaLoader: diskSchemaLoader,
    );
  }

  test('the first launch creates the database file and seeds it', () async {
    final AppDatabase database = await openFileDatabase(databasePath);
    final MemorySettingsStore store = MemorySettingsStore();
    final AppSettings settings = AppSettings(settingsStore: store);
    await settings.load();
    final services = await openAppServices(
      database: database,
      settings: settings,
      clock: fixedNow,
    );
    addTearDown(services.dispose);

    expect(File(databasePath).existsSync(), isTrue);
    expect(await services.vaccineTypes.list(), hasLength(7));
    expect((await services.pets.list()).map((Pet pet) => pet.name), <String>[
      'Bella',
      'Miso',
    ]);
    expect((await services.owners.load()).name, 'Maria Santos');
    expect(await services.sampleData.hasDemoData(), isTrue);
  });

  test('reopening the same file does not duplicate the seed', () async {
    final AppDatabase first = await openFileDatabase(databasePath);
    final AppSettings settings = AppSettings(
      settingsStore: MemorySettingsStore(),
    );
    await settings.load();
    final services = await openAppServices(
      database: first,
      settings: settings,
      clock: fixedNow,
    );
    await services.dispose();

    final AppDatabase second = await openFileDatabase(databasePath);
    final AppSettings secondSettings = AppSettings(
      settingsStore: MemorySettingsStore(),
    );
    await secondSettings.load();
    final reopened = await openAppServices(
      database: second,
      settings: secondSettings,
      clock: fixedNow,
    );
    addTearDown(reopened.dispose);

    expect(await reopened.pets.list(), hasLength(2));
    expect(await reopened.vaccineTypes.list(), hasLength(7));
    expect(await reopened.owners.load(), isNotNull);
  });

  test('a persisted "sample data off" skips the demo household', () async {
    final AppDatabase database = await openFileDatabase(databasePath);
    final AppSettings settings = AppSettings(
      settingsStore: MemorySettingsStore(<String, Object?>{
        'sampleDataEnabled': false,
      }),
    );
    await settings.load();
    final services = await openAppServices(
      database: database,
      settings: settings,
      clock: fixedNow,
    );
    addTearDown(services.dispose);

    expect(await services.pets.list(), isEmpty);
    expect(await services.vaccineTypes.list(), hasLength(7));
    expect(await services.sampleData.hasDemoData(), isFalse);
  });

  test('the JSON settings file persists the profile preferences', () async {
    final File file = File('${directory.path}/settings.json');
    final JsonSettingsStore store = JsonSettingsStore(file);
    expect(await store.read(), isEmpty);

    final AppSettings settings = AppSettings(settingsStore: store);
    await settings.load();
    expect(settings.sampleDataEnabled, isTrue);
    expect(settings.dueSoonWindowDays, 30);
    expect(settings.weightUnit, WeightUnit.kg);

    await settings.setSampleDataEnabled(false);
    await settings.setDueSoonWindowDays(45);
    await settings.setWeightUnit(WeightUnit.lb);
    expect(file.existsSync(), isTrue);

    final AppSettings reloaded = AppSettings(settingsStore: store);
    await reloaded.load();
    expect(reloaded.sampleDataEnabled, isFalse);
    expect(reloaded.dueSoonWindowDays, 45);
    expect(reloaded.weightUnit, WeightUnit.lb);
    expect(reloaded.formatWeight(10), '22.0 lb');

    await file.writeAsString('{not json');
    expect(await store.read(), isEmpty);
    final AppSettings fallback = AppSettings(settingsStore: store);
    await fallback.load();
    expect(fallback.sampleDataEnabled, isTrue);
  });

  test(
    'openAppServices without injected settings writes them next to the db',
    () async {
      final AppDatabase database = await openFileDatabase(databasePath);
      final services = await openAppServices(
        database: database,
        clock: fixedNow,
      );
      addTearDown(services.dispose);

      expect(await services.pets.list(), hasLength(2));

      await services.setSampleDataEnabled(false);
      final File settingsFile = File('${directory.path}/settings.json');
      expect(settingsFile.existsSync(), isTrue);
      expect(
        await settingsFile.readAsString(),
        contains('"sampleDataEnabled":false'),
      );

      final AppSettings reloaded = AppSettings(
        settingsStore: JsonSettingsStore(settingsFile),
      );
      await reloaded.load();
      expect(reloaded.sampleDataEnabled, isFalse);
    },
  );
}
