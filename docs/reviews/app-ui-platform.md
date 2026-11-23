# `lib/app`, `lib/ui`, `lib/platform`, build configuration — refactoring review

Part of the team review of the Pet Health Tracker. Review-only round: **no source
file was modified**; this document is the only artifact.

| | |
| --- | --- |
| Scope | `lib/app/**` (composition root, router, shell, centre action, phone frame, settings, `AppScope`), `lib/ui/**` (theme, status style, kit, formats), `lib/platform/**`, `lib/main.dart`, `pubspec.yaml`, `web/`, and the platform configuration (`ios/Runner/Info.plist`, `android/app/*`, `macos/Runner/*`) |
| Read for context | `AGENTS.md`, all of `lib/features/**` (to see how the shared layers are actually consumed), `lib/data/sqlite/app_database.dart`, `lib/data/settings/*`, `lib/data/pet_photos*`, `test/app/app_boot_test.dart`, `test/ui/app_chip_test.dart`, `test/web/web_boot_test.dart`, `docs/reviews/features.md`, plus the vendored Flutter 3.47.5 and go_router 18.1.4 sources under `.flutter-sdk/` and `.pub-cache/` where a finding depends on framework behaviour |
| Method | Line-by-line read of every in-scope file; framework claims checked against the vendored SDK source (go_router branch `TickerMode`, `GoRouterDelegate.popRoute`, `ButtonStyleButton` layout, `ColorScheme` fallbacks, modal-sheet safe area); WCAG contrast computed numerically from the `AppColors` constants |
| Tool runs (read-only) | `./tool/fv analyze lib/app lib/ui lib/platform lib/main.dart` → `No issues found!` (1.5 s). `./tool/format --output=none --set-exit-if-changed lib/app lib/ui lib/platform lib/main.dart` → 3 files would change (A9; `--output=none` writes nothing). No test suite run: this round is read-only and other members are writing, so behaviour claims are traced to source, not to a red/green run |
| Cross-reference | A1 is the foundation-side half of the same root cause `docs/reviews/features.md` reports as F1/F2; its R1 covers the screen-side subscription, so the two reports must be merged, not implemented twice |

## Verdict

**Needs targeted refactoring — 3 HIGH, 5 MEDIUM, 7 LOW, 0 CRITICAL.**

The shared layer's *architecture* is sound and should not be restructured: one
`AppServices` composition root constructed exactly once in `main()`, injected
through an `InheritedWidget`, consumed only in `build`/`didChangeDependencies`;
`StatefulShellRoute.indexedStack` retains tab state; the kit is small, token-driven
and free of local status colours; the platform seam is guarded by conditional
exports and the web build cannot reach `dart:io`; the palette measures 4.56–16.41:1
on every pair the app actually paints, so there is no contrast defect to fix.
`analyze` is clean.

The defects are all **seam and guard** problems, not design problems:

1. **The shell can write and navigate without the destination knowing** (A1).
   Two of the three centre-action flows write through `services` and then `go()`
   to the tab they name; the third writes with no signal at all. When the named
   tab is already the current branch, go_router neither changes `TickerMode` nor
   reloads, so the row the user just saved is not on screen. This is the
   highest-value refactor in this area and the only one that needs a new shared
   primitive (a revision notifier in `navigation_requests.dart`).
2. **Two user-facing guards are wrong rather than missing** (A2, A3). The web
   stub declares photo support off but the form never reads the flag, so the
   deployed Pages demo offers a "Choose photo" control that always answers "No
   photo chosen." iPhone landscape is enabled, but `PhoneFrame` treats the
   rotated 874 pt width as a desktop window and letterboxes the whole app into a
   390 × ~350 card.
3. **Small, well-contained correctness gaps in the shell and boot path**
   (A4–A8): an 80 ms tap race, a fixed-height primary button that overflows at the
   largest text sizes, a one-shot request that cannot express "no filter" and is
   never drained, Android back that exits from any tab, and a boot path with no
   error screen.

Everything else is hygiene (formatting, dead seam API, unused dependencies, web
template identity, bundle ids, token bypass). Ten small, ordered changes close
all fifteen findings; none of them touches `lib/domain` or `lib/data`, and none
requires a different state-management or routing approach.

## Findings

