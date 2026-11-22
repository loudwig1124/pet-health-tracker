/// Row <-> model mapping for every table. No SQL and no business rules here —
/// mappers convert formats only, repositories own the queries.
library;

import '../../domain/models/appointment.dart';
import '../../domain/models/health_record.dart';
import '../../domain/models/journal_entry.dart';
import '../../domain/models/owner.dart';
import '../../domain/models/pet.dart';
import '../../domain/models/vaccination.dart';
import '../../domain/models/vaccine_type.dart';
import 'wire.dart';

// --- owner -----------------------------------------------------------------

Map<String, Object?> ownerToRow(Owner owner) => <String, Object?>{
  'id': owner.id,
  'name': owner.name,
  'email': owner.email,
  'phone': owner.phone,
  'created_at': encodeInstant(owner.createdAt),
  'updated_at': encodeInstant(owner.updatedAt),
};

Owner ownerFromRow(Map<String, Object?> row) => Owner(
  id: row['id']! as int,
  name: row['name']! as String,
  email: row['email'] as String? ?? '',
  phone: row['phone'] as String? ?? '',
  createdAt: decodeInstant(row['created_at']),
  updatedAt: decodeInstant(row['updated_at']),
);

// --- pet -------------------------------------------------------------------

Map<String, Object?> petToRow(Pet pet) => <String, Object?>{
  'id': pet.id,
  'owner_id': pet.ownerId,
  'name': pet.name,
  'species': pet.species,
  'breed': trimToNull(pet.breed),
  'sex': pet.sex.wire,
  'date_of_birth': encodeDate(pet.dateOfBirth),
  'weight_kg': pet.weightKg,
  'microchip': trimToNull(pet.microchip),
  'photo_path': trimToNull(pet.photoPath),
  'created_at': encodeInstant(pet.createdAt),
  'updated_at': encodeInstant(pet.updatedAt),
};

Pet petFromRow(Map<String, Object?> row) => Pet(
  id: row['id']! as int,
  ownerId: row['owner_id']! as int,
  name: row['name']! as String,
  species: row['species']! as String,
  breed: row['breed'] as String?,
  sex: PetSex.fromWire(row['sex']! as String),
  dateOfBirth: decodeDate(row['date_of_birth']! as String),
  weightKg: decodeWeight(row['weight_kg']),
  microchip: row['microchip'] as String?,
  photoPath: row['photo_path'] as String?,
  createdAt: decodeInstant(row['created_at']),
  updatedAt: decodeInstant(row['updated_at']),
);

// --- journal_entry ---------------------------------------------------------

Map<String, Object?> journalEntryToRow(JournalEntry entry) => <String, Object?>{
  'id': entry.id,
  'pet_id': entry.petId,
  'kind': entry.kind.wire,
  'occurred_at': encodeInstant(entry.occurredAt),
  'note': trimToNull(entry.note),
  'duration_minutes': entry.durationMinutes,
  'created_at': encodeInstant(entry.createdAt),
  'updated_at': encodeInstant(entry.updatedAt),
};

JournalEntry journalEntryFromRow(Map<String, Object?> row) => JournalEntry(
  id: row['id']! as int,
  petId: row['pet_id']! as int,
  kind: JournalKind.fromWire(row['kind']! as String),
  occurredAt: decodeInstant(row['occurred_at']),
  note: row['note'] as String?,
  durationMinutes: row['duration_minutes'] as int?,
  createdAt: decodeInstant(row['created_at']),
  updatedAt: decodeInstant(row['updated_at']),
);

// --- health_record ---------------------------------------------------------

/// Health records are append-only, so there is no update mapper.
Map<String, Object?> healthRecordToRow(HealthRecord record) =>
    <String, Object?>{
      'id': record.id,
      'pet_id': record.petId,
      'recorded_on': encodeDate(record.recordedOn),
      'condition': trimToNull(record.condition),
      'diagnosis': trimToNull(record.diagnosis),
      'treatment': trimToNull(record.treatment),
      'prescribed_medication': trimToNull(record.prescribedMedication),
      'vet_name': trimToNull(record.vetName),
      'created_at': encodeInstant(record.createdAt),
    };

