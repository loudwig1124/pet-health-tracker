/// Every screen, at every phone size the app might meet.
///
/// Overflow here is an exception in tests, so this is a cheap compatibility
/// sweep: SE, small Android, Pro Max, a 320 pt relic, landscape and a tablet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/app/app_scope.dart';
import 'package:pet_health_tracker/features/appointments/appointments_screen.dart';
import 'package:pet_health_tracker/features/home/home_screen.dart';
import 'package:pet_health_tracker/features/journal/journal_screen.dart';
import 'package:pet_health_tracker/features/profile/profile_screen.dart';
import 'package:pet_health_tracker/ui/theme/app_theme.dart';

import '../../data/test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteHarness harness;

  setUp(() async {
    harness = await openHarness(seedDemo: true, inMemory: true);
  });
  tearDown(() async {
    await harness.dispose();
  });

  Future<void> pumpAt(
    WidgetTester tester,
    Widget screen,
    Size size,
  ) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        services: harness.services,
        child: MaterialApp(theme: AppTheme.light(), home: screen),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  for (final MapEntry<String, Size> device in <String, Size>{
    'SE 375x667': const Size(375, 667),
    'small Android 360x640': const Size(360, 640),
    'Pro Max 430x932': const Size(430, 932),
    'tiny 320x568': const Size(320, 568),
    'landscape 844x390': const Size(844, 390),
    'tablet 768x1024': const Size(768, 1024),
  }.entries) {
    for (final MapEntry<String, Widget> screen in <String, Widget>{
      'Home': const HomeScreen(),
      'Journal': const JournalScreen(),
      'Appointments': const AppointmentsScreen(),
      'Profile': const ProfileScreen(),
    }.entries) {
      testWidgets('${screen.key} fits ${device.key}', (
        WidgetTester tester,
      ) async {
        await pumpAt(tester, screen.value, device.value);
        final Object? error = tester.takeException();
        expect(error, isNull, reason: '${screen.key} at ${device.key}: $error');
      });
    }
  }
}
