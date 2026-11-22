/// A vaccination dose and its next due date.
library;

/// What a vaccination form submits.
class VaccinationDraft {
  const VaccinationDraft({
    required this.petId,
    this.vaccineTypeId,
    required this.vaccineName,
    required this.vaccinationDate,
    this.nextDueDate,
    this.vetName,
  });

  final int petId;
  final int? vaccineTypeId;
  final String vaccineName;
  final DateTime vaccinationDate;
  final DateTime? nextDueDate;
  final String? vetName;
}

/// The persisted vaccination. The name is snapshotted from the catalog so a
/// later rename never rewrites history.
class Vaccination {
  const Vaccination({
    required this.id,
    required this.petId,
    this.vaccineTypeId,
    required this.vaccineName,
    required this.vaccinationDate,
    this.nextDueDate,
    this.vetName,
    required this.createdAt,
  });

  final int id;
  final int petId;
  final int? vaccineTypeId;
  final String vaccineName;
  final DateTime vaccinationDate;
  final DateTime? nextDueDate;
  final String? vetName;
  final DateTime createdAt;
}
