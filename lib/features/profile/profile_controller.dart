/// Profile data: the household owner, the pets list and the version-line
/// counts. Settings live on `AppSettings`, which this controller listens to so
/// the three settings rows rebuild in place.
library;

import 'package:flutter/foundation.dart';

import '../../app/app_services.dart';
import '../../app/app_settings.dart';
import '../../domain/models/owner.dart';
import '../../domain/models/pet.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({required this.services}) {
    services.settings.addListener(_onSettingsChanged);
  }

  final AppServices services;

  Owner? _owner;
  List<Pet> _pets = const <Pet>[];
  int _recordCount = 0;
  bool _loading = true;
  Object? _loadError;
  bool _disposed = false;

  Owner? get owner => _owner;
  List<Pet> get pets => _pets;

  /// Journal entries + vaccinations + clinical notes + appointments. The
  /// version line is the demo-friendly count of everything the household has.
  int get recordCount => _recordCount;

  bool get isLoading => _loading;
  Object? get loadError => _loadError;

  AppSettings get settings => services.settings;

  /// Loads the owner, pets and counts. After the first load the previous rows
  /// stay on screen; there is no full-screen spinner on refreshes.
  Future<void> load() async {
    if (_owner == null) {
      _loading = true;
      _notify();
    }
    try {
      final Owner owner = await services.owners.load();
      final List<Pet> pets = await services.pets.list();
      _owner = owner;
      _pets = List<Pet>.unmodifiable(pets);
      _recordCount = await _countRecords(pets);
      _loadError = null;
    } catch (error) {
      _loadError = error;
    }
    _loading = false;
    _notify();
  }

  Future<void> setSampleDataEnabled(bool enabled) async {
    await services.setSampleDataEnabled(enabled);
    await load();
  }

  Future<void> setDueSoonWindowDays(int days) =>
      services.settings.setDueSoonWindowDays(days);

  Future<void> setWeightUnit(WeightUnit unit) =>
      services.settings.setWeightUnit(unit);

  DateTime now() => services.now();

  DateTime today() => services.today();

  Future<int> _countRecords(List<Pet> pets) async {
    // No COUNT query is exposed by the repositories and features must not write
    // SQL, so a bounded household fetch is the safe way to count.
    final int journalEntries = (await services.journal.listHousehold(
      limit: 1000,
    )).length;
    final int appointments =
        (await services.appointments.listUpcoming(now: now())).length +
        (await services.appointments.listHistory(now: now())).length;
    int total = journalEntries + appointments;
    for (final Pet pet in pets) {
      total += (await services.vaccinations.listForPet(pet.id)).length;
      total += (await services.healthRecords.listForPet(pet.id)).length;
    }
    return total;
  }

  void _onSettingsChanged() => _notify();

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    services.settings.removeListener(_onSettingsChanged);
    super.dispose();
  }
}
