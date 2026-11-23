/// Filesystem-dependent photo checks, resolved per platform.
library;

export 'photo_files_stub.dart' if (dart.library.io) 'photo_files_io.dart';
