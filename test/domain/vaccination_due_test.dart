import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/models/vaccination.dart';
import 'package:pet_health_tracker/domain/rules/vaccination_due.dart';

/// Each call is a distinct vaccine unless the test says otherwise, because the
/// rule now keeps only the newest dose per vaccine.
int _sequence = 0;

Vaccination vaccination({
  required DateTime? nextDueDate,
  String name = 'Rabies',
  int? id,
  int? typeId,
  DateTime? given,
}) {
  _sequence += 1;
  return Vaccination(
    id: id ?? _sequence,
    petId: 1,
    vaccineTypeId: typeId ?? _sequence,
    vaccineName: name,
    vaccinationDate: given ?? DateTime.utc(2025, 1, 1),
    nextDueDate: nextDueDate,
    createdAt: DateTime.utc(2025, 1, 1),
  );
}

void main() {
  final DateTime today = DateTime.utc(2026, 11, 21);

  group('vaccinationDueStatus', () {
    test('a missing due date means nothing is tracked', () {
      expect(vaccinationDueStatus(null, today), VaccinationDueStatus.upToDate);
    });

    test('yesterday is overdue', () {
      expect(
        vaccinationDueStatus(DateTime.utc(2026, 11, 20), today),
        VaccinationDueStatus.overdue,
      );
    });

    test('today is due soon, not overdue', () {
      expect(
        vaccinationDueStatus(DateTime.utc(2026, 11, 21), today),
        VaccinationDueStatus.dueSoon,
      );
    });

    test('the window boundary is inclusive at 30 days', () {
      expect(
        vaccinationDueStatus(DateTime.utc(2026, 12, 21), today),
        VaccinationDueStatus.dueSoon,
      );
      expect(
        vaccinationDueStatus(DateTime.utc(2026, 12, 22), today),
        VaccinationDueStatus.upToDate,
      );
    });

    test('the time of day never changes the answer', () {
      expect(
        vaccinationDueStatus(
          DateTime.utc(2026, 11, 21, 23, 59),
          DateTime.utc(2026, 11, 21, 0, 1),
        ),
        VaccinationDueStatus.dueSoon,
      );
      expect(
        vaccinationDueStatus(
          DateTime.utc(2026, 11, 20, 23, 59),
          DateTime.utc(2026, 11, 21, 0, 1),
        ),
        VaccinationDueStatus.overdue,
      );
    });

    test('a zero-day window only flags today', () {
      expect(
        vaccinationDueStatus(DateTime.utc(2026, 11, 21), today, windowDays: 0),
        VaccinationDueStatus.dueSoon,
      );
      expect(
        vaccinationDueStatus(DateTime.utc(2026, 11, 22), today, windowDays: 0),
        VaccinationDueStatus.upToDate,
      );
    });

    test('a custom window moves the boundary', () {
      expect(
        vaccinationDueStatus(DateTime.utc(2026, 12, 10), today, windowDays: 7),
        VaccinationDueStatus.upToDate,
      );
      expect(
        vaccinationDueStatus(DateTime.utc(2026, 11, 25), today, windowDays: 7),
        VaccinationDueStatus.dueSoon,
      );
    });
  });

  group('petVaccinationDueStatus', () {
    test('no tracked due dates reads up to date', () {
      expect(
        petVaccinationDueStatus(const <Vaccination>[], today),
        VaccinationDueStatus.upToDate,
      );
      expect(
        petVaccinationDueStatus(<Vaccination>[
          vaccination(nextDueDate: null),
        ], today),
        VaccinationDueStatus.upToDate,
      );
    });

    test('the most urgent status wins', () {
      final List<Vaccination> doses = <Vaccination>[
        vaccination(nextDueDate: DateTime.utc(2027, 6, 1), name: 'DHPP'),
        vaccination(nextDueDate: DateTime.utc(2026, 12, 1), name: 'FeLV'),
        vaccination(nextDueDate: DateTime.utc(2026, 10, 1), name: 'Rabies'),
      ];
      expect(
        petVaccinationDueStatus(doses, today),
        VaccinationDueStatus.overdue,
      );
    });

    test('due soon beats up to date', () {
      final List<Vaccination> doses = <Vaccination>[
        vaccination(nextDueDate: DateTime.utc(2027, 6, 1), name: 'DHPP'),
        vaccination(nextDueDate: DateTime.utc(2026, 11, 25), name: 'FeLV'),
      ];
      expect(
        petVaccinationDueStatus(doses, today),
        VaccinationDueStatus.dueSoon,
      );
    });
  });


  group('a newer dose supersedes an older one of the same vaccine', () {
    test('an old overdue dose stops counting once it is re-vaccinated', () {
      final List<Vaccination> doses = <Vaccination>[
        vaccination(
          id: 1,
          typeId: 7,
          given: DateTime.utc(2025, 1, 1),
          nextDueDate: DateTime.utc(2026, 1, 1),
        ),
        vaccination(
          id: 2,
          typeId: 7,
          given: DateTime.utc(2026, 11, 20),
          nextDueDate: DateTime.utc(2027, 11, 20),
        ),
      ];
      expect(
        petVaccinationDueStatus(doses, today),
        VaccinationDueStatus.upToDate,
      );
    });

    test('the newest dose with no due date clears that vaccine', () {
      final List<Vaccination> doses = <Vaccination>[
        vaccination(
          id: 1,
          typeId: 7,
          given: DateTime.utc(2025, 1, 1),
          nextDueDate: DateTime.utc(2026, 1, 1),
        ),
        vaccination(
          id: 2,
          typeId: 7,
          given: DateTime.utc(2026, 11, 20),
          nextDueDate: null,
        ),
      ];
      expect(
        petVaccinationDueStatus(doses, today),
        VaccinationDueStatus.upToDate,
      );
    });

    test('superseding is per vaccine, so another type can still be overdue', () {
      final List<Vaccination> doses = <Vaccination>[
        vaccination(
          id: 1,
          typeId: 7,
          name: 'Rabies',
          given: DateTime.utc(2025, 1, 1),
          nextDueDate: DateTime.utc(2026, 1, 1),
        ),
        vaccination(
          id: 2,
          typeId: 7,
          name: 'Rabies',
          given: DateTime.utc(2026, 11, 20),
          nextDueDate: DateTime.utc(2027, 11, 20),
        ),
        vaccination(
          id: 3,
          typeId: 8,
          name: 'DHPP',
          given: DateTime.utc(2025, 3, 1),
          nextDueDate: DateTime.utc(2026, 3, 1),
        ),
      ];
      expect(
        petVaccinationDueStatus(doses, today),
        VaccinationDueStatus.overdue,
      );
    });

    test('the label names the current dose, not the superseded one', () {
      final List<Vaccination> doses = <Vaccination>[
        vaccination(
          id: 1,
          typeId: 7,
          given: DateTime.utc(2025, 1, 1),
          nextDueDate: DateTime.utc(2026, 1, 1),
        ),
        vaccination(
          id: 2,
          typeId: 7,
          given: DateTime.utc(2026, 11, 20),
          nextDueDate: DateTime.utc(2027, 11, 20),
        ),
      ];
      expect(nextDueVaccination(doses)!.id, 2);
    });
  });

  group('nextDueVaccination', () {
    test('returns the earliest due date, including overdue ones', () {
      final List<Vaccination> doses = <Vaccination>[
        vaccination(nextDueDate: DateTime.utc(2027, 6, 1), name: 'DHPP'),
        vaccination(nextDueDate: DateTime.utc(2026, 9, 1), name: 'Rabies'),
      ];
      expect(nextDueVaccination(doses)!.vaccineName, 'Rabies');
    });

    test('ignores doses without a due date', () {
      final List<Vaccination> doses = <Vaccination>[
        vaccination(nextDueDate: null, name: 'Rabies'),
        vaccination(nextDueDate: DateTime.utc(2027, 6, 1), name: 'DHPP'),
      ];
      expect(nextDueVaccination(doses)!.vaccineName, 'DHPP');
    });

    test('returns null when nothing is tracked', () {
      expect(
        nextDueVaccination(<Vaccination>[vaccination(nextDueDate: null)]),
        isNull,
      );
    });
  });
}
