# `lib/features` — refactoring review

Part of the team review of the Pet Health Tracker. Review-only round: **no source
file was modified**; this document is the only artifact.

| | |
| --- | --- |
| Scope | `lib/features/**` — `home/` (+ `widgets/`, onboarding card), `journal/`, `appointments/`, `pets/` (+ `forms/`, photo), `profile/`, `onboarding/` |
| Read for context | `AGENTS.md`, `lib/app/` (shell, router, `AppScope`, services, settings, navigation requests), `lib/ui/` (theme, kit, formats), `lib/domain/` (models, rules, dashboard), `lib/data/` seams that features call, and every `test/features/**` + `test/app/app_boot_test.dart` |
| Method | Line-by-line read of all 31 feature files; verified behaviour against the Flutter 3.47.5 / go_router 18.1.4 sources in the workspace SDK (`.flutter-sdk`, `.pub-cache`) where the finding depends on framework behaviour |
| Not run | No `analyze`/`test`/`format` run: this round is read-only and other members are writing (`AGENTS.md` "Scope-limited tool runs"). Every claim below is traceable to the cited `file:line` |

## Verdict

**Needs targeted refactoring — 3 HIGH, 6 MEDIUM, 5 LOW, 0 CRITICAL.**

The feature layer itself is healthy: controller-per-screen with `ChangeNotifier`,
services resolved in `didChangeDependencies` (never `initState`), every controller
with a `_disposed` latch and a complete `dispose()`, no timers, no wall-clock
reads, no SQL, no raw hex, all dates formatted through `lib/ui/format`, and all
four branch screens already implement the `TickerMode` reload pattern.

The defects concentrate on **three seams**, not in the controllers:

1. **Write → refresh across an already-active branch.** The raised centre action
   (shell-owned) writes through `services` and then `go()`s to a tab. If that tab
   was already active, `TickerMode` never changes, so the branch's activation
   reload never fires and the write is invisible (F1, F2). This is one root
   cause with one fix; it is the highest-value refactor in this area.
2. **Return from a pushed route → refresh.** Profile opens the pet page
   fire-and-forget, so a pet edited on that page stays stale on Profile (F3) —
   the same class as the already-fixed "Profile stale name on tab activation".
3. **Absolute layout constants.** The pet page's two sheet stops are hard-coded
   against 844 pt (F4) and Home's pet card is hard-coded to 264 pt (F7). Both
   fail on real phones (SE-class portrait, large text) and on the deployed web
   build at small window heights.

Everything else is polish: a destructive tap with no confirmation, an onboarding
error path that can wedge the screen, a forked icon/avatar identity between Home
and Journal, and four narrow sheet/error-handling gaps.

The architecture should **not** be restructured: no provider/Riverpod, no lifting
the controllers into the shell, no changes to `lib/domain` or `lib/data`, no form
framework. Nine small, ordered changes (bottom of this document) close everything
found here.

## Findings

| ID | Severity | Finding | File:line |
| --- | --- | --- | --- |
| F1 | **HIGH** | Booking a visit from the centre action leaves an already-active Appointments tab stale | `lib/features/appointments/appointments_screen.dart:52` |
| F2 | **HIGH** | Logging an entry from the centre action leaves an already-active Journal feed stale | `lib/features/journal/journal_screen.dart:54` |
| F3 | **HIGH** | Profile pet rows never reload after the pet page pops | `lib/features/profile/profile_screen.dart:203` |
| F4 | MEDIUM | Pet page: sheet stops are pinned to an 844 pt surface (clipped on SE-class portrait, zero-height below 560 pt) | `lib/features/pets/pet_detail_screen.dart:244` |
| F5 | MEDIUM | Onboarding "start with the sample household" has no error path and can wedge the Welcome card | `lib/features/onboarding/first_run_card.dart:95` |
| F6 | MEDIUM | Onboarding save blanks the stored owner email and phone | `lib/features/onboarding/first_run_card.dart:71` |
| F7 | MEDIUM | Home's fixed 264 pt pet card overflows at ≥1.5× text scale | `lib/features/home/home_screen.dart:44` |
| F8 | MEDIUM | Journal delete is a single irreversible tap (no confirm, no undo) | `lib/features/journal/journal_entry_sheet.dart:221` |
| F9 | MEDIUM | The same journal kind renders different icons and badge shapes on Home vs Journal | `lib/features/journal/journal_screen.dart:260` |
| F10 | LOW | Picked photo files are orphaned when the form is cancelled or a second photo is picked | `lib/features/pets/forms/pet_form_sheet.dart:159` |
| F11 | LOW | A form sheet dismissed mid-save loses the caller's refresh (row saved, list not reloaded) | `lib/features/pets/forms/pet_form_sheet.dart:141` |
| F12 | LOW | Reload failures after data exists are silent; a tab switch shows the previous tab's rows | `lib/features/appointments/appointments_screen.dart:209` |
| F13 | LOW | Pet chooser reports a database read failure as "No pets yet" | `lib/features/pets/pet_chooser_sheet.dart:71` |
| F14 | LOW | Quick-log form silently drops an unparsable duration | `lib/features/home/widgets/quick_log_form_sheet.dart:118` |

