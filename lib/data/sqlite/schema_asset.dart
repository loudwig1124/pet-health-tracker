/// Bundled DDL (`db/schema.sql`) and the statement splitter used to apply it.
///
/// The file stays the single source of truth: the app applies the same artifact
/// the CLI validates with `sqlite3 :memory: ".read db/schema.sql"`.
library;

import 'package:flutter/services.dart';

/// Asset key of the shipped schema (declared in `pubspec.yaml`).
const String schemaAssetKey = 'db/schema.sql';

typedef SchemaLoader = Future<String> Function();

/// Loads the schema from the app bundle.
Future<String> loadSchemaAsset() => rootBundle.loadString(schemaAssetKey);

/// Splits a SQL script into executable statements: `;` outside string literals
/// and `--` comments ends a statement, except inside a `CREATE TRIGGER ... BEGIN
/// ... END;` body, whose internal semicolons belong to the trigger.
List<String> splitSqlStatements(String script) {
  final List<String> statements = <String>[];
  final StringBuffer buffer = StringBuffer();
  String? quote;
  bool inTrigger = false;

  void flush() {
    final String statement = buffer.toString().trim();
    buffer.clear();
    if (statement.isNotEmpty) {
      statements.add(statement);
    }
  }

  for (int i = 0; i < script.length; i++) {
    final String char = script[i];
    if (quote != null) {
      buffer.write(char);
      if (char == quote) {
        quote = null;
      }
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
      buffer.write(char);
      continue;
    }
    if (char == '-' && i + 1 < script.length && script[i + 1] == '-') {
      while (i < script.length && script[i] != '\n') {
        i++;
      }
      buffer.write('\n');
      continue;
    }
    if (char == ';') {
      if (!inTrigger &&
          buffer.toString().trimLeft().toLowerCase().startsWith(
            'create trigger',
          )) {
        inTrigger = true;
      }
      if (inTrigger &&
          !buffer.toString().trim().toLowerCase().endsWith('end')) {
        buffer.write(';');
        continue;
      }
      flush();
      inTrigger = false;
      continue;
    }
    buffer.write(char);
  }
  flush();
  return statements;
}

/// Statements to execute on database creation. `PRAGMA` statements are per
/// connection (and no-ops inside a transaction), so `AppDatabase.onConfigure`
/// sets them instead.
List<String> schemaStatements(String script) => splitSqlStatements(script)
    .where(
      (String statement) =>
          !statement.trimLeft().toUpperCase().startsWith('PRAGMA'),
    )
    .toList(growable: false);
