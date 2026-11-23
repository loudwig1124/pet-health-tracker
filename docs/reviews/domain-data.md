# Domain & data review — `lib/domain`, `lib/data`, `db/schema.sql`

Review round: read-only. No file under `lib/`, `test/` or `db/` was modified.
Commands run: `./tool/fv analyze lib/domain lib/data` (clean) and
`./tool/fv test test/domain test/data` (86 tests, all green). Additional
reproduction of the critical finding was done with `sqlite3 :memory:` loading
`db/schema.sql` exactly as the CLI smoke test does.

## Verdict (5 lines)

1. Structurally the foundation is sound: the domain is pure Dart, all SQL is in
   `lib/data`, the DDL is the shipped asset, and the tests exercise real SQLite.
2. **One CRITICAL:** the demo-row "ids ≥ 9000" convention is incompatible with
   `AUTOINCREMENT`, so toggling Sample data off deletes the household's own
   pets, journal, clinical notes, vaccinations and visits. Reproduced end to end.
3. **Two HIGH:** a booster never supersedes the previous dose's due date (a
   current pet stays Overdue forever), and Home's due status uses the UTC
   calendar day while every other screen uses the local day.
4. **Five MEDIUM:** last-visit dates are UTC-based, the demo freezes after its
   first seed, photo files orphan on failed saves, settings writes are not
   atomic, and the journal's per-pet filter reads one capped household page.
5. Everything is a contained fix (S/M) — no architectural rewrite is needed, but
   the CRITICAL must be fixed before any release or further feature work.

## Findings

| # | Severity | File:line | Issue |
| --- | --- | --- | --- |
| D1 | CRITICAL | `lib/data/seed/sample_data_service.dart:240` | Clearing demo rows deletes user rows: `AUTOINCREMENT` puts every new household row into the `>= 9000` demo range. |
| D2 | HIGH | `lib/domain/rules/vaccination_due.dart:58` | A newer booster never supersedes an older dose's past due date, so a current pet reads Overdue forever. |
| D3 | HIGH | `lib/data/sqlite/sqlite_dashboard_repository.dart:29` | Home's vaccination due status uses the UTC calendar day; every other screen uses the local day. |
| D4 | MEDIUM | `lib/data/sqlite/sqlite_dashboard_repository.dart:166` | "Last visit" is dated by the UTC day of `completedAt`, not the local day the owner saw. |
| D5 | MEDIUM | `lib/data/seed/sample_data_service.dart:49` | Demo dates are only relative to the first seed (`INSERT OR IGNORE` + fixed ids); the demo goes stale within days. |
| D6 | MEDIUM | `lib/data/pet_photos_io.dart:27` | Picked photos are copied eagerly and orphan on any failed/cancelled save or repeat pick. |
| D7 | MEDIUM | `lib/data/settings/settings_store_io.dart:33` | Settings writes truncate in place, and `read()` only handles `FormatException`; one IO error aborts boot. |
| D8 | MEDIUM | `lib/data/repositories/journal_entry_repository.dart:11` | `listForPet` is dead; the per-pet feed filters one 50-row household page in memory, hiding older entries. |
| D9 | LOW | `lib/domain/models/pet.dart:83` | Dead/duplicated API surface in domain and data (unused `toDraft`s, read-model fields, `daysBetween`, `formatWeightKg`, two photo-capability flags). |
| D10 | LOW | `db/schema.sql:41` | `PRAGMA journal_mode = WAL` is stripped and never set in `onConfigure`, contrary to the schema header and its test's rationale. |
| D11 | LOW | `lib/data/seed/sample_data_service.dart:60` | The demo persona ("Maria Santos") is written to the real owner row and survives after sample data is cleared. |

## [CRITICAL] Demo cleanup deletes user rows: AUTOINCREMENT poisons the reservation (D1)

**File:** `lib/data/seed/sample_data_service.dart:240` (`clearDemoHousehold`; the
floor is declared at `:18`, the demo-present check at `:34`, the first fixed id
at `:66`)

**Issue:** demo rows are inserted with explicit high ids under an
`INTEGER PRIMARY KEY AUTOINCREMENT` schema (pet 9001/9002, vaccination
9101–9104, health_record 9201/9202, appointment 9301/9302, journal_entry
9401–9404). SQLite updates `sqlite_sequence` to the largest explicit id, so the
next row the household creates lands inside the "demo" range and every later row
stays there for the life of the database:

