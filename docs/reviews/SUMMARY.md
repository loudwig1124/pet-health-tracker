# Refactoring decision — Pet Health Tracker

Synthesis of the four reviews in this directory: **60 findings — 1 CRITICAL, 10 HIGH, 26 MEDIUM, 23 LOW.** Sources are cited by their own IDs (`D…` domain-data, `A…` app-ui-platform, `F…` features, `Q…` tests-ci-docs).

## The decision

- **Fix five things before the demo (~1 day).** One data-loss defect, one wrong clinical status, one invisible-write class, one calendar-day bug, and the demo-script/README copy. Details below.
- **Seventeen grouped changes are worth doing after the demo** (~3–4 days, mostly S). They harden the product, not the demo.
- **Do not restructure anything.** All four reviews independently call the architecture sound — one `AppServices` composition root, `ChangeNotifier` + `AppScope`, `StatefulShellRoute`, a small token-driven kit. No provider/Riverpod/Bloc, no router rewrite, no schema or repository redesign.
- **The rest is not worth doing now** (cosmetics, store identity, broad test-harness work). "None of these justify a refactor" is *not* the answer: D1 alone does, and the demo script's 3:40 step is false without it.

## Deduplicated register, risk-ranked

| Risk | Merged entry | Sources | Decision |
| --- | --- | --- | --- |
| Data loss | Demo-id range deletes the owner's pets/records (reproduced); also breaks the scripted "Coco stays" step | D1 | **Fix now** |
| Wrong clinical status | A new booster never supersedes an older dose's past due date (pet stays Overdue forever) | D2 + Q2 | **Fix now** |
| User-visible wrong status | Dashboard uses the UTC calendar day where every other screen uses the local day | D3 + D4 | **Fix now** |
| Invisible writes | Centre action writes then `go()`s to the already-active branch; destination never reloads | A1 + F1 + F2 | **Fix now** |
| False copy | Demo script/README describe settings, chip label, hand-off and browser support that do not exist | Q3 (+ Q4, Q8) | **Fix now** |
| One-tap data loss | Journal delete has no confirm/undo | F8 | Post-demo |
| Preference loss / boot abort | Non-atomic settings write; only `FormatException` handled | D7 | Post-demo (after D1) |
| Storage leak | Photos are copied at pick time and orphan on failed/cancelled/re-picked saves | D6 + F10 | Post-demo |
| Web UX | "Choose photo" is shown on the Pages build but can never work; two dead capability flags | A2 + A10 + D9 (photo part) | Post-demo |
| User-visible stale | Profile never reloads after the pet page pops | F3 | Post-demo |
| Small screens | Pet-page sheet stops pinned to 844 pt; iPhone landscape letterboxes via `PhoneFrame` | F4 + A3 | Post-demo |
| First-run | Onboarding sample path can wedge; onboarding save blanks email/phone | F5 + F6 | Post-demo |
| Accessibility | Home card overflows at ≥1.5× text; `PrimaryButton` fixed 52 px; chips 36 pt | F7 + A5 + A15 | Post-demo |
| Blank Pages page | Web boot is never run in CI and boot has no failure path | Q1 + A8 | Post-demo* |
| Test gaps | Reset-household, modal/picker and hand-off flows untested; Home refresh assertion vacuous; sleep-based waits | Q5 + Q10 + Q11 + Q9 | Post-demo |
| Guardrails | Layering guard narrower than AGENTS.md; format "check" mutates and is absent from CI; no PR gate | Q6 + Q7 + A9 + Q12 | Post-demo |
| Demo decay/persona | Demo dates freeze after first seed; "Maria Santos" survives clearing sample data | D5 + D11 | Post-demo |
| Shell/kit correctness | Fade race on current-tab tap; filter request cannot mean "no filter"; Android back exits | A4 + A6 + A7 | Post-demo |
| Journal reach | Per-pet filter reads one capped 50-row page; `listForPet` is dead | D8 | Post-demo |
| Cosmetic/dead | Duplicate journal-kind icons/avatar; dead API; WAL never applied; unused deps; web/bundle identity; docs/shots, symlinks, screenshots, driver | F9 + D9 + D10 + A11–A14 + Q13–Q20 | Opportunistic / not now |

\* Promote to pre-demo if the Pages URL is shown during the demo (README leads with it).

## Before the demo

