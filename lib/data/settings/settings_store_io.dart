/// Preferences as a JSON file next to the database — offline, single user.
library;

import 'dart:convert';
import 'dart:io';

import 'settings_store.dart';

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
