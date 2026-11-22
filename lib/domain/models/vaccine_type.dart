/// The seeded vaccine catalog (rabies, DHPP, FVRCP, ...).
library;

import '../rules/calendar.dart';

/// A catalog entry. [intervalMonths] prefills the next due date on the form.
class VaccineType {
  const VaccineType({
    required this.id,
    required this.name,
    this.intervalMonths,
    this.isCore = true,
    this.sortOrder = 0,
  });

  final int id;
  final String name;
  final int? intervalMonths;
  final bool isCore;
  final int sortOrder;

  /// The prefilled next due date for a dose given on [vaccinationDate].
  DateTime? nextDueFrom(DateTime vaccinationDate) {
    final int? months = intervalMonths;
    if (months == null || months <= 0) {
      return null;
    }
    return addMonths(dateOnly(vaccinationDate), months);
  }
}