**1 · Demo-row ownership (D1) · S.**
Files: `lib/data/seed/sample_data_service.dart`, the seeding notes in `AGENTS.md`, `test/data/repositories_test.dart`.
Change: delete/reseed the demo table's exact seeded ids (`IN (…)`, one list per table) instead of `>= 9000`; make `demoHouseholdExists` check the same ids; add "seed demo → add a pet → clear → the pet survives".
Risk: low — if an id list drifts from the seeder a demo row survives (visible, not destructive), and the new test pins both lists.

**2 · Newest dose wins (D2 + Q2) · M.**
Files: `lib/domain/rules/vaccination_due.dart`, `test/domain/vaccination_due_test.dart`, `AGENTS.md`, `docs/demo-script.md:68-71`.
Change: reduce to the latest dose per `vaccineTypeId ?? name` before ranking; add the two "newer dose supersedes an overdue dose" tests; correct the "worst tracked status" wording.
Risk: medium — changes a documented rule and the pet page's per-row chips; the full suite must stay green. Time-boxed fallback: edit the demo script only (S) and accept the user bug.

**3 · One write signal (A1 + F1 + F2) · S.**
Files: `lib/app/navigation_requests.dart`, `lib/app/shell/centre_action_sheet.dart`, the four branch screens' `didChangeDependencies`.
Change: add `ValueNotifier<int> householdRevision`, bump it after each successful centre-action write, subscribe and reload while `_branchActive`.
Risk: low–medium — a wrong subscription means duplicate loads or reload loops; gate on `_branchActive` and dispose. Must be one commit across app + features, not two.

**4 · One local calendar day (D3 + D4) · S.**
Files: `lib/data/sqlite/sqlite_dashboard_repository.dart`, `DashboardRepository.load`, `lib/app/app_services.dart`.
Change: pass the calendar `today` explicitly for the due rule (from `AppServices.today()`), and `.toLocal()` before `dateOnly` for last-visit.
Risk: low — touches a repository signature and its tests; fixes two off-by-one-day bugs with one concept.

**5 · True docs (Q3 + Q4 + Q8) · S.**
Files: `README.md`, `docs/demo-script.md`, `AGENTS.md`.
Change: four settings (not three); Welcome is a Home card; "FeLV · in 10 days"; drop "View in Appointments" from the 2:45 beat; browser is supported; correct the coverage claim; "sample data default no".
Risk: none — rehearse only after this, so nobody narrates a screen that contradicts them.

## After the demo (worth doing)

| Change (sources) | Files / minimal change | Risk | Effort |
| --- | --- | --- | --- |
| Profile reloads on return (F3) | `profile_screen.dart` — await `PetRoutes.open`, then `load()` | None; mirrors Home | S |
| Journal delete guard (F8) | `journal_entry_sheet.dart` — confirm dialog or Undo snackbar | Low; one tap becomes two | S |
| Atomic settings + fallback (D7) | `settings_store_io.dart` — tmp+rename write, catch-all read, reconcile toggle on boot (after D1) | Low; reconcile before D1 would delete user rows | S |
| Photo lifecycle + web gate (D6 + F10 + A2 + A10) | `pet_photos_io.dart`, stub, `pet_form_sheet.dart` — temp-until-save or boot sweep; hide the control when unsupported; one capability flag | Low; tests need an injectable directory | M |
| Boot error screen + web test (A8 + Q1) | `main.dart` — `try/catch` around `openAppServices` rendering a themed retry app; `deploy-web.yml` — `flutter test --platform chrome test/web` | Low; web-only step | S |
| Onboarding hardening (F5 + F6) | `first_run_card.dart`, `home_screen.dart` — try/catch + mounted; pass the owner; preserve email/phone | Low | S |
| Small-surface layout (F4 + A3) | `pet_detail_screen.dart` — `LayoutBuilder` stops with a content floor; `phone_frame.dart`/`Info.plist` — portrait-only or `shortestSide` guard | Medium; the sheet's two stops are a designed behavior — re-test 390×844 + 375×667 | M |
| Large-text pass (F7 + A5 + A15) | `home_screen.dart`, `primary_button.dart`, `app_chip.dart` — scale card height, height floor, 44 pt hit area | Low; visual-only | M |
| Shell/requests batch (A4 + A6 + A7) | `app_shell.dart`, `navigation_requests.dart` + consumer — cancel the fade, request object with `take()`, `PopScope` back-to-Home | Low–medium; routing behavior | S each |
| Journal per-pet query (D8) | `journal_controller.dart` + repository — `listForPet` when filtered (or add paging) | Low | S |
| Test gaps (Q4 + Q5 + Q9 + Q10 + Q11) | `test/**` — reset-household, onboarding save, pet-page add-vaccination refresh, one picker per form, the two hand-offs, real `Recent` assertion, one deterministic wait helper | None for production | M |
| Guardrails (Q6 + Q7 + A9 + Q12) | `no_sql_outside_data_test.dart`, AGENTS/README, workflow, format — align allowlist/docs, `--output=none` check in CI, PR trigger, delete the 18-file format drift | Low | M |
| Demo freshness/persona (D5 + D11) | `sample_data_service.dart` — reseed on toggle-on only (or fix the comment); restore placeholder owner on clear | Low; D11 test pins the current leak | S |
| Identity/hygiene (A11–A14 + Q13–Q20) | `pubspec.yaml`, `web/`, `pbxproj`, `.gitignore`, `docs/shots` — real title/ids, drop unused deps/driver, prune screenshots, fix ignore patterns, `DEVELOPMENT_TEAM` | Low; no behavior change | S each |
| Dead code + WAL (D9 + D10) | `lib/domain`, `lib/data` — delete unused members; either add `PRAGMA journal_mode=WAL` to `onConfigure` or correct the schema header | Low; WAL unnecessary with one connection | S |
| Feature polish (F11–F14) | form sheets, `pet_chooser_sheet.dart`, `quick_log_form_sheet.dart` — `PopScope(canPop: !_saving)`, real chooser error state, shared duration validation | Low | S each |
| Journal-kind identity (F9) | `lib/ui/kit/` + `journal_screen.dart`/`home_screen.dart` — one badge/icon + shared `PetAvatar` | Low; purely visual | M (optional) |