---

## F1 — [HIGH] Booking a visit from the centre action leaves an already-active Appointments tab stale

**File:** `lib/features/appointments/appointments_screen.dart:52` (write path:
`lib/app/shell/centre_action_sheet.dart:50-58`)

**Issue:** From the Appointments tab, tap the raised `+` → *Book a vet visit* →
fill clinic/purpose → *Book visit*. `showAppointmentBookingSheet` returns `true`,
`services.appointments.create` has committed the row, the snackbar says
"Appointment booked." and `_bookVisit` calls
`GoRouter.of(context).go(Routes.appointments)` (`centre_action_sheet.dart:58`).
The shell is already on branch 2, so `TickerMode(enabled:)` never flips, the
branch never gets `didChangeDependencies`, and the screen still renders its
previous `_appointments` snapshot: the visit the user just booked is absent. On a
first-run household the list is empty and the "No upcoming visits" empty state
(`appointments_screen.dart:218-228`) is returned *before* the `RefreshIndicator`
(`:229`), so there is no pull-to-refresh escape either — only switching tabs
recovers, and the user has no reason to try that.

**Why existing guards do not catch it:** the only test that books through the
centre action, `test/app/app_boot_test.dart:127-160`, starts on **Home**, so the
Appointments branch is built *after* the write and loads fresh data — the
already-active case is never exercised. The screen tests pump
`AppointmentsScreen` standalone, where `TickerMode.valuesOf` returns the enabled
fallback, so activation is always "first build". `didChangeDependencies` is the
only reload trigger on this screen (`:52-58`), and it is precisely the mechanism a
same-branch `go()` does not disturb.

**Proposed minimal fix:** add one shared one-shot signal next to the existing
`NavigationRequests.appointmentsPetFilter`
(`lib/app/navigation_requests.dart`, foundation-owned):
`static final ValueNotifier<int> householdRevision`. Bump it after each
successful centre-action write (`centre_action_sheet.dart:54-58`, `:78-82`,
`:103-106`). In `AppointmentsScreen.didChangeDependencies` subscribe once, remove
in `dispose`, and reload in the listener when the already-tracked `_branchActive`
is true (`if (_branchActive) _controller!.load();`). Do the same in the three
other branch screens, which also carry household data. Effort **S**; fixes F1, F2
and the Profile record-count half of the centre-action health-record flow in one
change.

## F2 — [HIGH] Logging an entry from the centre action leaves an already-active Journal feed stale

**File:** `lib/features/journal/journal_screen.dart:54` (write path:
`lib/app/shell/centre_action_sheet.dart:71-82`)

**Issue:** From the Journal tab, tap `+` → *Log an entry* → pick a pet → *Save
entry*. `_logEntry` writes with `services.journal.create` and then
`go(Routes.journal)` (`centre_action_sheet.dart:82`). Same branch → no
`TickerMode` change → no `didChangeDependencies` → the feed still shows the rows
loaded when the tab was activated; the just-logged entry is missing while the
snackbar claims "Note logged." If the feed was empty, the "No entries yet" state
(`journal_screen.dart:123-130`) has no `RefreshIndicator` (the indicator is only
built at `:182` for the non-empty branch), so the user cannot even pull to
refresh. This is the more damaging of the pair: the Journal is the household's
only history surface, and a note that appears to vanish undermines every other
flow.

**Why existing guards do not catch it:** `test/app/app_boot_test.dart:172-200`
logs from Home, so the Journal branch is built for the first time afterwards and
loads correctly. `docs/demo-script.md` even lists "if a screen looks stale, pull
down to refresh" as the mitigation — a mitigation that does not exist on the
empty state. No test taps the centre action while Journal is the active tab.

**Proposed minimal fix:** the same `NavigationRequests.householdRevision` signal
as F1, subscribed by `JournalScreen` (`_branchActive` already exists at `:34`).
Effort **S** — shared with F1.