HealthRecord healthRecordFromRow(Map<String, Object?> row) => HealthRecord(
  id: row['id']! as int,
  petId: row['pet_id']! as int,
  recordedOn: decodeDate(row['recorded_on']! as String),
  condition: row['condition'] as String?,
  diagnosis: row['diagnosis'] as String?,
  treatment: row['treatment'] as String?,
  prescribedMedication: row['prescribed_medication'] as String?,
  vetName: row['vet_name'] as String?,
  createdAt: decodeInstant(row['created_at']),
);

// --- vaccine_type ----------------------------------------------------------

Map<String, Object?> vaccineTypeToRow(VaccineType type) => <String, Object?>{
  'id': type.id,
  'name': type.name,
  'interval_months': type.intervalMonths,
  'is_core': type.isCore ? 1 : 0,
  'sort_order': type.sortOrder,
};

VaccineType vaccineTypeFromRow(Map<String, Object?> row) => VaccineType(
  id: row['id']! as int,
  name: row['name']! as String,
  intervalMonths: row['interval_months'] as int?,
  isCore: (row['is_core']! as int) != 0,
  sortOrder: row['sort_order'] as int? ?? 0,
);

// --- vaccination -----------------------------------------------------------

Map<String, Object?> vaccinationToRow(Vaccination vaccination) =>
    <String, Object?>{
      'id': vaccination.id,
      'pet_id': vaccination.petId,
      'vaccine_type_id': vaccination.vaccineTypeId,
      'vaccine_name': vaccination.vaccineName,
      'vaccination_date': encodeDate(vaccination.vaccinationDate),
      'next_due_date': encodeNullableDate(vaccination.nextDueDate),
      'vet_name': trimToNull(vaccination.vetName),
      'created_at': encodeInstant(vaccination.createdAt),
    };

Vaccination vaccinationFromRow(Map<String, Object?> row) => Vaccination(
  id: row['id']! as int,
  petId: row['pet_id']! as int,
  vaccineTypeId: row['vaccine_type_id'] as int?,
  vaccineName: row['vaccine_name']! as String,
  vaccinationDate: decodeDate(row['vaccination_date']! as String),
  nextDueDate: decodeNullableDate(row['next_due_date']),
  vetName: row['vet_name'] as String?,
  createdAt: decodeInstant(row['created_at']),
);

// --- appointment -----------------------------------------------------------

Map<String, Object?> appointmentToRow(Appointment appointment) =>
    <String, Object?>{
      'id': appointment.id,
      'pet_id': appointment.petId,
      'clinic_name': appointment.clinicName,
      'purpose': appointment.purpose,
      'scheduled_at': encodeInstant(appointment.scheduledAt),
      'status': appointment.status.wire,
      'completed_at': appointment.completedAt == null
          ? null
          : encodeInstant(appointment.completedAt!),
      'cancel_reason': trimToNull(appointment.cancelReason),
      'created_at': encodeInstant(appointment.createdAt),
      'updated_at': encodeInstant(appointment.updatedAt),
    };

Appointment appointmentFromRow(Map<String, Object?> row) => Appointment(
  id: row['id']! as int,
  petId: row['pet_id'] as int?,
  clinicName: row['clinic_name']! as String,
  purpose: row['purpose']! as String,
  scheduledAt: decodeInstant(row['scheduled_at']),
  status: AppointmentStatus.fromWire(row['status']! as String),
  completedAt: row['completed_at'] == null
      ? null
      : decodeInstant(row['completed_at']),
  cancelReason: row['cancel_reason'] as String?,
  createdAt: decodeInstant(row['created_at']),
  updatedAt: decodeInstant(row['updated_at']),
);