- enable Sample data, add the owner's own pet "Coco" → `pet.id = 9003`;
- Coco's first journal entry → 9405, first clinical note → 9203, first visit
  → 9303;
- Profile → Sample data off (`AppServices.setSampleDataEnabled(false)` →
  `clearDemoHousehold`) runs `DELETE FROM appointment WHERE id >= 9000` and
  `DELETE FROM pet WHERE id >= 9000`; the pet delete cascades to Coco's journal
  entries, vaccinations and clinical notes.

One switch tap (the Profile switch has no confirmation dialog,
`lib/features/profile/profile_screen.dart:238`) destroys the user's own pet and
its whole clinical history. Reproduced against the shipped DDL: before clear
pets = `Bella, Miso, Coco`; after clear pets = `(none)`, the household journal = 0 rows,
Coco's clinical notes = 0 rows, and Coco's own appointment is gone. Because
`AUTOINCREMENT` never reuses ids, even after a clear the next user pet is 9004 —
the reservation is permanently broken after the first demo seed, not just once.

The same floor makes `demoHouseholdExists` unable to tell demo rows from user
rows: once Coco exists at 9003, the check is already true for a reason that has
nothing to do with the demo. Any fix that deletes exact ids must change this
check too, and today `hasDemoData()` is only consumed by tests.

**Why existing guards do not catch it:** the DDL itself is correct — the failure
is the convention. `test/data/repositories_test.dart:511-527` and
`test/data/bootstrap_test.dart` toggle sample data on an **empty** user dataset,
so no user row ever gets an id ≥ 9000; line 516's `hasDemoData() == false`
assertion passes only because that test never adds a user row at all. `AGENTS.md`
(§ "Seeding") states the id convention as guaranteed. Analyzer is clean and all
86 tests pass.

**Proposed minimal fix:** stop using an open-ended id range for tables that also
hold user rows. Smallest safe change: delete the exact seeded ids (define one
`const List<int>` per table from the same constants the seeder uses, and
`DELETE ... WHERE id IN (...)`), and make `demoHouseholdExists` check those exact
ids. Guard `AppServices.setSampleDataEnabled(false)` so it only clears when demo
rows are actually present. More robust when a migration is next written: seed
demo rows with negative ids (AUTOINCREMENT never generates them) or add a
`demo` marker column, and never delete by range. Update AGENTS.md. Effort: **S**
(exact ids) / **M** (negative ids or marker column).

## [HIGH] A new booster never clears the old dose's due status (D2)

**File:** `lib/domain/rules/vaccination_due.dart:58` (`petVaccinationDueStatus`;
the same defect is in `nextDueVaccination` at `:79`)

**Issue:** the status is computed over *every* dose row, and every dose keeps its
own `next_due_date` (the form always prefills it from the catalog interval at
`lib/features/pets/forms/vaccination_form_sheet.dart:74-81`). There is no update
API for vaccinations, so an old row's due date is never superseded:

1. Rabies recorded 2024-11-01 with next due 2025-11-01 (now overdue);
2. the owner records the 2026 booster with next due 2027-11-01;
3. the 2024 row still has a past due date, so `petVaccinationDueStatus` returns
   `overdue` (worst of the doses) and `nextDueVaccination` keeps returning the
   2024 dose.

The pet is current but Home says "Rabies · N days overdue", the pet page's
aggregate badge says Overdue, and the only workaround is to delete a dose — which the
repository has no API for. Recording a booster is the normal
vaccination workflow, so every pet that ever had an overdue dose stays flagged.

**Why existing guards do not catch it:** `test/domain/vaccination_due_test.dart`
only builds doses whose `name`s differ (Rabies/DHPP/FeLV), so no test ever has
two doses of the same vaccine; the repository test appends one dose per pet
(`test/data/repositories_test.dart:228-258`); the seeded demo has exactly one
dose per vaccine type, so the dashboard screenshot looks right.

**Proposed minimal fix:** reduce to the latest dose per vaccine before ranking.
Key doses by `vaccineTypeId ?? vaccineName.trim().toLowerCase()` and keep the one
with the greatest `vaccinationDate` (tie: greatest id); run
`vaccinationDueStatus` / `nextDueVaccination` over that reduced list. Add two
unit tests: "an overdue dose followed by a newer future-due dose reads up to
date", and "the latest dose wins even if an older one is more urgent".
`lib/features/pets/pet_detail_screen.dart:574` computes a per-row status for the
old dose too (it will still read Overdue); mark superseded rows or list only the
latest dose per vaccine. Effort: **M**.

