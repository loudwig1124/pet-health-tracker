/// Seeding: the vaccine catalog is always present; the demo household is opt-in
/// behind the Profile "Sample data" toggle.
///
/// Demo rows live in a reserved id range (>= 9000) under the household owner, so
/// removing them can never touch data the owner typed. Everything is idempotent
/// (`INSERT OR IGNORE`), which makes the toggle safe to flip repeatedly.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/rules/calendar.dart';
import '../../domain/models/owner.dart';
import '../sqlite/app_database.dart';
import '../sqlite/wire.dart';
import 'seed_data.dart';

/// First id reserved for demo rows.
const int demoIdFloor = 9000;

/// Inserts the vaccine catalog (idempotent).
Future<void> seedVaccineCatalog(Database db) async {
  for (final VaccineTypeSeed seed in vaccineTypeSeeds) {
    await db.insert('vaccine_type', <String, Object?>{
      'id': seed.id,
      'name': seed.name,
      'interval_months': seed.intervalMonths,
      'is_core': seed.isCore ? 1 : 0,
      'sort_order': seed.sortOrder,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}

/// True when the demo household is present.
Future<bool> demoHouseholdExists(Database db) async {
  final List<Map<String, Object?>> rows = await db.query(
    'pet',
    columns: <String>['id'],
    where: 'id >= ?',
    whereArgs: <Object?>[demoIdFloor],
    limit: 1,
  );
  return rows.isNotEmpty;
}

/// Inserts the two-pet demo household: one dog with an overdue rabies booster,
/// one cat, a few journal entries, a due-soon vaccine, one upcoming and one past
/// appointment, and two clinical notes.
///
/// [now] is the seed instant; demo dates are relative to it so the demo never
/// looks stale.
Future<void> seedDemoHousehold(Database db, {required DateTime now}) async {
  final DateTime today = dateOnly(now);
  final int ownerId = await _ownerId(db);

  await db.transaction((Transaction txn) async {
    // The demo is a persona: only rename an untouched placeholder, never a
    // name the owner typed.
    await txn.update(
      'owner',
      <String, Object?>{'name': 'Maria Santos'},
      where: 'id = ? AND name = ?',
      whereArgs: <Object?>[ownerId, kDefaultOwnerName],
    );

    // Pets — Bella the dog and Miso the cat.
    await _insertIgnoring(txn, 'pet', <String, Object?>{
      'id': 9001,
      'owner_id': ownerId,
      'name': 'Bella',
      'species': 'Dog',
      'breed': 'Golden Retriever mix',
      'sex': 'female',
      'date_of_birth': encodeDate(addMonths(today, -62)),
      'weight_kg': 12.4,
      'microchip': '900215004123456',
      'photo_path': null,
      'created_at': encodeInstant(now),
      'updated_at': encodeInstant(now),
    });
    await _insertIgnoring(txn, 'pet', <String, Object?>{
      'id': 9002,
      'owner_id': ownerId,
      'name': 'Miso',
      'species': 'Cat',
      'breed': 'Domestic shorthair',
      'sex': 'male',
      'date_of_birth': encodeDate(addMonths(today, -40)),
      'weight_kg': 4.2,
      'microchip': null,
      'photo_path': null,
      'created_at': encodeInstant(now),
      'updated_at': encodeInstant(now),
    });

    // Vaccinations: rabies overdue for Bella, FeLV due soon for Miso.
    await _vaccination(
      txn,
      id: 9101,
      petId: 9001,
      vaccineTypeId: 1,
      name: 'Rabies',
      vaccinationDate: today.subtract(const Duration(days: 400)),
      nextDueDate: today.subtract(const Duration(days: 35)),
      now: now,
    );
    await _vaccination(
      txn,
      id: 9102,
      petId: 9001,
      vaccineTypeId: 2,
      name: 'DHPP',
      vaccinationDate: today.subtract(const Duration(days: 200)),
      nextDueDate: today.add(const Duration(days: 120)),
      now: now,
    );
    await _vaccination(
      txn,
      id: 9103,
      petId: 9002,
      vaccineTypeId: 5,
      name: 'FVRCP',
      vaccinationDate: today.subtract(const Duration(days: 300)),
      nextDueDate: today.add(const Duration(days: 60)),
      now: now,
    );
    await _vaccination(
      txn,
      id: 9104,
      petId: 9002,
      vaccineTypeId: 6,
      name: 'FeLV',
      vaccinationDate: today.subtract(const Duration(days: 355)),
      nextDueDate: today.add(const Duration(days: 10)),
      now: now,
    );

    // Clinical notes (append-only rows).
    await _insertIgnoring(txn, 'health_record', <String, Object?>{
      'id': 9201,
      'pet_id': 9001,
      'recorded_on': encodeDate(today.subtract(const Duration(days: 25))),
      'condition': 'Otitis externa (left ear)',
      'diagnosis': 'Bacterial ear infection',
      'treatment': 'Ear cleaning and antibiotic drops for 10 days',
      'prescribed_medication': 'Ofloxacin otic drops',
      'vet_name': 'Dr. Ana Cruz',
      'created_at': encodeInstant(now),
    });
    await _insertIgnoring(txn, 'health_record', <String, Object?>{
      'id': 9202,
      'pet_id': 9002,
      'recorded_on': encodeDate(today.subtract(const Duration(days: 120))),
      'condition': 'Healthy annual exam',
      'diagnosis': null,
      'treatment': 'None needed',
      'prescribed_medication': null,
      'vet_name': 'Dr. Ana Cruz',
      'created_at': encodeInstant(now),
    });

    // Appointments: one upcoming, one completed in the past.
    final DateTime upcoming = _at(today.add(const Duration(days: 5)), 9, 30);
    final DateTime pastVisit = _at(
      today.subtract(const Duration(days: 20)),
      14,
      0,
    );
    await _insertIgnoring(txn, 'appointment', <String, Object?>{
      'id': 9301,
      'pet_id': 9001,
      'clinic_name': 'Paws & Claws Veterinary Clinic',
      'purpose': 'Annual wellness check',
      'scheduled_at': encodeInstant(upcoming),
      'status': 'scheduled',
      'completed_at': null,
      'cancel_reason': null,
      'created_at': encodeInstant(now),
      'updated_at': encodeInstant(now),
    });
    await _insertIgnoring(txn, 'appointment', <String, Object?>{
      'id': 9302,
      'pet_id': 9002,
      'clinic_name': 'Paws & Claws Veterinary Clinic',
      'purpose': 'Dental cleaning',
      'scheduled_at': encodeInstant(pastVisit),
      'status': 'completed',
      'completed_at': encodeInstant(pastVisit.add(const Duration(minutes: 45))),
      'cancel_reason': null,
      'created_at': encodeInstant(now),
      'updated_at': encodeInstant(now),
    });

    // Everyday journal entries.
    await _journal(
      txn,
      id: 9401,
      petId: 9001,
      kind: 'walk',
      occurredAt: _at(today.subtract(const Duration(days: 1)), 7, 10),
      note: 'Morning loop around the block',
      durationMinutes: 30,
      now: now,
    );
    await _journal(
      txn,
      id: 9402,
      petId: 9002,
      kind: 'fed',
      occurredAt: _at(today, 7, 0),
      note: 'Half a can of salmon pâté',
      durationMinutes: null,
      now: now,
    );
    await _journal(
      txn,
      id: 9403,
      petId: 9001,
      kind: 'note',
      occurredAt: _at(today.subtract(const Duration(days: 3)), 20, 15),
      note: 'Slept through the thunderstorm',
      durationMinutes: null,
      now: now,
    );
    await _journal(
      txn,
      id: 9404,
      petId: 9002,
      kind: 'symptom',
      occurredAt: _at(today.subtract(const Duration(days: 5)), 8, 30),
      note: 'Sneezed twice after breakfast',
      durationMinutes: null,
      now: now,
    );
  });
}

/// Removes the demo household (pets cascade to journal/vaccination/health
/// records; demo appointments are deleted explicitly because pet deletion only
/// nulls their `pet_id`).
Future<void> clearDemoHousehold(Database db) async {
  await db.transaction((Transaction txn) async {
    await txn.delete(
      'appointment',
      where: 'id >= ?',
      whereArgs: <Object?>[demoIdFloor],
    );
    await txn.delete(
      'pet',
      where: 'id >= ?',
      whereArgs: <Object?>[demoIdFloor],
    );
  });
}

/// App-facing seeding facade used by `AppServices`.
class SampleDataService {
  SampleDataService({
    required this.database,
    required DateTime Function() currentTime,
  }) : _clock = currentTime;

  final AppDatabase database;
  final DateTime Function() _clock;

  Future<void> seedCatalog() => seedVaccineCatalog(database.database);

  Future<void> seedDemo() =>
      seedDemoHousehold(database.database, now: _clock());

  Future<void> clearDemo() => clearDemoHousehold(database.database);

  Future<bool> hasDemoData() => demoHouseholdExists(database.database);
}

Future<int> _ownerId(DatabaseExecutor db) async {
  final List<Map<String, Object?>> rows = await db.query(
    'owner',
    columns: <String>['id'],
    orderBy: 'id ASC',
    limit: 1,
  );
  if (rows.isEmpty) {
    throw StateError(
      'Seed the demo only after the household owner exists (AppServices.boot).',
    );
  }
  return rows.single['id']! as int;
}

Future<void> _insertIgnoring(
  DatabaseExecutor db,
  String table,
  Map<String, Object?> values,
) {
  return db.insert(table, values, conflictAlgorithm: ConflictAlgorithm.ignore);
}

Future<void> _vaccination(
  DatabaseExecutor db, {
  required int id,
  required int petId,
  required int vaccineTypeId,
  required String name,
  required DateTime vaccinationDate,
  required DateTime nextDueDate,
  required DateTime now,
}) {
  return _insertIgnoring(db, 'vaccination', <String, Object?>{
    'id': id,
    'pet_id': petId,
    'vaccine_type_id': vaccineTypeId,
    'vaccine_name': name,
    'vaccination_date': encodeDate(vaccinationDate),
    'next_due_date': encodeDate(nextDueDate),
    'vet_name': 'Dr. Ana Cruz',
    'created_at': encodeInstant(now),
  });
}

Future<void> _journal(
  DatabaseExecutor db, {
  required int id,
  required int petId,
  required String kind,
  required DateTime occurredAt,
  required String? note,
  required int? durationMinutes,
  required DateTime now,
}) {
  return _insertIgnoring(db, 'journal_entry', <String, Object?>{
    'id': id,
    'pet_id': petId,
    'kind': kind,
    'occurred_at': encodeInstant(occurredAt),
    'note': note,
    'duration_minutes': durationMinutes,
    'created_at': encodeInstant(now),
    'updated_at': encodeInstant(now),
  });
}

/// Local date at a fixed clock time (the demo should read like a real day).
DateTime _at(DateTime day, int hour, int minute) =>
    DateTime(day.year, day.month, day.day, hour, minute);
