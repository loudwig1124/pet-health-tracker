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
    // The v2 schema ships no triggers, but the splitter must keep supporting
    // them: a BEGIN ... END body contains semicolons of its own.
    const String script = '''
CREATE TABLE t (id INTEGER PRIMARY KEY);
CREATE TRIGGER t_no_delete
BEFORE DELETE ON t
BEGIN
  SELECT RAISE(ABORT, 'no');
END;
CREATE TABLE u (id INTEGER PRIMARY KEY);
''';
    final List<String> statements = schemaStatements(script);

    final List<String> triggers = statements
        .where(
          (String statement) =>
              statement.toUpperCase().startsWith('CREATE TRIGGER'),
        )
        .toList(growable: false);
    expect(triggers, hasLength(1));
    expect(triggers.single.trimRight(), endsWith('END'));
    expect(triggers.single, contains('RAISE(ABORT'));
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
