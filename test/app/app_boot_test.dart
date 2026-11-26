import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/app/app.dart';
import 'package:pet_health_tracker/app/shell/app_shell.dart';

import '../data/test_support.dart';
import '../features/pets/test_harness.dart';

/// Boots the real app widget against an in-memory SQLite database, so this
/// proves the shell + router + real feature screens + theme wire together
/// without a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SqliteHarness harness;

  setUp(() async {
    harness = await openHarness(seedDemo: true, inMemory: true);
  });

  tearDown(() async {
    await harness.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(PetHealthTrackerApp(services: harness.services));
    await settleAsync(tester);
    await tester.pumpAndSettle();
  }

  Future<void> tapTab(WidgetTester tester, String tab) async {
    await tester.tap(find.byKey(ValueKey<String>(tab)));
    await settleAsync(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('boots to the real Home with the four-destination bar', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    // The demo household's first pet card is Home's real content.
    expect(find.byKey(const ValueKey<String>('pet-card-9001')), findsOneWidget);
    for (final String key in <String>[
      'placeholder-home',
      'placeholder-journal',
      'placeholder-appointments',
      'placeholder-profile',
    ]) {
      expect(
        find.byKey(ValueKey<String>(key), skipOffstage: false),
        findsNothing,
        reason: 'placeholder $key must be retired',
      );
    }
    for (final String tab in <String>[
      'tab-home',
      'tab-journal',
      'tab-appointments',
      'tab-profile',
    ]) {
      expect(
        find.byKey(ValueKey<String>(tab)),
        findsOneWidget,
        reason: 'missing destination $tab',
      );
    }
    expect(find.byKey(const ValueKey<String>('centre-action')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tabs open the four real destinations and stay alive', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tapTab(tester, 'tab-journal');
    expect(find.byKey(const ValueKey<String>('journal-list')), findsOneWidget);
    expect(find.text('Journal'), findsNWidgets(2));

    await tapTab(tester, 'tab-appointments');
    expect(
      find.byKey(const ValueKey<String>('appointments-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('appointment-card-9301')),
      findsOneWidget,
    );

    await tapTab(tester, 'tab-profile');
    expect(
      find.byKey(const ValueKey<String>('profile-pets-section')),
      findsOneWidget,
    );
    expect(find.text('Bella'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('setting-sample-data')),
      findsOneWidget,
    );

    await tapTab(tester, 'tab-home');
    expect(find.byKey(const ValueKey<String>('pet-card-9001')), findsOneWidget);

    // The IndexedStack keeps every visited branch mounted.
    expect(find.byType(IndexedStack), findsWidgets);
    for (final String key in <String>[
      'pet-card-9001',
      'journal-list',
      'appointments-list',
      'profile-pets-section',
    ]) {
      expect(
        find.byKey(ValueKey<String>(key), skipOffstage: false),
        findsOneWidget,
        reason: '$key should still be mounted',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the centre action books a real appointment', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey<String>('centre-action')));
    await tester.pumpAndSettle();

    expect(find.text('QUICK ACTIONS'), findsOneWidget);
    expect(find.text('Book a vet appointment'), findsOneWidget);
    expect(find.text('Log a journal entry'), findsOneWidget);
    expect(find.text('Add a vaccination'), findsOneWidget);
    expect(find.text('Add a health record'), findsOneWidget);
    expect(find.text('Soon'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('centre-action-book')));
    await settleAsync(tester);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('appointment-form-clinic')),
      'City Vet',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('appointment-form-purpose')),
      'Booster shot',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('appointment-form-save')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('appointment-form-save')),
    );
    await settleAsync(tester);
    await tester.pumpAndSettle();

    // The sheet closed, the booking is saved and the Appointments tab shows it.
    expect(find.text('Appointment booked.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('appointments-list')),
      findsOneWidget,
    );
    expect(find.text('City Vet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the centre action logs an entry for a chosen pet', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey<String>('centre-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('centre-action-log')));
    await settleAsync(tester);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('pet-chooser-row-9001')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('pet-chooser-row-9001')),
    );
    await settleAsync(tester);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save entry'));
    await tester.tap(find.text('Save entry'));
    await settleAsync(tester);
    await tester.pumpAndSettle();

    expect(find.text('Note logged.'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('journal-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the centre action appends a health record', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey<String>('centre-action')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('centre-action-health')),
    );
    await settleAsync(tester);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('pet-chooser-row-9002')),
    );
    await settleAsync(tester);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('health-record-form-condition')),
      'Annual check',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('health-record-form-save')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('health-record-form-save')),
    );
    await settleAsync(tester);
    await tester.pumpAndSettle();

    expect(find.text('Health record saved for Miso.'), findsOneWidget);
    final int records = await databaseResult(
      tester,
      () async =>
          (await harness.services.healthRecords.listForPet(9002)).length,
    );
    expect(records, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pet card opens the full-page pet route', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey<String>('pet-card-9001')));
    await settleAsync(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('pet-photo')), findsOneWidget);
    expect(find.text('Bella'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the shell bar renders four labelled destinations', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    final AppShellBar bar = tester.widget<AppShellBar>(
      find.byType(AppShellBar),
    );
    expect(bar.currentIndex, 0);
    expect(shellDestinations, hasLength(4));
    expect(
      shellDestinations.map(
        (ShellDestination destination) => destination.label,
      ),
      <String>['Home', 'Journal', 'Appointments', 'Profile'],
    );
  });

  testWidgets('the centre action can record a vaccination', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey<String>('centre-action')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('centre-action-vaccination')),
    );
    await settleAsync(tester);
    await tester.pumpAndSettle();

    // The chooser, then the real vaccination form for that pet.
    expect(find.text('Which pet was vaccinated?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('pet-chooser-row-9001')),
    );
    await settleAsync(tester);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('vaccination-form-save')),
      findsOneWidget,
    );
  });

}
