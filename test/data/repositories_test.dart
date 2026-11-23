import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/dashboard.dart';
import 'package:pet_health_tracker/data/repositories/appointment_repository.dart';
import 'package:pet_health_tracker/domain/models/appointment.dart';
import 'package:pet_health_tracker/domain/models/health_record.dart';
import 'package:pet_health_tracker/domain/models/journal_entry.dart';
import 'package:pet_health_tracker/domain/models/owner.dart';
import 'package:pet_health_tracker/domain/models/pet.dart';
import 'package:pet_health_tracker/domain/models/vaccination.dart';
import 'package:pet_health_tracker/domain/models/vaccine_type.dart';
import 'package:pet_health_tracker/domain/rules/appointment_rules.dart';
import 'package:pet_health_tracker/domain/rules/vaccination_due.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_support.dart';

PetDraft petDraft({
  String name = 'Bella',
  String species = 'Dog',
  String? breed = 'Golden Retriever mix',
  PetSex sex = PetSex.female,
  double weightKg = 12.4,
  String? microchip = '900215004123456',
}) {
  return PetDraft(
    name: name,
    species: species,
    breed: breed,
    sex: sex,
    dateOfBirth: DateTime.utc(2021, 3, 14),
    weightKg: weightKg,
    microchip: microchip,
  );
}

