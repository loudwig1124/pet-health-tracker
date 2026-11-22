import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/models/appointment.dart';
import 'package:pet_health_tracker/domain/rules/appointment_rules.dart';

Appointment appointment({
  AppointmentStatus status = AppointmentStatus.scheduled,
  DateTime? scheduledAt,
  DateTime? completedAt,
  String? cancelReason,
}) {
  final DateTime created = DateTime.utc(2026, 11, 1, 9);
  return Appointment(
    id: 7,
    petId: 1,
    clinicName: 'Paws & Claws',
    purpose: 'Wellness check',
    scheduledAt: scheduledAt ?? DateTime.utc(2026, 11, 21, 14),
    status: status,
    completedAt: completedAt,
    cancelReason: cancelReason,
    createdAt: created,
    updatedAt: created,
  );
}

void main() {
  final DateTime now = DateTime.utc(2026, 11, 21, 10);

  group('checkAppointmentTransition', () {
    test('scheduled can be completed', () {
      final AppointmentTransition check = checkAppointmentTransition(
        from: AppointmentStatus.scheduled,
        to: AppointmentStatus.completed,
        scheduledAt: DateTime.utc(2026, 11, 21, 14),
        now: now,
      );
      expect(check.isAllowed, isTrue);
      expect(check.block, isNull);
    });

    test('cancelling requires a reason', () {
      final AppointmentTransition withoutReason = checkAppointmentTransition(
        from: AppointmentStatus.scheduled,
        to: AppointmentStatus.cancelled,
        scheduledAt: DateTime.utc(2026, 11, 21, 14),
        now: now,
      );
      expect(withoutReason.isAllowed, isFalse);
      expect(
        withoutReason.block,
        AppointmentTransitionBlock.cancelReasonRequired,
      );

      final AppointmentTransition blankReason = checkAppointmentTransition(
        from: AppointmentStatus.scheduled,
        to: AppointmentStatus.cancelled,
        scheduledAt: DateTime.utc(2026, 11, 21, 14),
        now: now,
        cancelReason: '   ',
      );
      expect(blankReason.isAllowed, isFalse);

      final AppointmentTransition withReason = checkAppointmentTransition(
        from: AppointmentStatus.scheduled,
        to: AppointmentStatus.cancelled,
        scheduledAt: DateTime.utc(2026, 11, 21, 14),
        now: now,
        cancelReason: 'The clinic closed',
      );
      expect(withReason.isAllowed, isTrue);
    });

    test('no-show is blocked until the appointment time has passed', () {
      final AppointmentTransition early = checkAppointmentTransition(
        from: AppointmentStatus.scheduled,
        to: AppointmentStatus.noShow,
        scheduledAt: DateTime.utc(2026, 11, 21, 14),
        now: now,
      );
      expect(early.isAllowed, isFalse);
      expect(early.block, AppointmentTransitionBlock.noShowBeforeScheduledAt);

      final AppointmentTransition atTheAppointmentTime =
          checkAppointmentTransition(
            from: AppointmentStatus.scheduled,
            to: AppointmentStatus.noShow,
            scheduledAt: DateTime.utc(2026, 11, 21, 10),
            now: now,
          );
      expect(atTheAppointmentTime.isAllowed, isFalse);

      final AppointmentTransition late = checkAppointmentTransition(
        from: AppointmentStatus.scheduled,
        to: AppointmentStatus.noShow,
        scheduledAt: DateTime.utc(2026, 11, 21, 9),
        now: now,
      );
      expect(late.isAllowed, isTrue);
    });

    test('terminal states are immutable', () {
      for (final AppointmentStatus from in <AppointmentStatus>[
        AppointmentStatus.completed,
        AppointmentStatus.cancelled,
        AppointmentStatus.noShow,
      ]) {
        for (final AppointmentStatus to in AppointmentStatus.values) {
          if (to == from) {
            continue;
          }
          final AppointmentTransition check = checkAppointmentTransition(
            from: from,
            to: to,
            scheduledAt: DateTime.utc(2026, 11, 21, 9),
            now: now,
            cancelReason: 'rescheduled',
          );
          expect(
            check.isAllowed,
            isFalse,
            reason: '$from -> $to should be blocked',
          );
          expect(check.block, AppointmentTransitionBlock.alreadyTerminal);
        }
      }
    });

    test('the same status is not a transition', () {
      for (final AppointmentStatus status in AppointmentStatus.values) {
        final AppointmentTransition check = checkAppointmentTransition(
          from: status,
          to: status,
          scheduledAt: DateTime.utc(2026, 11, 21, 9),
          now: now,
        );
        expect(check.isAllowed, isFalse);
        expect(check.block, AppointmentTransitionBlock.sameStatus);
      }
    });
  });

  group('applyAppointmentTransition', () {
    test('completing stamps completed_at and updated_at', () {
      final Appointment original = appointment();
      final Appointment completed = applyAppointmentTransition(
        original,
        AppointmentStatus.completed,
        now: now,
      );
      expect(completed.status, AppointmentStatus.completed);
      expect(completed.completedAt, now);
      expect(completed.updatedAt, now);
      expect(completed.cancelReason, isNull);
      expect(completed.scheduledAt, original.scheduledAt);
    });

    test('cancelling keeps the trimmed reason and clears completed_at', () {
      final Appointment cancelled = applyAppointmentTransition(
        appointment(),
        AppointmentStatus.cancelled,
        now: now,
        cancelReason: '  Clinic closed  ',
      );
      expect(cancelled.status, AppointmentStatus.cancelled);
      expect(cancelled.cancelReason, 'Clinic closed');
      expect(cancelled.completedAt, isNull);
    });

    test('no-show after the time is allowed', () {
      final Appointment noShow = applyAppointmentTransition(
        appointment(scheduledAt: DateTime.utc(2026, 11, 20, 14)),
        AppointmentStatus.noShow,
        now: now,
      );
      expect(noShow.status, AppointmentStatus.noShow);
      expect(noShow.completedAt, isNull);
      expect(noShow.cancelReason, isNull);
    });

    test('blocked transitions throw with the blocking reason', () {
      expect(
        () => applyAppointmentTransition(
          appointment(status: AppointmentStatus.completed, completedAt: now),
          AppointmentStatus.cancelled,
          now: now,
          cancelReason: 'nope',
        ),
        throwsA(
          isA<AppointmentRuleException>().having(
            (AppointmentRuleException error) => error.block,
            'block',
            AppointmentTransitionBlock.alreadyTerminal,
          ),
        ),
      );

      expect(
        () => applyAppointmentTransition(
          appointment(),
          AppointmentStatus.noShow,
          now: now,
        ),
        throwsA(isA<AppointmentRuleException>()),
      );
    });
  });
}
