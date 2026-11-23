# `test/`, CI, docs and guardrails — refactoring review

Part of the team review of the Pet Health Tracker. Review-only round: **no source
file was modified**; this document is the only artifact.

| | |
| --- | --- |
| Scope | `test/**` (25 files, 5,581 lines), `.github/workflows/deploy-web.yml`, `README.md`, `docs/demo-script.md`, `tool/**`, `AGENTS.md`, `.gitignore`, `analysis_options.yaml`, repo hygiene (`git ls-files`, sizes, duplicates, secrets) |
| Read for context | All of `test/**`; `lib/` seams the tests touch (`app/di.dart`, `app/app_services.dart`, `app/app_settings.dart`, `app/router.dart`, `app/navigation_requests.dart`, `platform/`, `data/seed/`, `domain/rules/vaccination_due.dart`), the six modal call sites, README/demo-script/AGENTS claims checked against the code they describe |
| Method | Line-by-line read of every test file and workflow line; every doc claim checked against the cited code and, where useful, against the tests that pin it. Ran the suite, a randomized-order run, analyze, and the documented format check |
| Commands run | `./tool/fv analyze` → `No issues found!` · `./tool/fv test` → `+179: All tests passed!` · `./tool/fv test --test-randomize-ordering-seed=random` → `+179: All tests passed!` · `./tool/fv test test/web/web_boot_test.dart` → `No tests ran. No tests were found.` (exit 79) · `./tool/format --set-exit-if-changed lib test` → `Formatted 134 files (18 changed)` |
| Deviation (disclosed) | The documented format *check* rewrote 18 tracked files. I restored exactly those paths with `git checkout -- …`; `git status --porcelain` now reports only the untracked `docs/reviews/` directory. Nothing under `lib/`, `test/`, `.github/` or `docs/` differs from HEAD |

## Verdict

**Needs targeted refactoring — 2 HIGH, 10 MEDIUM, 8 LOW, 0 CRITICAL.**

The suite itself is in better shape than the raw count suggests. All 179 tests
contain assertions; the domain, data, schema and controller tests assert state
(the transition matrix even proves blocked moves are no-ops); the widget tests
boot the real router/shell/screens against real SQLite; `flutter analyze` is
clean; the suite is fast (17 s) and passes with randomized test order. "179
tests" in the README is accurate (`test/web` contributes zero on the VM,
`test/shots` is not picked up by name).

The problems are in the *edges of the gate*, not the middle of the suite:

