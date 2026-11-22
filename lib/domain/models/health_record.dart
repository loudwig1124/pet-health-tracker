/// Clinical notes. Append-only: no update or delete path exists.
library;

/// What a health-record form submits. At least one of [condition] or
/// [diagnosis] must be non-empty (the DDL enforces the same rule).
class HealthRecordDraft {
  const HealthRecordDraft({
    required this.petId,
    required this.recordedOn,
    this.condition,
    this.diagnosis,
    this.treatment,
    this.prescribedMedication,
    this.vetName,
  });

  final int petId;
  final DateTime recordedOn;
  final String? condition;
  final String? diagnosis;
  final String? treatment;
  final String? prescribedMedication;
  final String? vetName;
}

/// An immutable clinical note.
class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.petId,
    required this.recordedOn,
    this.condition,
    this.diagnosis,
    this.treatment,
    this.prescribedMedication,
    this.vetName,
    required this.createdAt,
  });

  final int id;
  final int petId;
  final DateTime recordedOn;
  final String? condition;
  final String? diagnosis;
  final String? treatment;
  final String? prescribedMedication;
  final String? vetName;
  final DateTime createdAt;

  /// Condition when present, otherwise the diagnosis — the row title.
  String get title {
    final String conditionText = condition?.trim() ?? '';
    if (conditionText.isNotEmpty) {
      return conditionText;
    }
    return diagnosis?.trim() ?? '';
  }
}
