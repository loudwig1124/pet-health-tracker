/// Home's state: the dashboard read model, the instant quick log and its undo.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../app/app_services.dart';
import '../../domain/dashboard.dart';
import '../../domain/models/journal_entry.dart';
import '../../domain/models/pet.dart';

/// Loads Home's snapshot and performs the two writes its quick-log row allows:
/// an instant save and its undo. The full form writes through [createEntry].
class HomeController extends ChangeNotifier {
  HomeController(this._services) {
    // Weight unit and the due-soon window both change Home's labels/statuses.
    _services.settings.addListener(_reloadForSettings);
  }

  final AppServices _services;

  Dashboard? _dashboard;
  String? _loadError;
  bool _disposed = false;

  /// The household snapshot, or null until the first successful load.
  Dashboard? get dashboard => _dashboard;

  /// Non-null when the last load failed; the screen offers a retry.
  String? get loadError => _loadError;

  /// The household clock, in the device's calendar (Today/Yesterday labels).
  DateTime get localNow => _services.now().toLocal();

  /// Loads the read model. Safe to call repeatedly; the newest result wins.
  Future<void> load() async {
    _loadError = null;
    _notify();
    try {
      final Dashboard dashboard = await _services.loadDashboard();
      if (_disposed) {
        return;
      }
      _dashboard = dashboard;
    } catch (_) {
      if (_disposed) {
        return;
      }
      _loadError = 'The household could not be loaded.';
    }
    _notify();
  }

  Future<void> refresh() => load();

  /// Saves a quick-log chip: the kind and the current instant, nothing else.
  /// No duration and no quantity are assumed.
  Future<JournalEntry> quickLog({required Pet pet, required JournalKind kind}) {
    return createEntry(
      JournalDraft(petId: pet.id, kind: kind, occurredAt: _services.now()),
    );
  }

  /// Saves the full form's draft and refreshes the snapshot.
  Future<JournalEntry> createEntry(JournalDraft draft) async {
    final JournalEntry entry = await _services.journal.create(draft);
    await load();
    return entry;
  }

  /// Deletes a just-saved entry (the snackbar's undo) and refreshes.
  Future<void> undo(JournalEntry entry) async {
    await _services.journal.delete(entry.id);
    await load();
  }

  void _reloadForSettings() {
    unawaited(load());
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _services.settings.removeListener(_reloadForSettings);
    super.dispose();
  }
}
