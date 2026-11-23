/// Web: browser storage.
library;

import '../data/settings/settings_store.dart';
import '../data/settings/settings_store_web.dart';

SettingsStore createSettingsStore(String dataDirectory) =>
    SharedPreferencesSettingsStore();
