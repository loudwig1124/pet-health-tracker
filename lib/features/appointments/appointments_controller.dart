/// Appointments state: the Upcoming/Past segmented view, the quiet pet filter
/// and the state-machine transitions the actions sheet may offer.
library;

import 'package:flutter/foundation.dart';

import '../../app/app_services.dart';
import '../../data/repositories/appointment_repository.dart';
import '../../domain/models/appointment.dart';
import '../../domain/models/pet.dart';
import '../../domain/rules/appointment_rules.dart';

/// The two slices of the appointment list.
enum AppointmentsTab { upcoming, past }

/// Loads and mutates the household appointments.
class AppointmentsController extends ChangeNotifier {
  AppointmentsController(this._services);

  final AppServices _services;

  AppointmentsTab _tab = AppointmentsTab.upcoming;
  int? _petFilterId;
  List<Appointment> _appointments = const <Appointment>[];
  List<Pet> _pets = const <Pet>[];
  bool _isLoading = true;
  String? _loadError;
  bool _disposed = false;

  AppointmentsTab get tab => _tab;

  /// Null means "all pets".
  int? get petFilterId => _petFilterId;

  /// Rows for the current tab and pet filter.
  List<Appointment> get appointments => _appointments;

  /// Household pets offered by the filter; empty until the first load.
  List<Pet> get pets => _pets;

  bool get isLoading => _isLoading;

  /// Non-null when the last load failed; the screen offers a retry.
  String? get loadError => _loadError;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    _notify();
    await _fetch();
    _isLoading = false;
    _notify();
  }

  Future<void> refresh() => load();

  Future<void> selectTab(AppointmentsTab tab) async {
    if (tab == _tab) {
      return;
    }
    _tab = tab;
    _notify();
    await load();
  }

  Future<void> selectPet(int? petId) async {
    if (petId == _petFilterId) {
      return;
    }
    _petFilterId = petId;
    _notify();
    await load();
  }

  /// Pet name for a card; a deleted pet leaves the visit under the household.
  String petLabelFor(int? petId) {
    if (petId == null) {
      return 'Household';
    }
    for (final Pet pet in _pets) {
      if (pet.id == petId) {
        return pet.name;
      }
    }
    return 'Pet';
  }

  /// The status moves the UI may offer for [appointment] right now. Terminal
  /// appointments offer none, and a no-show only appears once the scheduled
  /// time has passed. The repository enforces the same rule on write.
  List<AppointmentStatus> availableTransitions(Appointment appointment) {
    if (appointment.status.isTerminal) {
      return const <AppointmentStatus>[];
    }
    final DateTime now = _services.now();
    return <AppointmentStatus>[
      for (final AppointmentStatus to in const <AppointmentStatus>[
        AppointmentStatus.completed,
        AppointmentStatus.cancelled,
        AppointmentStatus.noShow,
      ])
        if (_check(appointment, to, now: now).isAllowed) to,
    ];
  }

  Future<Appointment> complete(int id) async {
    final Appointment updated = await _services.appointments.updateStatus(
      id,
      AppointmentStatus.completed,
      now: _services.now(),
    );
    await _reloadAfterMutation();
    return updated;
  }

  Future<Appointment> cancel(int id, String reason) async {
    final Appointment updated = await _services.appointments.updateStatus(
      id,
      AppointmentStatus.cancelled,
      now: _services.now(),
      cancelReason: reason,
    );
    await _reloadAfterMutation();
    return updated;
  }

  Future<Appointment> markNoShow(int id) async {
    final Appointment updated = await _services.appointments.updateStatus(
      id,
      AppointmentStatus.noShow,
      now: _services.now(),
    );
    await _reloadAfterMutation();
    return updated;
  }

  /// Cancels [id] as "rescheduled" and books the new time, atomically.
  Future<RescheduleResult> reschedule(
    int id, {
    required DateTime newScheduledAt,
  }) async {
    final RescheduleResult result = await _services.appointments.reschedule(
      id,
      newScheduledAt: newScheduledAt,
      now: _services.now(),
    );
    await _reloadAfterMutation();
    return result;
  }

  AppointmentTransition _check(
    Appointment appointment,
    AppointmentStatus to, {
    required DateTime now,
  }) {
    return checkAppointmentTransition(
      from: appointment.status,
      to: to,
      scheduledAt: appointment.scheduledAt,
      now: now,
      // Cancelling is always offered from `scheduled`; the sheet collects the
      // reason before the write, so probe with a placeholder here.
      cancelReason: to == AppointmentStatus.cancelled ? 'reason' : null,
    );
  }

  Future<void> _fetch() async {
    try {
      final DateTime now = _services.now();
      final List<Pet> pets = await _services.pets.list();
      final List<Appointment> appointments = _tab == AppointmentsTab.upcoming
          ? await _services.appointments.listUpcoming(
              now: now,
              petId: _petFilterId,
            )
          : await _services.appointments.listHistory(
              now: now,
              petId: _petFilterId,
            );
      _pets = pets;
      _appointments = appointments;
      _loadError = null;
    } catch (_) {
      _loadError = 'The appointments could not be loaded.';
    }
  }

  Future<void> _reloadAfterMutation() async {
    await _fetch();
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
