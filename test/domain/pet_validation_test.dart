import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/models/pet.dart';
import 'package:pet_health_tracker/domain/rules/pet_validation.dart';

PetDraft draft({
  String name = 'Bella',
  String species = 'Dog',
  String? breed = 'Golden Retriever mix',
  PetSex sex = PetSex.female,
  DateTime? dateOfBirth,
  double weightKg = 12.4,
  String? microchip = '900215004123456',
}) {
  return PetDraft(
    name: name,
    species: species,
    breed: breed,
    sex: sex,
    dateOfBirth: dateOfBirth ?? DateTime.utc(2021, 3, 14),
    weightKg: weightKg,
    microchip: microchip,
  );
}

void main() {
  final DateTime today = DateTime.utc(2026, 11, 21);

  test('a complete draft is accepted', () {
    final PetValidationResult result = validatePetDraft(draft(), today: today);
    expect(result.isValid, isTrue);
    expect(result.errors, isEmpty);
  });

  test('the name is required and bounded', () {
    expect(
      validatePetDraft(draft(name: '   '), today: today)[PetField.name],
      isNotNull,
    );
    expect(
      validatePetDraft(draft(name: 'x' * 41), today: today)[PetField.name],
      isNotNull,
    );
  });

  test('the species is required', () {
    expect(
      validatePetDraft(draft(species: ' '), today: today)[PetField.species],
      isNotNull,
    );
  });

  test('a long breed is rejected but an empty breed is fine', () {
    expect(
      validatePetDraft(draft(breed: 'x' * 41), today: today)[PetField.breed],
      isNotNull,
    );
    expect(validatePetDraft(draft(breed: null), today: today).isValid, isTrue);
  });

  test('the birthday cannot be in the future', () {
    expect(
      validatePetDraft(
        draft(dateOfBirth: DateTime.utc(2026, 11, 22)),
        today: today,
      )[PetField.dateOfBirth],
      isNotNull,
    );
    expect(
      validatePetDraft(
        draft(dateOfBirth: DateTime.utc(2026, 11, 21)),
        today: today,
      ).isValid,
      isTrue,
    );
  });

  test('a birthday over 40 years old is treated as a typo', () {
    expect(
      validatePetDraft(
        draft(dateOfBirth: DateTime.utc(1980, 1, 1)),
        today: today,
      )[PetField.dateOfBirth],
      isNotNull,
    );
  });

  test('the weight must be a sane positive number', () {
    expect(
      validatePetDraft(draft(weightKg: 0), today: today)[PetField.weightKg],
      isNotNull,
    );
    expect(
      validatePetDraft(draft(weightKg: -3), today: today)[PetField.weightKg],
      isNotNull,
    );
    expect(
      validatePetDraft(draft(weightKg: 301), today: today)[PetField.weightKg],
      isNotNull,
    );
    expect(
      validatePetDraft(draft(weightKg: 0.4), today: today).isValid,
      isTrue,
    );
  });

  test('the microchip is optional, but must be 9-15 digits when present', () {
    expect(
      validatePetDraft(draft(microchip: null), today: today).isValid,
      isTrue,
    );
    expect(
      validatePetDraft(draft(microchip: '   '), today: today).isValid,
      isTrue,
    );
    expect(
      validatePetDraft(
        draft(microchip: '12345678'),
        today: today,
      )[PetField.microchip],
      isNotNull,
    );
    expect(
      validatePetDraft(
        draft(microchip: '12345ABCDE'),
        today: today,
      )[PetField.microchip],
      isNotNull,
    );
    expect(
      validatePetDraft(draft(microchip: '123456789'), today: today).isValid,
      isTrue,
    );
    expect(
      validatePetDraft(
        draft(microchip: ' 123456789012345 '),
        today: today,
      ).isValid,
      isTrue,
    );
  });

  test('multiple errors are reported together', () {
    final PetValidationResult result = validatePetDraft(
      draft(name: '', species: '', weightKg: -1, microchip: 'abc'),
      today: today,
    );
    expect(
      result.errors.keys,
      containsAll(<PetField>[
        PetField.name,
        PetField.species,
        PetField.weightKg,
        PetField.microchip,
      ]),
    );
  });

  test('normalizeMicrochip trims and nulls blank values', () {
    expect(normalizeMicrochip('  '), isNull);
    expect(normalizeMicrochip(null), isNull);
    expect(normalizeMicrochip(' 900215004123456 '), '900215004123456');
  });

  test('formatWeightKg always shows one decimal', () {
    expect(formatWeightKg(12.44), '12.4 kg');
    expect(formatWeightKg(0), '0.0 kg');
  });
}
