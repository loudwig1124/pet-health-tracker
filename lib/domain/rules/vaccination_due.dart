/// The shared vaccination due rule: overdue / due soon / up to date over a
/// 30-day window. Pure: `today` is always a parameter, never `DateTime.now()`.
library;

import '../models/vaccination.dart';
import 'calendar.dart';

/// The approved default window: a booster due within the next 30 days is
/// "due soon".
const int defaultDueSoonWindowDays = 30;

/// The three faces of a vaccination due date.
enum VaccinationDueStatus {
  overdue('overdue', 'Overdue'),
  dueSoon('due_soon', 'Due soon'),
  upToDate('up_to_date', 'Up to date');

  const VaccinationDueStatus(this.wire, this.label);

  final String wire;
  final String label;

  /// Higher means more urgent (overdue beats due soon beats up to date).
  int get severity => switch (this) {
    VaccinationDueStatus.overdue => 2,
    VaccinationDueStatus.dueSoon => 1,
    VaccinationDueStatus.upToDate => 0,
  };
}

/// Due status of one due date.
///
/// A date before today is overdue; today or within [windowDays] days is due
/// soon; anything later is up to date. A null due date means "not tracked" and
/// reads up to date — nothing is due.
VaccinationDueStatus vaccinationDueStatus(
  DateTime? nextDueDate,
  DateTime today, {
  int windowDays = defaultDueSoonWindowDays,
}) {
  assert(windowDays >= 0, 'the due-soon window cannot be negative');
  if (nextDueDate == null) {
    return VaccinationDueStatus.upToDate;
  }
  final DateTime due = dateOnly(nextDueDate);
  final DateTime reference = dateOnly(today);
  if (due.isBefore(reference)) {
    return VaccinationDueStatus.overdue;
  }
  if (!due.isAfter(reference.add(Duration(days: windowDays)))) {
    return VaccinationDueStatus.dueSoon;
  }
  return VaccinationDueStatus.upToDate;
}

/// The most urgent status across a pet's tracked due dates. A pet with no
/// tracked due dates reads up to date (nothing is due).
VaccinationDueStatus petVaccinationDueStatus(
  Iterable<Vaccination> vaccinations,
  DateTime today, {
  int windowDays = defaultDueSoonWindowDays,
}) {
  VaccinationDueStatus worst = VaccinationDueStatus.upToDate;
  for (final Vaccination vaccination in vaccinations) {
    final VaccinationDueStatus status = vaccinationDueStatus(
      vaccination.nextDueDate,
      today,
      windowDays: windowDays,
    );
    if (status.severity > worst.severity) {
      worst = status;
    }
  }
  return worst;
}

/// The vaccination with the earliest next due date (overdue first), or null
/// when no dose has a due date.
Vaccination? nextDueVaccination(Iterable<Vaccination> vaccinations) {
  Vaccination? next;
  for (final Vaccination vaccination in vaccinations) {
    final DateTime? due = vaccination.nextDueDate;
    if (due == null) {
      continue;
    }
    if (next == null || due.isBefore(next.nextDueDate!)) {
      next = vaccination;
    }
  }
  return next;
}
