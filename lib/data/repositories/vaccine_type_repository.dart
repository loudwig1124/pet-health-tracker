/// The seeded vaccine catalog used by the vaccination form.
library;

import '../../domain/models/vaccine_type.dart';

abstract class VaccineTypeRepository {
  /// Core vaccines first, then catalog order.
  Future<List<VaccineType>> list();
}
