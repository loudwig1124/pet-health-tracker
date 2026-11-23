/// SQLite dashboard read model: one pass over the household, assembled with the
/// pure vaccination due rule.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/dashboard.dart';
import '../../domain/models/appointment.dart';
import '../../domain/models/journal_entry.dart';
import '../../domain/models/owner.dart';
import '../../domain/models/pet.dart';
import '../../domain/models/vaccination.dart';
import '../../domain/rules/calendar.dart';
import '../../domain/rules/vaccination_due.dart';
import '../repositories/dashboard_repository.dart';
import 'mappers.dart';
import 'wire.dart';

class SqliteDashboardRepository implements DashboardRepository {
  SqliteDashboardRepository(this._db);

  final Database _db;

  @override
  Future<Dashboard> load({
    required DateTime now,
    int dueSoonWindowDays = defaultDueSoonWindowDays,
  }) async {
    final DateTime reference = now.toUtc();

    final List<Map<String, Object?>> ownerRows = await _db.query(
      'owner',
      orderBy: 'id ASC',
      limit: 1,
    );
    if (ownerRows.isEmpty) {
      throw StateError(
        'No owner row. Boot through AppServices so the household is created.',
      );
    }
    final Owner owner = ownerFromRow(ownerRows.single);

    final List<Pet> pets = (await _db.query(
      'pet',
      orderBy: 'name COLLATE NOCASE ASC',
    )).map(petFromRow).toList(growable: false);

    final Map<int, List<Vaccination>> vaccinationsByPet =
        <int, List<Vaccination>>{};
    for (final Map<String, Object?> row in await _db.query('vaccination')) {
      final Vaccination vaccination = vaccinationFromRow(row);
      vaccinationsByPet
          .putIfAbsent(vaccination.petId, () => <Vaccination>[])
          .add(vaccination);
    }

    final List<Appointment> appointments = (await _db.query(
      'appointment',
      orderBy: 'scheduled_at ASC',
    )).map(appointmentFromRow).toList(growable: false);

    final List<JournalEntry> recentEntries = (await _db.query(
      'journal_entry',
      orderBy: 'occurred_at DESC',
      limit: 3,
    )).map(journalEntryFromRow).toList(growable: false);

    final Map<int, DateTime> lastRecordByPet = <int, DateTime>{};
    for (final Map<String, Object?> row in await _db.rawQuery(
      'SELECT pet_id, MAX(recorded_on) AS last_recorded_on '
      'FROM health_record GROUP BY pet_id',
    )) {
      final Object? lastRecordedOn = row['last_recorded_on'];
      if (lastRecordedOn is String) {
        lastRecordByPet[row['pet_id']! as int] = decodeDate(lastRecordedOn);
      }
    }

    final List<PetOverview> overviews = <PetOverview>[];
    for (final Pet pet in pets) {
      final List<Vaccination> petVaccinations =
          vaccinationsByPet[pet.id] ?? const <Vaccination>[];
      overviews.add(
        PetOverview(
          pet: pet,
          dueStatus: petVaccinationDueStatus(
            petVaccinations,
            reference,
            windowDays: dueSoonWindowDays,
          ),
          nextVaccination: nextDueVaccination(petVaccinations),
          nextAppointment: _nextFor(pet.id, appointments, reference),
          lastVisit: _lastVisitFor(pet.id, appointments, lastRecordByPet),
        ),
      );
    }

    final List<Appointment> nextAppointments = _nextDayFor(
      appointments,
      reference,
    );

    return Dashboard(
      owner: owner,
      pets: overviews,
      nextAppointment: nextAppointments.isEmpty ? null : nextAppointments.first,
      nextAppointments: nextAppointments,
      recentEntries: recentEntries,
      generatedAt: reference,
    );
  }

  /// All still-scheduled future appointments on the earliest upcoming day.
  ///
  /// Two pets booked for the same Tuesday both count as the next thing; a third
  /// pet booked for Wednesday is not yet urgent.
  List<Appointment> _nextDayFor(
    List<Appointment> appointments,
    DateTime reference,
  ) {
    DateTime? earliest;
    final List<Appointment> matches = <Appointment>[];
    for (final Appointment appointment in appointments) {
      if (appointment.status != AppointmentStatus.scheduled ||
          !appointment.scheduledAt.isAfter(reference)) {
        continue;
      }
      final DateTime day = dateOnly(appointment.scheduledAt.toLocal());
      earliest ??= day;
      if (day == earliest) {
        matches.add(appointment);
      }
    }
    return matches;
  }

  /// Next still-scheduled future appointment, optionally for one pet.
  Appointment? _nextFor(
    int? petId,
    List<Appointment> appointments,
    DateTime reference,
  ) {
    for (final Appointment appointment in appointments) {
      final bool matchesPet = petId == null || appointment.petId == petId;
      if (matchesPet &&
          appointment.status == AppointmentStatus.scheduled &&
          appointment.scheduledAt.isAfter(reference)) {
        return appointment;
      }
    }
    return null;
  }

  /// Latest completed visit or clinical note, as a calendar date.
  DateTime? _lastVisitFor(
    int petId,
    List<Appointment> appointments,
    Map<int, DateTime> lastRecordByPet,
  ) {
    DateTime? latest = lastRecordByPet[petId];
    for (final Appointment appointment in appointments) {
      if (appointment.petId != petId ||
          appointment.status != AppointmentStatus.completed) {
        continue;
      }
      final DateTime visitDate = dateOnly(
        appointment.completedAt ?? appointment.scheduledAt,
      );
      if (latest == null || visitDate.isAfter(latest)) {
        latest = visitDate;
      }
    }
    return latest;
  }
}
