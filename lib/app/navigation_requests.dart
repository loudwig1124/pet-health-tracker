/// One-shot requests a screen makes to another screen's state.
///
/// Home can't touch the Appointments controller directly — they live in
/// different branches — so the tap leaves a value here and the destination
/// consumes it the next time it becomes active.
library;

import 'package:flutter/foundation.dart';

abstract final class NavigationRequests {
  /// Bumped after any write that a screen might be showing. The navigation
  /// shell keeps every visited branch alive, so a write made from the centre
  /// action cannot rely on a tab switch to refresh the tabs that stay put.
  static final ValueNotifier<int> householdRevision = ValueNotifier<int>(0);

  /// Call after a successful write, before navigating away.
  static void bumpHousehold() => householdRevision.value++;

  /// Pet the Appointments list should focus when it next opens.
  ///
  /// A nullable *notifier* could not say "open with no pet filter": null was
  /// both "no request" and "no filter". The request object separates them.
  static final ValueNotifier<PetFilterRequest?> appointmentsFilter =
      ValueNotifier<PetFilterRequest?>(null);
}

/// One "open Appointments focused on this pet" request. A null [petId] means the
/// visit belongs to the household rather than a pet, so the list opens unfiltered.
class PetFilterRequest {
  const PetFilterRequest(this.petId);

  final int? petId;
}