| ID | Severity | Finding | File:line |
| --- | --- | --- | --- |
| A1 | **HIGH** | Centre-action writes then `go()` to the already-active branch — the new row stays invisible | `lib/app/shell/centre_action_sheet.dart:58` |
| A2 | **HIGH** | The web build shows a "Choose photo" control that can never work | `lib/data/pet_photos_stub.dart:7` |
| A3 | **HIGH** | Rotating an iPhone to landscape letterboxes the app into a 390 × ~350 card | `lib/app/phone_frame.dart:25` |
| A4 | MEDIUM | A tap on the current tab during a branch fade is overridden by the earlier tap | `lib/app/shell/app_shell.dart:105` |
| A5 | MEDIUM | `PrimaryButton`'s fixed 52 px height overflows its label at the largest text sizes | `lib/ui/kit/primary_button.dart:33` |
| A6 | MEDIUM | The one-shot pet-filter request cannot mean "no filter", and a pending request is never drained | `lib/app/navigation_requests.dart:12` |
| A7 | MEDIUM | Android back from a non-Home tab exits the app instead of returning Home | `lib/app/router.dart:35` |
| A8 | MEDIUM | Boot has no failure path: any error before `runApp` shows a blank window | `lib/main.dart:12` |
| A9 | LOW | Three files in this scope are not `dart format` clean | `lib/app/navigation_requests.dart:12` |
| A10 | LOW | Photo support is split across two platform seams with three capability signals, two of them dead | `lib/platform/photo_files.dart:4` |
| A11 | LOW | Two declared dependencies are unused and a driver file is orphaned | `pubspec.yaml:12` |
| A12 | LOW | The web shell still ships the Flutter template's identity | `web/index.html:32` |
| A13 | LOW | Bundle identifiers are placeholders or the original author's; Android release is debug-signed | `android/app/build.gradle.kts:19` |
| A14 | LOW | The app shell bypasses the theme tokens it exists to use | `lib/app/shell/app_shell.dart:295` |
| A15 | LOW | `AppChip` tap targets are 36 pt tall, under the project's 44 pt rule | `lib/ui/kit/app_chip.dart:79` |

---

## A1 — [HIGH] Centre-action writes then `go()` to the already-active branch

**File:** `lib/app/shell/centre_action_sheet.dart:58` (also `:82`; write paths
`:54-58`, `:78-82`, `:98-106`; the missing primitive is
`lib/app/navigation_requests.dart:12`)

**Issue:** From the Appointments tab, tap the raised `+` → *Book a vet visit* →
fill the form → *Book visit*. `showAppointmentBookingSheet` returns, the row has
been committed by `services.appointments.create`, the snackbar says "Appointment
booked.", and then `_bookVisit` calls `GoRouter.of(context).go(Routes.appointments)`
(`:58`). The shell is already on branch 2, so `go()` produces a route match with
the same branch index; `StatefulShellRoute.indexedStack` keeps the branch built
and `TickerMode(enabled:)` stays `true`, so `AppointmentsScreen.didChangeDependencies`
(the activation reload at `lib/features/appointments/appointments_screen.dart:52-58`)
never runs and the screen still renders the list it loaded when the tab was first
opened — without the visit just booked. On a first-run household the empty state
is returned before the `RefreshIndicator`, so even pull-to-refresh cannot recover.
The identical path for *Log an entry* → `go(Routes.journal)` (`:82`) leaves the
Journal feed stale the same way. The health-record flow (`:98-106`) does not
navigate but is the same write-with-no-signal pattern.

**Why existing guards do not catch it:** the shell's branch-activation mechanism
is exactly `TickerMode`, which the four screens read (`home_screen.dart:85`), and
the vendored go_router 18.1.4 really does drive it —
`_IndexedStackedRouteBranchContainer` wraps each branch in
`TickerMode(enabled: isActive)` (`route.dart:1779`). A `go()` to the current
branch does not change that value. The `AppShellSelection` fade helper (`app_shell.dart:137-160`) is not
used by the centre action, and even it would early-return for
`index == currentIndex` (`:105`). The only test that exercises booking through the
centre action, `test/app/app_boot_test.dart:122-160`, starts on **Home**, so the
Appointments branch is built after the write and loads fresh data; the
already-active case is never pumped. This is the root cause the features audit
reported as symptoms F1/F2.

**Proposed minimal fix:** add one shared, app-owned one-shot signal next to the
existing request — `static final ValueNotifier<int> householdRevision` in
`lib/app/navigation_requests.dart` — and bump it once after each successful
centre-action write (`centre_action_sheet.dart:54-58`, `:78-82`, `:98-106`).
The four branch screens subscribe while their branch is `_branchActive` and
reload on the tick (screen-side change; `docs/reviews/features.md` R1 already
specifies it). Do **not** implement the signal twice: the app side owns the
declaration and the bumps, features owns the subscriptions. Effort **S**.

## A2 — [HIGH] The web build shows a "Choose photo" control that can never work

**File:** `lib/data/pet_photos_stub.dart:7` (`supported => false`); the unguarded
consumer is `lib/features/pets/forms/pet_form_sheet.dart:300-306`

**Issue:** In the deployed Pages build — the audience the README advertises first
("Friends who just want to use it in a browser") — open Profile → *Add a pet*
(or a pet page → Edit). The photo block is rendered unconditionally and offers
"Choose photo". Tapping it calls the stub `pickFromLibrary()`, which returns
`null` immediately because web stores no photo paths; `_pickPhoto` interprets a
`null` as "the user backed out of the picker" and answers with the snackbar
"No photo chosen." (`pet_form_sheet.dart:162-168`). The control is dead and the
copy blames the user for a picker that never opened.