## F3 — [HIGH] Profile pet rows never reload after the pet page pops

**File:** `lib/features/profile/profile_screen.dart:203`

**Issue:** Profile → tap a pet row → *Edit* → rename the pet, change its weight or
photo, or add a vaccination / clinical note → back. The row was built from
`_controller.pets` and the tap is
`onTap: () => PetRoutes.open(context, pet.id)`, which drops the future
`PetRoutes.open` returns (`pet_routes.dart:29-34` completes when the page pops).
Nothing calls `_controller.load()` on return, so Profile keeps showing the old
name, old avatar, old age/weight-derived line and the stale `N records` footer
(`:257-261`) until the user leaves the Profile tab and comes back. Home already
does this correctly (`home_screen.dart:162-173`: `await handler(pet)` then
`refresh()`), which is why the same edit looks right on Home and wrong on Profile.

**Why existing guards do not catch it:** `test/features/profile/profile_screen_test.dart:205-241`
("a pet row opens the pet page route") asserts only that the pet page opened; it
never pops back and re-reads the row. The tab-activation reload fixed in commit
`0e88f03` covers a different trigger — a `TickerMode` flip, which a pushed route
does not produce.

**Proposed minimal fix:** make the row tap await and reload, mirroring Home:

```dart
onTap: () async {
  await PetRoutes.open(context, pet.id);
  if (mounted) {
    await _controller.load();
  }
},
```

Effort **S**.

## F4 — [MEDIUM] Pet page: sheet stops are pinned to an 844 pt surface

**File:** `lib/features/pets/pet_detail_screen.dart:244` (constants at `:32`,
`:35`; physics at `:270-272`)

**Issue:** `kPetSheetRestingTop = 560` and `kPetSheetRaisedTop = 168` are absolute
offsets from the top of the viewport. On a 375 × 667 phone (SE-class, a real
portrait target) the resting sheet is 107 pt tall, while the resting content
(name + meta + due chip + "VACCINES" header + the one dose row) measures roughly
230 pt and the scroll view is `NeverScrollableScrollPhysics` at rest
(`:270-272`) — so the dose that the resting state exists to show, and the
"swipe up for full history" hint, are clipped. Below **560 pt** of viewport height
the arithmetic goes negative: `AnimatedPositioned(top: 560, bottom: 0)` is
clamped to a **zero-height** sheet, so the drag handle is not laid out and the
page cannot be raised at all — only the photo, Back and Edit remain. That height
is reachable on the shipped web build (`PhoneFrame` sizes the app frame to
`min(windowHeight - 48, 844)`, `phone_frame.dart:28`), and the widget-test surface
used by `test/app/app_boot_test.dart` is exactly 800 × 600 → a 390 × 552 frame.

**Why existing guards do not catch it:** `test/features/pets/pet_detail_screen_test.dart:139-202`
asserts the layout at one surface only (`usePhoneSurface` = 390 × 844,
`test/features/pets/test_harness.dart:16`) and even asserts
`restingSheet.height == 844 - kPetSheetRestingTop`. The boot test does render the
pet page at 390 × 552, but it only asserts `find.text('Bella')` exists — a
zero-height widget is still found, so the test passes with no sheet on screen.
No test sets a small `physicalSize`.

**Proposed minimal fix:** derive both stops from the incoming constraints instead
of constants — wrap `_page` in a `LayoutBuilder` and use
`resting = min(kPetSheetRestingTop, constraints.maxHeight - kPetSheetMinHeight)`
with a real content floor (≈300 pt), plus `min(kPetSheetRaisedTop, maxHeight * 0.3)`;
when the resting sheet cannot fit its content, switch to
`ClampingScrollPhysics` so the content scrolls instead of clipping. Add a
375 × 667 and a landscape case to the pet-page test. Effort **M**.

## F5 — [MEDIUM] Onboarding "start with the sample household" has no error path and can wedge the Welcome card

**File:** `lib/features/onboarding/first_run_card.dart:95`

**Issue:** `_useSampleHousehold` sets `_saving = true`, then
`await widget.services.setSampleDataEnabled(true)` with no `try`/`catch` and no
`mounted` check, then calls `widget.onDone()`. `setSampleDataEnabled` seeds the
demo household (`app_services.dart:99-106`) — a transaction that can fail (disk
full, a locked database, a partially present demo row). If it throws, the future
completes with an unhandled error, `_saving` stays `true`, and the card renders
with the primary button labelled "Setting up…" and **both** buttons disabled
(`:182-191`) — no error text, no retry, no way back except killing the app.
`onDone` is never called, so Home keeps showing the Welcome card even if the
seed partially succeeded.

