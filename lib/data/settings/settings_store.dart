/// Persistence for the small preference set (no extra table: the schema is
/// fixed at seven tables). A JSON file next to the database is enough for an
/// offline, single-user app.
library;

import 'dart:convert';
import 'dart:io';

/// Read/write access to the preferences map.
abstract class SettingsStore {
  Future<Map<String, Object?>> read();

  Future<void> write(Map<String, Object?> values);
}

/// JSON file implementation. A corrupt file falls back to defaults instead of
/// blocking launch.
class JsonSettingsStore implements SettingsStore {
  JsonSettingsStore(this.file);

  final File file;

  @override
  Future<Map<String, Object?>> read() async {
    if (!await file.exists()) {
      return <String, Object?>{};
    }
    try {
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return Map<String, Object?>.from(decoded);
      }
    } on FormatException {
      return <String, Object?>{};
    }
    return <String, Object?>{};
  }

  @override
  Future<void> write(Map<String, Object?> values) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(values));
  }
}
