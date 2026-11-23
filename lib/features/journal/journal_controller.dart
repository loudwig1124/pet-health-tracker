/// Journal feed state: household entries, the pets they belong to, and the
/// edit/delete operations the feed allows.
///
/// Journal rows are ordinary editable rows. The append-only rule covers
/// clinical notes (`health_record`), not these.
library;

import 'package:flutter/foundation.dart';

import '../../app/app_services.dart';
import '../../domain/models/journal_entry.dart';
import '../../domain/models/pet.dart';

/// Loads and mutates the household journal.
class JournalController extends ChangeNotifier {
  JournalController(this._services);

  final AppServices _services;

  List<JournalEntry> _entries = const <JournalEntry>[];
  List<Pet> _pets = const <Pet>[];
  int? _petFilterId;
  Map<int, String> _petNames = const <int, String>{};
  bool _isLoading = true;
  String? _loadError;
  bool _disposed = false;

  /// Household feed, newest first (the repository's order).
  List<JournalEntry> get entries => _entries;

  /// Pets offered by the filter chips.
  List<Pet> get pets => _pets;

  /// Null means the whole household.
  int? get petFilterId => _petFilterId;

  Future<void> selectPet(int? petId) async {
    if (_petFilterId == petId) {
      return;
    }
    _petFilterId = petId;
    _notify();
    // Reload scoped to the pet: filtering the household's latest 50 rows hid a
    // busy household's older entries for a quiet pet.
    await load();
  }

  /// The rows the screen shows: everything, or one pet's share of it.
  List<JournalEntry> get visibleEntries => _petFilterId == null
      ? _entries
      : _entries
            .where((JournalEntry entry) => entry.petId == _petFilterId)
            .toList(growable: false);

  bool get isLoading => _isLoading;

  /// Non-null when the last load failed; the screen offers a retry.
  String? get loadError => _loadError;

  /// "Bella" for a live pet. Journal rows always have one: deleting a pet
  /// cascades to its journal entries.
  String petNameFor(int petId) => _petNames[petId] ?? 'Pet';

  /// Today in the device's calendar, the reference for Today/Yesterday labels.
  DateTime get localToday {
    final DateTime local = _services.now().toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    _notify();
    try {
      final List<JournalEntry> entries = await _services.journal.listHousehold(
        petId: _petFilterId,
      );
      final List<Pet> pets = await _services.pets.list();
      _entries = entries;
      _pets = pets;
      _petNames = <int, String>{for (final Pet pet in pets) pet.id: pet.name};
    } catch (_) {
      _loadError = 'The journal could not be loaded.';
    }
    _isLoading = false;
    _notify();
  }

  /// Saves the edit sheet's values and refreshes the feed.
  Future<JournalEntry> updateEntry(int id, JournalDraft draft) async {
    final JournalEntry updated = await _services.journal.update(id, draft);
    await _reloadAfterMutation();
    return updated;
  }

  Future<void> deleteEntry(int id) async {
    await _services.journal.delete(id);
    await _reloadAfterMutation();
  }

  Future<void> _reloadAfterMutation() async {
    _entries = await _services.journal.listHousehold(petId: _petFilterId);
    _loadError = null;
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
}
