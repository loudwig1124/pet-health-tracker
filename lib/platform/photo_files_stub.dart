/// Photo files on the web: there is no filesystem, so no stored photo exists
/// and the drawn portrait is always used.
library;

/// Always false: the web build stores no photo paths.
bool photoExists(String? path) => false;

/// The picker is hidden on the web; see `PetPhotos`' stub.
bool get supportsPhotoPicking => false;
