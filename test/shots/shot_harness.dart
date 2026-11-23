/// Screenshot harness: renders real screens to `test/shots/*.png`.
///
/// Not picked up by `flutter test` (no `_test` suffix). Run it explicitly:
///   ./tool/fv test --update-goldens test/shots/shot_harness.dart
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/app/app.dart';

import '../data/test_support.dart';
import '../features/pets/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final MapEntry<String, String> e in <String, String>{
      'Roboto': '/System/Library/Fonts/Supplemental/Arial.ttf',
      'MaterialIcons':
          '/Users/daniel/Documents/Coding Projects/School/School Project (AppDev)/'
              'Final Project/.flutter-sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final File f = File(e.value);
      if (!f.existsSync()) continue;
      final FontLoader l = FontLoader(e.key)
        ..addFont(Future<ByteData>.value(ByteData.sublistView(f.readAsBytesSync())));
      await l.load();
    }
  });

  late SqliteHarness harness;
  setUp(() async => harness = await openHarness(seedDemo: true, inMemory: true));
  tearDown(() async => harness.dispose());

  Future<void> shot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(PetHealthTrackerApp),
      matchesGoldenFile('$name.png'),
    );
  }

  testWidgets('shots', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(PetHealthTrackerApp(services: harness.services));
    await settleAsync(tester);
    await tester.pumpAndSettle();
    await shot(tester, 'live-home');

    await tester.tap(find.byKey(const ValueKey<String>('tab-journal')));
    await tester.pump();
    await settleAsync(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await shot(tester, 'live-journal');

    await tester.tap(find.byKey(const ValueKey<String>('tab-appointments')));
    await tester.pump();
    await settleAsync(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await shot(tester, 'live-appointments');

    await tester.tap(find.byKey(const ValueKey<String>('tab-profile')));
    await tester.pump();
    await settleAsync(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await shot(tester, 'live-profile');
  });
}
