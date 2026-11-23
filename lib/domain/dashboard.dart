/// The dashboard read model: everything Home needs in one immutable snapshot.
library;

import 'models/appointment.dart';
import 'models/journal_entry.dart';
import 'models/owner.dart';
import 'models/pet.dart';
import 'models/vaccination.dart';
import 'rules/vaccination_due.dart';

/// Home's data: owner, per-pet cards, the next household appointment and the
/// most recent journal entries.
class Dashboard {
  const Dashboard({
    required this.owner,
    required this.pets,
    this.nextAppointment,
    this.nextAppointments = const <Appointment>[],
    required this.recentEntries,
    required this.generatedAt,
  });

  final Owner owner;
  final List<PetOverview> pets;
  final Appointment? nextAppointment;

  /// Every still-scheduled appointment sharing the earliest upcoming date.
  /// "The most urgent day" can belong to more than one pet.
  final List<Appointment> nextAppointments;
  final List<JournalEntry> recentEntries;
  final DateTime generatedAt;

  bool get isEmpty => pets.isEmpty;
}

/// One swipeable pet card's worth of data.
class PetOverview {
  const PetOverview({
    required this.pet,
    required this.dueStatus,
    this.nextVaccination,
    this.nextAppointment,
    this.nextAppointments = const <Appointment>[],
    this.lastVisit,
  });

  final Pet pet;

  /// Most urgent tracked vaccination status; up to date when nothing is tracked.
  final VaccinationDueStatus dueStatus;

  /// The dose with the earliest due date (may already be overdue).
  final Vaccination? nextVaccination;

  /// This pet's next still-scheduled appointment in the future.
  final Appointment? nextAppointment;

  /// Every still-scheduled appointment sharing the earliest upcoming date.
  /// "The most urgent day" can belong to more than one pet.
  final List<Appointment> nextAppointments;

  /// Latest completed visit or clinical note, as a calendar date.
  final DateTime? lastVisit;
}
