/// Vet appointments and the state machine that guards their status.
library;

import '../../domain/models/appointment.dart';

/// Result of a reschedule: the cancelled row and the new scheduled one.
class RescheduleResult {
  const RescheduleResult({required this.previous, required this.next});

  final Appointment previous;
  final Appointment next;
}

abstract class AppointmentRepository {
  /// `scheduled` appointments still in the future, soonest first.
  Future<List<Appointment>> listUpcoming({required DateTime now, int? petId});

  /// Everything else (terminal states and scheduled appointments whose time has
  /// passed), newest first.
  Future<List<Appointment>> listHistory({required DateTime now, int? petId});

  Future<Appointment?> findById(int id);

  Future<Appointment> create(AppointmentDraft draft);

  /// Applies one legal transition; blocked transitions throw
  /// `AppointmentRuleException` (see `lib/domain/rules/appointment_rules.dart`).
  Future<Appointment> updateStatus(
    int id,
    AppointmentStatus status, {
    required DateTime now,
    String? cancelReason,
  });

  /// Cancels [id] with reason "rescheduled" and books the same visit again,
  /// atomically. Leaves two rows and one cancel reason.
  Future<RescheduleResult> reschedule(
    int id, {
    required DateTime newScheduledAt,
    required DateTime now,
  });
}