## [HIGH] Home's due status uses the UTC calendar day; the rest of the app uses the local day (D3)

**File:** `lib/data/sqlite/sqlite_dashboard_repository.dart:29` (the reference is
passed to the rule at `:86-90`)

**Issue:** `AppServices.loadDashboard()` passes `now()` — a UTC instant
(`lib/app/app_services.dart:109-110`). The repository keeps
`reference = now.toUtc()` and hands it to `petVaccinationDueStatus`, whose
`dateOnly()` takes the UTC year/month/day. Every other calendar-day decision in
the app uses the local day: `AppServices.today()` builds
`DateTime.utc(local.y, local.m, local.d)` (`app_services.dart:83-86`),
`PetDetailController.dueStatus` uses it, the journal labels use
`_services.now().toLocal()`, and the Home card's own "days overdue" label uses
`_services.today()` (`lib/features/home/home_screen.dart:346`).

In Asia/Manila (UTC+8) between 00:00 and 07:59 local, the UTC date is still
yesterday: a booster due yesterday is `overdue` on the pet page but `dueSoon` in
the dashboard, so the Home chip paints the amber "due soon" tone
(`AppChip.due`, tone from `overview.dueStatus`, `lib/features/home/widgets/pet_card.dart:86`)
while its own label reads "Rabies · 1 days overdue". In a UTC-negative zone the
inverse happens: a booster due today reads Overdue before the local day ends.

**Why existing guards do not catch it:** every data/domain test uses
`fixedNow = 2026-11-21T09:30Z` (`test/data/test_support.dart:15`), a mid-day UTC
instant whose UTC and local calendar days coincide in any normal test
environment. No test varies the clock near local midnight or asserts the
dashboard status equals the pet-page status.

**Proposed minimal fix:** pass the calendar day explicitly rather than deriving
it from an instant: add `required DateTime today` to `DashboardRepository.load`
(set by `AppServices.loadDashboard()` from its existing `today()`), use it for
the vaccination due rule, and keep `now` for the appointment instant
comparisons. A test can then pass a UTC `now` and a different calendar `today`
and assert the status without depending on the process timezone. The one-line
alternative — `final DateTime today = dateOnly(now.toLocal());` inside the
repository — is correct in production but not deterministically testable on CI.
Effort: **S**.

## [MEDIUM] "Last visit" is dated by the UTC day, not the day the owner saw (D4)

**File:** `lib/data/sqlite/sqlite_dashboard_repository.dart:166` (the correct
local-day pattern already exists at `:128`)

**Issue:** `_lastVisitFor` computes
`dateOnly(appointment.completedAt ?? appointment.scheduledAt)`. `completedAt` is
a UTC instant, so its UTC calendar date is used. A visit completed at 06:00 on
22 Nov in Manila is stored `2026-11-21T22:00Z` → `lastVisit` becomes 21 Nov and
the pet card prints yesterday's date
(`formatDayMonth` formats the fields as given, so the wrong day is shown as
is). It also competes with `health_record.recorded_on`, a local date the form
picked, so the two inputs to `lastVisit` are on different calendars and the
displayed day depends on which row happens to be later. `_nextDayFor` on
line 128 already does `.toLocal()`, so two appointment-derived values on the
same card use different calendars.

**Why existing guards do not catch it:** the same fixed 09:30 UTC clock; no test
has a completed visit near local midnight or checks the boundary.

**Proposed minimal fix:** `dateOnly((appointment.completedAt ?? appointment.scheduledAt).toLocal())`
— one line. To make the conversion testable on any host, extract it as a tiny
`localDate(DateTime)` helper next to `dateOnly` in `calendar.dart` and test it
there. Effort: **S**.

## [MEDIUM] The demo household freezes at its first seed despite the "never stale" comment (D5)

**File:** `lib/data/seed/sample_data_service.dart:49` (comment; inserts
`:66-233`, `INSERT OR IGNORE` helper at `:290`)

**Issue:** every demo row is `INSERT OR IGNORE` with a fixed id, and
`bootstrap()` re-runs `seedDemo()` on every launch while the toggle is on
(`lib/app/app_services.dart:90-96`), but existing rows are never updated. The
"relative to now" dates are therefore relative only to the *first* seed. Five
days later the demo's only upcoming appointment (id 9301,
`today + 5` at `:162`) is in the past, so Home's appointment section is empty;
ten days later Miso's "due soon" FeLV dose (id 9104, `today + 10` at `:133`) is
overdue as well and the demo shows two overdue pets — exactly the state the demo
is supposed to show off. The catalog has the same property: editing
`seed_data.dart` (e.g. an interval correction) never reaches an existing install
because `seedVaccineCatalog` is also `INSERT OR IGNORE` (`:21-31`).

