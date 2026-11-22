/// Composition root: one object holding the database-backed repositories, the
/// settings and the demo seeder. Feature screens receive it through `AppScope`.
///
/// This is the only place concrete SQLite repositories are constructed, so a
/// feature or test can swap the whole data layer by passing another
/// [AppServices] instance.
library;

import '../data/repositories/appointment_repository.dart';
import '../data/repositories/dashboard_repository.dart';
import '../data/repositories/health_record_repository.dart';
import '../data/repositories/journal_entry_repository.dart';
import '../data/repositories/owner_repository.dart';
import '../data/repositories/pet_repository.dart';
import '../data/repositories/vaccination_repository.dart';
import '../data/repositories/vaccine_type_repository.dart';
import '../data/seed/sample_data_service.dart';
import '../data/sqlite/app_database.dart';
import '../data/sqlite/sqlite_appointment_repository.dart';
import '../data/sqlite/sqlite_dashboard_repository.dart';
import '../data/sqlite/sqlite_health_record_repository.dart';
import '../data/sqlite/sqlite_journal_entry_repository.dart';
import '../data/sqlite/sqlite_owner_repository.dart';
import '../data/sqlite/sqlite_pet_repository.dart';
import '../data/sqlite/sqlite_vaccination_repository.dart';
import '../data/sqlite/sqlite_vaccine_type_repository.dart';
import '../domain/dashboard.dart';
import 'app_settings.dart';

/// Injectable clock: pure code takes `today`/`now` parameters, this is the one
/// place that reads the wall clock.
typedef Clock = DateTime Function();

/// Everything a screen needs, built once at app start.
class AppServices {
  AppServices({required this.database, required this.settings, Clock? clock})
    : _clock = clock ?? DateTime.now {
    final Clock resolvedClock = _clock;
    owners = SqliteOwnerRepository(database.database, resolvedClock);
    pets = SqlitePetRepository(database.database, resolvedClock);
    journal = SqliteJournalEntryRepository(database.database, resolvedClock);
    healthRecords = SqliteHealthRecordRepository(
      database.database,
      resolvedClock,
    );
    vaccinations = SqliteVaccinationRepository(
      database.database,
      resolvedClock,
    );
    vaccineTypes = SqliteVaccineTypeRepository(database.database);
    appointments = SqliteAppointmentRepository(
      database.database,
      resolvedClock,
    );
    dashboard = SqliteDashboardRepository(database.database);
    sampleData = SampleDataService(
      database: database,
      currentTime: resolvedClock,
    );
  }

  final AppDatabase database;
  final AppSettings settings;
  final Clock _clock;

  late final OwnerRepository owners;
  late final PetRepository pets;
  late final JournalEntryRepository journal;
  late final HealthRecordRepository healthRecords;
  late final VaccinationRepository vaccinations;
  late final VaccineTypeRepository vaccineTypes;
  late final AppointmentRepository appointments;
  late final DashboardRepository dashboard;
  late final SampleDataService sampleData;

  /// Current instant (UTC) for screens that need to pass `now`/`today` down.
  DateTime now() => _clock().toUtc();

  /// Current calendar day as UTC midnight, the shape the pure rules expect.
  DateTime today() {
    final DateTime current = _clock();
    return DateTime.utc(current.year, current.month, current.day);
  }

  /// First-run work: the owner row always exists, the catalog is always seeded,
  /// and the demo household follows the persisted toggle.
  Future<void> bootstrap() async {
    await owners.ensureDefault();
    await sampleData.seedCatalog();
    if (settings.sampleDataEnabled) {
      await sampleData.seedDemo();
    }
  }

  /// Keeps the Profile "Sample data" toggle and the rows it controls in step.
  Future<void> setSampleDataEnabled(bool enabled) async {
    if (enabled) {
      await sampleData.seedDemo();
    } else {
      await sampleData.clearDemo();
    }
    await settings.setSampleDataEnabled(enabled);
  }

  /// Home's read model, using the persisted due-soon window.
  Future<Dashboard> loadDashboard() =>
      dashboard.load(now: now(), dueSoonWindowDays: settings.dueSoonWindowDays);

  Future<void> dispose() async {
    settings.dispose();
    await database.close();
  }
}
