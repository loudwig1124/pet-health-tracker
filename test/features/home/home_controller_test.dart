import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/dashboard.dart';
import 'package:pet_health_tracker/domain/models/journal_entry.dart';
import 'package:pet_health_tracker/domain/models/pet.dart';
import 'package:pet_health_tracker/features/home/home_controller.dart';

import '../../data/test_support.dart';

/// Home's writes are deliberately narrow: the quick-log chip stores the kind and
/// the current instant, and nothing else.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final DateTime fixedMorning = DateTime.utc(2026, 11, 21, 9, 30);

  test('loads the seeded household into the dashboard', () async {
    final SqliteHarness harness = await openHarness(seedDemo: true);
    addTearDown(harness.dispose);
    final HomeController controller = HomeController(harness.services);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.loadError, isNull);
    expect(controller.dashboard, isNotNull);
    expect(
      controller.dashboard!.pets.map(
        (PetOverview overview) => overview.pet.name,
      ),
      <String>['Bella', 'Miso'],
    );
    expect(controller.dashboard!.nextAppointment, isNotNull);
    expect(controller.dashboard!.recentEntries, hasLength(3));
  });

  test('quick log writes kind and occurred_at only', () async {
    final SqliteHarness harness = await openHarness(seedDemo: true);
    addTearDown(harness.dispose);
    final HomeController controller = HomeController(harness.services);
    addTearDown(controller.dispose);
    await controller.load();

    final Set<int> before = (await harness.services.journal.listHousehold(
      limit: 100,
    )).map((JournalEntry entry) => entry.id).toSet();
    final Pet bella = controller.dashboard!.pets
        .firstWhere((PetOverview overview) => overview.pet.name == 'Bella')
        .pet;

    final JournalEntry saved = await controller.quickLog(
      pet: bella,
      kind: JournalKind.walk,
    );

    final List<JournalEntry> after = await harness.services.journal
        .listHousehold(limit: 100);
    final List<JournalEntry> added = after
        .where((JournalEntry entry) => !before.contains(entry.id))
        .toList();
    expect(added, hasLength(1), reason: 'exactly one row was written');

    final JournalEntry stored = added.single;
    expect(stored.id, saved.id);
    expect(stored.petId, bella.id);
    expect(stored.kind, JournalKind.walk);
    expect(stored.occurredAt, fixedMorning);
    expect(stored.note, isNull, reason: 'no note is assumed');
    expect(stored.durationMinutes, isNull, reason: 'no duration is assumed');

    // The snapshot is refreshed, so Home can show the new row immediately.
    expect(controller.dashboard!.recentEntries, isNotEmpty);
  });

  test('undo deletes the entry the quick log just wrote', () async {
    final SqliteHarness harness = await openHarness(seedDemo: true);
    addTearDown(harness.dispose);
    final HomeController controller = HomeController(harness.services);
    addTearDown(controller.dispose);
    await controller.load();

    final Pet miso = controller.dashboard!.pets
        .firstWhere((PetOverview overview) => overview.pet.name == 'Miso')
        .pet;
    final int before = (await harness.services.journal.listHousehold(
      limit: 100,
    )).length;

    final JournalEntry saved = await controller.quickLog(
      pet: miso,
      kind: JournalKind.fed,
    );
    expect(await harness.services.journal.findById(saved.id), isNotNull);

    await controller.undo(saved);

    expect(await harness.services.journal.findById(saved.id), isNull);
    expect(
      (await harness.services.journal.listHousehold(limit: 100)).length,
      before,
    );
  });
}