**Why existing guards do not catch it:** `test/data/repositories_test.dart:505-508`
only asserts that bootstrapping twice does not *duplicate* rows; no test advances
the clock between two seeds and inspects the dates.

**Proposed minimal fix:** make the intended semantics explicit. To keep the demo
alive: inside the existing transaction, delete the demo ids and re-insert them
(then only call this from the explicit toggle-on path, not every boot; note that
this discards user edits/notes added to demo pets — acceptable for sample data,
but call it out). To keep it frozen: correct the comment and seed only when
`demoHouseholdExists()` is false. For the catalog, use an upsert keyed on `name`
(or `id`) so corrections reach existing installs. Effort: **S/M**.

## [MEDIUM] Picked photos are copied eagerly and orphan on any failed save or repeat pick (D6)

**File:** `lib/data/pet_photos_io.dart:27` (the copy is written at `:44-47`)

**Issue:** `pickFromLibrary` immediately copies the chosen image into
`<databases>/pet_photos/` and returns the path. Only two call sites ever delete a
file: a successful edit that replaces/clears the photo
(`lib/features/pets/forms/pet_form_sheet.dart:136-140`) and `resetHousehold`
(`lib/app/app_services.dart:120-123`). If the save then fails — the form's own
"microchip is unique" case at `pet_form_sheet.dart:145-154` — or the user closes
the sheet after picking, the file stays forever; picking twice on the way to one
save orphans the first pick. Nothing sweeps the folder, so retries/abandoned
forms accumulate unreferenced images, and any future pet-delete path that does
not call `deleteOwned` adds more.

**Why existing guards do not catch it:** there is no test reference to
`PetPhotos`, `pickFromLibrary` or `deleteOwned` (the file system is outside the
DB transaction and the widget tests), and `deleteOwned` is only reached from the
two success paths above.

**Proposed minimal fix:** keep the pick in a temp file and move/copy it into the
owned folder only after the repository save succeeds, or — cheaper and enough —
add an ownership sweep at boot: list the photos folder, read
`SELECT photo_path FROM pet`, and delete unreferenced files older than a few
minutes (so an in-flight pick is safe). Storing the file name relative to the
photos folder instead of the absolute path would let the sweep and `deleteOwned`
work without depending on the current container path. Effort: **M**.

## [MEDIUM] Settings error paths: a non-atomic write can erase every preference, and an IO error aborts boot (D7)

**File:** `lib/data/settings/settings_store_io.dart:33` (`read` at `:17-30`)

**Issue:** `write` truncates `settings.json` in place. A crash/force-quit/power
loss between the truncate and the last byte leaves invalid JSON; the next launch
returns `{}`, `AppSettings.load()` falls back to defaults
(`lib/app/app_settings.dart:49-66`), so the weight unit and due-soon window
silently revert and `sampleDataEnabled` reads false while the demo rows are still
in the database — the toggle and its rows are now out of sync (turning it on
re-seeds; turning it off deletes). The doc comment claims "a corrupt file falls
back to defaults instead of blocking launch", but only `FormatException` is
caught: a `FileSystemException` from `exists`/`readAsString` (permissions,
storage failure, deletion race) escapes `load()` and out of `openAppServices`
(`lib/app/di.dart:28-41`), so boot fails with no UI.

**Why existing guards do not catch it:** `test/data/bootstrap_test.dart:144-149`
writes `'{not json'` and asserts the default fallback — it covers the
`FormatException` path only. No test injects an IO error, and the write cannot be
interrupted in a test.

**Proposed minimal fix:** write to `settings.json.tmp` and `rename` over the
target (atomic on both platforms), and wrap the whole read in
`try/catch (Object)` returning `{}` after a failed read. Separately, reconcile on
boot: when the loaded toggle is false, call `clearDemo()` so the flag and the
rows cannot drift (do this **after** D1 is fixed, or the reconcile will delete
user rows). Effort: **S**.

## [MEDIUM] The journal's per-pet filter reads one capped household page; `listForPet` is dead (D8)

**File:** `lib/data/repositories/journal_entry_repository.dart:11`
(implementation at `:32-33`; consumer
`lib/features/journal/journal_controller.dart:46-49, 73`)

