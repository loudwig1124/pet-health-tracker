/// One-shot requests a screen makes to another screen's state.
///
/// Home can't touch the Appointments controller directly — they live in
/// different branches — so the tap leaves a value here and the destination
/// consumes it the next time it becomes active.
library;

import 'package:flutter/foundation.dart';

abstract final class NavigationRequests {
  /// Pet the Appointments list should focus when it next opens.
  static final ValueNotifier<int?> appointmentsPetFilter =
      ValueNotifier<int?>(null);
}
