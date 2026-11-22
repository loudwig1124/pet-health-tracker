/// SQLite appointment repository. Every status write goes through the pure
/// state machine in `lib/domain/rules/appointment_rules.dart`.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/models/appointment.dart';
import '../../domain/rules/appointment_rules.dart';
import '../repositories/appointment_repository.dart';
import 'mappers.dart';
import 'wire.dart';

class SqliteAppointmentRepository implements AppointmentRepository {
  SqliteAppointmentRepository(this._db, this._clock);

  final Database _db;
  final DateTime Function() _clock;

  static const String _table = 'appointment';

  @override
  Future<List<Appointment>> listUpcoming({
    required DateTime now,
    int? petId,
  }) async {
    final String instant = encodeInstant(now);
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      where: petId == null
          ? "status = 'scheduled' AND scheduled_at > ?"
          : "pet_id = ? AND status = 'scheduled' AND scheduled_at > ?",
      whereArgs: petId == null ? <Object?>[instant] : <Object?>[petId, instant],
      orderBy: 'scheduled_at ASC',
    );
    return rows.map(appointmentFromRow).toList(growable: false);
  }

  @override
  Future<List<Appointment>> listHistory({
    required DateTime now,
    int? petId,
  }) async {
    final String instant = encodeInstant(now);
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      where: petId == null
          ? "(status <> 'scheduled' OR scheduled_at <= ?)"
          : "pet_id = ? AND (status <> 'scheduled' OR scheduled_at <= ?)",
      whereArgs: petId == null ? <Object?>[instant] : <Object?>[petId, instant],
      orderBy: 'scheduled_at DESC',
    );
    return rows.map(appointmentFromRow).toList(growable: false);
  }

  @override
  Future<Appointment?> findById(int id) => _find(_db, id);

  @override
  Future<Appointment> create(AppointmentDraft draft) async {
    final DateTime now = _clock().toUtc();
    final Appointment appointment = Appointment(
      id: 0,
      petId: draft.petId,
      clinicName: trimRequired(draft.clinicName),
      purpose: trimRequired(draft.purpose),
      scheduledAt: draft.scheduledAt.toUtc(),
      createdAt: now,
      updatedAt: now,
    );
    final Map<String, Object?> values = appointmentToRow(appointment)
      ..remove('id');
    final int id = await _db.insert(_table, values);
    return appointmentFromRow(<String, Object?>{...values, 'id': id});
  }

  @override
  Future<Appointment> updateStatus(
    int id,
    AppointmentStatus status, {
    required DateTime now,
    String? cancelReason,
  }) {
    return _db.transaction(
      (Transaction txn) => _updateStatus(
        txn,
        id,
        status,
        now: now.toUtc(),
        cancelReason: cancelReason,
      ),
    );
  }

  @override
  Future<RescheduleResult> reschedule(
    int id, {
    required DateTime newScheduledAt,
    required DateTime now,
  }) {
    final DateTime instant = now.toUtc();
    return _db.transaction((Transaction txn) async {
      final Appointment previous = await _updateStatus(
        txn,
        id,
        AppointmentStatus.cancelled,
        now: instant,
        cancelReason: 'rescheduled',
      );
      final Appointment next = Appointment(
        id: 0,
        petId: previous.petId,
        clinicName: previous.clinicName,
        purpose: previous.purpose,
        scheduledAt: newScheduledAt.toUtc(),
        createdAt: instant,
        updatedAt: instant,
      );
      final Map<String, Object?> values = appointmentToRow(next)..remove('id');
      final int newId = await txn.insert(_table, values);
      return RescheduleResult(
        previous: previous,
        next: appointmentFromRow(<String, Object?>{...values, 'id': newId}),
      );
    });
  }

  Future<Appointment?> _find(DatabaseExecutor db, int id) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : appointmentFromRow(rows.single);
  }

  Future<Appointment> _updateStatus(
    DatabaseExecutor db,
    int id,
    AppointmentStatus status, {
    required DateTime now,
    String? cancelReason,
  }) async {
    final Appointment? existing = await _find(db, id);
    if (existing == null) {
      throw StateError('No appointment with id $id');
    }
    final Appointment updated = applyAppointmentTransition(
      existing,
      status,
      now: now,
      cancelReason: cancelReason,
    );
    await db.update(
      _table,
      appointmentToRow(updated)..remove('id'),
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return updated;
  }
}
