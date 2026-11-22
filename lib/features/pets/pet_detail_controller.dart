/// Data for one pet's page: the pet, its vaccination doses and its clinical
/// notes. Clinical notes come from the append-only repository — this controller
/// has no way to change or remove one.
library;

import 'package:flutter/foundation.dart';

import '../../app/app_services.dart';
import '../../domain/models/health_record.dart';
import '../../domain/models/pet.dart';
import '../../domain/models/vaccination.dart';
import '../../domain/models/vaccine_type.dart';
import '../../domain/rules/calendar.dart';
import '../../domain/rules/vaccination_due.dart';

class PetDetailController extends ChangeNotifier {
  PetDetailController({required this.services, required this.petId});

  final AppServices services;
  final int petId;

  Pet? _pet;
  List<Vaccination> _vaccinations = const <Vaccination>[];
  List<HealthRecord> _healthRecords = const <HealthRecord>[];
  List<VaccineType> _vaccineTypes = const <VaccineType>[];
  bool _loading = true;
  bool _notFound = false;
  bool _disposed = false;

  Pet? get pet => _pet;
  bool get isLoading => _loading;
  bool get isNotFound => _notFound;

  /// Doses in display order: the next due date first, untracked doses last.
  List<Vaccination> get vaccinations => _vaccinations;

  /// One pet's clinical notes, newest first (the repository's order).
  List<HealthRecord> get healthRecords => _healthRecords;

  /// Seeded catalog for the vaccination form.
  List<VaccineType> get vaccineTypes => _vaccineTypes;

  DateTime get today => services.today();

  int get dueSoonWindowDays => services.settings.dueSoonWindowDays;

  /// The worst tracked vaccination status, from the shared 30-day-window rule.
  VaccinationDueStatus get dueStatus => petVaccinationDueStatus(
    _vaccinations,
    today,
    windowDays: dueSoonWindowDays,
  );

  /// "Dog · Golden Retriever mix · 5 yr 2 mo · 12.4 kg · Female".
  String get metaLabel {
    final Pet? pet = _pet;
    if (pet == null) {
      return '';
    }
    return <String>[
      pet.speciesLabel,
      ageLabel(pet.dateOfBirth, today),
      services.settings.formatWeight(pet.weightKg),
      pet.sex.label,
    ].join(' · ');
  }

  /// Loads the page. [showSpinner] is false for a silent refresh after a form
  /// save, so the pinned photo and sheet never unmount.
  Future<void> load({bool showSpinner = true}) async {
    if (showSpinner && _pet == null) {
      _loading = true;
      _notify();
    }
    try {
      final Pet? pet = await services.pets.findById(petId);
      if (pet == null) {
        _pet = null;
        _notFound = true;
        _vaccinations = const <Vaccination>[];
        _healthRecords = const <HealthRecord>[];
        _vaccineTypes = const <VaccineType>[];
      } else {
        final List<Vaccination> vaccinations = await services.vaccinations
            .listForPet(petId);
        final List<HealthRecord> healthRecords = await services.healthRecords
            .listForPet(petId);
        final List<VaccineType> vaccineTypes = await services.vaccineTypes
            .list();
        _pet = pet;
        _notFound = false;
        _vaccinations = _sorted(vaccinations);
        _healthRecords = healthRecords;
        _vaccineTypes = vaccineTypes;
      }
    } catch (_) {
      // Keep whatever was on screen; a first load failure is reported by the
      // screen as "could not load" because the pet is still null.
    }
    _loading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Overdue first, then the soonest due date, then doses without a due date by
  /// most recent dose. The resting sheet shows the first row, so it is always
  /// the dose that needs attention.
  static List<Vaccination> _sorted(List<Vaccination> vaccinations) {
    final List<Vaccination> sorted = List<Vaccination>.of(vaccinations);
    sorted.sort((Vaccination a, Vaccination b) {
      final DateTime? aDue = a.nextDueDate;
      final DateTime? bDue = b.nextDueDate;
      if (aDue == null && bDue == null) {
        return b.vaccinationDate.compareTo(a.vaccinationDate);
      }
      if (aDue == null) {
        return 1;
      }
      if (bDue == null) {
        return -1;
      }
      return aDue.compareTo(bDue);
    });
    return List<Vaccination>.unmodifiable(sorted);
  }
}
