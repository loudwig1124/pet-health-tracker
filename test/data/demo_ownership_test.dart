/// The sample household owns exact rows, not an id range: turning it off must
/// never touch anything the owner typed.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/models/journal_entry.dart';
import 'package:pet_health_tracker/domain/models/pet.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('clearing the demo keeps the owner\'s own pet and its records', () async {
    final SqliteHarness harness = await openHarness(
      seedDemo: true,
      inMemory: true,
    );
    addTearDown(harness.dispose);

    final Pet coco = await harness.services.pets.create(
      PetDraft(
        name: 'Coco',
        species: 'Dog',
        sex: PetSex.female,
        dateOfBirth: DateTime.utc(2023, 5, 1),
        weightKg: 8.5,
      ),
    );
    await harness.services.journal.create(
      JournalDraft(
        petId: coco.id,
        kind: JournalKind.fed,
        occurredAt: harness.services.now(),
      ),
    );
    // AUTOINCREMENT keeps counting past the demo ids, which is exactly why the
    // "id >= 9000" range could not tell the owner's rows from the demo's.
    expect(coco.id, greaterThanOrEqualTo(9000));

    await harness.services.setSampleDataEnabled(false);

    final List<Pet> pets = await harness.services.pets.list();
    expect(pets.map((Pet pet) => pet.name), <String>['Coco']);
    final List<JournalEntry> entries = await harness.services.journal
        .listHousehold(limit: 100);
    expect(entries, hasLength(1));
    expect(entries.single.petId, coco.id);
  });

  test('clearing the demo removes every demo row', () async {
    final SqliteHarness harness = await openHarness(
      seedDemo: true,
      inMemory: true,
    );
    addTearDown(harness.dispose);
    expect(await harness.services.sampleData.hasDemoData(), isTrue);

    await harness.services.setSampleDataEnabled(false);

    expect(await harness.services.pets.list(), isEmpty);
    expect(await harness.services.sampleData.hasDemoData(), isFalse);
    expect(await harness.services.journal.listHousehold(limit: 100), isEmpty);
    expect(
      await harness.services.appointments.listUpcoming(
        now: harness.services.now(),
      ),
      isEmpty,
    );
  });
}
