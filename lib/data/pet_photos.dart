/// Pet photo picking and storage, resolved per platform.
///
/// The web build has no filesystem: there is no picker and no stored photo, so
/// every pet keeps the drawn portrait.
library;

export 'pet_photos_stub.dart' if (dart.library.io) 'pet_photos_io.dart';
