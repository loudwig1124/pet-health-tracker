/// Web: SQLite runs in WebAssembly and stores itself in IndexedDB, so the
/// "path" is only a database name.
library;

import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite_common/sqlite_api.dart';

/// Opens the WASM factory. The no-worker variant keeps SQLite on the main
/// thread, which is plenty for a single-tab app and needs no extra script.
Future<({DatabaseFactory factory, String path})> platformDatabase() async =>
    (factory: databaseFactoryFfiWebNoWebWorker, path: 'pet_health_tracker.db');

/// The web has no filesystem; settings live in `shared_preferences`.
String platformDataDirectory(String databasePath) => '/';
