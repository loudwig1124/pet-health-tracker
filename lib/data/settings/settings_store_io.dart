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
    } catch (_) {
      // A corrupt or unreadable file falls back to defaults: booting with a
      // blank preference set is recoverable, refusing to start is not.
      return <String, Object?>{};
    }
    // Valid JSON that is not an object: treat it as absent.
    return <String, Object?>{};
  }

  @override
  Future<void> write(Map<String, Object?> values) async {
    await file.parent.create(recursive: true);
    // Write then rename: a crash mid-write leaves the previous settings intact
    // instead of a truncated file that reads as "no preferences".
    final File temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(values), flush: true);
    await temporary.rename(file.path);
  }
}
