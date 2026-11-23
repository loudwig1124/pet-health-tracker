import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/app/app_scope.dart';
import 'package:pet_health_tracker/domain/models/journal_entry.dart';
import 'package:pet_health_tracker/domain/models/pet.dart';
import 'package:pet_health_tracker/features/journal/journal_screen.dart';
import 'package:pet_health_tracker/ui/format/app_formats.dart';
import 'package:pet_health_tracker/ui/kit/list_row.dart';
import 'package:pet_health_tracker/ui/theme/app_theme.dart';

import '../../data/test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SqliteHarness harness;
  late SqliteHarness emptyHarness;
  late Pet bella;
  late Pet miso;
  late JournalEntry walk;
  late JournalEntry fed;
  late JournalEntry note;
  late JournalEntry symptom;

  final DateTime now = fixedNow();
  final DateTime local = now.toLocal();

  DateTime todayAt(int hour, int minute) =>
      DateTime(local.year, local.month, local.day, hour, minute);
  DateTime daysAgoAt(int days, int hour, int minute) =>
      DateTime(local.year, local.month, local.day - days, hour, minute);

  setUp(() async {
    harness = await openHarness(inMemory: true);
    // A file database: two `:memory:` handles can share one database.
    emptyHarness = await openHarness();
    bella = await harness.services.pets.create(
      PetDraft(
        name: 'Bella',
        species: 'Dog',
        sex: PetSex.female,
        dateOfBirth: DateTime.utc(2021, 3, 14),
        weightKg: 12.4,
      ),
    );
    miso = await harness.services.pets.create(
      PetDraft(
        name: 'Miso',
        species: 'Cat',
        sex: PetSex.male,
        dateOfBirth: DateTime.utc(2022, 7, 1),
        weightKg: 4.2,
      ),
    );
    walk = await harness.services.journal.create(
      JournalDraft(
        petId: bella.id,
        kind: JournalKind.walk,
        occurredAt: todayAt(7, 10),
        durationMinutes: 30,
      ),
    );
    fed = await harness.services.journal.create(
      JournalDraft(
        petId: miso.id,
        kind: JournalKind.fed,
        occurredAt: todayAt(8, 0),
      ),
    );
    note = await harness.services.journal.create(
      JournalDraft(
        petId: bella.id,
        kind: JournalKind.note,
        occurredAt: daysAgoAt(1, 20, 15),
      ),
    );
    symptom = await harness.services.journal.create(
      JournalDraft(
        petId: miso.id,
        kind: JournalKind.symptom,
        occurredAt: daysAgoAt(3, 8, 30),
      ),
    );
  });

  tearDown(() async {
    await harness.dispose();
    await emptyHarness.dispose();
  });

  /// Lets the real SQLite work finish, then rebuilds the widget tree.
  Future<void> settleDatabase(WidgetTester tester) async {
    for (int attempt = 0; attempt < 6; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpJournal(WidgetTester tester, {SqliteHarness? source}) async {
    await tester.pumpWidget(
      AppScope(
        services: (source ?? harness).services,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const JournalScreen(),
        ),
      ),
    );
    await settleDatabase(tester);
  }

  Future<void> tapByKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey<String>(key)));
    await settleDatabase(tester);
  }

  Future<void> clearSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('groups the feed by day with one hairline between neighbours', (
    WidgetTester tester,
  ) async {
    await pumpJournal(tester);

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);
    expect(
      find.text(formatFullDate(daysAgoAt(3, 0, 0)).toUpperCase()),
      findsOneWidget,
    );
    expect(
      find.text('Bella · ${formatTimeOfDay(walk.occurredAt)}'),
      findsOneWidget,
    );
    expect(
      find.text('Miso · ${formatTimeOfDay(fed.occurredAt)}'),
      findsOneWidget,
    );

    final List<String> titles = tester
        .widgetList<ListRow>(find.byType(ListRow))
        .map((ListRow row) => row.title)
        .toList();
    expect(titles, <String>['Fed', 'Walk · 30 min', 'Note', 'Symptom']);

    expect(
      tester
          .getSize(find.byKey(ValueKey<String>('journal-row-${walk.id}')))
          .height,
      greaterThanOrEqualTo(60),
    );
    // Only the two neighbouring TODAY rows share a hairline.
    expect(find.byType(Divider), findsNWidgets(1));
    expect(
      find.byKey(ValueKey<String>('journal-row-${note.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('journal-row-${symptom.id}')),
      findsOneWidget,
    );
    // The pet filter is here; the quick-log chips are not.
    expect(
      find.byKey(const ValueKey<String>('journal-pet-filter-all')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('journal-pet-filter-${bella.id}')),
      findsOneWidget,
    );
  });

  testWidgets('editing a row saves the note and optional duration', (
    WidgetTester tester,
  ) async {
    await pumpJournal(tester);
    await tapByKey(tester, 'journal-row-${walk.id}');

    expect(
      find.byKey(const ValueKey<String>('journal-edit-time')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('journal-edit-note')),
      'Evening loop',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('journal-edit-duration')),
      '45',
    );
    await tester.pump();
    await tapByKey(tester, 'journal-edit-save');

    expect(find.text('Entry updated.'), findsOneWidget);
    final JournalEntry? stored = await tester.runAsync<JournalEntry?>(
      () => harness.services.journal.findById(walk.id),
    );
    expect(stored!.note, 'Evening loop');
    expect(stored.durationMinutes, 45);
    expect(find.text('Walk · 45 min'), findsOneWidget);
    await clearSnackBar(tester);
  });


  testWidgets('keeping the entry leaves it in the database', (
    WidgetTester tester,
  ) async {
    await pumpJournal(tester);
    await tapByKey(tester, 'journal-row-${fed.id}');
    await tapByKey(tester, 'journal-edit-delete');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();

    final JournalEntry? stored = await tester.runAsync<JournalEntry?>(
      () => harness.services.journal.findById(fed.id),
    );
    expect(stored, isNotNull);
  });

  testWidgets('deleting a row removes it from the feed and the database', (
    WidgetTester tester,
  ) async {
    await pumpJournal(tester);
    await tapByKey(tester, 'journal-row-${fed.id}');
    await tapByKey(tester, 'journal-edit-delete');
    // Deleting is confirmed, not a single irreversible tap.
    await tester.pumpAndSettle();
    await tapByKey(tester, 'journal-delete-confirm');

    expect(find.text('Entry deleted.'), findsOneWidget);
    expect(find.byKey(ValueKey<String>('journal-row-${fed.id}')), findsNothing);
    final JournalEntry? stored = await tester.runAsync<JournalEntry?>(
      () => harness.services.journal.findById(fed.id),
    );
    expect(stored, isNull);
    await clearSnackBar(tester);
  });

  testWidgets('an entry without a note or duration opens a clean sheet', (
    WidgetTester tester,
  ) async {
    await pumpJournal(tester);
    await tapByKey(tester, 'journal-row-${fed.id}');

    final TextField noteField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('journal-edit-note')),
    );
    expect(noteField.controller!.text, '');
    final TextField durationField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('journal-edit-duration')),
    );
    expect(durationField.controller!.text, '');
  });

  testWidgets('lays out a phone-sized feed and edit sheet without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpJournal(tester);
    expect(tester.takeException(), isNull);

    await tapByKey(tester, 'journal-row-${walk.id}');
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the empty state when nothing is logged', (
    WidgetTester tester,
  ) async {
    await pumpJournal(tester, source: emptyHarness);

    expect(find.byKey(const ValueKey<String>('journal-empty')), findsOneWidget);
    expect(find.text('No entries yet'), findsOneWidget);
  });

  testWidgets('the pet filter narrows the feed to one animal', (
    WidgetTester tester,
  ) async {
    await pumpJournal(tester);
    expect(find.textContaining('Miso ·'), findsWidgets);

    await tapByKey(tester, 'journal-pet-filter-${bella.id}');
    await tester.pumpAndSettle();
    expect(find.textContaining('Miso ·'), findsNothing);
    expect(find.textContaining('Bella ·'), findsWidgets);

    await tapByKey(tester, 'journal-pet-filter-all');
    await tester.pumpAndSettle();
    expect(find.textContaining('Miso ·'), findsWidgets);
  });

}
