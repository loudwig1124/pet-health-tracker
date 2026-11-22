/// Boot: open the database, load settings and seed what the first launch needs.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/settings/settings_store.dart';
import '../data/sqlite/app_database.dart';
import 'app_services.dart';
import 'app_settings.dart';

/// Opens the real application: platform database directory, JSON settings file
/// next to it, schema applied on creation, catalog + demo data seeded.
///
/// Tests bypass the platform paths by passing [database] (a `:memory:` or temp
/// file database opened with `databaseFactoryFfi`) and [settings] (an
/// `AppSettings` backed by an in-memory store).
Future<AppServices> openAppServices({
  AppDatabase? database,
  AppSettings? settings,
  Clock? clock,
}) async {
  final AppDatabase resolvedDatabase =
      database ?? await AppDatabase.openDefault();

  AppSettings resolvedSettings;
  if (settings != null) {
    resolvedSettings = settings;
  } else {
    resolvedSettings = AppSettings(
      settingsStore: JsonSettingsStore(
        File(p.join(p.dirname(resolvedDatabase.path), 'settings.json')),
      ),
    );
    await resolvedSettings.load();
  }

  final AppServices services = AppServices(
    database: resolvedDatabase,
    settings: resolvedSettings,
    clock: clock,
  );
  await services.bootstrap();
  return services;
}
