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

/// The doses that still describe a pet's status: the most recent one for each
/// vaccine, by the date it was given (ids break same-day ties).
///
/// Vaccinations are append-only, so a pet accumulates history. Ranking every
/// row would let an old, overdue dose outrank the booster that superseded it —
/// a re-vaccinated pet could never clear "overdue".
Iterable<Vaccination> currentDoses(Iterable<Vaccination> vaccinations) {
  final Map<String, Vaccination> latest = <String, Vaccination>{};
  for (final Vaccination vaccination in vaccinations) {
    // A type id is the reliable key; the snapshotted name is the fallback for
    // historical rows that predate the catalog.
    final String key = vaccination.vaccineTypeId != null
        ? 'type:${vaccination.vaccineTypeId}'
        : 'name:${vaccination.vaccineName.trim().toLowerCase()}';
    final Vaccination? current = latest[key];
    if (current == null || _isNewer(vaccination, current)) {
      latest[key] = vaccination;
    }
  }
  return latest.values;
}

bool _isNewer(Vaccination candidate, Vaccination incumbent) {
  final int byDate = candidate.vaccinationDate.compareTo(
    incumbent.vaccinationDate,
  );
  if (byDate != 0) {
    return byDate > 0;
  }
  return candidate.id > incumbent.id;
}

/// The most urgent status across a pet's current doses. A pet with no tracked
/// due dates reads up to date (nothing is due).
VaccinationDueStatus petVaccinationDueStatus(
  Iterable<Vaccination> vaccinations,
  DateTime today, {
  int windowDays = defaultDueSoonWindowDays,
}) {
  VaccinationDueStatus worst = VaccinationDueStatus.upToDate;
  for (final Vaccination vaccination in currentDoses(vaccinations)) {
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

/// The current dose with the earliest next due date (overdue first), or null
/// when no current dose has a due date.
Vaccination? nextDueVaccination(Iterable<Vaccination> vaccinations) {
  Vaccination? next;
  for (final Vaccination vaccination in currentDoses(vaccinations)) {
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
