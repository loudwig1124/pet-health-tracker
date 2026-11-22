/// Vet appointments and their state machine.
library;

/// Appointment state. Only `scheduled` is open; the other three are terminal.
enum AppointmentStatus {
  scheduled('scheduled', 'Scheduled'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled'),
  noShow('no_show', 'No-show');

  const AppointmentStatus(this.wire, this.label);

  final String wire;
  final String label;

  /// Terminal states never transition again.
  bool get isTerminal => this != AppointmentStatus.scheduled;

  static AppointmentStatus fromWire(String value) => values.firstWhere(
    (AppointmentStatus status) => status.wire == value,
    orElse: () => AppointmentStatus.scheduled,
  );
}

/// What the booking form submits.
class AppointmentDraft {
  const AppointmentDraft({
    this.petId,
    required this.clinicName,
    required this.purpose,
    required this.scheduledAt,
  });

  final int? petId;
  final String clinicName;
  final String purpose;
  final DateTime scheduledAt;
}

/// The persisted appointment.
class Appointment {
  const Appointment({
    required this.id,
    this.petId,
    required this.clinicName,
    required this.purpose,
    required this.scheduledAt,
    this.status = AppointmentStatus.scheduled,
    this.completedAt,
    this.cancelReason,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int? petId;
  final String clinicName;
  final String purpose;
  final DateTime scheduledAt;
  final AppointmentStatus status;
  final DateTime? completedAt;
  final String? cancelReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOpen => status == AppointmentStatus.scheduled;

  AppointmentDraft toDraft() => AppointmentDraft(
    petId: petId,
    clinicName: clinicName,
    purpose: purpose,
    scheduledAt: scheduledAt,
  );
}
