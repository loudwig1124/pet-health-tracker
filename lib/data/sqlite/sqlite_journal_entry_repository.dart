/// SQLite journal repository.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/models/journal_entry.dart';
import '../repositories/journal_entry_repository.dart';
import 'mappers.dart';
import 'wire.dart';

class SqliteJournalEntryRepository implements JournalEntryRepository {
  SqliteJournalEntryRepository(this._db, this._clock);

  final Database _db;
  final DateTime Function() _clock;

  static const String _table = 'journal_entry';

  @override
  Future<List<JournalEntry>> listHousehold({int? petId, int limit = 50}) async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      where: petId == null ? null : 'pet_id = ?',
      whereArgs: petId == null ? null : <Object?>[petId],
      orderBy: 'occurred_at DESC',
      limit: limit,
    );
    return rows.map(journalEntryFromRow).toList(growable: false);
  }

  @override
  Future<List<JournalEntry>> listForPet(int petId, {int limit = 50}) =>
      listHousehold(petId: petId, limit: limit);

  @override
  Future<JournalEntry?> findById(int id) async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : journalEntryFromRow(rows.single);
  }

  @override
  Future<JournalEntry> create(JournalDraft draft) async {
    final DateTime now = _clock().toUtc();
    final JournalEntry entry = JournalEntry(
      id: 0,
      petId: draft.petId,
      kind: draft.kind,
      occurredAt: draft.occurredAt.toUtc(),
      note: trimToNull(draft.note),
      durationMinutes: _validDuration(draft.durationMinutes),
      createdAt: now,
      updatedAt: now,
    );
    final Map<String, Object?> values = journalEntryToRow(entry)..remove('id');
    final int id = await _db.insert(_table, values);
    return journalEntryFromRow(<String, Object?>{...values, 'id': id});
  }

  @override
  Future<JournalEntry> update(int id, JournalDraft draft) async {
    final JournalEntry? existing = await findById(id);
    if (existing == null) {
      throw StateError('No journal entry with id $id');
    }
    final DateTime now = _clock().toUtc();
    final JournalEntry updated = JournalEntry(
      id: existing.id,
      petId: draft.petId,
      kind: draft.kind,
      occurredAt: draft.occurredAt.toUtc(),
      note: trimToNull(draft.note),
      durationMinutes: _validDuration(draft.durationMinutes),
      createdAt: existing.createdAt,
      updatedAt: now,
    );
    await _db.update(
      _table,
      journalEntryToRow(updated)..remove('id'),
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return updated;
  }

  @override
  Future<void> delete(int id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  /// The DDL rejects zero or negative durations; treat them as "not recorded".
  int? _validDuration(int? minutes) {
    if (minutes == null || minutes <= 0) {
      return null;
    }
    return minutes;
  }
}
