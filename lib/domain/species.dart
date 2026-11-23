/// The species offered by the pet form and onboarding.
///
/// Kept small and local: a household tracks fur pets and the occasional bird or
/// reptile, not a zoological catalogue. "Other" leaves the door open without a
/// free-text field.
library;

/// Common household pets, in the order they are offered.
const List<String> kCommonSpecies = <String>[
  'Dog',
  'Cat',
  'Rabbit',
  'Hamster',
  'Guinea pig',
  'Bird',
  'Ferret',
  'Turtle',
  'Fish',
  'Other',
];

/// [species] plus the offered list, so an existing pet whose species was typed
/// before this list existed still shows up in the dropdown.
List<String> speciesOptions(String? species) {
  final String? trimmed = species?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return kCommonSpecies;
  }
  if (kCommonSpecies.contains(trimmed)) {
    return kCommonSpecies;
  }
  return <String>[trimmed, ...kCommonSpecies];
}
