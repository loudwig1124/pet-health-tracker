# Pet Health Tracker

An offline, phone-first pet health and vet appointment tracker for one household:
one owner, several pets, a shared journal, vet visits, vaccinations and
append-only clinical notes. No accounts, no network, no backend — the SQLite
database on the phone is the only source of truth.

| Destination | What it does |
| --- | --- |
| **Home** | Greeting and owner initial, swipeable pet cards (one due-status chip each), tap-to-log chips for Walk / Fed / Meds / Note, the next vet visit, and the two latest journal entries. |
| **Journal** | The household feed, newest first, grouped Today / Yesterday / full date. Tap any row to edit its time, note and duration, or delete it. |
| **Appointments** | Upcoming / Past toggle with a quiet per-pet filter. Tap a visit to mark it completed, cancel it with a reason, mark a no-show (only after the scheduled time), or reschedule it. |
| **Profile** | Owner details (editable), the pet list, and three settings: due-soon window, weight unit and the sample-data toggle. |
| **Pet page** | A full-page photo (or paper portrait) with a two-stop sheet: resting shows the name, worst due status and the vaccine that needs attention; raised reveals every vaccine and the append-only medical history. Reached by tapping a Home pet card or a Profile pet row. |

The raised centre button in the tab bar is the create menu: book a vet visit, log
an entry, or add a health record.

## Requirements

- macOS with Xcode + an iOS Simulator, or an Android device/emulator.
- Flutter is run through `./tool/fv`, which uses the workspace SDK copy. If
  `.flutter-sdk/` is absent (fresh clone), it falls back to `flutter` on `PATH`.
  See [`tool/README.md`](tool/README.md) for the sandbox setup and the one-line
  SDK patch this checkout needs while its path contains parentheses.

## Setup and run

Run everything from this `Pet Health Tracker/` directory:

```bash
# 1. Fetch dependencies
./tool/fv pub get

# 2. See the devices Flutter can target
./tool/fv devices

# 3. Boot a simulator (iOS example) and run the app
xcrun simctl boot "iPhone 17 Pro"
./tool/fv run -d "iPhone 17 Pro"
```

On first launch the app creates `pet_health_tracker.db`, adds the household
owner, seeds the vaccine catalog, and (with the persisted **Sample data** toggle
on, the default) seeds the demo household. See
[the demo script](docs/demo-script.md) for the five-minute walkthrough.

## Demo household

The seeded demo lives at ids `>= 9000` under the household owner, so it can be
removed without touching anything the owner typed:

- **Bella** (dog, Golden Retriever mix, 12.4 kg) — rabies booster overdue by 35
  days, DHPP up to date, one clinical note (ear infection).
- **Miso** (cat, Domestic shorthair, 4.2 kg) — FeLV due soon (10 days), FVRCP up
  to date, one clinical note (annual exam).
- Four journal entries (walk, feeding, note, symptom) spread across the last
  five days.
- One upcoming visit (Bella, annual wellness check, 5 days out) and one completed
  visit (Miso, dental cleaning, 20 days ago).
- Profile reads `Version 1.0.0 · 2 pets · 12 records`.

Dates are relative to the day the demo is seeded, so rehearsing weeks later
still shows a current household. `Profile → Sample data` is the only toggle:
turning it off deletes the demo rows, turning it on reseeds them, and both
states persist across restarts. Your own pets, entries and visits are never
touched by it.

## Tests and checks

```bash
./tool/fv analyze                       # static analysis, must be clean
./tool/fv test                          # full suite (domain, data, app, features)
./tool/fv test test/app                 # router/shell boot tests
./tool/fv test test/features/home       # one feature area
./tool/format --set-exit-if-changed lib test   # formatting gate
sqlite3 :memory: ".read db/schema.sql"  # DDL smoke test
```

The widget tests boot the real app (router, shell, feature screens) against a
real SQLite database via `sqflite_common_ffi`, using the shipped
`db/schema.sql` — not a copy. The suite covers the navigation shell, quick logging
and undo, the pet page and its form sheets, appointment transitions, profile
settings, and the demo seed.

## Shortcuts and gestures

In the app:

- **Centre `+` button** — book a visit, log an entry, add a health record.
- **Tap a quick-log chip** — save that kind at the current time; **long-press**
  it to open the full form (date, time, note, duration).
- **Pet card / Profile pet row** — open the pet page.
- **Tap the sheet handle or drag the sheet up** — raise the pet sheet; drag down
  to lower it.
- **Pull down** on Home, Journal or Appointments to reload.
- **Home cards** — tap the pager dots to jump between pets.

While `./tool/fv run` is attached: `r` hot reload, `R` hot restart, `q` quit.

## Project layout

| Path | Contents |
| --- | --- |
| `lib/app/` | composition root (`di.dart`, `app_services.dart`), router, shell, `AppSettings`, `AppScope` |
| `lib/domain/` | immutable models and pure rules — no Flutter, no SQL, no `dart:io` |
| `lib/data/` | SQLite bootstrap, mappers, repositories, seeding, settings store — all SQL lives here |
| `lib/ui/` | theme tokens, presentation-only kit, `intl` format helpers |
| `lib/features/<area>/` | Home, Journal, Appointments, Profile and Pets screens + controllers |
| `db/schema.sql` | the DDL contract, applied verbatim on first launch |
| `test/` | domain, data (real FFI SQLite), app boot and feature widget tests |
| `docs/` | demo/rehearsal material |
| `tool/` | the sandbox-safe Flutter/Dart wrappers |

[`AGENTS.md`](AGENTS.md) is the implementation contract: dependency rules, the
domain/data API, conventions and the definition of done.

## Data and storage

- One SQLite file (`pet_health_tracker.db`) in the platform database directory,
  created from `db/schema.sql`; a `settings.json` sits next to it.
- Date-only columns are `YYYY-MM-DD`; instants are ISO-8601 UTC. The app
  formats them for the device zone with `intl`.
- Clinical notes (`health_record`) are append-only: the schema's triggers reject
  updates and deletes, and the UI offers no edit or delete affordance.
- Journal entries stay editable; deleting a pet removes its journal,
  vaccination and clinical rows and leaves its appointments under the household.

## Troubleshooting

- **Always use `./tool/fv`** (and `./tool/format`), never a bare `flutter`/`dart`
  in this checkout: the wrappers keep the SDK cache and pub state inside the
  workspace, which the sandbox requires.
- **Never delete `.tool-home/` or `.pub-cache/`** — they hold the workspace-local
  tool home (with the `sqlite3` native-assets setting) and the pub cache.
- **`xcodebuild` permission errors under `~/Library/Developer/Xcode`** mean the
  process cannot write outside the repository. Run the launch from a normal
  terminal on the same machine, or point Xcode's DerivedData at a writable
  location.
- **Stale-looking data** — pull to refresh on Home, Journal or Appointments. The
  database file is reloaded on launch; deleting the app resets the first-run
  seed.
