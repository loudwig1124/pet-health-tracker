import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/repositories/appointment_repository.dart';
import 'package:pet_health_tracker/domain/models/appointment.dart';
import 'package:pet_health_tracker/domain/models/pet.dart';
import 'package:pet_health_tracker/domain/rules/appointment_rules.dart';
import 'package:pet_health_tracker/features/appointments/appointments_controller.dart';

import '../../data/test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SqliteHarness harness;
  late Pet bella;
  late Pet miso;
  late Appointment futureVisit;
  late Appointment misoVisit;
  late Appointment pastScheduled;
  late Appointment completedVisit;
  late Appointment cancelledVisit;
  late Appointment noShowVisit;

  final DateTime now = fixedNow();

  Future<Appointment> createVisit({
    int? petId,
    required String clinic,
    required String purpose,
    required DateTime scheduledAt,
  }) {
    return harness.services.appointments.create(
      AppointmentDraft(
        petId: petId,
        clinicName: clinic,
        purpose: purpose,
        scheduledAt: scheduledAt,
      ),
    );
  }

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

    futureVisit = await createVisit(
      petId: bella.id,
      clinic: 'Paws & Claws',
      purpose: 'Annual wellness check',
      scheduledAt: now.add(const Duration(days: 5)),
    );
    misoVisit = await createVisit(
      petId: miso.id,
      clinic: 'City Vet',
      purpose: 'FeLV booster',
      scheduledAt: now.add(const Duration(days: 6)),
    );
    pastScheduled = await createVisit(
      petId: bella.id,
      clinic: 'Paws & Claws',
      purpose: 'Dental cleaning',
      scheduledAt: now.subtract(const Duration(hours: 2)),
    );

    final Appointment completedDraft = await createVisit(
      petId: miso.id,
      clinic: 'Paws & Claws',
      purpose: 'Annual exam',
      scheduledAt: now.subtract(const Duration(days: 3)),
    );
    completedVisit = await harness.services.appointments.updateStatus(
      completedDraft.id,
      AppointmentStatus.completed,
      now: now,
    );

    final Appointment cancelledDraft = await createVisit(
      petId: bella.id,
      clinic: 'City Vet',
      purpose: 'Grooming consult',
      scheduledAt: now.subtract(const Duration(days: 4)),
    );
    cancelledVisit = await harness.services.appointments.updateStatus(
      cancelledDraft.id,
      AppointmentStatus.cancelled,
      now: now,
      cancelReason: 'Clinic closed',
    );

    final Appointment noShowDraft = await createVisit(
      petId: miso.id,
      clinic: 'Paws & Claws',
      purpose: 'Dental follow-up',
      scheduledAt: now.subtract(const Duration(days: 5)),
    );
    noShowVisit = await harness.services.appointments.updateStatus(
      noShowDraft.id,
      AppointmentStatus.noShow,
      now: now,
    );
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('loads the upcoming tab by default and splits history', () async {
    final AppointmentsController controller = AppointmentsController(
      harness.services,
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.tab, AppointmentsTab.upcoming);
    expect(controller.isLoading, isFalse);
    expect(controller.loadError, isNull);
    expect(
      controller.appointments.map((Appointment item) => item.id).toList(),
      <int>[futureVisit.id, misoVisit.id],
    );

    await controller.selectTab(AppointmentsTab.past);

    expect(controller.tab, AppointmentsTab.past);
    expect(
      controller.appointments.map((Appointment item) => item.id).toList(),
      <int>[
        pastScheduled.id,
        completedVisit.id,
        cancelledVisit.id,
        noShowVisit.id,
      ],
    );
  });

  test('the pet filter narrows both tabs', () async {
    final AppointmentsController controller = AppointmentsController(
      harness.services,
    );
    addTearDown(controller.dispose);
    await controller.load();

    await controller.selectPet(bella.id);
    expect(controller.petFilterId, bella.id);
    expect(
      controller.appointments.map((Appointment item) => item.id).toList(),
      <int>[futureVisit.id],
    );

    await controller.selectPet(miso.id);
    expect(
      controller.appointments.map((Appointment item) => item.id).toList(),
      <int>[misoVisit.id],
    );

    await controller.selectPet(null);
    expect(controller.petFilterId, isNull);
    expect(controller.appointments, hasLength(2));
  });

  test('pet labels fall back to the household', () async {
    final AppointmentsController controller = AppointmentsController(
      harness.services,
    );
    addTearDown(controller.dispose);
    await controller.load();

    expect(controller.petLabelFor(null), 'Household');
    expect(controller.petLabelFor(bella.id), 'Bella');
    expect(controller.petLabelFor(miso.id), 'Miso');
  });

  test('available transitions follow the state machine', () async {
    final AppointmentsController controller = AppointmentsController(
      harness.services,
    );
    addTearDown(controller.dispose);
    await controller.load();

    expect(controller.availableTransitions(futureVisit), <AppointmentStatus>[
      AppointmentStatus.completed,
      AppointmentStatus.cancelled,
    ]);
    expect(controller.availableTransitions(pastScheduled), <AppointmentStatus>[
      AppointmentStatus.completed,
      AppointmentStatus.cancelled,
      AppointmentStatus.noShow,
    ]);
    for (final Appointment terminal in <Appointment>[
      completedVisit,
      cancelledVisit,
      noShowVisit,
    ]) {
      expect(controller.availableTransitions(terminal), isEmpty);
    }
  });

  test('completing a visit moves it from Upcoming to Past', () async {
    final AppointmentsController controller = AppointmentsController(
      harness.services,
    );
    addTearDown(controller.dispose);
    await controller.load();

    final Appointment completed = await controller.complete(futureVisit.id);

    expect(completed.status, AppointmentStatus.completed);
    expect(completed.completedAt, now);
    expect(
      controller.appointments.any(
        (Appointment item) => item.id == futureVisit.id,
      ),
      isFalse,
    );
    expect(controller.availableTransitions(completed), isEmpty);

    await controller.selectTab(AppointmentsTab.past);
    expect(
      controller.appointments.any(
        (Appointment item) => item.id == futureVisit.id,
      ),
      isTrue,
    );
  });

  test('a blocked no-show throws and leaves the row scheduled', () async {
    final AppointmentsController controller = AppointmentsController(
      harness.services,
    );
    addTearDown(controller.dispose);
    await controller.load();

    await expectLater(
      controller.markNoShow(futureVisit.id),
      throwsA(
        isA<AppointmentRuleException>().having(
          (AppointmentRuleException error) => error.block,
          'block',
          AppointmentTransitionBlock.noShowBeforeScheduledAt,
        ),
      ),
    );
    final Appointment? stored = await harness.services.appointments.findById(
      futureVisit.id,
    );
    expect(stored!.status, AppointmentStatus.scheduled);
  });

  test('cancelling needs a reason and stores it', () async {
    final AppointmentsController controller = AppointmentsController(
      harness.services,
    );
    addTearDown(controller.dispose);
    await controller.load();

    await expectLater(
      controller.cancel(futureVisit.id, '   '),
      throwsA(
        isA<AppointmentRuleException>().having(
          (AppointmentRuleException error) => error.block,
          'block',
          AppointmentTransitionBlock.cancelReasonRequired,
        ),
      ),
    );

    final Appointment cancelled = await controller.cancel(
      futureVisit.id,
      ' Pet unwell ',
    );
    expect(cancelled.status, AppointmentStatus.cancelled);
    expect(cancelled.cancelReason, 'Pet unwell');
  });

  test('terminal appointments reject every further transition', () async {
    final AppointmentsController controller = AppointmentsController(
      harness.services,
    );
    addTearDown(controller.dispose);
    await controller.load();

    final Matcher blocked = throwsA(
      isA<AppointmentRuleException>().having(
        (AppointmentRuleException error) => error.block,
        'block',
        AppointmentTransitionBlock.alreadyTerminal,
      ),
    );
    // Completing an already-completed row reports "same status".
    await expectLater(
      controller.complete(completedVisit.id),
      throwsA(
        isA<AppointmentRuleException>().having(
          (AppointmentRuleException error) => error.block,
          'block',
          AppointmentTransitionBlock.sameStatus,
        ),
      ),
      reason: 'completed cannot be completed again',
    );
    await expectLater(
      controller.cancel(completedVisit.id, 'Too late'),
      blocked,
      reason: 'completed cannot be cancelled',
    );
    await expectLater(
      controller.markNoShow(completedVisit.id),
      blocked,
      reason: 'completed cannot become a no-show',
    );
    // Rescheduling first cancels the old row, so a cancelled row reports the
    // already-cancelled state instead of a repeat transition.
    await expectLater(
      controller.reschedule(
        cancelledVisit.id,
        newScheduledAt: now.add(const Duration(days: 14)),
      ),
      throwsA(
        isA<AppointmentRuleException>().having(
          (AppointmentRuleException error) => error.block,
          'block',
          AppointmentTransitionBlock.sameStatus,
        ),
      ),
      reason: 'cancelled visits cannot be rescheduled',
    );
  });

  test('rescheduling leaves two rows and one "rescheduled" reason', () async {
    final AppointmentsController controller = AppointmentsController(
      harness.services,
    );
    addTearDown(controller.dispose);
    await controller.load();

    final DateTime newScheduledAt = now.add(const Duration(days: 10));
    final RescheduleResult result = await controller.reschedule(
      futureVisit.id,
      newScheduledAt: newScheduledAt,
    );

    expect(result.previous.status, AppointmentStatus.cancelled);
    expect(result.previous.cancelReason, 'rescheduled');
    expect(result.next.status, AppointmentStatus.scheduled);
    expect(result.next.scheduledAt, newScheduledAt);
    expect(result.next.id, isNot(result.previous.id));

    expect(
      controller.appointments.map((Appointment item) => item.id).toList(),
      <int>[misoVisit.id, result.next.id],
    );

    final List<Map<String, Object?>> rows = await harness.db.query(
      'appointment',
    );
    expect(rows, hasLength(7));
    expect(
      rows.where(
        (Map<String, Object?> row) => row['cancel_reason'] == 'rescheduled',
      ),
      hasLength(1),
    );
  });
}
