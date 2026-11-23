@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/app/app_settings.dart';
import 'package:pet_health_tracker/app/di.dart';
import 'package:pet_health_tracker/app/app_services.dart';
import 'package:pet_health_tracker/data/settings/settings_store.dart';
import 'package:pet_health_tracker/domain/models/owner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the database opens and seeds on the web', () async {
    final AppServices services = await openAppServices(
      settings: AppSettings(settingsStore: _MemoryStore()),
    );
    addTearDown(services.dispose);

    final Owner owner = await services.owners.load();
    expect(owner.name, isNotEmpty);
    // Sample data is off by default, so a fresh browser has no pets.
    expect(await services.pets.list(), isEmpty);
  });
}

class _MemoryStore implements SettingsStore {
  Map<String, Object?> values = <String, Object?>{};

  @override
  Future<Map<String, Object?>> read() async => values;

  @override
  Future<void> write(Map<String, Object?> values) async => this.values = values;
}
