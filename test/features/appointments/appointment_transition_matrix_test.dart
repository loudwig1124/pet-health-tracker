/// The full appointment transition matrix, exercised through the repository
/// (the layer the UI's actions end up in).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/repositories/appointment_repository.dart';
import 'package:pet_health_tracker/domain/models/appointment.dart';
import 'package:pet_health_tracker/domain/rules/appointment_rules.dart';

import '../../data/test_support.dart';

/// Creates an appointment already sitting in [status]. Scheduled and no-show
/// rows use a past time so the "after scheduled_at" rule can be observed as
/// allowed; completed/cancelled rows use a future time (the time is irrelevant
/// once terminal).
Future<Appointment> seedInStatus(
  SqliteHarness harness,
  AppointmentStatus status,
) async {
  final DateTime now = harness.services.now();
  final bool pastTime =
      status == AppointmentStatus.scheduled ||
      status == AppointmentStatus.noShow;
  final Appointment created = await harness.services.appointments.create(
    AppointmentDraft(
      clinicName: 'Paws & Claws',
      purpose: 'Wellness check',
      scheduledAt: pastTime
          ? now.subtract(const Duration(hours: 2))
          : now.add(const Duration(days: 2)),
    ),
  );
  return switch (status) {
    AppointmentStatus.scheduled => created,
    AppointmentStatus.completed =>
      await harness.services.appointments.updateStatus(
        created.id,
        AppointmentStatus.completed,
        now: now,
      ),
    AppointmentStatus.cancelled =>
      await harness.services.appointments.updateStatus(
        created.id,
        AppointmentStatus.cancelled,
        now: now,
        cancelReason: 'Clinic closed',
      ),
    AppointmentStatus.noShow =>
      await harness.services.appointments.updateStatus(
        created.id,
        AppointmentStatus.noShow,
        now: now,
      ),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SqliteHarness harness;

  setUpAll(() async {
    harness = await openHarness(inMemory: true);
  });

  tearDownAll(() async {
    await harness.dispose();
  });

  /// Expected block for every `from -> to` pair. `null` means allowed.
  const Map<String, AppointmentTransitionBlock?> expectedBlocks =
      <String, AppointmentTransitionBlock?>{
        'scheduled->scheduled': AppointmentTransitionBlock.sameStatus,
        'scheduled->completed': null,
        'scheduled->cancelled': null,
        'scheduled->no_show': null,
        'completed->scheduled': AppointmentTransitionBlock.alreadyTerminal,
        'completed->completed': AppointmentTransitionBlock.sameStatus,
        'completed->cancelled': AppointmentTransitionBlock.alreadyTerminal,
        'completed->no_show': AppointmentTransitionBlock.alreadyTerminal,
        'cancelled->scheduled': AppointmentTransitionBlock.alreadyTerminal,
        'cancelled->completed': AppointmentTransitionBlock.alreadyTerminal,
        'cancelled->cancelled': AppointmentTransitionBlock.sameStatus,
        'cancelled->no_show': AppointmentTransitionBlock.alreadyTerminal,
        'no_show->scheduled': AppointmentTransitionBlock.alreadyTerminal,
        'no_show->completed': AppointmentTransitionBlock.alreadyTerminal,
        'no_show->cancelled': AppointmentTransitionBlock.alreadyTerminal,
        'no_show->no_show': AppointmentTransitionBlock.sameStatus,
      };

  group('transition matrix', () {
    for (final AppointmentStatus from in AppointmentStatus.values) {
      for (final AppointmentStatus to in AppointmentStatus.values) {
        test('${from.wire} -> ${to.wire}', () async {
          final Appointment seeded = await seedInStatus(harness, from);
          AppointmentTransitionBlock? actualBlock;
          Appointment? updated;
          try {
            updated = await harness.services.appointments.updateStatus(
              seeded.id,
              to,
              now: harness.services.now(),
              cancelReason: 'Clinic closed',
            );
          } on AppointmentRuleException catch (error) {
            actualBlock = error.block;
          }

          final String pair = '${from.wire}->${to.wire}';
          expect(actualBlock, expectedBlocks[pair]);

          final Appointment stored = (await harness.services.appointments
              .findById(seeded.id))!;
          if (expectedBlocks[pair] == null) {
            expect(updated, isNotNull);
            expect(updated!.status, to);
            expect(stored.status, to);
            if (to == AppointmentStatus.completed) {
              expect(stored.completedAt, isNotNull);
            }
          } else {
            expect(updated, isNull);
            expect(
              stored.status,
              from,
              reason: 'blocked transitions are no-ops',
            );
          }
        });
      }
    }
  });

  group('guard rails', () {
    test('a no-show before the scheduled time is blocked', () async {
      final DateTime now = harness.services.now();
      final Appointment future = await harness.services.appointments.create(
        AppointmentDraft(
          clinicName: 'Paws & Claws',
          purpose: 'Wellness check',
          scheduledAt: now.add(const Duration(hours: 4)),
        ),
      );

      await expectLater(
        harness.services.appointments.updateStatus(
          future.id,
          AppointmentStatus.noShow,
          now: now,
        ),
        throwsA(
          isA<AppointmentRuleException>().having(
            (AppointmentRuleException error) => error.block,
            'block',
            AppointmentTransitionBlock.noShowBeforeScheduledAt,
          ),
        ),
      );
    });

    test('cancelling without a reason is blocked', () async {
      final Appointment future = await harness.services.appointments.create(
        AppointmentDraft(
          clinicName: 'Paws & Claws',
          purpose: 'Wellness check',
          scheduledAt: harness.services.now().add(const Duration(days: 2)),
        ),
      );

      for (final String? reason in <String?>[null, '', '   ']) {
        await expectLater(
          harness.services.appointments.updateStatus(
            future.id,
            AppointmentStatus.cancelled,
            now: harness.services.now(),
            cancelReason: reason,
          ),
          throwsA(
            isA<AppointmentRuleException>().having(
              (AppointmentRuleException error) => error.block,
              'block',
              AppointmentTransitionBlock.cancelReasonRequired,
            ),
          ),
        );
      }
    });

    test('a reschedule leaves two rows and one "rescheduled" reason', () async {
      final DateTime now = harness.services.now();
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

      expect(result.previous.id, original.id);
      expect(result.previous.status, AppointmentStatus.cancelled);
      expect(result.previous.cancelReason, 'rescheduled');
      expect(result.next.id, isNot(original.id));
      expect(result.next.status, AppointmentStatus.scheduled);

      final List<Map<String, Object?>> rows = await harness.db.query(
        'appointment',
        where: 'id IN (?, ?)',
        whereArgs: <Object?>[result.previous.id, result.next.id],
      );
      expect(rows, hasLength(2));
      expect(
        rows.where(
          (Map<String, Object?> row) => row['cancel_reason'] == 'rescheduled',
        ),
        hasLength(1),
      );
      expect(
        rows.where((Map<String, Object?> row) => row['status'] == 'scheduled'),
        hasLength(1),
      );
    });
  });
}
