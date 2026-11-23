/// Native platforms: a JSON file beside the database.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/settings/settings_store.dart';
import '../data/settings/settings_store_io.dart';

SettingsStore createSettingsStore(String dataDirectory) =>
    JsonSettingsStore(File(p.join(dataDirectory, 'settings.json')));
