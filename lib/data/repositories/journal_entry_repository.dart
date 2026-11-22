/// Everyday household log entries (editable, unlike clinical records).
library;

import '../../domain/models/journal_entry.dart';

abstract class JournalEntryRepository {
  /// Household feed, newest first. [petId] narrows it to one pet.
  Future<List<JournalEntry>> listHousehold({int? petId, int limit = 50});

  /// One pet's entries, newest first.
  Future<List<JournalEntry>> listForPet(int petId, {int limit = 50});

  Future<JournalEntry?> findById(int id);

  Future<JournalEntry> create(JournalDraft draft);

  Future<JournalEntry> update(int id, JournalDraft draft);

  Future<void> delete(int id);
}
