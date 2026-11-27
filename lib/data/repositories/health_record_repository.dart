/// Clinical notes. Append-only by design: there is no update or delete method,
/// and the DDL's triggers reject both.
library;

import '../../domain/models/health_record.dart';

abstract class HealthRecordRepository {
  /// One pet's medical history, newest first.
  Future<List<HealthRecord>> listForPet(int petId);

  Future<HealthRecord> append(HealthRecordDraft draft);

  /// Rewrites an existing note. Clinical notes are editable since schema v2.
  Future<HealthRecord> update(int id, HealthRecordDraft draft);

  Future<void> delete(int id);
}
