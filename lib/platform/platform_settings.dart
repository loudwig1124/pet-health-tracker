/// Chooses how preferences are persisted on this platform.
library;

export 'platform_settings_stub.dart'
    if (dart.library.io) 'platform_settings_io.dart';