1. **The deployed artifact is never executed.** The only web-boot test is
   `@TestOn('browser')`, so `flutter test` in CI ignores it (verified: "No tests
   ran"). The Pages job builds and publishes with no runtime check, and the web
   entry point has no error path — a missing `sqlite3.wasm` publishes a blank
   page (Q1).
2. **The demo script describes behaviour the rule does not implement.** Adding a
   booster is scripted to flip the chip to "Up to date"; the rule reads every
   historical dose, so the pet stays Overdue — and, because vaccinations are
   append-only, a real user can never clear the marker by re-vaccinating (Q2).
3. **Whole flows are never opened**: reset household (row → dialog → confirm),
   onboarding saves, every date/time picker, the photo picker, both cross-tab
   hand-offs. The reason is structural: the harness has no deterministic way to
   settle a modal whose body does real async work (Q5, Q11, Q9).
4. **The guardrail is narrower than the contract it advertises** (Q6), and the
   documented formatting "check" mutates source and is absent from CI (Q7).
5. **Repo hygiene**: tracked SDK symlinks that the docs call gitignored, 3.3 MB
   of orphaned duplicate screenshots, a dead integration driver, a committed
   personal signing team (Q13–Q20).

No architecture change is warranted for this section; twelve small changes and
one product decision close everything below.

## Findings

| ID | Severity | Finding | File:line |
| --- | --- | --- | --- |
| Q1 | **HIGH** | CI can publish a web build it never ran; the browser test is skipped on the VM | `.github/workflows/deploy-web.yml:39` |
| Q2 | **HIGH** | Demo script's booster step contradicts the due rule (overdue can never be cleared by re-vaccinating) | `docs/demo-script.md:68` |
| Q3 | MEDIUM | Five documented behaviours are now false (settings count, Welcome "destination", chip label, hand-off, browser support) | `README.md:13,15,207` · `docs/demo-script.md:44,96,117` |
| Q4 | MEDIUM | README overstates coverage: onboarding and the pet page's add-sheets are untested | `README.md:136` |
| Q5 | MEDIUM | The destructive "Reset household" flow has no test at all | `lib/features/profile/profile_screen.dart:241` |
| Q6 | MEDIUM | Layering guard is narrower than AGENTS.md; contract stale on `lib/platform/`; a feature already imports `data/` | `test/data/no_sql_outside_data_test.dart:39` |
| Q7 | MEDIUM | The documented format "check" rewrites source (18 files) and CI never checks formatting | `AGENTS.md:39` |
| Q8 | MEDIUM | AGENTS.md says sample data defaults on; the code defaults off | `AGENTS.md:193` |
| Q9 | MEDIUM | Four copies of a fixed-sleep "wait for the database" make the suite timing-dependent | `test/features/pets/test_harness.dart:26` |
| Q10 | MEDIUM | Home's user-visible refresh is not asserted (would pass with the reload removed) | `test/features/home/home_controller_test.dart:70` |
| Q11 | MEDIUM | No test operates a modal picker, the reset dialog, the photo picker or either hand-off | `test/features/home/home_screen_test.dart:250` |
| Q12 | MEDIUM | CI runs only on `push: main`; branch/PR work — including this refactor — is never tested | `.github/workflows/deploy-web.yml:7` |
| Q13 | LOW | Shared `setUpAll` database, process-global navigation notifier, duplicated fixtures, wrong comment | `test/features/appointments/appointment_transition_matrix_test.dart:62` |
| Q14 | LOW | Screenshot harness uses absolute personal font paths, is gitignored and never runs in CI | `test/shots/shot_harness.dart:22` |
| Q15 | LOW | SDK/pub symlinks are tracked although `.gitignore` and tool/README say they are ignored | `.gitignore:51` |
| Q16 | LOW | 3.3 MB of `docs/shots` screenshots, five byte-identical pairs, referenced by no document | `docs/shots/` |
| Q17 | LOW | Integration-test driver and dependency exist with no integration suite | `test_driver/integration_test.dart:1` |
| Q18 | LOW | A personal `DEVELOPMENT_TEAM` and bundle id are committed | `ios/Runner.xcodeproj/project.pbxproj:380` |
| Q19 | LOW | `cancel-in-progress` can cancel a Pages deployment mid-flight | `.github/workflows/deploy-web.yml:17` |
| Q20 | LOW | "without overflow" tests assert only `takeException`, nothing about content or bounds | `test/features/appointments/appointments_screen_test.dart:433` |

---

## Q1 — [HIGH] CI can publish a web build it never ran; the browser test is skipped on the VM

**File:** `.github/workflows/deploy-web.yml:39-52` · `test/web/web_boot_test.dart:1` · `lib/platform/platform_database_stub.dart:10` · `lib/main.dart:12`

**Issue:** The only test that opens the web database is annotated `@TestOn('browser')` (`web_boot_test.dart:1`), so plain `flutter test` on the VM ignores the file entirely — verified: `./tool/fv test test/web/web_boot_test.dart` prints `No tests ran. No tests were found.` and exits 79. The deploy job's gate (`deploy-web.yml:39-42`) is exactly that VM run, then it builds (44-48) and uploads (50-52) with no runtime check. The web factory is `databaseFactoryFfiWebNoWebWorker` (`platform_database_stub.dart:5,10`), which loads `web/sqlite3.wasm` at runtime; nothing in `flutter build web` verifies that file exists or that the database opens. If the wasm is deleted/renamed or the factory regresses, the build succeeds and Pages publishes; `main.dart:12` awaits `openAppServices()` with no error handling, so `runApp` never runs and every visitor gets a blank page.

**Why existing guards do not catch it:** compilation is not execution — `flutter build web` type-checks the web entry point but never constructs a database; the browser-only test is excluded from the default run; the workflow never passes `--platform chrome`; and there is no post-build or post-deploy smoke check.

**Proposed minimal fix:** add one step after `Fetch packages`: `flutter test --platform chrome test/web/web_boot_test.dart` (Chrome is preinstalled on `ubuntu-latest`), before `flutter build web`. Cheap fallback if headless Chrome is unwanted: `test -f build/web/sqlite3.wasm` immediately after the build.

## Q2 — [HIGH] Demo script's booster step contradicts the due rule (overdue can never be cleared by re-vaccinating)

**File:** `docs/demo-script.md:68-71` · `lib/domain/rules/vaccination_due.dart:58-75` · `lib/features/pets/pet_detail_controller.dart:48` · `lib/data/sqlite/sqlite_vaccination_repository.dart:21-28`

**Issue:** Step 4 of the pet-page beat says the raised sheet's chip will read **Up to date** after adding a Rabies booster "because the rule reads the latest vaccination", and step 5 says Home's card does too. Neither happens. `petVaccinationDueStatus` (`vaccination_due.dart:58-75`) takes the *worst* status over every dose returned by `listForPet` (`sqlite_vaccination_repository.dart:21-28`), and the seeded overdue dose (id 9101, `next_due_date = today − 35 d`, `lib/data/seed/sample_data_service.dart:102-104`) is never updated or removed (vaccinations are append-only). `nextDueVaccination` (`vaccination_due.dart:79-89`) still returns that old row, so Home's `_dueLabelFor` (`lib/features/home/home_screen.dart:340-357`) keeps rendering "Rabies · 35 days overdue". The presenter narrates the opposite of what the screen shows mid-demo — and a real user who vaccinates their pet can never clear an overdue marker.

**Why existing guards do not catch it:** `pet_detail_screen_test.dart:204-235` only asserts statuses for doses that already exist; it never appends a newer dose for an already-overdue vaccine. The pet page's `+ Add` path (`pet_detail_screen.dart:130-140`) is not exercised by any test (Q11), and the demo script is prose that nothing executes.

**Proposed minimal fix:** decide the intended rule. If the newest dose per vaccine wins (what the script and the product imply), derive the due status and the "next vaccination" from the newest dose per `vaccine_name`/`vaccine_type_id` in `lib/domain/rules/vaccination_due.dart`, and add a test that appends a 2027 Rabies dose to the seeded pet and asserts Overdue → Up to date plus Home's new label. If not intended, correct `docs/demo-script.md:68-71` to stop promising the flip.

## Q3 — [MEDIUM] Five documented behaviours are now false

**File:** `README.md:13,15,207` · `docs/demo-script.md:44,96-98,117` · `lib/features/profile/profile_screen.dart:214-254` · `lib/app/router.dart:35-93` · `lib/features/home/home_screen.dart:340-357` · `lib/features/appointments/appointments_screen.dart:81-87`

**Issue:** (a) `README.md:13` and `docs/demo-script.md:117` both say Profile has "three settings"; the screen renders four (`profile_screen.dart:214-254`), and `test/features/profile/profile_screen_test.dart:73-94` asserts four rows — "Reset household" is missing from both documents. (b) `README.md:15` lists **Welcome** as a destination beside the four tabs, but there is no welcome route (`router.dart:35-93` has four shell branches plus the pet page); Welcome is Home's empty-state card (`home_screen.dart:387-399` → `first_run_card.dart`). (c) `docs/demo-script.md:44` quotes Miso's chip as "FeLV · due in 10 days"; `home_screen.dart:340-357` renders "FeLV · in 10 days" ("due" is only used for "due today"/"due tomorrow"), so the presenter reads words that are not on the screen. (d) `docs/demo-script.md:96-98` promises the actions sheet offers **View in Appointments** when tapping the new City Vet card at 2:45; the 2:00 step has already landed the demo on the Appointments tab, and `appointments_screen.dart:81-87` opens the sheet without `showViewInSection`, so the row (`appointment_actions_sheet.dart:317-341`) is absent — it only exists from Home (`home_screen.dart:200-206`). (e) `README.md:207` says a browser is "not a supported target — phone or simulator only", contradicting README:73-95 (browser distribution is automated through Pages) and the committed web target.

**Why existing guards do not catch it:** prose is not executed; there is no doc check and no test reads the README or demo script; the profile test pins four rows but cannot fail a sentence, and the demo script is only rehearsed by hand.

**Proposed minimal fix:** (a) say "four settings" in both files; (b) call Welcome a first-run card on Home, or move it out of the destinations table; (c) correct the Miso quote to "FeLV · in 10 days"; (d) drop "View in Appointments" from the 2:45 beat (or move that beat to Home); (e) rewrite the README troubleshooting row as "Browser or lab PC → use the Pages URL, or `flutter run -d chrome` from source".

## Q4 — [MEDIUM] README overstates coverage: onboarding and the pet page's add-sheets are untested

**File:** `README.md:136-140` · `lib/features/onboarding/first_run_card.dart:51,93` · `lib/features/pets/pet_detail_screen.dart:130-154`

**Issue:** README says the widget tests cover "onboarding", but no test references any `first-run-*` control — the sole onboarding assertion is that the Welcome card renders (`test/features/home/home_screen_test.dart:396-400`). `FirstRunCard._create` (`first_run_card.dart:51-89`, writes owner + first pet) and `_useSampleHousehold` (`:93-96`, the documented first-launch path at README:102-106) never run, so both first-run writes have no regression guard. The same sentence claims "the pet page and its sheets"; `pet_detail_screen_test.dart` never opens `add-vaccination`/`add-health-record` (`pet_detail_screen.dart:130-154`) — those sheets are tested only in isolation (`test/features/pets/pet_forms_test.dart`), so the page → form → refresh chain (the demo's 0:35 beat) is unguarded.

**Why existing guards do not catch it:** `flutter test` has no coverage gate (the workflow only runs analyze + test), coverage claims are prose, and a broken `_create` still leaves the Welcome card rendering, so the existing empty-household test stays green.

**Proposed minimal fix:** correct the README sentence, then add two focused widget tests: (a) empty household → fill `first-run-owner`/`first-run-pet` → tap `first-run-create` → one pet exists and the card is gone; (b) tap `first-run-sample` → demo pets exist and `settings.sampleDataEnabled` is true. Add one pet-page test: tap `add-vaccination` → save → the new `vaccine-row-<id>` appears.

## Q5 — [MEDIUM] The destructive "Reset household" flow has no test at all

**File:** `lib/features/profile/profile_screen.dart:241-323` · `lib/app/app_services.dart:118-128` · `test/features/profile/profile_screen_test.dart:80-94`

**Issue:** Reset household is the only destructive action in the app: it deletes every appointment, then every pet (cascading journal/vaccination/health rows), deletes owned photo files, and turns sample data off. It has zero tests. The profile test only asserts that `setting-reset-household` and `reset-household-confirm` exist; no test taps the row, the confirm button, or the `reset-forget-owner` checkbox. A regression that deletes hand-made pets, leaves appointments pointing at nothing, skips photo cleanup, or forgets the owner-reset ships silently.

**Why existing guards do not catch it:** the profile test stops at key existence; AGENTS.md's definition of done has no destructive-flow requirement; and the dialog is outside the harness's deterministic path (Q11), so it was simply never attempted.

**Proposed minimal fix:** one widget test with two hand-made pets plus the demo household: (a) Cancel leaves everything; (b) confirm keeps the owner but empties pets and appointments and sets `sampleDataEnabled` false; (c) ticking `reset-forget-owner` asserts the owner name goes back to `kDefaultOwnerName`. Photo cleanup needs a separate seam first: `PetPhotos.deleteOwned` calls `sqflite.getDatabasesPath()` (`lib/data/pet_photos_io.dart:19-20,51-57`), a platform channel that is unavailable in widget tests — cover it with an injectable directory or leave it out of this test.

## Q6 — [MEDIUM] Layering guard is narrower than AGENTS.md; contract stale on `lib/platform/`; a feature already imports `data/`

**File:** `test/data/no_sql_outside_data_test.dart:12-18,39-62` · `AGENTS.md:83-96` · `AGENTS.md:65-75` · `README.md:167-177` · `lib/features/pets/forms/pet_form_sheet.dart:17`

**Issue:** The guard was widened to allow `lib/platform/` (test name at `:39`, allowlist at `:53-56`) but the contract was not: `AGENTS.md:86-87` still says only `lib/data/` and `lib/app/di.dart` may import `package:sqflite/`; neither `AGENTS.md:65-75` nor `README.md:167-177` lists `lib/platform/` at all; and `AGENTS.md:96` claims "The rules are enforced by `test/data/no_sql_outside_data_test.dart`" when only the domain-purity, SQL-text and sqflite-import rules are checked. Nothing checks `lib/ui/**` ("no repositories, no database, no `dart:io`") or `lib/features/**` ("read through repository interfaces, never construct a database"): a feature already imports a concrete data-layer file (`pet_form_sheet.dart:17` → `lib/data/pet_photos.dart`), and the SQL marker set (`:12-18`) omits `UPDATE ` and is case-sensitive, so a screen calling `rawUpdate('UPDATE pet …')` would pass. Secondary: `AGENTS.md:201` "never hard-code hex" is also unenforced — `lib/app/shell/app_shell.dart:345` already ships `Color(0x330E6B5F)`.

**Why existing guards do not catch it:** the test is an allowlist for one import string plus five uppercase SQL markers; `analysis_options.yaml` only includes `flutter_lints` + `avoid_print`, so `flutter analyze` has no import-boundary rule and no hex check.

**Proposed minimal fix:** update the contract — add `lib/platform/` to the folder table and README layout, change the sqflite sentence to "`lib/data/`, `lib/platform/` and `lib/app/di.dart`", and narrow line 96 to what is actually checked. Extend the guard with (a) a feature → data import scan (allow repository-interface files if intended), (b) a `lib/ui` scan for `data/`/`dart:io`/sqflite, (c) `UPDATE `/`JOIN `/case-insensitive markers. Fix or justify `pet_form_sheet.dart:17` in the same change.

## Q7 — [MEDIUM] The documented format "check" rewrites source (18 files) and CI never checks formatting

**File:** `AGENTS.md:38-39` · `README.md:132` · `tool/README.md:46` · `.github/workflows/deploy-web.yml:39-42`

**Issue:** `dart format` writes by default; `--set-exit-if-changed` only changes the exit code. Running the documented check (`./tool/format --set-exit-if-changed lib test`) on a clean checkout rewrote 18 files (12 under `lib/`, 6 under `test/`, e.g. `lib/ui/kit/app_chip.dart`, `lib/features/profile/profile_screen.dart`, `test/data/repositories_test.dart`, `test/shots/shot_harness.dart`) — so the tree is not format-clean and the command is a mutation, not a check. That is exactly the hazard `AGENTS.md:53-58` documents for mid-review runs. On top of that, CI never runs any format check, so the drift is invisible.

**Why existing guards do not catch it:** `flutter analyze` does not check formatting, the workflow runs only analyze + test, and the exit code is easy to lose behind a pipe (as happened in this review's own invocation, which is why the deviation above is disclosed).

**Proposed minimal fix:** document the real check as `./tool/format --output=none --set-exit-if-changed lib test`; run `./tool/format lib test` once to clear the 18 files; add the `--output=none` command to `deploy-web.yml` before `flutter analyze`.

## Q8 — [MEDIUM] AGENTS.md says sample data defaults on; the code defaults off

**File:** `AGENTS.md:193-195` · `lib/app/app_settings.dart:34-36` · `test/data/bootstrap_test.dart:54-56` · `README.md:102`

**Issue:** AGENTS.md says the demo household is seeded "when the persisted toggle is on, default yes". The code default is **off** (`_sampleDataEnabled = false` in `app_settings.dart:36`), the README says "off by default", and three tests pin that (fresh install has no pets; `bootstrap_test.dart:54-56`; `web_boot_test.dart:22-23`). An implementer following the contract would "fix" the seeder or the tests in the wrong direction.

**Why existing guards do not catch it:** docs are not executed and no test reads AGENTS.md; the statement survived the very commit that flipped the default (`08f0245`, "First launch starts empty"), which touched only `lib/app/app_settings.dart` and `test/data/bootstrap_test.dart`.

**Proposed minimal fix:** replace "default yes" with "default no — a fresh install opens on the Welcome card".

## Q9 — [MEDIUM] Four copies of a fixed-sleep "wait for the database" make the suite timing-dependent

**File:** `test/features/pets/test_harness.dart:26-37` · `test/features/home/home_screen_test.dart:42-55` · `test/features/appointments/appointments_screen_test.dart:128-136` · `test/features/journal/journal_screen_test.dart:92-100`

**Issue:** "Wait for the real database" exists four times with fixed wall-clock sleeps: 5 × 100 ms + a 400 ms pump, a single 100 ms, 6 × 20 ms, 6 × 20 ms; `profile_screen_test.dart:156,174` uses 300 ms. The comments admit a load chain can "stop halfway", and 120 ms is the entire budget for a chain of SQLite calls. On a loaded CI runner (or a cold SQLite/native-assets build) a query can land after the assertions, turning correct code into an intermittent failure. Because `SqliteHarness.dispose()` (`test/data/test_support.dart:54-59`) closes the database and then deletes the temp directory, a query that survives the last sleep can also surface as an unhandled exception during teardown.

**Why existing guards do not catch it:** CI runs each push once with no retries; the sleeps are hidden inside four per-file helpers, so there is no single place to fix or observe them; and randomized order passes today, so the flake is latent rather than manifest.

**Proposed minimal fix:** one shared helper in `test/features/pets/test_harness.dart` — either `pumpUntil(tester, finder, timeout: 2 s)` pumping 10 ms steps, or make loads awaitable in tests (`await tester.runAsync(controller.load); await tester.pump();`). Delete the three copies.

## Q10 — [MEDIUM] Home's user-visible refresh is not asserted (would pass with the reload removed)

**File:** `test/features/home/home_controller_test.dart:70-71` · `lib/features/home/home_controller.dart:59-69` · `test/features/home/home_screen_test.dart:198-235`

**Issue:** The controller test comments "the snapshot is refreshed, so Home can show the new row immediately" and asserts `controller.dashboard!.recentEntries, isNotEmpty` — already true after the initial load (the demo seed has three entries). Deleting `await load()` from `createEntry` (`home_controller.dart:66-69`) leaves that test green. The widget test verifies the DB row and the snackbar but never that the new Recent row/note appears, so the "Recent updates immediately" promise (README:10, `docs/demo-script.md:76`) has no guard at either level.

**Why existing guards do not catch it:** the assertion is weaker than the claim; the widget test checks the write side-effect (direct database read) rather than the rendered result.

**Proposed minimal fix:** assert `controller.dashboard!.recentEntries.first.id == saved.id` in the controller test, and in the widget test assert the new `recent-entry-<id>` key (or the entered note) is on screen after the save.

## Q11 — [MEDIUM] No test operates a modal picker, the reset dialog, the photo picker or either hand-off

**File:** `lib/features/home/widgets/quick_log_form_sheet.dart:70,91` · `lib/features/appointments/appointment_form_sheet.dart:103,116` · `lib/features/appointments/appointment_reschedule_sheet.dart:54,67` · `lib/features/journal/journal_entry_sheet.dart:70` · `lib/features/pets/forms/form_fields.dart:67` · `lib/features/profile/profile_screen.dart:270` · tests: `test/features/home/home_screen_test.dart:250-251`

**Issue:** Every modal picker is only asserted to exist, never operated: the eight `showDatePicker`/`showTimePicker` sites above, the reset `showDialog`, the photo picker (`pet_form_sheet.dart:159`, a platform channel), and both hand-offs — the Home avatar (`home-owner-avatar`) and "View in Appointments" (`appointment-action-view-section`). Tests assert the fields (`form-date`/`form-time` at `home_screen_test.dart:250-251`, `appointment-reschedule-date` at `appointments_screen_test.dart:309-316`, `journal-edit-time` at `journal_screen_test.dart:184-187`) and then save with the defaults. A regression in local-picker → UTC conversion, in a dialog's `pop` result, or in a hand-off would ship undetected.

**Why existing guards do not catch it:** the harness has no deterministic way to settle a modal — `pumpAndSettle` cannot settle while a spinner animates and the database futures only advance inside `tester.runAsync` (`test/features/pets/test_harness.dart:4-5`), so the suite uses fixed sleeps (Q9) and avoids opening modals; nothing measures interaction coverage.

**Proposed minimal fix:** add a fake-services `pumpScreen` (in-memory repositories or a `Completer`-backed `AppServices`) so widget futures complete in fake async; then ordinary `pumpAndSettle` drives modals. Cover one picker per form, the reset dialog (Q5), and the two hand-offs. Keep the real-FFI harness for `test/data/**`.

## Q12 — [MEDIUM] CI runs only on `push: main`; branch/PR work — including this refactor — is never tested

**File:** `.github/workflows/deploy-web.yml:7-10` (deploy job at `:54-62`)

**Issue:** The only workflow triggers on `push` to `main` and `workflow_dispatch`. Branch and pull-request work is never analyzed or tested; the first signal for a broken refactor is a red `main` plus a skipped deployment after merge.

**Why existing guards do not catch it:** there is no PR workflow and no branch protection in the repository; the deploy pipeline is the only CI.

**Proposed minimal fix:** add `pull_request: branches: [main]` to `on:`, and guard the `deploy` job with `if: github.event_name != 'pull_request'` (Pages still deploys only from `main`).

## Q13 — [LOW] Shared `setUpAll` database, process-global navigation notifier, duplicated fixtures, wrong comment

**File:** `test/features/appointments/appointment_transition_matrix_test.dart:62-68` · `lib/app/navigation_requests.dart:12` · `test/features/appointments/appointments_controller_test.dart:41-121` vs `test/features/appointments/appointments_screen_test.dart:45-125` · `test/features/journal/journal_screen_test.dart:34-36`

**Issue:** One `setUpAll` database is shared by all 19 tests in the matrix file, so a leak or failure poisons the rest. `NavigationRequests.appointmentsPetFilter` is a process-global `ValueNotifier` (`navigation_requests.dart:12`) that no test resets. The two appointments test files copy ~80 identical fixture lines. `journal_screen_test.dart:35` claims "two `:memory:` handles can share one database" — they cannot, which is why it opens a file database. A randomized-order run passes today, so this is latent, not currently wrong.

**Why existing guards do not catch it:** there is no `setUp` that resets static state, and `flutter test` runs each file in its own isolate, which hides cross-file leaks.

**Proposed minimal fix:** open a per-test harness in the matrix file (or wipe the tables in `tearDown`); set `NavigationRequests.appointmentsPetFilter.value = null` in a global `setUp`; extract `appointmentsFixture()`; correct the comment.

## Q14 — [LOW] Screenshot harness uses absolute personal font paths, is gitignored and never runs in CI

**File:** `test/shots/shot_harness.dart:20-33` · `.gitignore:55-56` · `README.md:145`

**Issue:** The harness loads Roboto from `/System/Library/Fonts/Supplemental/Arial.ttf` and MaterialIcons from an absolute path under `/Users/daniel/Documents/…`; when the file is absent it silently continues, so another machine renders different glyphs. Its PNG output is gitignored (`.gitignore:56`), and the file name has no `_test` suffix, so `flutter test` and CI never run it. It is a manual screenshot script presented (README:145) as the screenshot-regeneration path; nothing compares the images, so a UI regression changes them silently.

**Why existing guards do not catch it:** the file is excluded by naming, the goldens are not committed, and there is no CI step for it — there is nothing that can fail.

**Proposed minimal fix:** resolve fonts without absolute paths (SDK cache/`rootBundle`) or rely on the test font; either commit the four goldens and run the file in CI, or rename it `tool/screenshots.dart` and document it as a manual tool.

## Q15 — [LOW] SDK/pub symlinks are tracked although `.gitignore` and tool/README say they are ignored

**File:** `.gitignore:31,50-53` · `.flutter-sdk` · `.pub-cache` · `tool/README.md:20-21,85-87`

**Issue:** `.flutter-sdk` and `.pub-cache` are committed symlinks (git mode `120000`) pointing at `../Final Project/…`; `.gitignore:51-52` lists `.flutter-sdk/` and `.pub-cache/` and `tool/README.md:20-21,85-87` says both are "gitignored", but a trailing slash only matches a directory, and `git check-ignore .flutter-sdk` returns no match. `.pub-cache/` also appears twice (`:31` and `:52`). On a fresh clone the symlinks dangle.

**Why existing guards do not catch it:** git's trailing-slash semantics are silent; no check verifies the "gitignored" claim in tool/README.

**Proposed minimal fix:** change the two patterns to `.flutter-sdk` and `.pub-cache` (no trailing slash), delete the duplicate at `:31`, then `git rm --cached .flutter-sdk .pub-cache`; `tool/fv` already falls back to `PATH`.

## Q16 — [LOW] 3.3 MB of `docs/shots` screenshots, five byte-identical pairs, referenced by no document

**File:** `docs/shots/` (19 PNGs, 3,336 KB; e.g. `docs/shots/promo/home.png` == `docs/shots/v2-home.png`) · `web/sqlite3.wasm`

**Issue:** No document references `docs/shots/**` — README and `docs/demo-script.md` mention only `test/shots/*.png` — and five pairs are byte-identical (`promo/home`=`v2-home`, `promo/journal`=`v2-journal`, `promo/profile`=`v2-profile`, `promo/pet`=`05-pet`, `fixed-journal`=`02-journal`). The `v2-`/`fixed-` names are stale iteration artifacts. By contrast `web/sqlite3.wasm` (748 KB) is deliberate and required: the web factory is `databaseFactoryFfiWebNoWebWorker` (`lib/platform/platform_database_stub.dart:10`), which needs no `sqflite_sw.js`.

**Why existing guards do not catch it:** screenshots are binary, review diffs do not show them, and nothing links or checks them.

**Proposed minimal fix:** keep only the images the demo doc uses, link them from `docs/demo-script.md`, dedupe, and either commit a named subset or ignore `docs/shots/` the way `test/shots/*.png` is ignored.

## Q17 — [LOW] Integration-test driver and dependency exist with no integration suite

**File:** `test_driver/integration_test.dart:1-3` · `pubspec.yaml:25-26`

**Issue:** The integration-test driver and the `integration_test` dev dependency are committed, but the repository has no `integration_test/` suite and CI never invokes them. The driver cannot fail and no test uses the dependency.

**Why existing guards do not catch it:** `flutter test` ignores `test_driver/`; CI has no integration step.

**Proposed minimal fix:** delete both, or add the one device smoke test the driver implies (boot against a real `sqflite` file database, seed, read one row) and run it.

## Q18 — [LOW] A personal `DEVELOPMENT_TEAM` and bundle id are committed

**File:** `ios/Runner.xcodeproj/project.pbxproj:380,387,562`

**Issue:** The project pins a personal signing identity: `DEVELOPMENT_TEAM = QC548H26VR` and `PRODUCT_BUNDLE_IDENTIFIER = com.danielestillore.petHealthTracker`. README:38-44 tells a new user to change the bundle id and team, but a fresh clone's first `flutter run -d <phone>` fails Automatic Signing against a team the user does not own, before they reach that step.

**Why existing guards do not catch it:** there is no check on committed signing settings; the README treats it as prose.

**Proposed minimal fix:** remove `DEVELOPMENT_TEAM` (and optionally the bundle id) from the committed `pbxproj` so Xcode's automatic-signing flow fills it; keep the README step.

## Q19 — [LOW] `cancel-in-progress` can cancel a Pages deployment mid-flight

**File:** `.github/workflows/deploy-web.yml:17-19` (deploy job `:54-62`)

**Issue:** `concurrency.group: pages` with `cancel-in-progress: true` covers the `deploy` job too. A push that lands during `actions/deploy-pages@v4` cancels the deployment mid-flight; the run is cancelled and the site keeps the previous build until the next successful deploy. GitHub's Pages guidance is not to cancel deployments.

**Why existing guards do not catch it:** concurrency is configured once for the whole workflow; there is no environment-level protection.

**Proposed minimal fix:** move concurrency to the `build` job only, or set `cancel-in-progress: ${{ github.event_name == 'pull_request' }}` so `main` deploys are never cancelled.

## Q20 — [LOW] "without overflow" tests assert only `takeException`, nothing about content or bounds

**File:** `test/features/appointments/appointments_screen_test.dart:433-449` · `test/features/journal/journal_screen_test.dart:241-254`

**Issue:** Both "lays out a phone-sized … without overflow" tests assert only `tester.takeException() == null`. They pass if the sheet body renders empty or loses its rows; no text, size or bounds is checked, and only the default text scale is exercised. They read as coverage of the sheets but assert only the absence of exceptions.

**Why existing guards do not catch it:** the assertion is exactly the one line that looks like the intent; nothing compares the rendered content.

**Proposed minimal fix:** keep the overflow intent but pump at 320 × 568 and at 1.5× text scale, assert the expected action rows exist and the sheet rect lies inside the view — or fold them into the modal tests from Q11.

---

## Checks that passed (not findings)

- `./tool/fv analyze` → `No issues found! (ran in 1.7s)`. No findings are hidden behind red analysis.
- `./tool/fv test` → `+179: All tests passed!` in ~17 s. The README/demo "179 tests" is accurate: `test/web` contributes zero on the VM and `test/shots` is excluded by its file name.
- `./tool/fv test --test-randomize-ordering-seed=random` → `+179: All tests passed!`. No observed order dependence (the static-state items in Q13 are latent).
- A failing test does block deployment: the `build` job runs `flutter analyze` and `flutter test` in one `bash -e` block (`deploy-web.yml:39-42`), and `deploy` has `needs: build` (`:55`). Only the *runtime* web gap is Q1.
- The Flutter version is pinned (`flutter-version: 3.47.5`, `channel: stable`, `:32-33`) and matches `AGENTS.md` and `pubspec.yaml:7` (`^3.13.4`).
- Caching is SDK-only (`cache: true`, `:34`); no pub cache and no build-artifact cache is reused across commits, so nothing stale can be restored.
- `db/schema.sql` is well guarded: `test/data/schema_test.dart` exercises the real engine (7 tables, FK enforcement, UNIQUE microchip, CHECK ties, append-only triggers, cascade behaviour) and `test/data/schema_asset_test.dart` proves the bundled asset equals the on-disk DDL. The documented `sqlite3 :memory: ".read db/schema.sql"` smoke test is redundant with that.
- README facts that check out: sample data off by default; demo household numbers (4 journal entries, 4 vaccinations, 2 clinical notes, 2 visits = the 12 "records" the profile test pins); photo copied into `pet_photos/` and deleted after a replace/clear (`pet_form_sheet.dart:139`); pull-to-refresh on Home, Journal and Appointments (`RefreshIndicator` in all three screens); the web database in IndexedDB with no photos (`pet_photos_stub.dart`, `platform_database_stub.dart`); `--base-href` guidance.
- No secrets in tracked files; `android/local.properties` (absolute personal SDK path) is correctly ignored; `test/shots/*.png` and `.tool-home/` are ignored.
- Every test case contains at least one `expect`/`expectLater` (scripted scan); the only body without a direct assertion is the screenshot harness, which asserts inside its `shot()` helper.

## Residual risks not asserted

1. **CI parity for the SQLite native-assets build.** `.tool-home/.config/flutter/settings` contains `{"enable-native-assets": true}`, and `tool/README.md:22,35-36` ties that flag to the `sqlite3` build hook that supplies the FFI library the data tests load. `deploy-web.yml` never runs `flutter config --enable-native-assets`; the runner's `HOME` has no project Flutter config, so the flag is off by default. A fresh-`HOME` run of `test/data/schema_asset_test.dart` passed locally, but the `.dart_tool/hooks_runner` artifacts already existed, so I could not prove a CI failure either way. One clean-container `flutter pub get && flutter test` should settle it before the gate is trusted.
2. **The browser test could not be executed here.** `flutter test --platform chrome test/web/web_boot_test.dart` produced no output for over ten minutes in this sandbox and was cancelled, so whether that test currently passes is unverified. Its exclusion from CI (Q1) is independent and verified.
3. **Format check semantics.** The 18-file rewrite was observed with the project's own locked SDK (`./tool/format` uses `.flutter-sdk/bin/cache/dart-sdk/bin/dart`), so it is not a host-formatter artefact.

## Ordered refactor list

| # | Action | Findings | Effort |
| --- | --- | --- | --- |
| 1 | Add `flutter test --platform chrome test/web/web_boot_test.dart` to the workflow before the build (fallback: assert `build/web/sqlite3.wasm` exists) | Q1 | S |
| 2 | Decide the booster rule; implement newest-dose-per-vaccine **or** correct the demo script; add the append-a-newer-dose test | Q2 | M |
| 3 | Correct the five stale doc statements (settings count, Welcome, chip label, hand-off, browser row) | Q3 | S |
| 4 | Tighten the home refresh assertions (controller `.first.id`, widget row key) | Q10 | S |
| 5 | Add the reset-household widget test (cancel / confirm / forget-owner) | Q5 | S–M |
| 6 | Add onboarding save + sample-household tests and the pet-page add-vaccination refresh test; correct the README coverage sentence | Q4 | M |
| 7 | Add a `pull_request` trigger and `if:` on the deploy job | Q12 | S |
| 8 | Switch the documented format check to `--output=none`, clear the 18 files, add it to CI | Q7 | S |
| 9 | Align AGENTS.md/README with `lib/platform/`; widen the layering guard (feature→data, ui purity, `UPDATE `/case-insensitive markers); fix the one existing import | Q6 | M |
| 10 | Replace the four sleep helpers with one deterministic wait and a fake-services harness for modals; then cover pickers, dialogs and hand-offs | Q9, Q11 | M–L |
| 11 | Correct AGENTS.md's "default yes" to "default no" | Q8 | S |
| 12 | Hygiene batch: per-test matrix harness + notifier reset + shared fixture; screenshot tooling; symlink ignore fix; screenshot prune; delete/complete the integration driver; unset the signing team; split deploy concurrency | Q13–Q20 | S each |

**Decision needed before 2:** whether "latest dose per vaccine wins" is the product rule. If it is, Q2 is a domain fix (and the demo script is right); if it is not, the script must say so. Everything else is mechanical and can be done without reopening the architecture.
