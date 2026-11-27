import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_support.dart';

/// The committed DDL is the contract: these tests exercise the real SQLite
/// engine against `db/schema.sql` (no mocks, no copy of the schema).
void main() {
  late SqliteHarness harness;
  late int ownerId;

  setUp(() async {
    harness = await openHarness();
    final List<Map<String, Object?>> owners = await harness.db.query(
      'owner',
      columns: <String>['id'],
      limit: 1,
    );
    ownerId = owners.single['id']! as int;
  });

  tearDown(() async {
    await harness.dispose();
  });

  Future<int> insertPet({String? microchip, String name = 'Bella'}) {
    return harness.db.insert('pet', <String, Object?>{
      'owner_id': ownerId,
      'name': name,
      'species': 'Dog',
      'breed': 'Mix',
      'sex': 'female',
      'date_of_birth': '2021-03-14',
      'weight_kg': 12.4,
      'microchip': microchip,
      'photo_path': null,
      'created_at': '2026-11-21T09:30:00.000Z',
      'updated_at': '2026-11-21T09:30:00.000Z',
    });
  }

  Future<int> insertAppointment({
    required String status,
    String? completedAt,
    String? cancelReason,
    int? petId,
    String scheduledAt = '2026-11-26T01:30:00.000Z',
  }) {
    return harness.db.insert('appointment', <String, Object?>{
      'pet_id': petId,
      'clinic_name': 'Paws & Claws',
      'purpose': 'Wellness check',
      'scheduled_at': scheduledAt,
      'status': status,
      'completed_at': completedAt,
      'cancel_reason': cancelReason,
      'created_at': '2026-11-21T09:30:00.000Z',
      'updated_at': '2026-11-21T09:30:00.000Z',
    });
  }

  Future<int> insertJournal(String kind, {required int petId}) {
    return harness.db.insert('journal_entry', <String, Object?>{
      'pet_id': petId,
      'kind': kind,
      'occurred_at': '2026-11-21T08:00:00.000Z',
      'note': 'note',
      'duration_minutes': null,
      'created_at': '2026-11-21T08:00:00.000Z',
      'updated_at': '2026-11-21T08:00:00.000Z',
    });
  }

  Future<int> insertHealthRecord(int petId) {
    return harness.db.insert('health_record', <String, Object?>{
      'pet_id': petId,
      'recorded_on': '2026-11-01',
      'condition': 'Otitis externa',
      'diagnosis': 'Bacterial ear infection',
      'treatment': 'Ear cleaning',
      'prescribed_medication': 'Ofloxacin drops',
      'vet_name': 'Dr. Ana Cruz',
      'created_at': '2026-11-01T09:00:00.000Z',
    });
  }

  test('the DDL creates exactly the seven tables', () async {
    final List<Map<String, Object?>> rows = await harness.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    expect(
      rows.map((Map<String, Object?> row) => row['name']).toList(),
      <String>[
        'appointment',
        'health_record',
        'journal_entry',
        'owner',
        'pet',
        'vaccination',
        'vaccine_type',
      ],
    );
  });

  test('foreign keys are enforced on every connection', () async {
    final List<Map<String, Object?>> rows = await harness.db.rawQuery(
      'PRAGMA foreign_keys',
    );
    expect(rows.single.values.single, 1);
    expect(
      () => harness.db.insert('vaccination', <String, Object?>{
        'pet_id': 424242,
        'vaccine_name': 'Rabies',
        'vaccination_date': '2026-01-01',
        'next_due_date': null,
        'created_at': '2026-11-21T09:30:00.000Z',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('microchip is UNIQUE and nullable', () async {
    await insertPet(microchip: null, name: 'First');
    await insertPet(microchip: null, name: 'Second');
    await insertPet(microchip: '900215004123456', name: 'Third');

    expect(
      () => insertPet(microchip: '900215004123456', name: 'Duplicate'),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('a vaccination next due date must be after the dose date', () async {
    final int petId = await insertPet();
    Future<int> insertVaccination(String dose, String? nextDue) {
      return harness.db.insert('vaccination', <String, Object?>{
        'pet_id': petId,
        'vaccine_type_id': null,
        'vaccine_name': 'Rabies',
        'vaccination_date': dose,
        'next_due_date': nextDue,
        'vet_name': null,
        'created_at': '2026-11-21T09:30:00.000Z',
      });
    }

    await insertVaccination('2026-01-01', null);
    await insertVaccination('2026-01-01', '2027-01-01');
    expect(
      () => insertVaccination('2026-01-01', '2026-01-01'),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      () => insertVaccination('2026-01-01', '2025-12-31'),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('appointment status CHECK ties completed_at to completed', () async {
    final int petId = await insertPet();
    await insertAppointment(status: 'scheduled', petId: petId);
    await insertAppointment(
      status: 'completed',
      completedAt: '2026-11-21T10:00:00.000Z',
      petId: petId,
    );
    await insertAppointment(
      status: 'cancelled',
      cancelReason: 'rescheduled',
      petId: petId,
    );

    expect(
      () => insertAppointment(status: 'completed', petId: petId),
      throwsA(isA<DatabaseException>()),
      reason: 'completed needs completed_at',
    );
    expect(
      () => insertAppointment(
        status: 'scheduled',
        completedAt: '2026-11-21T10:00:00.000Z',
        petId: petId,
      ),
      throwsA(isA<DatabaseException>()),
      reason: 'only completed may carry completed_at',
    );
    expect(
      () => insertAppointment(status: 'cancelled', petId: petId),
      throwsA(isA<DatabaseException>()),
      reason: 'a cancellation needs a reason',
    );
    expect(
      () => insertAppointment(status: 'postponed', petId: petId),
      throwsA(isA<DatabaseException>()),
      reason: 'unknown statuses are rejected',
    );
  });

  test('journal kind is restricted to the seven kinds', () async {
    final int petId = await insertPet();
    for (final String kind in <String>[
      'walk',
      'fed',
      'meds',
      'grooming',
      'training',
      'note',
      'symptom',
    ]) {
      await insertJournal(kind, petId: petId);
    }
    expect(
      () => insertJournal('swim', petId: petId),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('a clinical note needs a condition or a diagnosis', () async {
    final int petId = await insertPet();
    expect(
      () => harness.db.insert('health_record', <String, Object?>{
        'pet_id': petId,
        'recorded_on': '2026-11-01',
        'condition': null,
        'diagnosis': null,
        'created_at': '2026-11-01T09:00:00.000Z',
      }),
      throwsA(isA<DatabaseException>()),
    );
    await insertHealthRecord(petId);
  });

  test('health records are editable and deletable (schema v2)', () async {
    final int petId = await insertPet();
    final int recordId = await insertHealthRecord(petId);

    await harness.db.update(
      'health_record',
      <String, Object?>{'treatment': 'Rewritten'},
      where: 'id = ?',
      whereArgs: <Object?>[recordId],
    );
    final List<Map<String, Object?>> rows = await harness.db.query(
      'health_record',
      where: 'id = ?',
      whereArgs: <Object?>[recordId],
    );
    expect(rows.single['treatment'], 'Rewritten');

    await harness.db.delete(
      'health_record',
      where: 'id = ?',
      whereArgs: <Object?>[recordId],
    );
    expect(await harness.db.query('health_record'), isEmpty);
  });

  test(
    'deleting a pet cascades records but keeps appointment history',
    () async {
      final int petId = await insertPet();
      await insertJournal('walk', petId: petId);
      await insertHealthRecord(petId);
      await harness.db.insert('vaccination', <String, Object?>{
        'pet_id': petId,
        'vaccine_name': 'Rabies',
        'vaccination_date': '2026-01-01',
        'next_due_date': '2027-01-01',
        'created_at': '2026-11-21T09:30:00.000Z',
      });
      final int appointmentId = await insertAppointment(
        status: 'completed',
        completedAt: '2026-11-21T10:00:00.000Z',
        petId: petId,
      );

      await harness.db.delete(
        'pet',
        where: 'id = ?',
        whereArgs: <Object?>[petId],
      );

      expect(await harness.db.query('journal_entry'), isEmpty);
      expect(await harness.db.query('health_record'), isEmpty);
      expect(await harness.db.query('vaccination'), isEmpty);

      final List<Map<String, Object?>> appointments = await harness.db.query(
        'appointment',
        where: 'id = ?',
        whereArgs: <Object?>[appointmentId],
      );
      expect(appointments.single['pet_id'], isNull);
      expect(appointments.single['status'], 'completed');
    },
  );

  test('the v2 schema carries no append-only triggers', () async {
    final List<Map<String, Object?>> rows = await harness.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'trigger' ORDER BY name",
    );
    expect(rows, isEmpty);
  });
}