**Why existing guards do not catch it:** the stub declares
`static bool get supported => false` and its docstring says "so the form hides the
control", but nothing in `lib/` or `test/` reads `PetPhotos.supported` (grep: it is
defined in the io and stub files only). `lib/platform/photo_files_stub.dart:9`
adds a *second* unused capability flag (`supportsPhotoPicking`) that was evidently
meant for the same gate, which made the missing consumer easy to miss. No widget
test pumps the pet form under the web stub; the form tests run on the native (io)
implementation where the picker is real.

**Proposed minimal fix:** wrap the photo block (`pet_form_sheet.dart:286-313`) in
`if (PetPhotos.supported)` and, when false, show the one-line note the README
already promises ("Photos aren't available in the browser; the drawn portrait is
used"). Delete the duplicate `supportsPhotoPicking` flag in the same pass (A10).
Effort **S**.

## A3 — [HIGH] Rotating an iPhone to landscape letterboxes the app into a 390 × ~350 card

**File:** `lib/app/phone_frame.dart:25` (width guard) and `:28` (height);
`ios/Runner/Info.plist:61-62` allows the rotation

**Issue:** `UISupportedInterfaceOrientations` lists `LandscapeLeft` and
`LandscapeRight` for iPhone, so the app rotates. On rotation the logical window
becomes e.g. 874 × 402 (iPhone 17 Pro) or 667 × 375 (SE). `PhoneFrame` is
installed on **every** platform (`lib/app/app.dart:55-56`) and only checks
`size.width <= 560`; 874 > 560, so it treats a rotated phone as a desktop window:
it centres the app in a 390 × (402 − 48) = 390 × 354 card, paints the letterbox in
`AppColors.hairline`, and zeroes `padding`/`viewInsets` for the child. The user
rotates a phone and the whole app shrinks into a small card floating in grey —
on the SE the card is only 327 pt tall, and the pet page / sheets were designed
for an 844 pt surface.

**Why existing guards do not catch it:** the file's own docstring says it "leaves a
phone untouched", but the guard is width-based, so it leaves *portrait* phones
untouched only; nothing sets `SystemChrome.setPreferredOrientations`, no test
pumps the app at a landscape size, and the widget-test default surface (800 × 600)
exercises the frame without ever asserting on it. `analysis_options.yaml` excludes
`ios/**`, so the plist is outside the analyzer's view.

**Proposed minimal fix:** pick one, both are one-line:
(a) contract-aligned — drop the two landscape entries from
`UISupportedInterfaceOrientations` in `ios/Runner/Info.plist:58-63` (keep the iPad
array), so a phone stays portrait like the web manifest declares
(`orientation: portrait-primary`); or
(b) frame-guard — change `phone_frame.dart:25` to
`if (size.shortestSide < 600) return child;`, so phones (any orientation) pass
through and only genuinely wide windows are framed. Effort **S**.

## A4 — [MEDIUM] A tap on the current tab during a branch fade is overridden by the earlier tap

**File:** `lib/app/shell/app_shell.dart:105` (the early return), with the race at
`:110-118`

**Issue:** Tap *Journal*, then within the 80 ms fade-out tap *Home* (the current
tab). The Home tap enters the `index == shell.currentIndex` branch and returns
after `goBranch(index, initialLocation: true)` **without** bumping `_generation`
and without cancelling the running animation. The in-flight `_select(1)` then
finishes `await _fade.reverse()` (now at 0), sees `generation != _generation` is
false (`:113`), calls `shell.goBranch(1)` and fades back in. The app ends on
Journal although Home was the last tap. The comment at `:84-85` promises "a
second tap supersedes the first instead of being ignored"; that is true only when
the second tap is a *different* index. The reverse sequence (tap Home on Home
while a fade is in flight) also leaves the destination button of the pending tab
moving while the bar already highlights Home.

**Why existing guards do not catch it:** the generation counter is only advanced
on the different-index path, and the current-tab path neither stops the ticker nor
restores opacity. `test/app/app_boot_test.dart` taps one tab and then
`pumpAndSettle`s before the next tap, so the overlap never exists in tests; the
window is 80 ms, which is short but reachable on a double tap.

**Proposed minimal fix:** in the `index == shell.currentIndex` branch, cancel the
in-flight select before switching —
`_generation++; _fade.value = 1;` — then `shell.goBranch(index, initialLocation: true)`.
Assigning `_fade.value` stops the controller (which cancels the awaited
`TickerFuture`), and the generation bump is belt-and-braces if the continuation
does resume. Effort **S**.

## A5 — [MEDIUM] `PrimaryButton`'s fixed 52 px height overflows its label at the largest text sizes

**File:** `lib/ui/kit/primary_button.dart:33` (the theme's baseline is
`lib/ui/theme/app_theme.dart:197`)

**Issue:** `PrimaryButton` wraps the `FilledButton` in `SizedBox(height: 52)`,
which turns the button's 52 pt minimum into a hard maximum. The theme sets the
button label to `AppTextStyles.body` (15 px, `height: 1.35`, so a 20.25 px line at
1×). At iOS *Larger Text* AX4 (≈2.35×) the line is ≈48 px and at AX5 (≈3.12×) it
is ≈63 px; M3's default button padding has zero vertical inset, so at AX5 the
"Save pet" / "Book visit" label is laid out in a 52 px box and paints ≈11 px
outside the accent pill — over the sheet content above/below the button, on every
form. At 2× it still fits, so this is specifically the largest accessibility sizes
that the app says it supports.

**Why existing guards do not catch it:** `flutter analyze` cannot see layout, all
widget tests run at the default 1.0 text scaler, and the theme's
`minimumSize: Size.fromHeight(52)` reads as if the button were text-scale
friendly. The kit comment documents 52 px as the design ("52 px filled accent
button"), so the fixed height looks intentional rather than load-bearing.

**Proposed minimal fix:** let the height be a floor —
`SizedBox(width: expand ? double.infinity : null, child: button)` and rely on the
theme's `minimumSize` for the 52 pt baseline; the button then grows with the
label. Effort **S**.

## A6 — [MEDIUM] The one-shot pet-filter request cannot mean "no filter", and a pending request is never drained

**File:** `lib/app/navigation_requests.dart:12`; consumer
`lib/features/appointments/appointments_screen.dart:62-69`; producer
`lib/features/home/home_screen.dart:224-232`

**Issue:** the request is `ValueNotifier<int?>` where `null` is both "nothing was
requested" and "requested: show all pets". `_openAppointments(petId: null)` is the
intentional second case — Home's "no upcoming visit" card
(`home_screen.dart:470`) and "View in Appointments" for an appointment whose pet
was deleted (`appointment.petId` is nullable, `home_screen.dart:211`) both send
`null`. `_applyRequestedFilter` reads `null` as "no request" and returns before
calling `selectPet(null)`, so a pet filter chosen earlier on the Appointments chip
row (`appointments_screen.dart:156-183`) survives: the user taps "View in
Appointments" on a household visit and is shown a *different* pet's list — the
visit they tapped is not on it. Second failure mode: nothing drains the request
except a successful activation. If the switch is superseded or interrupted (e.g.
the A4 race, a future direct `go`, a test, or a shell rebuild), the value stays
set and is consumed by a later, unrelated visit; `AppServices.resetHousehold()`
(`lib/app/app_services.dart:118-128`) does not clear it either, so the stale id of
a deleted pet can be applied afterwards — `_PetFilterRow` then shows no selected
chip (`"All pets"` is only selected when the id is `null`) and the list is empty.

**Why existing guards do not catch it:** the request has no "present" marker, no
drain method and no owner; the only clear is the consumer's inline `= null`, which
runs only when the value is non-null and the branch activates. The UI renders from
`controller.petFilterId`, not from the request, so nothing can notice the
mismatch. The only test that touches the filter (`test/features/appointments`)
drives `selectPet` directly, never the request.

**Proposed minimal fix:** make the request an explicit one-shot value object in
the same file — e.g. `class AppointmentsListRequest { const AppointmentsListRequest({this.petId}); final int? petId; }`
with `static final ValueNotifier<AppointmentsListRequest?> appointmentsRequest`
and a single `static AppointmentsListRequest? takeAppointmentsRequest()` that
reads and clears; the consumer always calls `selectPet(request.petId)` (including
`null`) when `take` returns non-null; `resetHousehold` calls
`NavigationRequests.clear()`. This also gives A1's `householdRevision` a natural
home. Effort **S**.

## A7 — [MEDIUM] Android back from a non-Home tab exits the app instead of returning Home

**File:** `lib/app/router.dart:35-93` (no intercept); shell
`lib/app/shell/app_shell.dart:103-119`

**Issue:** on Android, with Journal/Appointments/Profile active, press back. The
route tree has one page in the active branch navigator and one shell page under
the root navigator, so go_router's `popRoute` (`delegate.dart:56-79` in the
vendored 18.1.4) walks `maybePop()` and returns `false`; Flutter's
`WidgetsBinding.handlePopRoute` then falls through to `SystemNavigator.pop()` and
the app closes from any tab. The user loses their place instead of being returned
to the start destination, which is the Android convention for bottom-bar apps.
On the pet page back works (it is a pushed route); the web is unaffected because
the browser owns history.

**Why existing guards do not catch it:** nothing intercepts back — `GoRouter` is
built with no `onExit`, no `PopScope` wraps the shell, and
`test/app/app_boot_test.dart` never calls `handlePopRoute` (it taps tabs). The
behaviour is a framework default, so `analyze` and the widget tests cannot see it.

**Proposed minimal fix:** wrap the shell body in
`PopScope(canPop: widget.navigationShell.currentIndex == 0, onPopInvokedWithResult: (bool didPop, Object? _) { if (!didPop) _select(AppShellSelection.home); })`
inside `AppShell.build` (`app_shell.dart:122-134`). Back then fades to Home from
any other tab, and exits from Home as users expect. Effort **S**.

## A8 — [MEDIUM] Boot has no failure path: any error before `runApp` shows a blank window

**File:** `lib/main.dart:12`

**Issue:** `openAppServices()` opens the database, loads settings and seeds the
household inside `main()` before `runApp`. If any step throws, the exception is
unhandled and `runApp` is never reached: the user gets a white window with no
copy, no retry and no way to recover. Concrete inputs: the web build cannot fetch
`sqlite3.wasm` (served with a wrong MIME type, blocked by an extension/proxy) or
IndexedDB is unavailable (private mode / quota), a native database path or plugin
fails to initialise, or the settings file raises something other than
`FormatException` — `JsonSettingsStore.read` only catches `FormatException`
(`lib/data/settings/settings_store_io.dart:26`), so a permission/IO error
propagates straight out of `openAppServices`. On the Pages demo this is the whole
first impression.

**Why existing guards do not catch it:** the boot tests never call `main()` —
`test/app/app_boot_test.dart` builds `PetHealthTrackerApp` with an already-open
harness — and `test/web/web_boot_test.dart` is `@TestOn('browser')`, which
`flutter test` does not run on the VM CI job. There is no `try`/`catch`, no
`runZonedGuarded`, no error app, and no `ErrorWidget.builder` override.

**Proposed minimal fix:** catch the boot failure and render a minimal error app —
`try { services = await openAppServices(); } catch (error) { runApp(BootFailureApp(error: error)); return; }`
in `main()`, where `BootFailureApp` is a `MaterialApp` with the theme, a short
message ("The household notebook could not be opened.") and a Retry button that
calls `main()` again (plus a "clear site data" hint on web via `kIsWeb`). Effort
**S**.

## A9 — [LOW] Three files in this scope are not `dart format` clean

**File:** `lib/app/navigation_requests.dart:12`; also `lib/ui/kit/app_chip.dart:78-109`
and `lib/platform/platform_database_io.dart:10`

**Issue:** `./tool/format --output=none --set-exit-if-changed lib/app lib/ui lib/platform lib/main.dart`
reports `Changed lib/app/navigation_requests.dart`, `Changed lib/ui/kit/app_chip.dart`,
`Changed lib/platform/platform_database_io.dart` (34 files, 3 changed). The
`AppChip` body is visibly mis-indented (the `ConstrainedBox`/`InkWell` block at
`:78-109`), and `platform_database_io.dart:10` is over the line limit. Nothing
breaks at runtime; the risk is review noise and the convention that formatting is
enforced.

**Why existing guards do not catch it:** `flutter analyze` does not check
formatting, the deploy workflow runs only `analyze` + `test`
(`.github/workflows/deploy-web.yml`), and AGENTS.md deliberately leaves the
full-tree `--set-exit-if-changed` check to an integration pass that this round
never ran.

**Proposed minimal fix:** run `./tool/format lib/app lib/ui lib/platform lib/main.dart`
in the integration pass (whitespace only) and add
`./tool/format --output=none --set-exit-if-changed lib test` as a CI step. Effort
**S**.

## A10 — [LOW] Photo support is split across two platform seams with three capability signals, two of them dead

**File:** `lib/platform/photo_files.dart:4`; also `lib/data/pet_photos.dart:7`,
`lib/platform/photo_image.dart:4`, `lib/platform/photo_files_stub.dart:9`

**Issue:** the same `dart.library.io` dispatch is implemented three times for one
concern: `PetPhotos` (pick/store/delete) in `lib/data`, `photoExists` +
`supportsPhotoPicking` in `lib/platform/photo_files.dart`, and `photoImage` in
`lib/platform/photo_image.dart`. The capability signals disagree with each other
in name and consumer: the io files say `true`, the stubs say `false`, and nothing
reads either flag (`PetPhotos.supported` is the one A2 shows is unread;
`supportsPhotoPicking` has no caller). Adding a platform (or fixing A2) means
editing two layers and keeping three flags in sync by memory, and the one
behaviour that actually matters (`existsSync` on an owned path) is duplicated
across the seam.

**Why existing guards do not catch it:** `analysis_options.yaml` cannot see unused
public API, the layering rules allow both directories (`lib/data` owns photo
storage, `lib/platform` owns platform dispatch), and the one seam test runs on the
native implementation only.

**Proposed minimal fix:** keep one seam: move `PetPhotos` under `lib/platform/`
next to `photo_files.dart`/`photo_image.dart` (or fold `photoExists`/`photoImage`
into `lib/data/pet_photos.dart`) and delete `supportsPhotoPicking` +
`PetPhotos.supported` once A2's single `supported` flag is read by the form. No
behaviour change. Effort **M** (mechanical; touches feature imports).

## A11 — [LOW] Two declared dependencies are unused and a driver file is orphaned

**File:** `pubspec.yaml:12` (`cupertino_icons`) and `:25` (`integration_test`);
`test_driver/integration_test.dart:1-4`

**Issue:** `cupertino_icons` is imported nowhere (`grep -rn "CupertinoIcons\|cupertino_icons" lib test`
→ no matches), so its bundled icon font is resolved and shipped for nothing. `integration_test`
is a dev dependency, but the repository has no `integration_test/` directory —
only the driver `test_driver/integration_test.dart`, which calls
`integrationDriver()` for a suite that does not exist, so the dependency can never
run and CI never invokes it. Both stay in `pubspec.lock` and the resolve graph
forever.

**Why existing guards do not catch it:** `flutter analyze` does not report unused
package dependencies, and the deploy workflow runs `flutter test` only, which
ignores `test_driver/`; nothing else references either name.

**Proposed minimal fix:** remove `cupertino_icons` and `integration_test` from
`pubspec.yaml` and delete `test_driver/` (or, if the driver is meant to stay, add
the missing `integration_test/app_test.dart` and a CI job that runs it). Effort
**S**.

## A12 — [LOW] The web shell still ships the Flutter template's identity

**File:** `web/index.html:32`; also `:21`, `:26`, and `web/manifest.json:2-3,7-8`

**Issue:** the published Pages build is titled `pet_health_tracker` in the browser
tab, its description meta and PWA manifest both read "A new Flutter project.",
and the PWA `theme_color`/`background_color` are the template blue `#0175C2`
rather than the app's `#0E6B5F`/`#FAF8F5`. When a friend installs the demo to a
home screen, the name, icon splash and window chrome are visibly not this app.

**Why existing guards do not catch it:** `flutter build web` copies these files
verbatim; `analysis_options.yaml` excludes `web/**`, no test asserts the document
title, and the README links the Pages URL without mentioning the shell copy.

**Proposed minimal fix:** set `<title>Pet Health Tracker</title>`, the description,
`apple-mobile-web-app-title`, and the manifest `name`/`short_name`/`description`,
and change `theme_color` to `#0E6B5F` and `background_color` to `#FAF8F5`. Effort
**S**.

## A13 — [LOW] Bundle identifiers are placeholders or the original author's; Android release is debug-signed

**File:** `android/app/build.gradle.kts:19` (also `:8`, `:18`, `:34`, `:36`);
`android/app/src/main/AndroidManifest.xml:3`;
`macos/Runner/Configs/AppInfo.xcconfig:11`;
`ios/Runner.xcodeproj/project.pbxproj:387`

**Issue:** the Android `applicationId`/`namespace` are the Flutter placeholder
`com.example.pet_health_tracker`, the launcher label is the package name
(`pet_health_tracker`), release builds are signed with the debug key, and two
template TODO comments remain. macOS is `com.example.petHealthTracker` with
`PRODUCT_NAME = pet_health_tracker` (so the desktop window title is the package
name), while iOS is the original author's `com.danielestillore.petHealthTracker`.
Consequence: no store upload is possible from this tree, `com.example.*`
collides with every other sample app (side-by-side installs, backup restore), and
the three platforms do not share one identity.

**Why existing guards do not catch it:** the README documents changing the iOS
bundle id for a device build, which makes the iOS value look intentional; nothing
in CI builds a signed Android artifact, and the analyzer excludes
`android/ios/macos`.

**Proposed minimal fix:** pick one real identifier (e.g.
`com.<household>.pethealthtracker`) and use it for Android `applicationId` +
namespace, iOS and macOS; set the Android label and macOS `PRODUCT_NAME` to
"Pet Health Tracker"; remove the TODO comments; document (or configure) release
signing. Effort **S**.

## A14 — [LOW] The app shell bypasses the theme tokens it exists to use

**File:** `lib/app/shell/app_shell.dart:295`; also `:292-296` and `:345`

**Issue:** the destination label is
`AppTextStyles.caption.copyWith(fontSize: 11)` — a raw type size, while AGENTS.md
§UI kit and the theme's own header say "never hard-code … type sizes". The
literal also hides that 11 px sits exactly on the documented 11 px floor, so the
only place that boundary is reached is invisible in review. The raised centre
action's shadow is `const Color(0x330E6B5F)` (`:345`), a raw hex colour where the
rest of the app derives tints from `AppColors` (the theme's own splash literals
at `app_theme.dart:275-276` are acceptable because that file is the token home).

**Why existing guards do not catch it:** `flutter_lints` has no magic-number rule,
and the shell's tests assert keys/labels/semantics, not styles; the grep patterns
used before this round looked for hex in `lib/features`, not `lib/app`.

**Proposed minimal fix:** add a `navLabel` style to `AppTextStyles` in
`app_theme.dart` (caption size 11, weight resolved at the call site) and use it at
`app_shell.dart:292-296`; replace the shadow literal with a token or
`Color.alphaBlend(AppColors.accent.withValues(alpha: 0.2), Colors.transparent)`.
Effort **S**.

## A15 — [LOW] `AppChip` tap targets are 36 pt tall, under the project's 44 pt rule

**File:** `lib/ui/kit/app_chip.dart:79`

**Issue:** `ConstrainedBox(minHeight: 36)` with `vertical: 8` padding yields a
36 pt tappable pill (the text is 15.6 pt tall, so the constraint decides the
height); `dense` drops the content to ≈27.6 pt and still clamps to 36. Every
quick-log chip on Home and every pet-filter chip on Appointments is therefore an
8 pt-under tap target relative to AGENTS.md §Conventions ("tap targets ≥ 44 px").
For motor-accessibility users the filter row — a horizontally scrolling strip of
small targets — is the only way to narrow the list.

**Why existing guards do not catch it:** Material's own chip height is 32, so 36
looks generous; `test/ui/app_chip_test.dart` pins colours and contrast but never
size; no lint enforces the 44 pt rule, and this audit's grep only looked at
explicit `SizedBox`/`height:` values, not `minHeight`.

**Proposed minimal fix:** raise the tappable box to 44 (`minHeight: 44`, reducing
the vertical padding to keep the visible pill close to its current 36 pt) or wrap
the `InkWell` in a 44-high transparent hit area without changing the painted pill.
Effort **S**.

---

## Checked and clean (no finding)

These were audited specifically and are worth recording, because they are the
places a reviewer would expect a defect:

**1. Composition and lifecycle.** `AppServices` is constructed exactly once
(`openAppServices`, `di.dart:16-43`), `bootstrap()` runs once, and nothing can
open a second database: `main()` is the only caller and `AppDatabase.openDefault`
is reached only through `openAppServices`. Every `AppScope.of` lookup in `lib/`
is in `build`/`didChangeDependencies` (six call sites; the two `late final`
captures are in `didChangeDependencies` with explanatory comments at
`profile_screen.dart:55`/`pet_detail_screen.dart:68`, never `initState`).
`AppScope` wraps `MaterialApp.router`, so sheets, dialogs and the shell all
resolve it. Disposal is complete: `_router.dispose()` (`app.dart:38-41`),
`_fade.dispose()` (`app_shell.dart:97-101`), `_pageController.dispose()` and every
screen controller; `AppSettings` keeps no external listeners and is disposed with
`AppServices`; `AppServices.dispose()` is intentionally not called in `main` (the
database lives for the process). No `print`, no TODO/FIXME, no dead placeholder
screen in the scope. `AppServices.resetHousehold` deletes photos before pets and
toggles the sample-data setting through the one correct path.

**2. Navigation mechanics.** For a `StatefulShellRoute.indexedStack`, go_router
18.1.4 really does wrap each branch in `TickerMode(enabled: isActive)`
(`route.dart:1779`), so the branch-activation reload pattern the app relies on is
sound — the gaps are A1 (no signal when the branch does not change) and A4 (the
fade race), not the mechanism. Branch state is retained. The pet page is the only
top-level route; a malformed `/pets/abc` deep link falls back to `petId: -1` and
renders the real "Pet not found" `EmptyState` with a Go back action
(`pet_detail_screen.dart:165-191`). `initialLocation` does not clobber web deep
links: go_router only applies it when the platform default route is `/`
(`_effectiveInitialLocation`, `router.dart:621-635`), and the app uses the default
hash URL strategy, so a refresh on `/#/appointments` under the Pages base-href
still lands on Appointments. No other imperative navigation exists in `lib/app`
(grep for `.go(`/`.push(`/`goBranch`): only the two centre-action calls (A1) and
the shell's branch switches — so the captain's "other `go()` calls" question is
answered: there are none.

**3. Theme and contrast (measured).** WCAG ratios of the pairs the app actually
paints: `secondary`/`paper` 5.36, `secondary`/`surface` 5.68, `accent`/`paper`
6.03, `accent`/`surface` 6.39, white/`accent` 6.39, `overdue`/`overdueSurface`
5.67, `dueSoon`/`dueSoonSurface` 4.56, `upToDate`/`upToDateSurface` 5.62,
`ink`/`paper` 16.41, accent chip tint 5.51 — every pair ≥ AA 4.5:1 for the sizes
used, so there is no contrast finding. The deliberately partial
`ColorScheme.light` is safe: unset container colours fall back to the palette
(`secondaryContainer → secondary`, `onSecondaryContainer → onSecondary`, and the
`primaryContainer` family likewise), so `SegmentedButton`'s selected segment
renders accent-on-white rather than M3 lavender. `TextTheme` covers each style
Material asks for. The only text-scaling break found is A5; the kit's other
fixed sizes are minimums that grow (`ListRow` 60, `AppChip` 36+), and the shell's
76 pt bar is the tightest case (75.6 pt of content at 3.12×) but still fits, so it
is not reported. The one sub-44 target in the kit is A15.

**4. Platform seam.** No web build can reach `dart:io`: every `dart:io` import
lives in a `*_io.dart` library reached only through an
`export '…_stub.dart' if (dart.library.io) '…_io.dart'` guard, and the only direct
`_io` import is `platform_settings_io.dart → settings_store_io.dart` (io→io,
never on web). `web/sqlite3.wasm` is present (748,686 bytes), as are
`web/index.html`, `manifest.json` and the icons; the web database boots through
`databaseFactoryFfiWebNoWebWorker` with a documented main-thread trade-off.
Settings parity holds (same map contract, corrupt JSON → defaults on both
platforms). Database parity holds (same `({factory, path})` record; the app owns
`db/schema.sql` as an asset on both). iOS declares
`NSPhotoLibraryUsageDescription`; macOS has app-sandbox +
`files.user-selected.read-only` and no network entitlement (image_picker/desktop
picker works); deployment targets (iOS 15, macOS 12) are consistent with the
plugins, and `sqflite_darwin` does support macOS, so the README's desktop target
is real. Photo parity is A2, seam shape is A10.

**5. Build configuration.** `analyze` is clean; the only asset (`db/schema.sql`)
is declared; dependency ranges are caret-ranged with a committed lock; the
offline contract holds (no HTTP client, auth, analytics or telemetry dependency);
CI pins the SDK to 3.47.5 and builds with a `--base-href` that matches the Pages
repository path. `cupertino_icons`/`integration_test` hygiene is A11; the web
identity is A12; platform identity is A13.

**6. Rebuild cost.** Nothing in this scope rebuilds expensively. `AppShell.build`
is a `Scaffold` + `FadeTransition` + a stateless bar, and only the shell rebuilds
when the branch index changes; `AppShellSelection.updateShouldNotify` compares the
`select` function, and Dart instance-method tear-offs on the same `State` compare
equal, so wrapping the branch tree in that `InheritedWidget` does not notify on
every shell rebuild. The kit is stateless and `const`-constructible
(`AppCard`, `ListRow`, `SectionLabel`, `StatusDot`, `EmptyState`), and no kit
widget does work in `build` beyond reading its arguments. The only per-build I/O
is `photoExists`'s synchronous `File.existsSync()`
(`lib/platform/photo_files_io.dart:12`), called once per visible pet avatar
(`lib/features/home/widgets/pet_card.dart:153`, `lib/features/pets/pet_photo.dart:27`)
— a single `stat` per card rebuild, unnoticeable at household scale; it is noted
rather than reported, because the alternative (async existence checks) would
complicate every list for no measurable gain.

## What genuinely needs refactoring

Ordered by value. **S/M/L** = effort. Each row names the findings it closes.

| # | Effort | Refactor | Closes |
| --- | --- | --- | --- |
| R1 | **S** | **A cross-branch write signal.** Add `ValueNotifier<int> householdRevision` to `lib/app/navigation_requests.dart`, bump it once after each successful centre-action write, and have the four branch screens subscribe while active and reload. App side = the file + bumps; screen side is `docs/reviews/features.md` R1. One primitive, one place. | A1 |
| R2 | **S** | **Make one-shot requests explicit.** Replace `ValueNotifier<int?>` with a nullable request object + `take()` that reads and clears in one call; always apply the pet (including `null`); clear pending requests from `resetHousehold`. | A6 (and removes the A4-adjacent leak path) |
| R3 | **S** | **Shell interaction correctness.** Cancel the in-flight fade (and restore opacity) when the current tab is tapped; wrap the shell body in a `PopScope` that fades to Home for back from other tabs. | A4, A7 |
| R4 | **S** | **Web photo gate.** Hide the photo control when `PetPhotos.supported` is false and show the portrait note instead; delete the duplicate `supportsPhotoPicking` flag. | A2, part of A10 |
| R5 | **S** | **Phone orientation / frame guard.** Either make iPhone portrait-only in `Info.plist` (contract) or make `PhoneFrame` key off `shortestSide`, not width. | A3 |
| R6 | **S** | **Boot failure screen.** Catch `openAppServices` failures in `main()` and render a themed error app with Retry; optionally `runZonedGuarded`. | A8 |
| R7 | **S** | **Kit accessibility pass.** Let `PrimaryButton` grow from a 52 pt floor; bring `AppChip`'s hit area to 44. One pass, both are single-line changes plus tests. | A5, A15 |
| R8 | **M** | **One photo seam.** Move `PetPhotos` next to `photo_files.dart`/`photo_image.dart` (or fold the latter into the data seam), one `supported` flag, no dead capability getters. | A10 |
| R9 | **S** | **Ship hygiene.** Remove unused dependencies and the orphan driver; fill in the web title/description/manifest colours; set one real bundle id across Android/iOS/macOS, remove the template TODOs and state the release-signing story. | A11, A12, A13 |
| R10 | **S** | **Formatting + tokens.** `./tool/format` on the three files, add the format check to CI, and move the shell's 11 px label and shadow hex into `AppTextStyles`/`AppColors`. | A9, A14 |

**What should not be refactored.** The composition root and the shell design are
right for this app and should stay: one `AppServices` built in `main()`, injected
through `AppScope` (`InheritedWidget`), consumed in
`build`/`didChangeDependencies` only; `StatefulShellRoute.indexedStack` with
`TickerMode`-driven activation; a small token-driven kit with one status palette;
a `dart.library.io` platform seam; Material 3 theme in one file; the deliberately
partial `ColorScheme` (it falls back to the palette correctly — do not "fix" it
by hand-setting container colours). No provider/Riverpod/Bloc, no repository or
schema change, no router rewrite, and no `lib/domain`/`lib/data` change is needed
from this scope. R1 and R2 are the only changes that add shared API, and both are
small additions to an existing file; everything else is a guard, a token or a
configuration value.
