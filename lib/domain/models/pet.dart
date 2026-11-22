/// A household pet.
library;

/// Sex as it is stored (`male`, `female`, `unknown`).
enum PetSex {
  male('male', 'Male'),
  female('female', 'Female'),
  unknown('unknown', 'Unknown');

  const PetSex(this.wire, this.label);

  final String wire;
  final String label;

  static PetSex fromWire(String value) => values.firstWhere(
    (PetSex sex) => sex.wire == value,
    orElse: () => PetSex.unknown,
  );
}

/// An editable pet value object (what the pet form submits).
class PetDraft {
  const PetDraft({
    required this.name,
    required this.species,
    this.breed,
    required this.sex,
    required this.dateOfBirth,
    required this.weightKg,
    this.microchip,
    this.photoPath,
  });

  final String name;
  final String species;
  final String? breed;
  final PetSex sex;
  final DateTime dateOfBirth;
  final double weightKg;
  final String? microchip;
  final String? photoPath;
}

/// The persisted pet.
class Pet {
  const Pet({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.species,
    this.breed,
    required this.sex,
    required this.dateOfBirth,
    required this.weightKg,
    this.microchip,
    this.photoPath,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int ownerId;
  final String name;
  final String species;
  final String? breed;
  final PetSex sex;
  final DateTime dateOfBirth;
  final double weightKg;
  final String? microchip;
  final String? photoPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// "Dog · Golden Retriever mix" (skips the breed when absent).
  String get speciesLabel {
    final String? trimmedBreed = breed?.trim();
    if (trimmedBreed == null || trimmedBreed.isEmpty) {
      return species;
    }
    return '$species · $trimmedBreed';
  }

  PetDraft toDraft() => PetDraft(
    name: name,
    species: species,
    breed: breed,
    sex: sex,
    dateOfBirth: dateOfBirth,
    weightKg: weightKg,
    microchip: microchip,
    photoPath: photoPath,
  );

  Pet copyWith({
    int? id,
    int? ownerId,
    String? name,
    String? species,
    String? breed,
    PetSex? sex,
    DateTime? dateOfBirth,
    double? weightKg,
    String? microchip,
    String? photoPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Pet(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      sex: sex ?? this.sex,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      weightKg: weightKg ?? this.weightKg,
      microchip: microchip ?? this.microchip,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
