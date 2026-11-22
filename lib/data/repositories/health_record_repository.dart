/// Clinical notes. Append-only by design: there is no update or delete method,
/// and the DDL's triggers reject both.
library;

import '../../domain/models/health_record.dart';

abstract class HealthRecordRepository {
  /// One pet's medical history, newest first.
  Future<List<HealthRecord>> listForPet(int petId);

  Future<HealthRecord> append(HealthRecordDraft draft);
}
