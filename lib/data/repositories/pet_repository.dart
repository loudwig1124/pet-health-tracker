/// Household pets.
library;

import '../../domain/models/pet.dart';

abstract class PetRepository {
  /// Pets ordered by name.
  Future<List<Pet>> list();

  Future<Pet?> findById(int id);

  /// Creates a pet under the household owner and returns it with its id.
  Future<Pet> create(PetDraft draft);

  /// Replaces the editable fields. Nullable fields are written as provided
  /// (null clears breed/microchip/photo).
  Future<Pet> update(int id, PetDraft draft);

  /// Deletes the pet; journal entries, vaccinations and health records cascade.
  Future<void> delete(int id);
}
