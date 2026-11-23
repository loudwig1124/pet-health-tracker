/// How the app opens its database on the current platform.
library;

export 'platform_database_stub.dart'
    if (dart.library.io) 'platform_database_io.dart';
