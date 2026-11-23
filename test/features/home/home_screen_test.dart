import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/app/app_scope.dart';
import 'package:pet_health_tracker/app/app_services.dart';
import 'package:pet_health_tracker/domain/models/journal_entry.dart';
import 'package:pet_health_tracker/domain/models/pet.dart';
import 'package:pet_health_tracker/features/home/home_screen.dart';
import 'package:pet_health_tracker/features/home/widgets/pet_page_dots.dart';
import 'package:pet_health_tracker/ui/kit/app_chip.dart';
import 'package:pet_health_tracker/ui/theme/app_theme.dart';

import '../../data/test_support.dart';

/// Home's layout and its two writes, against the real seeded SQLite household.
///
/// The harness is opened in `setUp` (real async) and every database read made
/// from inside a widget test goes through `tester.runAsync`, because widget
/// tests run under a fake clock.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final DateTime fixedMorning = DateTime.utc(2026, 11, 21, 9, 30);

  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpHome(
    WidgetTester tester,
    AppServices services, {
    Widget screen = const HomeScreen(),
  }) async {
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(theme: AppTheme.light(), home: screen),
      ),
    );
    // The dashboard load is real database work; let it finish before pumping.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  /// Lets real database work in the widget's async handlers finish, then
  /// rebuilds. Widget tests otherwise only advance the fake clock.
  Future<void> settleDatabase(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  /// Lets the undo snackbar's four-second timer expire before the test ends.
  Future<void> expireSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  group('seeded household', () {
    late SqliteHarness harness;

    setUp(() async {
      harness = await openHarness(seedDemo: true, inMemory: true);
    });

    tearDown(() async {
      await harness.dispose();
    });

    testWidgets(
      'lays out the two seeded pets, dots, quick log, visit and recent rows',
      (WidgetTester tester) async {
        usePhoneSurface(tester);
        await pumpHome(tester, harness.services);

        // Greeting row with the owner's initial avatar.
        expect(find.textContaining('Maria'), findsOneWidget);
        expect(find.text('M'), findsOneWidget);

        // The card is 310 x 264 on a 390-wide screen.
        final Finder bella = find.byKey(
          const ValueKey<String>('pet-card-9001'),
        );
        expect(bella, findsOneWidget);
        expect(tester.getSize(bella).width, closeTo(310, 0.5));
        expect(tester.getSize(bella).height, 264);

        // 62 px round avatar, name at 27, then species/breed/age/weight.
        final Size avatar = tester.getSize(
          find.byKey(const ValueKey<String>('pet-avatar-9001')),
        );
        expect(avatar.width, 62);
        expect(avatar.height, 62);
        final Text name = tester.widget<Text>(
          find.descendant(of: bella, matching: find.text('Bella')),
        );
        expect(name.style?.fontSize, 27);
        expect(
          find.descendant(
            of: bella,
            matching: find.textContaining('Dog · Golden Retriever mix'),
          ),
          findsOneWidget,
        );

        // Exactly one status chip, driven by the shared due rule.
        final Finder chips = find.descendant(
          of: bella,
          matching: find.byType(AppChip),
        );
        expect(chips, findsOneWidget);
        expect(
          find.descendant(of: chips, matching: find.textContaining('Rabies')),
          findsOneWidget,
        );

        for (final String label in <String>['AGE', 'WEIGHT', 'SEX']) {
          expect(
            find.descendant(of: bella, matching: find.text(label)),
            findsOneWidget,
            reason: 'missing $label stat',
          );
        }
        expect(
          find.descendant(
            of: bella,
            matching: find.textContaining('Last visit ·'),
          ),
          findsOneWidget,
        );

        // Two pets, two dots.
        expect(find.byType(PetPageDots), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('pet-dot-0')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('pet-dot-1')), findsOneWidget);

        // The four quick-log chips, in the approved order.
        for (final String kind in <String>['walk', 'fed', 'meds', 'note']) {
          expect(
            find.byKey(ValueKey<String>('quick-log-$kind')),
            findsOneWidget,
            reason: 'missing quick-log chip $kind',
          );
        }

        // The next appointment card.
        expect(
          find.byKey(const ValueKey<String>('next-appointment')),
          findsOneWidget,
        );
        expect(find.text('Paws & Claws Veterinary Clinic'), findsOneWidget);
        expect(find.textContaining('Annual wellness check'), findsOneWidget);

        // The last two journal entries.
        expect(
          find.byKey(const ValueKey<String>('recent-entry-9402')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('recent-entry-9401')),
          findsOneWidget,
        );
        expect(find.text('Walk · 30 min'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a chip tap writes kind + occurred_at only, and undo removes it',
      (WidgetTester tester) async {
        usePhoneSurface(tester);
        await pumpHome(tester, harness.services);

        final Set<int> before = (await tester.runAsync(
          () => harness.services.journal.listHousehold(limit: 100),
        ))!.map((JournalEntry entry) => entry.id).toSet();

        await tester.tap(find.byKey(const ValueKey<String>('quick-log-walk')));
        await settleDatabase(tester);

        // The undo affordance is part of the instant save.
        expect(find.text('Walk logged'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);

        final List<JournalEntry> after = (await tester.runAsync(
          () => harness.services.journal.listHousehold(limit: 100),
        ))!;
        final List<JournalEntry> added = after
            .where((JournalEntry entry) => !before.contains(entry.id))
            .toList();
        expect(added, hasLength(1));
        final JournalEntry entry = added.single;
        expect(entry.petId, 9001, reason: 'the first card is Bella');
        expect(entry.kind, JournalKind.walk);
        expect(entry.occurredAt, fixedMorning);
        expect(entry.note, isNull);
        expect(entry.durationMinutes, isNull);

        await tester.tap(find.text('Undo'));
        await settleDatabase(tester);
        await expireSnackBar(tester);

        expect(
          await tester.runAsync(
            () => harness.services.journal.findById(entry.id),
          ),
          isNull,
        );
        expect(
          (await tester.runAsync(
            () => harness.services.journal.listHousehold(limit: 100),
          ))!.length,
          before.length,
        );
      },
    );

    testWidgets('long-press opens the full form and saves the details', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await pumpHome(tester, harness.services);

      await tester.longPress(
        find.byKey(const ValueKey<String>('quick-log-meds')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Log for Bella'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('form-date')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('form-time')), findsOneWidget);
      expect(find.text('Save entry'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('form-note')),
        'Anti-rabies',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('form-duration')),
        '15',
      );
      await tester.pump();
      await tester.tap(find.text('Save entry'));
      await settleDatabase(tester);

      final JournalEntry entry =
          (await tester.runAsync(
            () => harness.services.journal.listHousehold(limit: 100),
          ))!.firstWhere(
            (JournalEntry candidate) => candidate.note == 'Anti-rabies',
          );
      expect(entry.kind, JournalKind.meds);
      expect(entry.durationMinutes, 15);
      expect(entry.petId, 9001);
      expect(find.text('Meds logged'), findsOneWidget);
      await expireSnackBar(tester);
    });

    testWidgets('tapping a dot jumps the pager to that pet', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await pumpHome(tester, harness.services);

      final Finder bella = find.byKey(const ValueKey<String>('pet-card-9001'));
      final Finder miso = find.byKey(const ValueKey<String>('pet-card-9002'));
      expect(tester.getTopLeft(bella).dx, closeTo(40, 0.5));

      await tester.tap(find.byKey(const ValueKey<String>('pet-dot-1')));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(miso).dx, closeTo(40, 0.5));
      expect(tester.getTopLeft(bella).dx, lessThan(0));
    });

    testWidgets('the pager ends on the add-a-pet card', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await pumpHome(tester, harness.services);

      for (int page = 0; page < 2; page++) {
        await tester.drag(find.byType(PageView), const Offset(-350, 0));
        await tester.pumpAndSettle();
      }

      expect(
        find.byKey(const ValueKey<String>('add-pet-card')),
        findsOneWidget,
      );
      expect(find.text('Add a pet'), findsOneWidget);
      expect(find.text('Photo, name, and a birthday'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('pet-dot-0')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('pet-dot-1')), findsOneWidget);
    });
  });

  group('one pet', () {
    late SqliteHarness harness;
    late Pet solo;

    setUp(() async {
      harness = await openHarness(inMemory: true);
      solo = await harness.services.pets.create(
        PetDraft(
          name: 'Solo',
          species: 'Dog',
          sex: PetSex.female,
          dateOfBirth: DateTime.utc(2021, 3, 4),
          weightKg: 9.5,
        ),
      );
    });

    tearDown(() async {
      await harness.dispose();
    });

    testWidgets('hides the dots at one pet and shows one per pet at two', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await pumpHome(tester, harness.services);

      expect(
        find.byKey(ValueKey<String>('pet-card-${solo.id}')),
        findsOneWidget,
      );
      expect(find.byType(PetPageDots), findsNothing);

      final Pet duo = (await tester.runAsync(
        () => harness.services.pets.create(
          PetDraft(
            name: 'Duo',
            species: 'Cat',
            sex: PetSex.male,
            dateOfBirth: DateTime.utc(2022, 5, 6),
            weightKg: 4,
          ),
        ),
      ))!;
      await pumpHome(
        tester,
        harness.services,
        screen: const HomeScreen(key: ValueKey<String>('home-two-pets')),
      );

      expect(find.byType(PetPageDots), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('pet-dot-0')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('pet-dot-1')), findsOneWidget);
      expect(
        find.byKey(ValueKey<String>('pet-card-${duo.id}')),
        findsOneWidget,
      );
    });
  });

  group('empty household', () {
    late SqliteHarness harness;

    setUp(() async {
      harness = await openHarness(inMemory: true);
    });

    tearDown(() async {
      await harness.dispose();
    });

    testWidgets('shows the empty household state when there are no pets', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await pumpHome(tester, harness.services);

      // An empty household gets onboarding, not a dead end.
      expect(
        find.byKey(const ValueKey<String>('first-run-card')),
        findsOneWidget,
      );
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.byType(PetPageDots), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
