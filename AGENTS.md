# AGENTS.md — Pet Health Tracker (Flutter)

The implementation contract for every member of the build. **Read this before
editing anything.** If something here looks wrong, report it to the captain
instead of silently working around it.

## What this app is

An offline pet health and vet appointment tracker for a single household: one
owner, several pets, a household journal, vet appointments, vaccinations and
append-only clinical notes. Phone only (portrait-first), no auth, no network, no
backend, no analytics. The database is the only source of truth.

## Stack (locked — do not add alternatives)

| Concern | Choice |
| --- | --- |
| SDK | Flutter **3.47.5** stable / Dart **3.13.4** (workspace SDK copy, run via `./tool/fv`) |
| Routing | `go_router` **18** with a `StatefulShellRoute.indexedStack` |
| Storage | `sqflite` **2.4** + hand-written SQL in `db/schema.sql`. No ORM, no drift, no codegen |
| State | `ChangeNotifier` controllers + `AppScope` (InheritedWidget). No Bloc/Riverpod/provider |
| Dates | `intl` for display; stored formats below |
| Tests | `flutter_test` + `sqflite_common_ffi` against the real `db/schema.sql` |

Offline only: never add HTTP clients, auth, telemetry or a remote config.

## Commands (run from `Pet Health Tracker/`)

```bash
./tool/fv pub get
./tool/fv analyze
./tool/fv test                    # everything
./tool/fv test test/domain        # pure rules
./tool/fv test test/data          # schema + repositories (real SQLite via FFI)
./tool/fv test test/app           # shell / boot widget tests
./tool/fv test test/features/home # a feature area
# formatting — pass your own paths (see "Scope-limited tool runs" below)
./tool/format lib/features/home test/features/home
./tool/format --set-exit-if-changed lib/features/home test/features/home
# schema smoke test: imports exactly as the app applies it
sqlite3 :memory: ".read db/schema.sql"
```

**Sandbox rules**
- Never run bare `flutter`/`dart`: the system SDK writes its cache outside the
  workspace and the repo path contains parentheses (a Flutter 3.47.5 otool bug on
  `flutter test`).
- `.flutter-sdk`, `.pub-cache` and `.tool-home` are gitignored workspace
  artifacts. `.flutter-sdk` is a relative symlink to the sibling
  `Final Project/.flutter-sdk` (the patched SDK copy). **Never copy the 4 GB SDK
  into this project and never delete `.tool-home/` or `.pub-cache/`.**
- See `tool/README.md` for the SDK/runner recipe and the one-line patch.
- **Scope-limited tool runs.** While other members are writing, run formatting
  and analysis against your own task's paths only:
  `./tool/format lib/features/home test/features/home` and
  `./tool/fv analyze lib/features/home test/features/home`. A repo-wide
  `./tool/format lib test` rewrote eight files owned by another member mid-task
  this session, and a full-tree run reads everyone's half-written files. The
  full-tree `./tool/format --set-exit-if-changed lib test` and
  `./tool/fv analyze` belong to the integration pass, when a single member is the
  only writer.

## Folder layout and write ownership

| Path | Contents | Owner |
| --- | --- | --- |
| `lib/app/` | composition root (`di.dart`, `app_services.dart`), router, shell, `AppSettings`, `AppScope` | foundation |
| `lib/domain/` | immutable models + pure rules (no Flutter, no sqflite, no `dart:io`) | foundation |
| `lib/data/` | SQLite bootstrap, mappers, repositories, seeding, settings store — **all SQL** | foundation |
| `lib/ui/` | theme tokens + presentation-only kit + `intl` format helpers | foundation |
| `lib/features/<area>/` | screens + controllers for one area | the feature task that owns it |
| `test/domain/`, `test/data/`, `test/app/` | foundation tests | foundation |
| `test/features/<area>/` | feature tests | the feature task that owns it |
| `db/schema.sql`, `pubspec.yaml`, `AGENTS.md`, `tool/` | foundation | foundation |
| `README.md`, `docs/` | demo/rehearsal docs | QA/integration |

Feature tasks **never** edit `lib/app/`, `lib/ui/`, `lib/domain/`, `lib/data/`,
`lib/main.dart` or `pubspec.yaml`. If a screen needs a new model field, widget or
repository method, request it through the captain; do not fork the shared layer.

