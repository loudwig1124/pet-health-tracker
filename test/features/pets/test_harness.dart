/// Widget-test helpers for the feature screens.
///
/// The screens load from a real SQLite database (`sqflite_common_ffi`); its
/// futures complete on the real event loop, so tests wait with `runAsync`
/// instead of `pumpAndSettle` while a loading spinner is visible.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/app/app_scope.dart';
import 'package:pet_health_tracker/app/app_services.dart';
import 'package:pet_health_tracker/ui/theme/app_theme.dart';

/// The phone surface the two sheet stops are defined against (390 x 844).
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Lets real async work finish across several frames.
///
/// A screen load is a chain of database calls: each await only starts the next
/// call when the fake-async event loop is pumped, so a single `runAsync` window
/// can stop halfway. Alternating real waits with pumps walks the whole chain.
Future<void> settleAsync(
  WidgetTester tester, {
  Duration wait = const Duration(milliseconds: 100),
  int rounds = 5,
}) async {
  for (int round = 0; round < rounds; round++) {
    await tester.runAsync(() => Future<void>.delayed(wait));
    await tester.pump(const Duration(milliseconds: 80));
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Pumps [screen] inside the app scope and theme, then waits for its loads.
Future<void> pumpScreen(
  WidgetTester tester,
  AppServices services,
  Widget screen,
) async {
  await tester.pumpWidget(
    AppScope(
      services: services,
      child: MaterialApp(theme: AppTheme.light(), home: screen),
    ),
  );
  await settleAsync(tester);
}

/// Runs a database call from a widget test on the real event loop.
Future<T> databaseResult<T>(
  WidgetTester tester,
  Future<T> Function() read,
) async {
  late T value;
  await tester.runAsync(() async {
    value = await read();
  });
  return value;
}
