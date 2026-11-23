/// Persistence for the small preference set (no extra table: the schema is
/// fixed at seven tables).
///
/// Only the contract lives here: the JSON-file implementation needs `dart:io`,
/// so the concrete store is chosen per platform in `lib/platform/`.
library;

/// Read/write access to the preferences map.
abstract class SettingsStore {
  Future<Map<String, Object?>> read();

  Future<void> write(Map<String, Object?> values);
}