**Why existing guards do not catch it:** the sibling `_create` path directly above
it does handle failure (`:82-90`), so this reads as an oversight rather than a
decision; no test forces `setSampleDataEnabled` to throw, so
`test/app/app_boot_test.dart` (which only taps "Create my household") stays green.

**Proposed minimal fix:** wrap the call in `try`/`catch`, add
`if (!mounted) return;` before every `setState`/`onDone`, set
`_error = 'Could not load the sample household. Try again.'` and clear `_saving`
in the catch. Effort **S**.

## F6 — [MEDIUM] Onboarding save blanks the stored owner email and phone

**File:** `lib/features/onboarding/first_run_card.dart:71`

**Issue:** `_create` saves `OwnerDraft(name: ownerName)`; `OwnerDraft` defaults
`email`/`phone` to `''` (`domain/models/owner.dart:6`) and
`SqliteOwnerRepository.save` writes all three columns, so a name-only draft erases
whatever was stored. The card only appears when the household has no pets, which
is reachable **without** a fresh install: Profile → *Reset household* with "Also
forget my name and details" **unchecked** (the default, `profile_screen.dart:269`)
deletes the pets and keeps the owner row. Home then shows the Welcome card, whose
name field is empty because `_owner` is never prefilled from the saved owner; the
user retypes their name and taps *Create my household* → the name is restored but
the saved email and phone are replaced with empty strings, and Profile afterwards
reads "Add an email" / "Add a phone number".

**Why existing guards do not catch it:** no test covers onboarding after a reset,
and `first_run_card` is only pumped on a virgin harness. The reset test
(`profile_screen_test.dart:145-183`) verifies the *toggle*, not a subsequent
onboarding save. Nothing in the card's constructor accepts the current owner, so
there is no obvious place the loss would be noticed in review.

**Proposed minimal fix:** pass the loaded owner into the card
(`FirstRunCard(services: …, owner: dashboard.owner, onDone: …)` — Home already has
`dashboard.owner` at `home_screen.dart:382`), prefill `_owner` from it in
`initState`, and submit
`OwnerDraft(name: name, email: widget.owner?.email ?? '', phone: widget.owner?.phone ?? '')`.
Effort **S**.

## F7 — [MEDIUM] Home's fixed 264 pt pet card overflows at ≥1.5× text scale

**File:** `lib/features/home/home_screen.dart:44` (card body:
`lib/features/home/widgets/pet_card.dart:45-127`)

**Issue:** the pager wraps every card in `SizedBox(height: kPetCardHeight)` (264)
and `PetCard` lays out a `Column` of avatar+name (62), the due chip (36), a stat
row, two dividers and the "Last visit" row inside that fixed box. Measured at the
default scale the content needs ≈246 pt; at a 1.5× text scale it needs ≈300 pt and
at 2.0× ≈360 pt, so a user with iOS Larger Text or Android font size 1.5–2.0 gets
`RenderFlex overflowed` stripes in debug and a clipped "Last visit" row (and
clipped stats) in release — on the app's primary screen, for every pet.

**Why existing guards do not catch it:** no test sets `MediaQuery.textScaler` or
`textScaleFactor` anywhere in `lib/` or `test/` (verified by grep), and every Home
test pins 390 × 844 at the default scale
(`test/features/home/home_screen_test.dart:25-29`). The PageView requires a bounded
page height, so this cannot be found by simply removing the constant.

**Proposed minimal fix:** scale the pager height from the current text scale in
`HomeScreen.build`:

```dart
final double cardHeight = kPetCardHeight *
    MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.4);
```

and pass it to the `SizedBox` (rename the constant to a base value). Add one Home
test at `textScaler: TextScaler.linear(2.0)` asserting
`tester.takeException() == null` and that "Last visit" is visible. Effort **M**.

## F8 — [MEDIUM] Journal delete is a single irreversible tap

