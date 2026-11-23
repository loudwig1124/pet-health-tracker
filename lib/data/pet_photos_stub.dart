/// Web: photos are not supported, so the form hides the control.
library;

/// A picker that never opens.
class PetPhotos {
  /// The web build offers no picker.
  static bool get supported => false;

  Future<String?> pickFromLibrary() async => null;

  Future<void> deleteOwned(String? path) async {}
}
