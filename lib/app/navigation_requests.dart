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
  static final ValueNotifier<int?> appointmentsPetFilter =
      ValueNotifier<int?>(null);
}