**File:** `lib/features/journal/journal_entry_sheet.dart:221` (delete path at
`:133-153`; caller's message at `lib/features/journal/journal_screen.dart:75-79`)

**Issue:** in the edit sheet, "Delete entry" (`:218-223`) calls `_delete`, which
runs `controller.deleteEntry` immediately — no confirmation step, no undo — and
closes the sheet; the caller only shows a plain "Entry deleted." snackbar with no
action. A stray tap on a red text button at the bottom of a scrollable sheet
permanently removes a row from the household's only history. The one truly
destructive action elsewhere in the app does ask first: *Reset household* uses an
`AlertDialog` naming what will be deleted (`profile_screen.dart:268-323`). The
appointment actions are also one tap, but those change a row's status and the row
survives with its history; this one erases the content.

**Why existing guards do not catch it:** `test/features/journal/journal_screen_test.dart:214`
taps `journal-edit-delete` and asserts "Entry deleted." — the single-tap behaviour
is encoded in the test, so the suite protects the current design rather than
questioning it. There is no undo anywhere for journal rows (only for quick-log
adds, `home_screen.dart:285-299`).

**Proposed minimal fix:** cheapest and consistent with the codebase — confirm
before deleting (reuse the `showDialog<bool>` pattern from
`profile_screen.dart:270-312`, or a small `showAppSheet` with "Delete entry" /
"Keep entry"). If a confirm is felt to be too heavy, the alternative is a
post-delete `SnackBar` with **Undo** that re-creates the row from the captured
draft. Effort **S**.

## F9 — [MEDIUM] The same journal kind renders different icons and badge shapes on Home vs Journal

**File:** `lib/features/journal/journal_screen.dart:260` vs
`lib/features/home/widgets/journal_kind_badge.dart:12`

**Issue:** two independent mappings exist for one domain enum, and they already
disagree: `JournalKind.walk` is `Icons.pets` on Home's recent rows but
`Icons.directions_walk` in the Journal feed; `note` is `Icons.notes` vs
`Icons.sticky_note_2_outlined`; `symptom` is `Icons.monitor_heart_outlined` vs
`Icons.sick_outlined`; `fed`/`meds` differ between filled and outlined variants.
The badge itself also forks: Home draws a 34 pt **circle** tinted accent-on-paper
(`journal_kind_badge.dart:31-43`), Journal draws a 34 pt **rounded square** tinted
accent-on-surface (`journal_screen.dart:249-257`). The same walk entry therefore
changes icon and shape when the user moves from Home to Journal — on a screen
pair that is otherwise pixel-consistent. Folding in the same duplication: Home's
card re-implements the pet avatar (`pet_card.dart:133-171`: due-soon-tinted circle
with `Icons.pets`) instead of the shared `PetAvatar` used by Profile and the pet
chooser (`pets/pet_photo.dart:70-104`: accent-tinted with `Icons.pets_rounded`),
so a pet without a photo is yellow on Home and green on Profile.

**Why existing guards do not catch it:** there is no shared widget, so neither
feature's tests can see the other's choices; no golden/image test covers row
leading icons, and the AGENTS.md kit contract does not name a journal-kind badge.
The duplication is legitimate (features may not edit `lib/ui/`), which is exactly
why it drifted.

**Proposed minimal fix:** request one foundation-owned home for the identity —
move `journalKindIcon` + `JournalKindBadge` into `lib/ui/kit/` (and let
`PetAvatar` cover Home's card at `size: 62`), then delete both feature-local
copies. If a `lib/ui` change is out of scope for this round, the interim fix is to
have `journal_screen.dart` import Home's existing
`widgets/journal_kind_badge.dart` and use `JournalKindBadge`, deleting
`_JournalKindIcon`; the long-term fix still belongs in `ui/kit`. Effort **M**
(move + two call sites + golden-free widget tests for both screens).

## F10 — [LOW] Picked photo files are orphaned when the form is cancelled or a second photo is picked

**File:** `lib/features/pets/forms/pet_form_sheet.dart:159` (copy happens in
`lib/data/pet_photos_io.dart:27-48`; cleanup only at `pet_form_sheet.dart:136-140`)

**Issue:** `PetPhotos().pickFromLibrary()` copies the chosen image into
`<databases>/pet_photos/pet_<micros>.jpg` **at pick time**. The form deletes a
replaced file only after a *successful save* (`_save`, `:136-140`). Two ordinary
sequences leak a file each time: pick A → pick B → Save (A is nobody's original,
so it is never deleted), and pick A → dismiss the sheet (nothing is deleted).
Because the copies are full 1024 px JPEGs, repeated photo changes grow the app's
storage silently.

**Why existing guards do not catch it:** the only cleanup path is the save path,
and `deleteOwned` ignores paths outside its folder, so a leak cannot fail loudly.
Tests never exercise the picker with a real file (the web/stub picker returns
`null`), and there is no orphan sweep on boot.

**Proposed minimal fix:** keep `_unsavedPick` in the form state; when the picker
returns a new path while one is pending, delete the pending one; in `dispose()`
delete the pending pick unless it is now the saved value. Effort **S**.

## F11 — [LOW] A form sheet dismissed mid-save loses the caller's refresh

**File:** `lib/features/pets/forms/pet_form_sheet.dart:141` (same shape in
`vaccination_form_sheet.dart:135-138`, `health_record_form_sheet.dart:91-94`,
`owner_form_sheet.dart:79-82`, `journal_entry_sheet.dart:118-121`)

**Issue:** each form disables its primary button while `_saving` but leaves the
modal sheet drag- and backdrop-dismissible. If the sheet is dismissed while the
write is in flight, the repository call still completes, then `if (!mounted)
return;` skips `Navigator.pop(true)`, so `showPetForm`/`showVaccinationForm`/…
resolve `null` and every caller's `if (saved == true) reload()` is skipped. Result:
the row exists in SQLite, but the list the user is looking at does not show it —
and for the pet form reached from the pet page, the page's `_refresh()` also never
runs. The window is small (a local SQLite write) but non-zero on a busy device.

**Why existing guards do not catch it:** only the buttons are disabled; nothing
prevents the modal route from popping, and no test dismisses a sheet while a save
is pending.

**Proposed minimal fix:** wrap each form body in `PopScope(canPop: !_saving)` (no
`PopScope` exists anywhere in `lib/` today, so this is a small, uniform addition),
and/or have callers reload unconditionally after the sheet closes rather than only
on `true`. Effort **S**.

## F12 — [LOW] Reload failures after data exists are silent; a tab switch shows the previous tab's rows

**File:** `lib/features/appointments/appointments_screen.dart:209` (controller:
`lib/features/appointments/appointments_controller.dart:61-63`; Journal has the
same shape at `journal_screen.dart:114`)

**Issue:** the error branch requires `controller.appointments.isEmpty`, so once a
list has rows a failed reload leaves the old rows on screen with no indication
that they are stale — the user reads them as current. Compounding it,
`selectTab`/`selectPet` notify *before* awaiting the fetch
(`appointments_controller.dart:61-63`, `:67-73`), so tapping **Past** leaves the
**Upcoming** rows visible under the Past segment for the whole query, and
indefinitely if that query then fails. Journal behaves the same way for a failed
`load()` with rows present.

**Why existing guards do not catch it:** tests always `settleDatabase` before
asserting, so the intermediate frame is never observed, and no test injects a
repository failure after a successful first load.

**Proposed minimal fix:** surface a non-blocking inline row ("Couldn't refresh —
pull to try again", or a `SnackBar`) whenever `loadError != null` even with rows
present, and clear `_appointments` (or set `isLoading` such that a spinner shows)
at the start of a tab/filter switch so two tabs can never share rows. Effort **S**.

## F13 — [LOW] Pet chooser reports a database read failure as "No pets yet"

**File:** `lib/features/pets/pet_chooser_sheet.dart:71`

**Issue:** `_load`'s `catch` only clears `_loading`, leaving `_pets` empty, so the
sheet renders the empty state "No pets yet — Add a pet from Profile first."
(`:93-99`) when the real cause is a failed `pets.list()`. From the centre action
this dead-ends both *Log an entry* and *Add a health record*, and it actively
misinforms: the household does have pets, and the suggested fix (add a pet) would
create a duplicate.

**Why existing guards do not catch it:** no test makes `pets.list()` throw, and
the empty state is the same widget in both cases.

**Proposed minimal fix:** store `_error = 'Could not load the pets.'` in the
catch and render an `EmptyState` with a *Try again* action (`controller`-free —
just call `_load()` again), exactly as Journal/Appointments do. Effort **S**.

## F14 — [LOW] Quick-log form silently drops an unparsable duration

**File:** `lib/features/home/widgets/quick_log_form_sheet.dart:118` (field at
`:217-222`)

**Issue:** the duration field only sets `keyboardType: TextInputType.number`;
paste, autofill, a hardware keyboard or some IMEs can put "30 min" or "1.5" in it,
`int.tryParse` returns `null`, and the entry is saved with no duration — no error,
no hint. The journal edit sheet validates the identical field and blocks the save
with "Enter minutes as a whole number"
(`journal_entry_sheet.dart:88-100`, `:197-210`), so two forms for the same model
disagree about silent data loss.

**Why existing guards do not catch it:** the Home test types nothing into the
duration field, and the widget cannot distinguish "empty" from "unparsable" after
`tryParse`.

**Proposed minimal fix:** reuse the journal sheet's approach — `digitsOnly`
input formatter, a `_durationError` set in `onChanged`, `errorText` on the field
and `_save` blocked while non-null. Effort **S**.

---

## Checked and clean (no finding)

Recorded so the next reader does not repeat the audit. Each item was checked
against the code, not assumed.

**1. Controller lifecycle.** All six areas resolve services in
`didChangeDependencies` and never in `initState`
(`home_screen.dart:79-101`, `journal_screen.dart:37-58`,
`appointments_screen.dart:35-59`, `profile_screen.dart:47-65`,
`pet_detail_screen.dart:62-77`). Every `TextEditingController` in the eight sheets
is disposed (`pet_form_sheet.dart:84-91`, `owner_form_sheet.dart:56-62`,
`health_record_form_sheet.dart:58-66`, `vaccination_form_sheet.dart:67-71`,
`quick_log_form_sheet.dart:62-67`, `journal_entry_sheet.dart:61-66`,
`appointment_form_sheet.dart:67-72`, `appointment_cancel_sheet.dart:45-49`); the
`PageController` is too (`home_screen.dart:103-108`). The two settings listeners
are added and removed symmetrically (`home_controller.dart:16-19`/`:88-93`,
`profile_controller.dart:14-16`/`:106-111`). No timers exist in `lib/features`.
Every post-`await` `setState` is `mounted`-guarded, and the five controllers carry
a `_disposed` latch (`home_controller.dart:82-93`, `journal_controller.dart:103-113`,
`appointments_controller.dart:193-203`, `profile_controller.dart:100-111`,
`pet_detail_controller.dart:104-114`); the couple of post-`await`
`_controller!.load()` calls in Home's sheet handlers (`home_screen.dart:153-155`,
`:214`) can therefore only run against a disposed controller that ignores the
call — no setState-after-dispose and no `notifyListeners`-after-dispose found.
`notifyListeners` during a build is only reachable from the first
`didChangeDependencies` load, where no listener exists yet; on later activation
the notifier's listener is a descendant of the screen, which Flutter permits.

**2. Reload / freshness.** All four shell branches implement the `TickerMode`
pattern correctly (`home_screen.dart:85-100`, `journal_screen.dart:42-57`,
`appointments_screen.dart:39-58`, `profile_screen.dart:52-64`), including the
`_branchActive` edge-trigger and the first-build case. The shell does wrap every
branch in `Offstage` + `TickerMode` (go_router 18.1.4
`.pub-cache/.../go_router-18.1.4/lib/src/route.dart:1779`) and
`TickerMode.valuesOf` establishes the inherited dependency
(`.flutter-sdk/packages/flutter/lib/src/widgets/ticker_provider.dart:139`), so the
dependency does fire. The three gaps are F1, F2, F3. Pet-page return to Home
(`home_screen.dart:162-173`), Home's own sheets
(`home_screen.dart:175-187`, `:139-156`, `:191-220`) and Profile's own sheets
(`profile_screen.dart:73-89`) all reload explicitly.

**3. State handling.** Every screen has loading / error / empty paths
(`home_screen.dart:703-723`, `journal_screen.dart:108-130`,
`appointments_screen.dart:203-228`, `profile_screen.dart:138-153`,
`pet_detail_screen.dart:160-191`), each with a retry, and each empty state uses
the kit `EmptyState`. No infinite-spinner path exists: every controller that
exposes `isLoading` clears it outside its `try`. The only silent-error cases are
F12, F13 and the pet page's documented "keep what is on screen" refresh
(`pet_detail_controller.dart:96-99`), which the screen covers with the
not-found/first-load state.

**4. Sheets and dialogs.** All five `show*Sheet` helpers return a typed result and
every caller checks for `null` before acting (`journal_screen.dart:66-80`,
`appointments_screen.dart:77-91`, `home_screen.dart:139-156`/`:191-220`/
`:234-283`, `profile_screen.dart:73-127`, `pet_detail_screen.dart:114-150`).
Double-submit is blocked by `_saving`/`_isBusy` on every sheet. Keyboard handling
is central and correct: `AppSheetBody` adds `viewInsets.bottom` and every form
scrolls (`lib/ui/kit/app_sheet.dart:29-47`); the cancel sheet's `autofocus` field
is inside that scroll view. On cancel, every sheet disposes its controllers
(because `State.dispose` runs on pop) and the modal returns `null`, which callers
treat as "nothing saved".

**5. Cross-feature coupling.** `NavigationRequests.appointmentsPetFilter` is
written once (`home_screen.dart:225`) and consumed-and-cleared exactly once
(`appointments_screen.dart:62-69`) on branch activation; the only leak path is a
second tab tap within the shell's 80 ms fade, which supersedes the branch switch
and leaves the request pending for a later, unrelated visit — not user-visible,
so not reported. Home's throwaway `JournalController`/`AppointmentsController`
(`home_screen.dart:139-156`, `:191-220`) are deliberate, disposed on every exit
path, and their data is refreshed by the owning screen's own reload; they cost one
extra household read per sheet opening and create no stale or leaked state. The
`_dueLabelFor` day-count text (`home_screen.dart:340-357`) is the one piece of
presentation logic that duplicates what a shared helper could own — no defect
today (only Home needs it), noted in R7 below.

**6. Accessibility and small screens.** Icon-only actions all carry labels or
tooltips (`pet_detail_screen.dart:310-319` tooltip "Back", `:465-467` semantics on
the sheet handle, `home_screen.dart:561-563` owner avatar, `pet_page_dots.dart:139-141`
dots, plus the kit's `AppChip`/`ListRow` semantics). The dots' tap strip is 44 pt
(`pet_page_dots.dart:32`), the sheet header actions use
`MaterialTapTargetSize.padded` (`pet_detail_screen.dart:524-538`), and the only
sub-44 target in the area is the 30 pt pet-sheet handle (`:475-476`) whose toggle
is duplicated by a vertical drag anywhere on the sheet — noted, not reported as a
defect. Status colours all come from `status_style.dart` through
`AppChip.due`/`AppChip.appointment` — no local status colours and no raw hex
anywhere in `lib/features` (verified by grep; the only local `TextStyle` is
`profile_screen.dart:306`, a colour-only override that inherits the theme size).
Every long label is `maxLines`-capped with `TextOverflow.ellipsis`. Large text is
the one real robustness gap (F7); the small-viewport gap is F4.

## What genuinely needs refactoring

Ordered. **S/M/L** = effort. Each item names the findings it closes.

| # | Effort | Refactor | Closes |
| --- | --- | --- | --- |
| R1 | **S** | **One refresh signal for writes the branch did not make.** Add `ValueNotifier<int> householdRevision` to `lib/app/navigation_requests.dart` (foundation-owned; request it), bump it after each successful centre-action write, and have the four branch screens subscribe while their `_branchActive` is true and reload. Removes the whole "write then invisible" class instead of patching each flow. | F1, F2 |
| R2 | **S** | **Profile reloads after the pet page pops.** Await `PetRoutes.open` and `load()` on return, exactly as Home already does. | F3 |
| R3 | **S** | **Harden the onboarding card.** `try`/`catch` + `mounted` guard around the sample-household seed; accept the current owner, prefill the name, and preserve email/phone on save. | F5, F6 |
| R4 | **M** | **Derive the pet page's sheet stops from the viewport.** `LayoutBuilder` + a content floor + scrollable resting content; add a 375 × 667 and a landscape test. | F4 |
| R5 | **S** | **Guard the journal delete.** Confirm before deleting (or offer Undo), matching the reset-household convention. | F8 |
| R6 | **M** | **Text-scale-safe Home card.** Scale the pager page height from `MediaQuery.textScalerOf` (clamped) and add an overflow test at 2.0×. | F7 |
| R7 | **M** | **One journal-kind identity, one pet avatar.** Move `journalKindIcon` + `JournalKindBadge` into `lib/ui/kit/`, use `PetAvatar` on Home's card, delete both feature-local forks. Optional in the same pass: move Home's "N days overdue / due today" label builder next to `formatRelativeDay` so it is reusable and testable. | F9 |
| R8 | **S** | **Sheet/form robustness batch.** `PopScope(canPop: !_saving)` on the five forms; delete orphaned picked photos on cancel/re-pick; a real error state in the pet chooser; shared duration validation between the quick-log and journal-edit forms. | F10, F11, F13, F14 |
| R9 | **S** | **Surface refresh failures.** Show a non-blocking "couldn't refresh" affordance when rows exist, and clear the list on a tab/filter switch so two tabs never share rows. | F12 |

**What should not be refactored.** The feature layer's structure is right for this
app and should be left alone: `ChangeNotifier` + `AppScope` with per-screen
controllers (no provider/Riverpod/Bloc), screens as full `Scaffold`s inside the
shell, sheets as functions returning typed results, `services.now()`/`today()`
injected rather than `DateTime.now()`, and pure rules consulted from `lib/domain`.
Nothing here needs the controllers lifted into the shell, a repository change, or
a form framework. R1 is the only change that reaches outside `lib/features`, and
it is a 3-line addition to an existing file.