## Dependency rules

- `lib/domain/**` — pure Dart. No `package:flutter/`, no `package:sqflite`, no
  `dart:io`, no `rootBundle`. Takes `today`/`now` as parameters.
- `lib/data/**` — SQL, mappers, repositories, seed, settings file. **SQL text
  lives here and nowhere else.** Only this layer (and `lib/app/di.dart`) may
  import `package:sqflite/`.
- `lib/ui/**` — presentation only: theme tokens, kit widgets, `intl` formats. No
  repositories, no database, no `dart:io`.
- `lib/features/**` — screens + `ChangeNotifier` controllers. Read through
  repository interfaces from `AppScope.of(context).services`; never write SQL and
  never construct a database.
- `lib/app/**` — composition root: the only place concrete SQLite repositories
  are constructed.

The rules are enforced by `test/data/no_sql_outside_data_test.dart`.

## Domain API (`lib/domain/`)

Immutable models: `Owner`, `Pet`, `JournalEntry`, `HealthRecord`, `Vaccination`,
`VaccineType`, `Appointment`; each form submits a `XxxDraft`. Models carry the
storage ids and timestamps; drafts do not.

Enums on the wire:

- `PetSex` → `male | female | unknown`
- `JournalKind` → `walk | fed | meds | grooming | training | note | symptom`
  (`JournalKind.quickLog` is the Home chip order: walk, fed, meds, note)
- `AppointmentStatus` → `scheduled | completed | cancelled | no_show`
- `VaccinationDueStatus` → `overdue | due_soon | up_to_date`

Pure rules:

```dart
// lib/domain/rules/vaccination_due.dart — the 30-day window, today is a parameter
VaccinationDueStatus vaccinationDueStatus(DateTime? nextDueDate, DateTime today,
    {int windowDays = defaultDueSoonWindowDays});
VaccinationDueStatus petVaccinationDueStatus(Iterable<Vaccination>, DateTime today, {int windowDays});
Vaccination? nextDueVaccination(Iterable<Vaccination>);   // earliest due date, overdue included

// lib/domain/rules/appointment_rules.dart — the state machine
AppointmentTransition checkAppointmentTransition({from, to, scheduledAt, now, cancelReason});
Appointment applyAppointmentTransition(Appointment, AppointmentStatus to, {required DateTime now, String? cancelReason});
class AppointmentRuleException implements Exception { final AppointmentTransitionBlock block; }
```

The machine: `scheduled` → `completed | cancelled | no_show`; terminal states are
immutable; `no_show` only when `now` is strictly after `scheduled_at`; cancelling
always needs a reason (`reschedule` writes "rescheduled").

```dart
// lib/domain/rules/pet_validation.dart
PetValidationResult validatePetDraft(PetDraft draft, {required DateTime today});
String? normalizeMicrochip(String? raw);
String formatWeightKg(double kg);

// lib/domain/rules/calendar.dart — date-only arithmetic
DateTime dateOnly(DateTime), addMonths(DateTime, int), ageInYears(DateTime, DateTime),
String ageLabel(DateTime birth, DateTime today);
```

