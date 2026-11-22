// Recorded demo tour for the promo cut.
//
// Run on a booted simulator while `simctl io booted recordVideo` is rolling:
// every beat below is a real gesture on a real device. The holds are deliberately
// long so the footage is usable — the editor trims them, not the tour.
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/promo_tour_test.dart -d "iPhone 17 Pro"

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pet_health_tracker/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Hold the current screen for the recorder. Pumping in ~30 fps slices keeps
  /// animations and timers advancing in real time — a bare `Future.delayed`
  /// freezes the engine and leaves snackbars stuck on screen.
  Future<void> hold(WidgetTester tester, int milliseconds) async {
    final DateTime end = DateTime.now().add(Duration(milliseconds: milliseconds));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 33));
    }
  }

  Future<bool> tapKey(
    WidgetTester tester,
    String key, {
    int holdMs = 900,
  }) async {
    final Finder finder = find.byKey(ValueKey<String>(key));
    if (finder.evaluate().isEmpty) {
      return false;
    }
    await tester.tap(finder.first, warnIfMissed: false);
    await hold(tester, holdMs);
    return true;
  }

  Future<bool> drag(
    WidgetTester tester,
    String key,
    Offset delta, {
    int holdMs = 900,
  }) async {
    final Finder finder = find.byKey(ValueKey<String>(key));
    if (finder.evaluate().isEmpty) {
      return false;
    }
    await tester.drag(finder.first, delta);
    await hold(tester, holdMs);
    return true;
  }

  testWidgets('promo tour', (WidgetTester tester) async {
    await app.main();
    await hold(tester, 2200);
    await tapKey(tester, 'tab-home', holdMs: 1400);

    // --- take reset: reseed the demo household so every recording is identical
    await tapKey(tester, 'tab-profile', holdMs: 1400);
    await tapKey(tester, 'setting-sample-data-switch', holdMs: 2400);
    await tapKey(tester, 'setting-sample-data-switch', holdMs: 2800);
    await tapKey(tester, 'tab-home', holdMs: 2000);

    // --- beat 1: the pet pager
    await drag(tester, 'pet-card-9001', const Offset(-320, 0), holdMs: 2000);
    await drag(tester, 'pet-card-9002', const Offset(320, 0), holdMs: 1800);

    // --- beat 2: journal, filtered by pet
    await tapKey(tester, 'tab-journal', holdMs: 1800);
    await tapKey(tester, 'journal-pet-filter-9001', holdMs: 2400);
    await tapKey(tester, 'journal-pet-filter-all', holdMs: 1600);

    // --- beat 3: close an appointment, then look at it in Past
    await tapKey(tester, 'tab-appointments', holdMs: 1800);
    await tapKey(tester, 'appointment-card-9301', holdMs: 1600);
    await tapKey(tester, 'appointment-action-complete', holdMs: 2400);
    await tapKey(tester, 'appointments-tab-past', holdMs: 2400);
    await tapKey(tester, 'appointments-tab-upcoming', holdMs: 1200);

    // --- beat 4: the pet page, sheet raised
    await tapKey(tester, 'tab-home', holdMs: 1600);
    await tapKey(tester, 'pet-card-9001', holdMs: 2400);
    await drag(tester, 'pet-sheet', const Offset(0, -420), holdMs: 900);
    await tester.pumpAndSettle();
    await hold(tester, 2600);
    await tapKey(tester, 'pet-back', holdMs: 1600);

    // --- beat 5: profile
    await tapKey(tester, 'tab-profile', holdMs: 1600);
    final Finder list = find.byType(ListView);
    if (list.evaluate().isNotEmpty) {
      await tester.drag(list.first, const Offset(0, -180));
      await hold(tester, 2400);
    }

    // --- beat 6: log a walk, then undo it (the snackbar ends with the take)
    await tapKey(tester, 'tab-home', holdMs: 1800);
    await tapKey(tester, 'quick-log-walk', holdMs: 2600);
    final Finder undo = find.text('Undo');
    if (undo.evaluate().isNotEmpty) {
      await tester.tap(undo.first, warnIfMissed: false);
      await hold(tester, 2200);
    }
    await hold(tester, 800);
  });
}
