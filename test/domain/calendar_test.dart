import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/models/vaccine_type.dart';
import 'package:pet_health_tracker/domain/rules/calendar.dart';

void main() {
  group('dateOnly', () {
    test('drops the time of day', () {
      expect(
        dateOnly(DateTime(2026, 11, 21, 23, 59)),
        DateTime.utc(2026, 11, 21),
      );
    });
  });

  group('addMonths', () {
    test('moves forward and back by calendar months', () {
      expect(
        addMonths(DateTime.utc(2026, 1, 15), 1),
        DateTime.utc(2026, 2, 15),
      );
      expect(
        addMonths(DateTime.utc(2026, 1, 15), -1),
        DateTime.utc(2025, 12, 15),
      );
    });

    test('clamps to the last day of the target month', () {
      expect(
        addMonths(DateTime.utc(2026, 1, 31), 1),
        DateTime.utc(2026, 2, 28),
      );
      expect(
        addMonths(DateTime.utc(2024, 1, 31), 1),
        DateTime.utc(2024, 2, 29),
      );
      expect(
        addMonths(DateTime.utc(2026, 3, 31), -1),
        DateTime.utc(2026, 2, 28),
      );
    });

    test('rolls over the year', () {
      expect(
        addMonths(DateTime.utc(2026, 11, 21), 3),
        DateTime.utc(2027, 2, 21),
      );
      expect(addMonths(DateTime.utc(2026, 1, 1), 12), DateTime.utc(2027, 1, 1));
    });
  });

  group('daysBetween', () {
    test('counts whole calendar days', () {
      expect(
        daysBetween(DateTime.utc(2026, 11, 1), DateTime.utc(2026, 11, 21)),
        20,
      );
      expect(
        daysBetween(DateTime.utc(2026, 11, 21), DateTime.utc(2026, 11, 1)),
        -20,
      );
      expect(
        daysBetween(
          DateTime.utc(2026, 11, 20, 23),
          DateTime.utc(2026, 11, 21, 1),
        ),
        1,
      );
    });
  });

  group('age', () {
    final DateTime today = DateTime.utc(2026, 11, 21);

    test('ageInYears handles the day before the birthday', () {
      expect(ageInYears(DateTime.utc(2021, 3, 14), today), 5);
      expect(ageInYears(DateTime.utc(2026, 11, 22), today), 0);
      expect(ageInYears(DateTime.utc(2026, 11, 21), today), 0);
    });

    test('ageInYears never goes negative', () {
      expect(ageInYears(DateTime.utc(2027, 1, 1), today), 0);
    });

    test('ageLabel covers days, weeks, months and years', () {
      expect(ageLabel(today.subtract(const Duration(days: 4)), today), '4 d');
      expect(ageLabel(today.subtract(const Duration(days: 21)), today), '3 wk');
      expect(ageLabel(DateTime.utc(2026, 5, 1), today), '6 mo');
      expect(ageLabel(DateTime.utc(2021, 3, 14), today), '5 yr 8 mo');
      expect(ageLabel(DateTime.utc(2021, 11, 21), today), '5 yr');
      expect(ageLabel(DateTime.utc(2026, 11, 22), today), '—');
    });
  });

  group('VaccineType.nextDueFrom', () {
    test('prefills the next due date from the catalogue interval', () {
      const VaccineType rabies = VaccineType(
        id: 1,
        name: 'Rabies',
        intervalMonths: 12,
      );
      expect(
        rabies.nextDueFrom(DateTime.utc(2026, 3, 31)),
        DateTime.utc(2027, 3, 31),
      );
    });

    test('a type without an interval has no prefill', () {
      const VaccineType custom = VaccineType(id: 9, name: 'Custom');
      expect(custom.nextDueFrom(DateTime.utc(2026, 3, 31)), isNull);
    });

    test('a monthly type prefills a month out', () {
      const VaccineType deworming = VaccineType(
        id: 7,
        name: 'Deworming',
        intervalMonths: 1,
      );
      expect(
        deworming.nextDueFrom(DateTime.utc(2026, 1, 31)),
        DateTime.utc(2026, 2, 28),
      );
    });
  });
}