void main() {
  final DateTime now = fixedNow();

  group('empty household', () {
    late SqliteHarness harness;

    setUp(() async {
      harness = await openHarness();
    });

    tearDown(() async {
      await harness.dispose();
    });

    test('the owner row is created on boot and can be edited', () async {
      final Owner owner = await harness.services.owners.load();
      // An untouched household is nobody's yet.
      expect(owner.name, kDefaultOwnerName);
      expect(owner.id, 1);

      final Owner saved = await harness.services.owners.save(
        const OwnerDraft(
          name: '  Maya Reyes ',
          email: ' maya@example.com ',
          phone: ' +63 917 555 0142 ',
        ),
      );
      expect(saved.name, 'Maya Reyes');
      expect(saved.email, 'maya@example.com');
      expect(saved.phone, '+63 917 555 0142');

      final Owner reloaded = await harness.services.owners.load();
      expect(reloaded.name, 'Maya Reyes');
      expect(reloaded.email, 'maya@example.com');
    });

    test('pets round-trip through create, update, list and delete', () async {
      final Pet created = await harness.services.pets.create(petDraft());
      expect(created.id, greaterThan(0));
      expect(created.ownerId, 1);
      expect(created.dateOfBirth, DateTime.utc(2021, 3, 14));
      expect(created.sex, PetSex.female);
      expect(created.speciesLabel, 'Dog · Golden Retriever mix');

      final Pet? loaded = await harness.services.pets.findById(created.id);
      expect(loaded!.name, 'Bella');
      expect(loaded.microchip, '900215004123456');

      final Pet updated = await harness.services.pets.update(
        created.id,
        petDraft(
          name: 'Bella Rose',
          breed: null,
          microchip: null,
          weightKg: 13.1,
        ),
      );
      expect(updated.name, 'Bella Rose');
      expect(updated.breed, isNull);
      expect(updated.microchip, isNull);
      expect(updated.weightKg, 13.1);
      expect(updated.createdAt, created.createdAt);

      final List<Pet> pets = await harness.services.pets.list();
      expect(pets, hasLength(1));

      await harness.services.pets.delete(created.id);
      expect(await harness.services.pets.list(), isEmpty);
    });

    test('a duplicate microchip is rejected by the database', () async {
      await harness.services.pets.create(petDraft(name: 'Bella'));
      expect(
        () => harness.services.pets.create(petDraft(name: 'Bella 2')),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('quick journal entries save kind and time only', () async {
      final Pet pet = await harness.services.pets.create(petDraft());
      final JournalEntry entry = await harness.services.journal.create(
        JournalDraft(petId: pet.id, kind: JournalKind.walk, occurredAt: now),
      );
      expect(entry.kind, JournalKind.walk);
      expect(entry.occurredAt, now);
      expect(entry.note, isNull);
      expect(entry.durationMinutes, isNull);
      expect(entry.title, 'Walk');

      final JournalEntry withDuration = await harness.services.journal.create(
        JournalDraft(
          petId: pet.id,
          kind: JournalKind.walk,
          occurredAt: now.subtract(const Duration(hours: 2)),
          durationMinutes: 30,
          note: 'Morning loop',
        ),
      );
      expect(withDuration.title, 'Walk · 30 min');

      final List<JournalEntry> feed = await harness.services.journal
          .listHousehold();
      expect(feed.map((JournalEntry entry) => entry.id), <int>[
        entry.id,
        withDuration.id,
      ]);
      expect(await harness.services.journal.listForPet(pet.id), hasLength(2));

      final JournalEntry edited = await harness.services.journal.update(
        withDuration.id,
        JournalDraft(
          petId: pet.id,
          kind: JournalKind.training,
          occurredAt: now.subtract(const Duration(hours: 3)),
          note: 'Recall practice',
          durationMinutes: 10,
        ),
      );
      expect(edited.kind, JournalKind.training);
      expect(edited.note, 'Recall practice');
      expect(edited.durationMinutes, 10);

      await harness.services.journal.delete(entry.id);
      expect(await harness.services.journal.listHousehold(), hasLength(1));
    });

    test(
      'journal entries with a non-positive duration store no duration',
      () async {
        final Pet pet = await harness.services.pets.create(petDraft());
        final JournalEntry entry = await harness.services.journal.create(
          JournalDraft(
            petId: pet.id,
            kind: JournalKind.meds,
            occurredAt: now,
            durationMinutes: 0,
          ),
        );
        expect(entry.durationMinutes, isNull);
        expect(entry.title, 'Meds');
      },
    );

    test(
      'clinical notes append newest first and prefer the condition title',
      () async {
        final Pet pet = await harness.services.pets.create(petDraft());
        await harness.services.healthRecords.append(
          HealthRecordDraft(
            petId: pet.id,
            recordedOn: DateTime.utc(2026, 10, 1),
            condition: 'Routine exam',
            vetName: 'Dr. Cruz',
          ),
        );
        final HealthRecord latest = await harness.services.healthRecords.append(
          HealthRecordDraft(
            petId: pet.id,
            recordedOn: DateTime.utc(2026, 11, 1),
            diagnosis: 'Bacterial ear infection',
            treatment: 'Ear cleaning',
          ),
        );
        expect(latest.title, 'Bacterial ear infection');
        expect(latest.condition, isNull);

        final List<HealthRecord> records = await harness.services.healthRecords
            .listForPet(pet.id);
        expect(records.map((HealthRecord record) => record.title), <String>[
          'Bacterial ear infection',
          'Routine exam',
        ]);
      },
    );

    test(
      'a clinical note without a condition or diagnosis is refused',
      () async {
        final Pet pet = await harness.services.pets.create(petDraft());
        expect(
          () => harness.services.healthRecords.append(
            HealthRecordDraft(
              petId: pet.id,
              recordedOn: DateTime.utc(2026, 11, 1),
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test(
      'vaccinations round-trip and refuse a due date before the dose',
      () async {
        final Pet pet = await harness.services.pets.create(petDraft());
        final Vaccination vaccination = await harness.services.vaccinations
            .append(
              VaccinationDraft(
                petId: pet.id,
                vaccineTypeId: 1,
                vaccineName: 'Rabies',
                vaccinationDate: DateTime.utc(2026, 1, 10),
                nextDueDate: DateTime.utc(2027, 1, 10),
                vetName: 'Dr. Cruz',
              ),
            );
        expect(vaccination.nextDueDate, DateTime.utc(2027, 1, 10));
        expect(vaccination.vaccineName, 'Rabies');

        final List<Vaccination> doses = await harness.services.vaccinations
            .listForPet(pet.id);
        expect(doses, hasLength(1));

        expect(
          () => harness.services.vaccinations.append(
            VaccinationDraft(
              petId: pet.id,
              vaccineName: 'Rabies',
              vaccinationDate: DateTime.utc(2026, 1, 10),
              nextDueDate: DateTime.utc(2026, 1, 10),
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('the vaccine catalog is seeded, core vaccines first', () async {
      final List<String> names = (await harness.services.vaccineTypes.list())
          .map((VaccineType type) => type.name)
          .toList();
      expect(names, hasLength(7));
      expect(names.take(3), <String>['Rabies', 'DHPP', 'FVRCP']);
      expect(names, contains('FeLV'));
    });

    test('appointments split into upcoming and history', () async {
      final Pet pet = await harness.services.pets.create(petDraft());
      final Appointment upcoming = await harness.services.appointments.create(
        AppointmentDraft(
          petId: pet.id,
          clinicName: 'Paws & Claws',
          purpose: 'Wellness check',
          scheduledAt: now.add(const Duration(days: 5)),
        ),
      );
      expect(upcoming.status, AppointmentStatus.scheduled);

      final Appointment past = await harness.services.appointments.create(
        AppointmentDraft(
          petId: pet.id,
          clinicName: 'Paws & Claws',
          purpose: 'Dental cleaning',
          scheduledAt: now.subtract(const Duration(days: 10)),
        ),
      );

      expect(
        (await harness.services.appointments.listUpcoming(now: now))
            .map((Appointment appointment) => appointment.id),
        <int>[upcoming.id],
      );
      expect(
        (await harness.services.appointments.listHistory(now: now))
            .map((Appointment appointment) => appointment.id),
        contains(past.id),
      );
    });

    test('completing an appointment is terminal and immutable', () async {
      final Appointment appointment = await harness.services.appointments
          .create(
            AppointmentDraft(
              clinicName: 'Paws & Claws',
              purpose: 'Wellness check',
              scheduledAt: now.add(const Duration(days: 1)),
            ),
          );
      final Appointment completed = await harness.services.appointments
          .updateStatus(appointment.id, AppointmentStatus.completed, now: now);
      expect(completed.completedAt, now);
      expect(completed.status, AppointmentStatus.completed);

      expect(
        () => harness.services.appointments.updateStatus(
          appointment.id,
          AppointmentStatus.cancelled,
          now: now.add(const Duration(hours: 1)),
          cancelReason: 'changed my mind',
        ),
        throwsA(
          isA<AppointmentRuleException>().having(
            (AppointmentRuleException exception) => exception.block,
            'block',
            AppointmentTransitionBlock.alreadyTerminal,
          ),
        ),
      );
    });

    test(
      'cancelling needs a reason; no-show needs a past appointment time',
      () async {
        final Appointment future = await harness.services.appointments.create(
          AppointmentDraft(
            clinicName: 'Paws & Claws',
            purpose: 'Wellness check',
            scheduledAt: now.add(const Duration(days: 2)),
          ),
        );
        expect(
          () => harness.services.appointments.updateStatus(
            future.id,
            AppointmentStatus.cancelled,
            now: now,
          ),
          throwsA(
            isA<AppointmentRuleException>().having(
              (AppointmentRuleException exception) => exception.block,
              'block',
              AppointmentTransitionBlock.cancelReasonRequired,
            ),
          ),
        );

        final Appointment cancelled = await harness.services.appointments
            .updateStatus(
              future.id,
              AppointmentStatus.cancelled,
              now: now,
              cancelReason: 'Clinic closed',
            );
        expect(cancelled.cancelReason, 'Clinic closed');

        final Appointment past = await harness.services.appointments.create(
          AppointmentDraft(
            clinicName: 'Paws & Claws',
            purpose: 'Missing visit',
            scheduledAt: now.subtract(const Duration(days: 1)),
          ),
        );
        final Appointment noShow = await harness.services.appointments
            .updateStatus(past.id, AppointmentStatus.noShow, now: now);
        expect(noShow.status, AppointmentStatus.noShow);
      },
    );

    test('no-show is blocked before the appointment time', () async {
      final Appointment future = await harness.services.appointments.create(
        AppointmentDraft(
          clinicName: 'Paws & Claws',
          purpose: 'Wellness check',
          scheduledAt: now.add(const Duration(hours: 4)),
        ),
      );
      expect(
        () => harness.services.appointments.updateStatus(
          future.id,
          AppointmentStatus.noShow,
          now: now,
        ),
        throwsA(
          isA<AppointmentRuleException>().having(
            (AppointmentRuleException exception) => exception.block,
            'block',
            AppointmentTransitionBlock.noShowBeforeScheduledAt,
          ),
        ),
      );
    });

    test('rescheduling leaves two rows and one "rescheduled" reason', () async {
      final Appointment original = await harness.services.appointments.create(
        AppointmentDraft(
          clinicName: 'Paws & Claws',
          purpose: 'Wellness check',
          scheduledAt: now.add(const Duration(days: 3)),
        ),
      );
      final RescheduleResult result = await harness.services.appointments
          .reschedule(
            original.id,
            newScheduledAt: now.add(const Duration(days: 10)),
            now: now,
          );

      expect(result.previous.status, AppointmentStatus.cancelled);
      expect(result.previous.cancelReason, 'rescheduled');
      expect(result.next.status, AppointmentStatus.scheduled);
      expect(result.next.scheduledAt, now.add(const Duration(days: 10)));
      expect(
        (await harness.services.appointments.listUpcoming(now: now))
            .map((Appointment appointment) => appointment.id),
        <int>[result.next.id],
      );
      final List<Appointment> history = await harness.services.appointments
          .listHistory(now: now);
      expect(history, hasLength(1));
      expect(history.single.cancelReason, 'rescheduled');
    });

    test('an empty household yields an empty dashboard snapshot', () async {
      final Dashboard dashboard = await harness.services.loadDashboard();
      expect(dashboard.owner.name, kDefaultOwnerName);
      expect(dashboard.pets, isEmpty);
      expect(dashboard.isEmpty, isTrue);
      expect(dashboard.nextAppointment, isNull);
      expect(dashboard.recentEntries, isEmpty);
    });
  });

  group('seeded demo household', () {
    late SqliteHarness harness;

    setUp(() async {
      harness = await openHarness(seedDemo: true);
    });

    tearDown(() async {
      await harness.dispose();
    });

    test('the two demo pets are present and ordered by name', () async {
      final List<Pet> pets = await harness.services.pets.list();
      expect(pets.map((Pet pet) => pet.name), <String>['Bella', 'Miso']);
      expect(pets.first.speciesLabel, 'Dog · Golden Retriever mix');
      expect(await harness.services.sampleData.hasDemoData(), isTrue);
    });

    test(
      'dashboard carries due status, next appointment and recent entries',
      () async {
        final Dashboard dashboard = await harness.services.loadDashboard();
        expect(dashboard.pets, hasLength(2));

        final PetOverview bella = dashboard.pets.first;
        expect(bella.pet.name, 'Bella');
        expect(bella.dueStatus, VaccinationDueStatus.overdue);
        expect(bella.nextVaccination!.vaccineName, 'Rabies');
        expect(bella.nextAppointment!.purpose, 'Annual wellness check');
        expect(bella.lastVisit, isNotNull);

        final PetOverview miso = dashboard.pets.last;
        expect(miso.pet.name, 'Miso');
        expect(miso.dueStatus, VaccinationDueStatus.dueSoon);
        expect(miso.nextVaccination!.vaccineName, 'FeLV');
        expect(miso.nextAppointment, isNull);
        expect(miso.lastVisit, isNotNull);

        expect(dashboard.nextAppointment!.purpose, 'Annual wellness check');
        expect(dashboard.recentEntries, hasLength(3));
        expect(
          dashboard.recentEntries.first.occurredAt.isAfter(
            dashboard.recentEntries.last.occurredAt,
          ),
          isTrue,
        );
      },
    );

    test('the due-soon window comes from the dashboard call', () async {
      final Dashboard narrow = await harness.services.dashboard.load(
        now: now,
        dueSoonWindowDays: 0,
      );
      final PetOverview miso = narrow.pets.last;
      expect(miso.dueStatus, VaccinationDueStatus.upToDate);
    });

    test('bootstrapping again does not duplicate demo rows', () async {
      await harness.services.bootstrap();
      expect(await harness.services.pets.list(), hasLength(2));
    });

    test(
      'turning sample data off clears demo rows but keeps the household',
      () async {
        await harness.services.setSampleDataEnabled(false);

        expect(await harness.services.pets.list(), isEmpty);
        expect(await harness.services.sampleData.hasDemoData(), isFalse);
        expect((await harness.services.owners.load()).name, 'Maria Santos');
        expect(await harness.services.vaccineTypes.list(), hasLength(7));
        expect(harness.services.settings.sampleDataEnabled, isFalse);
        expect(
          (await harness.services.appointments.listHistory(now: now)),
          isEmpty,
        );

        await harness.services.setSampleDataEnabled(true);
        expect(await harness.services.pets.list(), hasLength(2));
        expect(harness.services.settings.sampleDataEnabled, isTrue);
      },
    );
  });

  test('the same urgent day lists every pet booked on it', () async {
    final SqliteHarness harness = await openHarness(inMemory: true);
    addTearDown(harness.dispose);
    final Pet miss = await harness.services.pets.create(
      PetDraft(
        name: 'Miso',
        species: 'Cat',
        sex: PetSex.female,
        dateOfBirth: DateTime.utc(2022, 7, 1),
        weightKg: 4.2,
      ),
    );
    final Pet chew = await harness.services.pets.create(
      PetDraft(
        name: 'Chewy',
        species: 'Dog',
        sex: PetSex.male,
        dateOfBirth: DateTime.utc(2020, 2, 2),
        weightKg: 9.1,
      ),
    );
    final DateTime today = harness.services.today();
    final DateTime sameDay = today.add(const Duration(days: 2));

    await harness.services.appointments.create(
      AppointmentDraft(
        petId: miss.id,
        clinicName: 'A',
        purpose: 'Booster',
        scheduledAt: sameDay.add(const Duration(hours: 9)),
      ),
    );
    await harness.services.appointments.create(
      AppointmentDraft(
        petId: chew.id,
        clinicName: 'B',
        purpose: 'Check-up',
        scheduledAt: sameDay.add(const Duration(hours: 14)),
      ),
    );
    // A later day must not join the urgent list.
    await harness.services.appointments.create(
      AppointmentDraft(
        petId: miss.id,
        clinicName: 'C',
        purpose: 'Later',
        scheduledAt: sameDay.add(const Duration(days: 3)),
      ),
    );

    final Dashboard dashboard = await harness.services.loadDashboard();
    expect(dashboard.nextAppointments, hasLength(2));
    expect(
      dashboard.nextAppointments.map((Appointment a) => a.petId),
      containsAll(<int>[miss.id, chew.id]),
    );
  });

}
