/// The one household profile.
library;

import '../../domain/models/owner.dart';

abstract class OwnerRepository {
  /// Loads the household owner. Throws [StateError] when the app was not
  /// bootstrapped through `AppServices` (no owner row exists).
  Future<Owner> load();

  /// Loads the owner, creating the default household row on first run.
  Future<Owner> ensureDefault();

  /// Saves profile edits and returns the updated owner.
  Future<Owner> save(OwnerDraft draft);
}
