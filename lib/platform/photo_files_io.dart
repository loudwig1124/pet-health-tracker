/// Photo files on a platform with a filesystem.
library;

import 'dart:io';

/// True when [path] points at a file that still exists.
bool photoExists(String? path) {
  final String? trimmed = path?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return false;
  }
  return File(trimmed).existsSync();
}
