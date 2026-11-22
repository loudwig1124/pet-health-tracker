/// App-wide preferences surfaced on the Profile screen: sample data toggle,
/// due-soon window and weight unit.
library;

import 'package:flutter/foundation.dart';

import '../data/settings/settings_store.dart';
import '../domain/rules/vaccination_due.dart';

/// Weight unit offered by the Profile settings row.
enum WeightUnit {
  kg('kg', 'Kilograms'),
  lb('lb', 'Pounds');

  const WeightUnit(this.wire, this.label);

  final String wire;
  final String label;

  static WeightUnit fromWire(String? value) => values.firstWhere(
    (WeightUnit unit) => unit.wire == value,
    orElse: () => WeightUnit.kg,
  );
}

/// Mutable, listenable settings. Controllers and screens listen with
/// `ListenableBuilder`; toggling sample data also seeds/clears rows through
/// `AppServices.setSampleDataEnabled`.
class AppSettings extends ChangeNotifier {
  AppSettings({SettingsStore? settingsStore}) : _store = settingsStore;

  final SettingsStore? _store;

  bool _sampleDataEnabled = true;
  int _dueSoonWindowDays = defaultDueSoonWindowDays;
  WeightUnit _weightUnit = WeightUnit.kg;

  /// Demo household visibility. On by default so the first launch has content.
  bool get sampleDataEnabled => _sampleDataEnabled;

  /// Vaccinations due within this many days read "due soon".
  int get dueSoonWindowDays => _dueSoonWindowDays;

  WeightUnit get weightUnit => _weightUnit;

  /// Loads persisted values, keeping defaults for missing/corrupt entries.
  Future<void> load() async {
    final Map<String, Object?> values =
        await _store?.read() ?? const <String, Object?>{};

    final Object? enabled = values['sampleDataEnabled'];
    if (enabled is bool) {
      _sampleDataEnabled = enabled;
    }
    final Object? window = values['dueSoonWindowDays'];
    if (window is int && window > 0 && window <= 365) {
      _dueSoonWindowDays = window;
    }
    final Object? unit = values['weightUnit'];
    if (unit is String) {
      _weightUnit = WeightUnit.fromWire(unit);
    }
    notifyListeners();
  }

  /// Sets the demo-data preference. Callers use
  /// `AppServices.setSampleDataEnabled` so rows and preference stay in sync.
  Future<void> setSampleDataEnabled(bool value) async {
    if (_sampleDataEnabled == value) {
      return;
    }
    _sampleDataEnabled = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setDueSoonWindowDays(int value) async {
    if (value <= 0 || value > 365 || _dueSoonWindowDays == value) {
      return;
    }
    _dueSoonWindowDays = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setWeightUnit(WeightUnit value) async {
    if (_weightUnit == value) {
      return;
    }
    _weightUnit = value;
    notifyListeners();
    await _persist();
  }

  /// "12.4 kg" or "27.3 lb".
  String formatWeight(double weightKg) {
    if (_weightUnit == WeightUnit.lb) {
      return '${(weightKg * 2.2046226218).toStringAsFixed(1)} lb';
    }
    return '${weightKg.toStringAsFixed(1)} kg';
  }

  Future<void> _persist() async {
    await _store?.write(<String, Object?>{
      'sampleDataEnabled': _sampleDataEnabled,
      'dueSoonWindowDays': _dueSoonWindowDays,
      'weightUnit': _weightUnit.wire,
    });
  }
}
