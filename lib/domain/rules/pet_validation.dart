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

/// One Unicode letter somewhere in the text: names are names, not numbers.
final RegExp _hasLetter = RegExp(r'\p{L}', unicode: true);

/// Weight input: 1–3 integer digits, optional comma/point and up to 2 decimals.
/// Deliberately rejects exponent notation, which `double.tryParse` accepts
/// ("1e5" is a very over-the-board pet).
final RegExp _weightPattern = RegExp(r'^\d{1,3}([.,]\d{1,2})?$');

/// The heaviest plausible pet, in kilograms. Anything above this is a typo.
const double kMaxWeightKg = 300;

/// Parses a weight field, or null when the text is not a usable weight.
double? parseWeightInput(String raw) {
  final String text = raw.trim();
  if (!_weightPattern.hasMatch(text)) {
    return null;
  }
  final double value = double.parse(text.replaceAll(',', '.'));
  return value > 0 && value <= kMaxWeightKg ? value : null;
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
  } else if (!_hasLetter.hasMatch(name)) {
    errors[PetField.name] = 'A name needs at least one letter';
  } else if (name.length > 40) {
    errors[PetField.name] = 'Keep the name under 40 characters';
  }

  final String species = draft.species.trim();
  if (species.isEmpty) {
    errors[PetField.species] = 'Pick a species';
  } else if (!_hasLetter.hasMatch(species)) {
    errors[PetField.species] = 'A species needs at least one letter';
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

  if (draft.weightKg.isNaN || draft.weightKg.isInfinite || draft.weightKg <= 0) {
    errors[PetField.weightKg] = 'Weight must be greater than zero';
  } else if (draft.weightKg > kMaxWeightKg) {
    errors[PetField.weightKg] = 'Weight must be ${kMaxWeightKg.toInt()} kg or less';
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