`lib/domain/dashboard.dart` is Home's read model: `Dashboard { owner, pets,
nextAppointment, recentEntries, generatedAt }` and `PetOverview { pet, dueStatus,
nextVaccination, nextAppointment, lastVisit }`. `PetOverview.dueStatus` is the
worst tracked status; a pet with no tracked due dates reads `upToDate`.

## Data and app API (`lib/data/`, `lib/app/`)

```dart
// lib/app/app_scope.dart — the only way screens get data
final AppServices services = AppScope.of(context);
final Owner owner = await services.owners.load();
final bool demoOn = services.settings.sampleDataEnabled;
```

`AppScope.of` registers an inherited dependency, so resolve services in
`build`/`didChangeDependencies` — **not** in `initState`, where creating that
dependency is an error. Capture the services in `didChangeDependencies` and hand
them to your controller there. There is no separate non-dependent accessor, so
`initState` is never the place to look services up. `AppScope.maybeOf` exists only
for widgets that must render without services.

```dart
// lib/app/app_services.dart
services.owners         // OwnerRepository:  load(), ensureDefault(), save(OwnerDraft)
services.pets           // PetRepository:    list(), findById(id), create(PetDraft), update(id, PetDraft), delete(id)
services.journal        // JournalEntryRepository: listHousehold({petId, limit}), listForPet(id, {limit}), findById, create(JournalDraft), update(id, JournalDraft), delete(id)
services.healthRecords  // HealthRecordRepository: listForPet(id), append(HealthRecordDraft)  — append-only
services.vaccinations   // VaccinationRepository: listForPet(id), append(VaccinationDraft)
services.vaccineTypes   // VaccineTypeRepository: list()
services.appointments   // AppointmentRepository: listUpcoming({now, petId}), listHistory({now, petId}), findById, create(AppointmentDraft), updateStatus(id, status, {now, cancelReason}), reschedule(id, {newScheduledAt, now})
services.dashboard      // DashboardRepository: load({now, dueSoonWindowDays}) — prefer services.loadDashboard()
services.sampleData     // SampleDataService: seedCatalog(), seedDemo(), clearDemo(), hasDemoData()
services.settings       // AppSettings (ChangeNotifier): sampleDataEnabled, dueSoonWindowDays, weightUnit, formatWeight(kg)
services.now()          // UTC instant; pass it down instead of calling DateTime.now() in a screen
services.today()        // UTC midnight; what the pure rules expect
services.loadDashboard()      // uses the persisted due-soon window
services.setSampleDataEnabled(bool) // seeds/clears demo rows AND persists the toggle
```

Repositories take explicit `now`/`today` arguments where time matters; only
`AppServices` reads the wall clock. Throw `AppointmentRuleException` from
`updateStatus`/`reschedule` when the state machine blocks a move — the UI checks
`checkAppointmentTransition` first to grey out impossible actions.

Screens rebuild on preference changes with
`ListenableBuilder(listenable: services.settings, builder: ...)`. Controllers are
per-feature `ChangeNotifier`s; dispose them with the screen.

### Seeding

`AppDatabase.openDefault()` creates the database from `db/schema.sql`;
`AppServices.bootstrap()` then ensures the single `owner` row, seeds the vaccine
catalog (always) and the demo household (when the persisted toggle is on, default
yes). Demo rows live at ids `>= 9000` under the household owner, so they can be
removed without touching the owner's own rows. `services.setSampleDataEnabled`
is the only correct toggle path.

## UI kit and theme (`lib/ui/`)

Tokens (`lib/ui/theme/app_theme.dart`) — never hard-code hex, radii or type sizes:

- `AppColors`: paper `#FAF8F5`, surface `#FFFFFF`, ink `#1B1A18`, secondary
  `#6B6660`, hairline `#ECE7E1`, accent `#0E6B5F`, overdue `#B3261E` on
  `#FCEBEA`, due soon `#A16000` on `#FDF3E3`, up to date `#2F6B3F` on `#EAF3EC`.
- `AppRadii`: card 20, sheet 28, chip 16. `AppSpacing`: 4/8/12/16/24/32.
- `AppTextStyles`: display 30, name 27, body 15, caption 12, section label
  tracked caps. The theme maps them into `ThemeData` (Material 3).

Kit (`lib/ui/kit/`): `SectionLabel` (uppercases + tracks, optional trailing),
`AppChip` (`AppChip.due(status)`, `AppChip.appointment(status)`, tones), `AppCard`,
`ListRow` (60 px rhythm, one hairline), `StatusDot` (`StatusDot.due(status)`),
`EmptyState`, `PrimaryButton`/`SecondaryButton`, `showAppSheet`/`AppSheetBody`
(28 px sheet, keyboard-aware). Status colours come from
`lib/ui/theme/status_style.dart` (`vaccinationStatusPalette`,
`appointmentStatusPalette`) — never invent a status colour locally.

Date/number labels: `lib/ui/format/app_formats.dart` (`formatDayMonth`,
`formatFullDate`, `formatWeekdayShort`, `formatTimeOfDay`, `formatDateTimeLabel`,
`formatRelativeDay`, `formatWeightKg`); weights go through
`services.settings.formatWeight(kg)`.

