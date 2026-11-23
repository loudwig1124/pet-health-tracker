/// The widget that paints a stored photo, resolved per platform.
library;

export 'photo_image_stub.dart' if (dart.library.io) 'photo_image_io.dart';