**Issue:** `listForPet(petId)` exists (implemented as `listHousehold(petId:)`)
but nothing in `lib/` calls it — only `test/data/repositories_test.dart:142`.
`JournalController.load()` calls `listHousehold()` with the default `limit: 50`
and filters in memory. `listHousehold` has no offset/cursor, so the newest 50
household entries are the only rows the app can ever show: after a few weeks of
quick logging, selecting a quiet pet's chip shows an empty or truncated feed even
though its entries exist (they fell off the 50-row page), and no older entry is
reachable at all.

**Why existing guards do not catch it:** the journal widget tests use far fewer
than 50 entries, and the data test calls `listForPet` directly, so the dead
method looks covered.

**Proposed minimal fix:** in `JournalController`, call
`services.journal.listForPet(id)` when `petFilterId != null` (keep the in-memory
filter only for the "All" chip), or add `limit/offset` to the repository and page
the feed. Delete whichever of `listHousehold` / `listForPet` stops being used.
Effort: **S**.

## [LOW] Dead and duplicated API surface across domain and data (D9)

**File:** `lib/domain/models/pet.dart:83` (full list below)

**Issue:** nothing in `lib/` calls: `Pet.toDraft`
(`lib/domain/models/pet.dart:83`), `Owner.toDraft` (`lib/domain/models/owner.dart:40`),
`JournalEntry.toDraft` (`lib/domain/models/journal_entry.dart:81`),
`Appointment.toDraft` (`lib/domain/models/appointment.dart:68`). Never read in
`lib/`: `Dashboard.nextAppointment` (`lib/domain/dashboard.dart:25`) and
`Dashboard.generatedAt` (`:31`), `PetOverview.nextAppointment` (`:56`) and
`.nextAppointments` (`:60`) — production reads only `Dashboard.nextAppointments`
(`:29`). `calendar.daysBetween` (`lib/domain/rules/calendar.dart:22`) is tested
but unused while `lib/features/home/home_screen.dart:346` re-implements it.
`formatWeightKg` (`lib/domain/rules/pet_validation.dart:98`) is tested but dead
because weights go through `AppSettings.formatWeight`
(`lib/app/app_settings.dart:98`) — two formatters that already disagree on
negatives. `PetPhotos.supported` (`lib/data/pet_photos_io.dart:12`) and
`supportsPhotoPicking` (`lib/platform/photo_files_io.dart:16`) duplicate each
other and neither is consulted: on the web build the pet form still shows
"Choose photo" and the stub returns null, so the tap ends in a "No photo chosen."
snackbar instead of the control being hidden.

**Why existing guards do not catch it:** the analyzer does not warn on unused
public members, `./tool/fv analyze lib/domain lib/data` is clean, and AGENTS.md
lists some of these (`formatWeightKg`, `hasDemoData`) as API.

**Proposed minimal fix:** delete the four `toDraft` methods and the four unread
read-model fields; have the Home due label call `daysBetween` or delete it; keep
`AppSettings.formatWeight` as the only weight formatter (delete
`formatWeightKg`); collapse the two photo capability flags into
`supportsPhotoPicking` and hide the photo row when it is false. Effort: **S**.

## [LOW] `journal_mode = WAL` never reaches the app, contrary to the schema header (D10)

**File:** `db/schema.sql:41` (header claim at `:37-39`; `onConfigure` at
`lib/data/sqlite/app_database.dart:42-45`)

**Issue:** `schemaStatements` drops every `PRAGMA`
(`lib/data/sqlite/schema_asset.dart:80-84`) because the DDL runs inside
`onCreate`'s transaction. The schema header says sqflite's `onConfigure`
"also sets these", but `onConfigure` sets only `foreign_keys` and `busy_timeout`
— `journal_mode` is never set, so the app runs in rollback-journal mode. The
same claim is restated as the rationale in
`test/data/schema_asset_test.dart:20-25`, so both say WAL is configured when it
is not. With one connection this is invisible; it becomes a
"database is locked"/throughput problem the moment a second connection or an
isolate reads the database, and it actively misleads the next reader.

**Why existing guards do not catch it:** no test reads `PRAGMA journal_mode`;
`schema_asset_test` only asserts the PRAGMAs were stripped.

**Proposed minimal fix:** add
`await db.execute('PRAGMA journal_mode = WAL');` to `AppDatabase.open`'s
`onConfigure` (before the other pragmas) and assert
`query('PRAGMA journal_mode')` returns `wal` in the harness test; or change the
schema header to say rollback journal is deliberate. Effort: **S**.

