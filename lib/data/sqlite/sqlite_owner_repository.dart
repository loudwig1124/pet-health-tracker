/// SQLite owner repository.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/models/owner.dart';
import '../repositories/owner_repository.dart';
import 'mappers.dart';
import 'wire.dart';

class SqliteOwnerRepository implements OwnerRepository {
  SqliteOwnerRepository(this._db, this._clock);

  final Database _db;
  final DateTime Function() _clock;

  static const String _table = 'owner';

  @override
  Future<Owner> load() async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      orderBy: 'id ASC',
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError(
        'No owner row. Boot through AppServices so the household is created.',
      );
    }
    return ownerFromRow(rows.single);
  }

  @override
  Future<Owner> ensureDefault() async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      columns: <String>['id'],
      orderBy: 'id ASC',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return load();
    }
    final DateTime now = _clock().toUtc();
    final int id = await _db.insert(_table, <String, Object?>{
      'name': 'Maria Santos',
      'email': '',
      'phone': '',
      'created_at': encodeInstant(now),
      'updated_at': encodeInstant(now),
    });
    return Owner(id: id, name: 'Maria Santos', createdAt: now, updatedAt: now);
  }

  @override
  Future<Owner> save(OwnerDraft draft) async {
    final Owner current = await load();
    final DateTime now = _clock().toUtc();
    final String name = trimRequired(draft.name);
    if (name.isEmpty) {
      throw ArgumentError.value(draft.name, 'name', 'cannot be empty');
    }
    await _db.update(
      _table,
      <String, Object?>{
        'name': name,
        'email': trimRequired(draft.email),
        'phone': trimRequired(draft.phone),
        'updated_at': encodeInstant(now),
      },
      where: 'id = ?',
      whereArgs: <Object?>[current.id],
    );
    return current.copyWith(
      name: name,
      email: trimRequired(draft.email),
      phone: trimRequired(draft.phone),
      updatedAt: now,
    );
  }
}
