/// Pet form validation. Pure: the form passes what it has, this returns the
/// per-field errors so the UI can place them next to the right input.
library;

import 'dart:math' as math;

import '../models/pet.dart';
import 'calendar.dart';

/// A field the pet form can show an error under.
enum PetField {
  name('Name'),
  species('Species'),
  breed('Breed'),
  dateOfBirth('Date of birth'),
  weightKg('Weight'),
  microchip('Microchip');

  const PetField(this.label);

  final String label;
}

/// Validation outcome. [errors] is empty when the draft is accepted.
class PetValidationResult {
  const PetValidationResult(this.errors);

  final Map<PetField, String> errors;

  bool get isValid => errors.isEmpty;

  String? operator [](PetField field) => errors[field];
}

/// A microchip must be 9–15 digits (ISO 11784/11785 chips are 15).
final RegExp _microchipPattern = RegExp(r'^\d{9,15}$');

/// Trims a microchip; blank becomes null so the UNIQUE column does not store ''.
String? normalizeMicrochip(String? raw) {
  final String? trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

/// Validates a pet draft as of [today]. Pet age cannot be negative and a pet
/// older than 40 years is almost certainly a typo.
PetValidationResult validatePetDraft(
  PetDraft draft, {
  required DateTime today,
}) {
  final Map<PetField, String> errors = <PetField, String>{};

  final String name = draft.name.trim();
  if (name.isEmpty) {
    errors[PetField.name] = 'A pet needs a name';
  } else if (name.length > 40) {
    errors[PetField.name] = 'Keep the name under 40 characters';
  }

  final String species = draft.species.trim();
  if (species.isEmpty) {
    errors[PetField.species] = 'Pick a species';
  } else if (species.length > 30) {
    errors[PetField.species] = 'Keep the species under 30 characters';
  }

  final String? breed = draft.breed?.trim();
  if (breed != null && breed.length > 40) {
    errors[PetField.breed] = 'Keep the breed under 40 characters';
  }

  final DateTime birth = dateOnly(draft.dateOfBirth);
  final DateTime reference = dateOnly(today);
  if (birth.isAfter(reference)) {
    errors[PetField.dateOfBirth] = 'The birthday cannot be in the future';
  } else if (birth.isBefore(DateTime.utc(reference.year - 40, 1, 1))) {
    errors[PetField.dateOfBirth] = 'Check the birthday — that is over 40 years';
  }

  if (draft.weightKg.isNaN || draft.weightKg <= 0) {
    errors[PetField.weightKg] = 'Weight must be greater than zero';
  } else if (draft.weightKg > 300) {
    errors[PetField.weightKg] = 'Weight must be 300 kg or less';
  }

  final String? microchip = normalizeMicrochip(draft.microchip);
  if (microchip != null && !_microchipPattern.hasMatch(microchip)) {
    errors[PetField.microchip] = 'A microchip is 9–15 digits';
  }

  return PetValidationResult(errors);
}

/// Formats a weight for display. Kept next to validation so the form and the
/// card agree on the "1 decimal" rule.
String formatWeightKg(double weightKg) {
  final double clamped = math.max(0, weightKg);
  return '${clamped.toStringAsFixed(1)} kg';
}