## [LOW] The demo persona leaks into the real owner row and outlives the demo (D11)

**File:** `lib/data/seed/sample_data_service.dart:60` (clear at `:240`)

**Issue:** `seedDemoHousehold` renames the single owner row to "Maria Santos"
when its name is still the placeholder; `clearDemoHousehold` deletes
pets/appointments but never restores the name. Journey: Welcome → "Use sample
household" (owner becomes Maria Santos) → later turn Sample data off → the demo
pets/visits vanish, but Profile still shows "Maria Santos" and Home greets
"Good morning, Maria" as soon as a pet is added through Profile instead of the
Welcome card. The commit that added this ("demo persona only with demo data")
intended the persona to exist only with demo data, so the leftover name defeats
that intent.

**Why existing guards do not catch it:** `test/data/repositories_test.dart:511-527`
asserts `owner.name == 'Maria Santos'` *after* clearing, so the suite pins the
leak in. This is a design call for the captain, not a silent bug.

**Proposed minimal fix:** on clear, restore `kDefaultOwnerName` if (and only if)
the name is still the demo persona; update the test to expect the placeholder.
(The "only if" keeps a user who is genuinely named Maria Santos from being
renamed.) Effort: **S**.

## Checked and found clean (no finding)

- **Append-only health records:** `db/schema.sql:185-196` rejects every `UPDATE`
  and every `DELETE` while the parent pet exists; the pet-delete cascade is
  tested alongside it (`test/data/schema_test.dart:234-299`), and the repository
  exposes no update/delete method. `ON DELETE CASCADE` really does run after the
  parent row is gone, so the trigger's `WHEN EXISTS` ordering is correct on this
  engine.
- **Cascade assumptions:** pet delete nulls `appointment.pet_id` and removes
  journal/vaccination/health rows; covered against the real DDL, not a copy.
- **Appointment state machine:** guards run in the right order (same status,
  terminal, no-show strictly after `scheduled_at`, cancel reason required);
  reschedule is transactional and a blocked transition rolls back cleanly.
- **One owner row:** enforced only in Dart (`ensureDefault` checks then inserts;
  nothing deletes or creates another), but no user path can create a second row
  today. If a `CHECK (id = 1)` is added in the next migration, the DDL header's
  "exactly one owner row" claim becomes true; until then it is a comment, not a
  constraint. Not reported as a bug because no reachable failure exists.
- **Other Dart-only invariants:** microchip format, the 40-year DOB bound, the
  300 kg weight cap and the name/breed length limits live only in
  `validatePetDraft`. Every write path goes through the form today; if a second
  caller appears (import, extra seed), enforce them in the repository too.
- **Queries:** no injection surface (constant table/column names, `whereArgs`
  everywhere); date-only string comparison is safe because the stored format is
  fixed-width; every list query uses an explicit `ORDER BY`.
- **Seeding atomicity:** the demo insert is one transaction, so a mid-seed
  failure rolls back rather than leaving half a household; the catalog seed is
  individually idempotent. The problem with seeding is the id convention (D1)
  and freshness (D5), not partial writes.

## Recommended refactors, in order

| # | Refactor | Why now | Effort |
| --- | --- | --- | --- |
| 1 | Fix demo-row ownership (D1): exact-id deletes + exact-id presence check, or negative ids / marker column | Data loss; blocks any release | S/M |
| 2 | Supersede older doses in the due rule (D2) with two unit tests | Clinical status is wrong after any booster | M |
| 3 | One calendar-day convention in the dashboard (D3 + D4) | Fixes two user-visible off-by-one bugs with one concept | S |
| 4 | Decide demo freshness and make the seed/catalog match (D5) | The demo is a deliverable and decays within days | S |
| 5 | Photo lifecycle: temp-until-save or boot sweep (D6) | Storage leak, files that no code can ever own again | M |
| 6 | Atomic settings write + IO fallback + boot reconcile (D7, after D1) | Silent preference loss and a boot-blocking error path | S |
| 7 | Per-pet journal query (or offset paging) and delete the unused method (D8) | Old entries are unreachable; the filter misleads | S |
| 8 | Low-risk cleanups: dead API surface (D9), WAL pragma/doc (D10), demo persona restore (D11) | Reduce the surface future work must keep in step | S |

If only one change is made this round, make it refactor 1: it is the only
finding that destroys data the user typed, and it is reachable with one switch on
a fresh install.
