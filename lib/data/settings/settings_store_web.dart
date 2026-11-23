/// Preferences in the browser's local storage, since the web has no files.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'settings_store.dart';

/// Keeps the whole preferences map as one JSON string.
class SharedPreferencesSettingsStore implements SettingsStore {
  static const String _key = 'pet_health_tracker.settings';

  @override
  Future<Map<String, Object?>> read() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null) {
      return <String, Object?>{};
    }
    try {
      final Object? decoded = jsonDecode(raw);
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
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(values));
  }
}
