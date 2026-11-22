import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/models/journal_entry.dart';
import 'package:pet_health_tracker/domain/models/pet.dart';
import 'package:pet_health_tracker/features/journal/journal_controller.dart';

import '../../data/test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SqliteHarness harness;
  late Pet bella;
  late Pet miso;
  late JournalEntry walk;
  late JournalEntry fed;
  late JournalEntry older;

  final DateTime now = fixedNow();
  final DateTime local = now.toLocal();

  DateTime todayAt(int hour, int minute) =>
      DateTime(local.year, local.month, local.day, hour, minute);

  setUp(() async {
    harness = await openHarness(inMemory: true);
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
    older = await harness.services.journal.create(
      JournalDraft(
        petId: bella.id,
        kind: JournalKind.note,
        occurredAt: DateTime(local.year, local.month, local.day - 3, 10, 0),
      ),
    );
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('loads the household feed newest first and maps pet names', () async {
    final JournalController controller = JournalController(harness.services);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.isLoading, isFalse);
    expect(controller.loadError, isNull);
    expect(
      controller.entries.map((JournalEntry entry) => entry.id).toList(),
      <int>[fed.id, walk.id, older.id],
    );
    expect(controller.petNameFor(bella.id), 'Bella');
    expect(controller.petNameFor(miso.id), 'Miso');
    expect(controller.localToday, DateTime(local.year, local.month, local.day));
  });

  test('updating an entry persists it and refreshes the feed', () async {
    final JournalController controller = JournalController(harness.services);
    addTearDown(controller.dispose);
    await controller.load();

    final DateTime movedTo = todayAt(18, 45);
    final JournalEntry updated = await controller.updateEntry(
      walk.id,
      JournalDraft(
        petId: bella.id,
        kind: JournalKind.walk,
        occurredAt: movedTo,
        note: '  Evening loop  ',
        durationMinutes: 45,
      ),
    );

    expect(updated.note, 'Evening loop');
    expect(updated.durationMinutes, 45);
    expect(updated.occurredAt, movedTo.toUtc());
    final JournalEntry? stored = await harness.services.journal.findById(
      walk.id,
    );
    expect(stored!.note, 'Evening loop');
    expect(stored.durationMinutes, 45);
    expect(
      controller.entries
          .firstWhere((JournalEntry entry) => entry.id == walk.id)
          .note,
      'Evening loop',
    );
    // Moved to 18:45, so it is now the newest entry of the day.
    expect(controller.entries.first.id, walk.id);
  });

  test('deleting an entry removes it from the feed and the database', () async {
    final JournalController controller = JournalController(harness.services);
    addTearDown(controller.dispose);
    await controller.load();

    await controller.deleteEntry(fed.id);

    expect(await harness.services.journal.findById(fed.id), isNull);
    expect(
      controller.entries.any((JournalEntry entry) => entry.id == fed.id),
      isFalse,
    );
    expect(controller.entries, hasLength(2));
  });
}
