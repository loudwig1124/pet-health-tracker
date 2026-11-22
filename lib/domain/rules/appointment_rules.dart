/// Appointment state machine. Terminal states are immutable; a no-show is only
/// recordable once `scheduled_at` has passed.
library;

import '../models/appointment.dart';

/// Why a transition is not allowed.
enum AppointmentTransitionBlock {
  /// The appointment is completed, cancelled or no-show.
  alreadyTerminal('This appointment is already closed'),

  /// From and to are the same state.
  sameStatus('Already in that state'),

  /// No-show needs a scheduled time in the past.
  noShowBeforeScheduledAt(
    'A no-show can only be recorded after the appointment time',
  ),

  /// Cancelling always needs a reason.
  cancelReasonRequired('A cancellation needs a reason');

  const AppointmentTransitionBlock(this.message);

  final String message;
}

/// Result of checking one transition.
class AppointmentTransition {
  const AppointmentTransition.allowed() : block = null;

  const AppointmentTransition.blocked(this.block);

  final AppointmentTransitionBlock? block;

  bool get isAllowed => block == null;

  String? get message => block?.message;
}

/// Checks `from -> to` without mutating anything.
AppointmentTransition checkAppointmentTransition({
  required AppointmentStatus from,
  required AppointmentStatus to,
  required DateTime scheduledAt,
  required DateTime now,
  String? cancelReason,
}) {
  if (from == to) {
    return const AppointmentTransition.blocked(
      AppointmentTransitionBlock.sameStatus,
    );
  }
  if (from.isTerminal) {
    return const AppointmentTransition.blocked(
      AppointmentTransitionBlock.alreadyTerminal,
    );
  }
  if (to == AppointmentStatus.noShow && !now.isAfter(scheduledAt)) {
    return const AppointmentTransition.blocked(
      AppointmentTransitionBlock.noShowBeforeScheduledAt,
    );
  }
  if (to == AppointmentStatus.cancelled &&
      (cancelReason == null || cancelReason.trim().isEmpty)) {
    return const AppointmentTransition.blocked(
      AppointmentTransitionBlock.cancelReasonRequired,
    );
  }
  return const AppointmentTransition.allowed();
}

/// Thrown when a repository or controller attempts a blocked transition.
class AppointmentRuleException implements Exception {
  const AppointmentRuleException(this.block);

  final AppointmentTransitionBlock block;

  @override
  String toString() => 'AppointmentRuleException: ${block.message}';
}

/// Applies a transition, returning the new appointment. Throws
/// [AppointmentRuleException] when the state machine blocks it.
Appointment applyAppointmentTransition(
  Appointment appointment,
  AppointmentStatus to, {
  required DateTime now,
  String? cancelReason,
}) {
  final AppointmentTransition check = checkAppointmentTransition(
    from: appointment.status,
    to: to,
    scheduledAt: appointment.scheduledAt,
    now: now,
    cancelReason: cancelReason,
  );
  if (!check.isAllowed) {
    throw AppointmentRuleException(check.block!);
  }

  final String? trimmedReason = cancelReason?.trim();
  return Appointment(
    id: appointment.id,
    petId: appointment.petId,
    clinicName: appointment.clinicName,
    purpose: appointment.purpose,
    scheduledAt: appointment.scheduledAt,
    status: to,
    completedAt: to == AppointmentStatus.completed ? now : null,
    cancelReason: to == AppointmentStatus.cancelled ? trimmedReason : null,
    createdAt: appointment.createdAt,
    updatedAt: now,
  );
}
