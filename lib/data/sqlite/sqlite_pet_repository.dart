/// SQLite pet repository.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/models/pet.dart';
import '../../domain/rules/calendar.dart';
import '../repositories/pet_repository.dart';
import 'mappers.dart';
import 'wire.dart';

class SqlitePetRepository implements PetRepository {
  SqlitePetRepository(this._db, this._clock);

  final Database _db;
  final DateTime Function() _clock;

  static const String _table = 'pet';

  @override
  Future<List<Pet>> list() async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(petFromRow).toList(growable: false);
  }

  @override
  Future<Pet?> findById(int id) async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : petFromRow(rows.single);
  }

  @override
  Future<Pet> create(PetDraft draft) async {
    final int ownerId = await _requireOwnerId();
    final DateTime now = _clock().toUtc();
    final Pet pet = Pet(
      id: 0,
      ownerId: ownerId,
      name: trimRequired(draft.name),
      species: trimRequired(draft.species),
      breed: trimToNull(draft.breed),
      sex: draft.sex,
      dateOfBirth: dateOnly(draft.dateOfBirth),
      weightKg: draft.weightKg,
      microchip: trimToNull(draft.microchip),
      photoPath: trimToNull(draft.photoPath),
      createdAt: now,
      updatedAt: now,
    );
    final Map<String, Object?> values = petToRow(pet)..remove('id');
    final int id = await _db.insert(_table, values);
    return pet.copyWith(id: id);
  }

  @override
  Future<Pet> update(int id, PetDraft draft) async {
    final Pet? existing = await findById(id);
    if (existing == null) {
      throw StateError('No pet with id $id');
    }
    final DateTime now = _clock().toUtc();
    final Pet updated = Pet(
      id: existing.id,
      ownerId: existing.ownerId,
      name: trimRequired(draft.name),
      species: trimRequired(draft.species),
      breed: trimToNull(draft.breed),
      sex: draft.sex,
      dateOfBirth: dateOnly(draft.dateOfBirth),
      weightKg: draft.weightKg,
      microchip: trimToNull(draft.microchip),
      photoPath: trimToNull(draft.photoPath),
      createdAt: existing.createdAt,
      updatedAt: now,
    );
    await _db.update(
      _table,
      petToRow(updated)..remove('id'),
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return updated;
  }

  @override
  Future<void> delete(int id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<int> _requireOwnerId() async {
    final List<Map<String, Object?>> rows = await _db.query(
      'owner',
      columns: <String>['id'],
      orderBy: 'id ASC',
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError(
        'No owner row. Boot through AppServices so the household is created.',
      );
    }
    return rows.single['id']! as int;
  }
}
