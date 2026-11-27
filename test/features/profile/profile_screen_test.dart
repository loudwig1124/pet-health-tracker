import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_health_tracker/app/app_scope.dart';
import 'package:pet_health_tracker/app/app_settings.dart';
import 'package:pet_health_tracker/domain/models/owner.dart';
import 'package:pet_health_tracker/features/pets/pet_routes.dart';
import 'package:pet_health_tracker/features/profile/profile_screen.dart';
import 'package:pet_health_tracker/ui/kit/list_row.dart';
import 'package:pet_health_tracker/ui/theme/app_theme.dart';

import '../../data/test_support.dart';
import '../pets/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SqliteHarness harness;

  setUp(() async {
    harness = await openHarness(seedDemo: true, inMemory: true);
    await harness.services.owners.save(
      const OwnerDraft(
        name: 'Maria Santos',
        email: 'maria.santos@example.com',
        phone: '+63 917 555 0142',
      ),
    );
  });

  tearDown(() async {
    await harness.dispose();
  });

  Future<void> pumpProfile(WidgetTester tester) async {
    usePhoneSurface(tester);
    await pumpScreen(tester, harness.services, const ProfileScreen());
  }

  testWidgets('shows the owner, pets, exactly three settings rows and counts', (
    WidgetTester tester,
  ) async {
    await pumpProfile(tester);

    expect(find.text('Profile'), findsOneWidget);
    final Text initial = tester.widget<Text>(
      find.byKey(const ValueKey<String>('profile-owner-initial')),
    );
    expect(initial.data, 'M');
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('maria.santos@example.com'), findsOneWidget);
    expect(find.text('+63 917 555 0142'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('profile-edit-owner')),
      findsOneWidget,
    );

    expect(
      find.byKey(const ValueKey<String>('profile-pet-row-9001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('profile-pet-row-9002')),
      findsOneWidget,
    );
    expect(find.text('Bella'), findsOneWidget);
    expect(find.text('Miso'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('profile-add-pet')),
      findsOneWidget,
    );

    final Finder settings = find.byKey(
      const ValueKey<String>('settings-section'),
    );
    expect(
      find.descendant(of: settings, matching: find.byType(ListRow)),
      findsNWidgets(4),
    );
    for (final String key in <String>[
      'setting-due-window',
      'setting-weight-unit',
      'setting-sample-data',
      'setting-reset-household',
    ]) {
      expect(
        find.descendant(
          of: settings,
          matching: find.byKey(ValueKey<String>(key)),
        ),
        findsOneWidget,
        reason: 'missing setting row $key',
      );
    }
    expect(find.text('Due-soon window'), findsOneWidget);
    expect(find.text('30 days'), findsOneWidget);
    expect(find.text('Weight unit'), findsOneWidget);
    expect(find.text('kg'), findsOneWidget);
    expect(find.text('Sample data'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('setting-sample-data-switch')),
      findsOneWidget,
    );

    // 4 journal entries + 4 vaccinations + 2 clinical notes + 2 appointments.
    expect(find.textContaining('2 pets'), findsOneWidget);
    expect(find.textContaining('12 records'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner edits are persisted', (WidgetTester tester) async {
    await pumpProfile(tester);

    await tester.tap(find.byKey(const ValueKey<String>('profile-edit-owner')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('owner-form-name')),
      'Maria Cruz',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('owner-form-email')),
      'maria.cruz@example.com',
    );
    await tester.tap(find.byKey(const ValueKey<String>('owner-form-save')));
    await settleAsync(tester);
    await tester.pumpAndSettle();

    expect(find.text('Maria Cruz'), findsOneWidget);
    expect(find.text('maria.cruz@example.com'), findsOneWidget);

    final Owner stored = await databaseResult(
      tester,
      () => harness.services.owners.load(),
    );
    expect(stored.name, 'Maria Cruz');
    expect(stored.email, 'maria.cruz@example.com');
    expect(stored.phone, '+63 917 555 0142');

    // The persisted row survives a fresh mount of the screen.
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpProfile(tester);
    expect(find.text('Maria Cruz'), findsOneWidget);
  });

  testWidgets('sample data toggle seeds and clears the demo household', (
    WidgetTester tester,
  ) async {
    await pumpProfile(tester);

    final Finder toggle = find.byKey(
      const ValueKey<String>('setting-sample-data-switch'),
    );
    expect(tester.widget<Switch>(toggle).value, isTrue);

    await tester.tap(toggle);
    await settleAsync(tester, wait: const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(harness.services.settings.sampleDataEnabled, isFalse);
    expect(
      find.byKey(const ValueKey<String>('profile-pet-row-9001')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('profile-empty-pets')),
      findsOneWidget,
    );
    expect(find.textContaining('0 pets'), findsOneWidget);
    expect(find.textContaining('0 records'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('setting-sample-data-switch')),
    );
    await settleAsync(tester, wait: const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(harness.services.settings.sampleDataEnabled, isTrue);
    expect(
      find.byKey(const ValueKey<String>('profile-pet-row-9001')),
      findsOneWidget,
    );
  });

  testWidgets('settings choices update and persist', (
    WidgetTester tester,
  ) async {
    await pumpProfile(tester);

    await tester.tap(find.byKey(const ValueKey<String>('setting-due-window')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('60 days'));
    await tester.pumpAndSettle();
    expect(harness.services.settings.dueSoonWindowDays, 60);
    expect(find.text('60 days'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('setting-weight-unit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pounds (lb)'));
    await tester.pumpAndSettle();
    expect(harness.services.settings.weightUnit, WeightUnit.lb);
    expect(find.text('lb'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pet row opens the pet page route', (
    WidgetTester tester,
  ) async {
    usePhoneSurface(tester);
    final GoRouter router = GoRouter(
      initialLocation: '/profile',
      routes: <RouteBase>[
        PetRoutes.route(),
        GoRoute(
          path: '/profile',
          builder: (BuildContext context, GoRouterState state) =>
              const ProfileScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      AppScope(
        services: harness.services,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await settleAsync(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('profile-pet-row-9001')),
    );
    await settleAsync(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('pet-photo')), findsOneWidget);
    expect(find.text('Bella'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });


}