## Do not do

- Any state-management or routing rewrite; any `lib/domain`/`lib/data` layering change (all four reviews: the structure is right).
- A harness rebuild (Q9) or a coverage-tooling detour (Q4) — its gaps are closed by the specific tests above; the 179-test suite is healthy.
- WAL unless a second connection is planned (D10) — fixing the comment is enough.
- The shared journal-kind widget (F9) before the demo — pure cosmetics, M effort.
- Repo-history or store-signing work (A13): bundle ids/signing only matter if publishing to a store; the Pages demo and the README's free-Apple-ID path do not need it.
- A PR CI workflow (Q12) if this stays a solo school repo — nice-to-have, not a defect.
- Any screenshot/binary/symlink cleanup beyond a quick prune (Q14–Q16) — none of it affects the app.

## Where the reviews disagree

1. **Is the booster rule a bug?** D2 says yes; features did not flag it because AGENTS.md and tests pin the "worst dose" semantics; Q2 frames it as script vs product. **Resolution:** adopt newest-dose-wins — with an append-only vaccination API, the current rule leaves users permanently Overdue, and the demo script already documents the intended behavior.
2. **Which photo capability flag survives?** D9 would keep `supportsPhotoPicking`; A2/A10 would keep `PetPhotos.supported`. **Resolution:** keep `PetPhotos.supported` (it sits with the picker the form calls) and delete the platform flag; A2's fix is the real user bug, D9's is cleanup.
3. **Severity of the Pages blank-page risk:** A8 MEDIUM vs Q1 HIGH for the same failure. **Resolution:** treat it as release-HIGH, but post-demo for a phone demo; move up only if the URL is shown.
4. **How bad is demo decay?** D5 says the demo goes stale within days; the script's rehearsal step (Sample data off → on) refreshes dates, so it is **not** demo-blocking.
5. **Who writes the revision notifier?** app-ui proposes declaration + bumps, features proposes the screen subscriptions; both want the same primitive. **Resolution:** one change, app side owns the declaration and bumps, features owns the subscriptions — do not implement twice.
6. **D3's fix shape:** explicit `today` parameter (testable) vs one-line `.toLocal()` (production-correct, not deterministically testable). **Resolution:** take the parameter; testability is the point.

## Bottom line

One contained pre-demo round — five changes, about a day — makes the demo truthful and removes the only path that destroys data the owner typed. Nothing else in the four reports delays the demo; none of it requires a refactor of the architecture. If less than a day is available: fix D1 and edit the demo script (D2's fallback). That is the irreducible set.