## Navigation shell (`lib/app/router.dart`, `lib/app/shell/`)

- Four destinations in a `StatefulShellRoute.indexedStack`: `/home` (name
  `home`), `/journal`, `/appointments`, `/profile`. Tab state is retained per
  branch; branches are built lazily on first visit. The builders point at the
  real screens: `HomeScreen` (wired with `onOpenPet` → `PetRoutes.open`),
  `JournalScreen`, `AppointmentsScreen` and `ProfileScreen`.
- The pet page is the one top-level route outside the shell (`PetRoutes.route()`,
  `/pets/:petId`), so its photo covers the bottom bar. Home cards and Profile pet
  rows open it through `PetRoutes.open`, which completes when the page pops so
  the caller can reload.
- The raised centre action opens the real quick-action sheet
  (`showCentreActionSheet`): **Book a vet visit** (`showAppointmentBookingSheet`),
  **Log an entry** (pet chooser, then `showQuickLogForm`) and **Add a health
  record** (pet chooser, then `showHealthRecordForm`). There is no placeholder
  sheet and no `lib/app/placeholders/` directory.
- When a branch becomes active again its screen reloads: the shell keeps
  offstage branches mounted inside `TickerMode`, and Home/Journal/Appointments
  use that to refresh. Writes made in another tab therefore show up without a
  manual pull-to-refresh.
- `Routes` holds every path/name — never hard-code route strings in a screen.
- Feature screens are full `Scaffold`s (the shell provides the bar as the outer
  Scaffold's `bottomNavigationBar`). Keep the top app bar inside the screen.

## Database conventions

- 7 tables: `owner`, `pet`, `journal_entry`, `health_record`, `vaccination`,
  `appointment`, `vaccine_type`. The DDL is the contract; read its header.
- Date-only columns are `TEXT 'YYYY-MM-DD'`; instants are ISO-8601 UTC with
  milliseconds (`2026-11-21T08:30:00.000Z`). Use `lib/data/sqlite/wire.dart`.
- `pet.microchip` is nullable and UNIQUE. `pet.date_of_birth` and
  `pet.weight_kg` are required.
- `vaccination.next_due_date` must be `NULL` or strictly after
  `vaccination_date`.
- `appointment.completed_at` is non-null exactly when `status = 'completed'`;
  cancelled rows always carry `cancel_reason`. Deleting a pet leaves its
  appointments (`pet_id` becomes `NULL`) but deletes journal/vaccination/health
  rows.
- `health_record` is append-only: no update/delete API, and the DDL triggers
  reject both (the only allowed delete is the pet-delete cascade). Clinical notes
  get no edit or delete affordance.
- Migrations are hand-written in `lib/data/sqlite/app_database.dart`; version 1
  ships now. Never change an existing table without a migration step.
- `db/schema.sql` must stay importable by
  `sqlite3 :memory: ".read db/schema.sql"` and is bundled as an asset.

## Conventions

- Naming: `snake_case` tables/columns; `lowerCamelCase` Dart fields; repositories
  `XxxRepository` + `SqliteXxxRepository`; mappers `xxxToRow`/`xxxFromRow`;
  screens `XxxScreen`; controllers `XxxController`.
- Every screen uses the kit; no raw hex colours, no `TextStyle(fontSize: 13)`.
- Empty states use `EmptyState`; primary action uses `PrimaryButton`.
- Accessibility: tap targets ≥ 44 px, `Semantics` labels on icon-only actions,
  no text below 11 px.
- No `print` in `lib/`; no TODO stubs; no dead code.
- Tests: pure rules in `test/domain/`, SQL/seed in `test/data/`, screens in
  `test/features/<area>/`. Use `openHarness()` from `test/data/test_support.dart`
  for a real in-memory/file SQLite database with the shipped DDL.

## Definition of done (feature tasks)

1. `./tool/fv analyze` reports no issues.
2. `./tool/fv test` is green (or at least the feature's tests plus the full
   suite — another member may be mid-edit; report exactly what you ran).
3. Screens use the kit/theme and the domain rules (no duplicated due-date logic,
   no local status colours, no SQL).
4. Journal entries are editable; clinical records stay append-only.
5. Report the exact commands, their output, and every file touched.
