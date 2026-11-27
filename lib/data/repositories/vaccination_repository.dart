/// Vaccination doses and their due dates.
library;

import '../../domain/models/vaccination.dart';

abstract class VaccinationRepository {
  /// One pet's doses, most recent first.
  Future<List<Vaccination>> listForPet(int petId);

  /// Appends a dose. The due-date rule is checked by the database CHECK.
  Future<Vaccination> append(VaccinationDraft draft);

  /// Rewrites an existing dose (a typo in the date or the vet is fixable).
  Future<Vaccination> update(int id, VaccinationDraft draft);

  Future<void> delete(int id);
}
