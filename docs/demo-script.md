# Five-minute demo script

A rehearsed walkthrough of the Pet Health Tracker in the order it will be
performed. Target: **4:45**, leaving buffer inside the five-minute limit.

## Before the demo

1. Confirm the app still opens. On iOS it is signed with a free Apple ID, which
   expires **seven days** after install — if in doubt, rebuild:
   `FV_REAL_HOME=1 ./tool/fv run -d Ludwig`.
2. Make sure the demo data is on: **Profile → Sample data** off, then on (a
   fresh install starts with it off and shows the Welcome card instead). That
   deletes and reseeds only the rows at ids 9000+, so anything you added by hand
   survives.
3. Keep the phone in portrait and the volume off. The screens are designed for a
   390 × 844 surface.
4. Know your exits: if a screen looks stale, pull down to refresh; if the data is
   too edited, toggle Sample data off and on.

Rehearse once in this exact order. Every logged item adds a record, so the
toggle at the end is the reset.

## Timeline

| Time | Step | What to show |
| --- | --- | --- |
| 0:00 | Home | The household at a glance |
| 0:35 | Pet page | One photo, two sheet stops, a booster added |
| 1:40 | Quick log | One tap logs a walk; undo is offered, then expires |
| 2:00 | Book a visit | The centre `+` action books a real appointment |
| 2:45 | Complete it | The state machine, Upcoming → Past |
| 3:15 | Journal | Editable feed, grouped by day, filtered per pet |
| 3:40 | Profile | Owner, pets, settings, sample data |
| 4:45 | Close | Back to Home |

## 0:00 — Home (35 s)

1. Launch. It opens on **Home**.
2. Point out the greeting (`Good afternoon, Maria` — the greeting follows the
   clock, and only the first name is shown) and the `M` avatar. **Tap the avatar** to show it opens Profile with the same fade the tab bar uses, then come back.
3. Tap the second pager dot to show **Miso**, then swipe back to **Bella**.
   - Bella: dog, ≈5 yr, 12.4 kg, **“Rabies · 35 days overdue”** — the chip names
     the vaccine, not just the state.
   - Miso: cat, ≈3 yr, 4.2 kg, **“FeLV · due in 10 days”**.
   - Narration: “One card per pet, one status chip, derived from the vaccination
     rule — nothing about ‘overdue’ is stored.”
4. Point at **LOG SOMETHING** (Walk, Fed, Meds, Note), the **next-visit card**
   (`Paws & Claws Veterinary Clinic · Bella · Annual wellness check`), and
   **Recent** (three entries).
5. Narration: “Offline, single household, SQLite. No accounts, no network.”

## 0:35 — Pet page and booster (65 s)

1. Tap **Bella’s card** — it slides in from the right; the tab bar is covered by
   the photo.
   - The photo (drawn portrait until a real one is set) fills the screen; the
     sheet rests at the bottom with the name, meta line, **Overdue** chip,
     **VACCINES** and one row: Rabies, overdue.
2. Drag the sheet up (or tap the handle).
   - The photo stays exactly where it is and blurs; the sheet rises to reveal all
     vaccines and **MEDICAL HISTORY** (otitis externa, Dr. Cruz).
   - Narration: “The photo is painted once and never resizes — only the sheet and
     its blur travel. Clinical notes are append-only; the UI offers no edit.”
3. Tap **+ Add** next to VACCINES.
   - The form opens with the vaccine type selected, today’s date, and the next
     due date prefilled from the catalog interval.
   - Type `Dr. Ana Cruz` in Vet and **Save**.
4. Back on the raised sheet, the chip reads **Up to date** — the new dose
   outranks the overdue one because the rule reads the latest vaccination.
5. Tap back. Home reloads and Bella’s card also reads up to date.
   - Narration: “The due status is one pure rule, not a copy per screen.”

## 1:40 — Log a walk (20 s)

1. With Bella’s card active, tap the **Walk** chip.
2. A snackbar says `Walk logged · UNDO` and **Recent** updates immediately.
3. Leave the snackbar alone for five seconds and let it disappear.
   - Narration: “One tap stores the kind and the moment — no invented duration.
     Long-press opens the full form for a note or another time.”

## 2:00 — Book a visit (45 s)

1. Tap the raised centre **+**.
2. The quick-action sheet shows the three real create flows: *Book a vet visit*,
   *Log an entry*, *Add a health record*.
3. Tap **Book a vet visit**, then fill: Pet **Bella**, Clinic `City Vet`, Purpose
   `Booster follow-up`, tomorrow at 9:30, **Book visit**.
4. The sheet closes with a confirmation and the app lands on **Appointments →
   Upcoming** with the City Vet visit at the top.
   - Narration: “The centre button is the only create entry point — one place to
     look for every kind of record.”

## 2:45 — Complete it (30 s)

1. Tap the new **City Vet** card.
2. The actions sheet offers **Mark completed**, **Cancel**, **Reschedule**, and
   **View in Appointments**; **Mark no-show** is greyed out (“Available after the
   appointment time”) because the visit is in the future.
3. **Mark completed** → the visit leaves Upcoming.
4. Tap **Past**: the completed visit is listed with a **Completed** chip; open it
   and show the read-only summary.
   - Narration: “Terminal states stay terminal — enforced in the domain layer and
     again by the repository.”

## 3:15 — Journal (25 s)

1. Tap **Journal**.
2. Entries are newest first, grouped **TODAY** / **YESTERDAY** / full date, with
   the walk you just logged at the top.
3. Tap the **Miso** filter chip at the top: only Miso’s rows remain. Tap **All
   pets** to restore the household.
   - Narration: “The same list, scoped by a filter — not a second screen.”
4. Tap the walk row, change the note to `Morning loop, sunny`, **Save changes**.

## 3:40 — Profile (65 s)

1. Tap **Profile**. Point out the owner block, **MY PETS**, the three **SETTINGS**
   rows and the version line with live counts.
2. **Edit** the owner: name `Maria Santos`, save. The avatar becomes `M` and
   Home’s greeting uses the first name.
3. **Add a pet** — `Coco`, dog, female, ≈2 years old, 8.5 kg. MY PETS and the
   counts update.
4. Toggle **Sample data** off: Bella, Miso and their demo rows disappear, Coco
   stays. Toggle it on: the demo household returns.
   - Narration: “Demo rows live at ids 9000+ behind a persisted toggle; clearing
     them can never touch the owner’s own rows.”

## 4:45 — Close

1. Tap **Home**. The greeting reads `Good …, Maria`; the household is back.
2. One sentence: “Tested against the real SQLite schema — analyze clean, 179
   tests green, and the app never talks to a network.”

## If something goes wrong

- **A list looks stale** — pull down to refresh; the tab that regains focus also
  reloads by itself.
- **Demo data was edited too much** — Profile → Sample data off, then on.
- **Accidental quick log** — the snackbar offers **UNDO** for five seconds.
- **Nothing loads** — quit and relaunch; the database, owner and vaccine catalog
  are created on first launch.
