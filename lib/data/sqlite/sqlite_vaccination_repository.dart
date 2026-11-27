/// SQLite vaccination repository.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/models/vaccination.dart';
import '../../domain/rules/calendar.dart';
import '../repositories/vaccination_repository.dart';
import 'mappers.dart';
import 'wire.dart';

class SqliteVaccinationRepository implements VaccinationRepository {
  SqliteVaccinationRepository(this._db, this._clock);

  final Database _db;
  final DateTime Function() _clock;

  static const String _table = 'vaccination';

  @override
  Future<List<Vaccination>> listForPet(int petId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      where: 'pet_id = ?',
      whereArgs: <Object?>[petId],
      orderBy: 'vaccination_date DESC, id DESC',
    );
    return rows.map(vaccinationFromRow).toList(growable: false);
  }

  @override
  Future<Vaccination> append(VaccinationDraft draft) async {
    final DateTime vaccinationDate = dateOnly(draft.vaccinationDate);
    final DateTime? nextDueDate = draft.nextDueDate == null
        ? null
        : dateOnly(draft.nextDueDate!);
    if (nextDueDate != null && !nextDueDate.isAfter(vaccinationDate)) {
      throw ArgumentError.value(
        draft.nextDueDate,
        'nextDueDate',
        'must be after the vaccination date',
      );
    }
    final Vaccination vaccination = Vaccination(
      id: 0,
      petId: draft.petId,
      vaccineTypeId: draft.vaccineTypeId,
      vaccineName: trimRequired(draft.vaccineName),
      vaccinationDate: vaccinationDate,
      nextDueDate: nextDueDate,
      vetName: trimToNull(draft.vetName),
      createdAt: _clock().toUtc(),
    );
    final Map<String, Object?> values = vaccinationToRow(vaccination)
      ..remove('id');
    final int id = await _db.insert(_table, values);
    return vaccinationFromRow(<String, Object?>{...values, 'id': id});
  }

  @override
  Future<Vaccination> update(int id, VaccinationDraft draft) async {
    final DateTime vaccinationDate = dateOnly(draft.vaccinationDate);
    final DateTime? nextDueDate = draft.nextDueDate == null
        ? null
        : dateOnly(draft.nextDueDate!);
    if (nextDueDate != null && !nextDueDate.isAfter(vaccinationDate)) {
      throw ArgumentError.value(
        draft.nextDueDate,
        'nextDueDate',
        'must be after the vaccination date',
      );
    }
    final Vaccination vaccination = Vaccination(
      id: id,
      petId: draft.petId,
      vaccineTypeId: draft.vaccineTypeId,
      vaccineName: trimRequired(draft.vaccineName),
      vaccinationDate: vaccinationDate,
      nextDueDate: nextDueDate,
      vetName: trimToNull(draft.vetName),
      createdAt: _clock().toUtc(),
    );
    final Map<String, Object?> values = vaccinationToRow(vaccination)
      ..remove('id');
    final int changed = await _db.update(
      _table,
      values,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    if (changed == 0) {
      throw StateError('Vaccination $id no longer exists');
    }
    return vaccinationFromRow(<String, Object?>{...values, 'id': id});
  }

  @override
  Future<void> delete(int id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: <Object?>[id]);
  }
}
