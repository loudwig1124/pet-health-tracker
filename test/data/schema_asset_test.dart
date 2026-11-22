import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/sqlite/schema_asset.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the shipped schema splits into executable statements', () {
    final String script = File('db/schema.sql').readAsStringSync();
    final List<String> statements = schemaStatements(script);

    expect(statements, hasLength(greaterThan(10)));
    expect(
      statements.where((String statement) => statement.startsWith('PRAGMA')),
      isEmpty,
      reason: 'pragmas are per connection, set by AppDatabase.onConfigure',
    );
  });

  test('trigger bodies stay whole (internal semicolons are not split)', () {
    final String script = File('db/schema.sql').readAsStringSync();
    final List<String> statements = schemaStatements(script);

    final List<String> triggers = statements
        .where(
          (String statement) =>
              statement.toUpperCase().startsWith('CREATE TRIGGER'),
        )
        .toList(growable: false);
    expect(triggers, hasLength(2));
    for (final String trigger in triggers) {
      expect(trigger.trimRight(), endsWith('END'));
      expect(trigger, contains('RAISE(ABORT'));
    }
    expect(
      statements.where((String statement) => statement == 'END'),
      isEmpty,
      reason: 'the trigger END must not become its own statement',
    );
  });

  test('the bundled asset is the same DDL as db/schema.sql', () async {
    final String bundled = await loadSchemaAsset();
    final String onDisk = File('db/schema.sql').readAsStringSync();
    expect(bundled, onDisk);
  });
}
