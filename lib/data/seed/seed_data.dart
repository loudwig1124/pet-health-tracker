/// The vaccine catalog shipped with the app. Fixed ids so the demo household
/// can reference them and `INSERT OR IGNORE` stays idempotent.
library;

/// One catalog row.
class VaccineTypeSeed {
  const VaccineTypeSeed({
    required this.id,
    required this.name,
    required this.intervalMonths,
    required this.isCore,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final int? intervalMonths;
  final bool isCore;
  final int sortOrder;
}

/// Dog and cat vaccines a household vet is likely to record.
const List<VaccineTypeSeed> vaccineTypeSeeds = <VaccineTypeSeed>[
  VaccineTypeSeed(
    id: 1,
    name: 'Rabies',
    intervalMonths: 12,
    isCore: true,
    sortOrder: 10,
  ),
  VaccineTypeSeed(
    id: 2,
    name: 'DHPP',
    intervalMonths: 12,
    isCore: true,
    sortOrder: 20,
  ),
  VaccineTypeSeed(
    id: 3,
    name: 'Leptospirosis',
    intervalMonths: 12,
    isCore: false,
    sortOrder: 30,
  ),
  VaccineTypeSeed(
    id: 4,
    name: 'Bordetella',
    intervalMonths: 12,
    isCore: false,
    sortOrder: 40,
  ),
  VaccineTypeSeed(
    id: 5,
    name: 'FVRCP',
    intervalMonths: 12,
    isCore: true,
    sortOrder: 50,
  ),
  VaccineTypeSeed(
    id: 6,
    name: 'FeLV',
    intervalMonths: 12,
    isCore: false,
    sortOrder: 60,
  ),
  VaccineTypeSeed(
    id: 7,
    name: 'Deworming',
    intervalMonths: 3,
    isCore: false,
    sortOrder: 70,
  ),
];
