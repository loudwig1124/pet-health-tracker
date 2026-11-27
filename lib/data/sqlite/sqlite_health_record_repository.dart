/// SQLite health-record repository: insert, read, update and delete.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/models/health_record.dart';
import '../../domain/rules/calendar.dart';
import '../repositories/health_record_repository.dart';
import 'mappers.dart';
import 'wire.dart';

class SqliteHealthRecordRepository implements HealthRecordRepository {
  SqliteHealthRecordRepository(this._db, this._clock);

  final Database _db;
  final DateTime Function() _clock;

  static const String _table = 'health_record';

  @override
  Future<List<HealthRecord>> listForPet(int petId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      where: 'pet_id = ?',
      whereArgs: <Object?>[petId],
      orderBy: 'recorded_on DESC, id DESC',
    );
    return rows.map(healthRecordFromRow).toList(growable: false);
  }

  @override
  Future<HealthRecord> append(HealthRecordDraft draft) async {
    final String? condition = trimToNull(draft.condition);
    final String? diagnosis = trimToNull(draft.diagnosis);
    if (condition == null && diagnosis == null) {
      throw ArgumentError('A clinical note needs a condition or a diagnosis');
    }
    final DateTime now = _clock().toUtc();
    final HealthRecord record = HealthRecord(
      id: 0,
      petId: draft.petId,
      recordedOn: dateOnly(draft.recordedOn),
      condition: condition,
      diagnosis: diagnosis,
      treatment: trimToNull(draft.treatment),
      prescribedMedication: trimToNull(draft.prescribedMedication),
      vetName: trimToNull(draft.vetName),
      createdAt: now,
    );
    final Map<String, Object?> values = healthRecordToRow(record)..remove('id');
    final int id = await _db.insert(_table, values);
    return healthRecordFromRow(<String, Object?>{...values, 'id': id});
  }

  @override
  Future<HealthRecord> update(int id, HealthRecordDraft draft) async {
    final String? condition = trimToNull(draft.condition);
    final String? diagnosis = trimToNull(draft.diagnosis);
    if (condition == null && diagnosis == null) {
      throw ArgumentError('A clinical note needs a condition or a diagnosis');
    }
    final HealthRecord record = HealthRecord(
      id: id,
      petId: draft.petId,
      recordedOn: dateOnly(draft.recordedOn),
      condition: condition,
      diagnosis: diagnosis,
      treatment: trimToNull(draft.treatment),
      prescribedMedication: trimToNull(draft.prescribedMedication),
      vetName: trimToNull(draft.vetName),
      createdAt: _clock().toUtc(),
    );
    final Map<String, Object?> values = healthRecordToRow(record)..remove('id');
    final int changed = await _db.update(
      _table,
      values,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    if (changed == 0) {
      throw StateError('Health record $id no longer exists');
    }
    return healthRecordFromRow(<String, Object?>{...values, 'id': id});
  }

  @override
  Future<void> delete(int id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: <Object?>[id]);
  }
}
