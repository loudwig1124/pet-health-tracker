# Five-minute demo script

A rehearsed walkthrough of the Pet Health Tracker in the order it will be
performed. Target: **4:45**, leaving buffer inside the five-minute limit.

## Before the demo

1. Launch from this `Pet Health Tracker/` directory:
   `./tool/fv run -d "iPhone 17 Pro"` (or the device id from `./tool/fv devices`).
2. Wait for Home to finish loading. The first launch seeds the demo household;
   if the app has been used before, reset it:
   - For a clean demo household: **Profile → Sample data** off, then on.
   - For a completely clean run (including owner and pets you added):
     delete the app from the simulator/device and relaunch.
3. Keep the phone in portrait. The screens are designed for a 390 × 844 surface.

Rehearse once in this exact order; the categories you touch are additive (each
logged item adds a record), and the sample-data toggle at the end is the reset.

## Timeline

| Time | Step | What to show |
| --- | --- | --- |
| 0:00 | Home | The household at a glance |
| 0:35 | Pet page | One photo, two sheet stops, a booster added |
| 1:40 | Quick log | One tap logs a walk; undo is offered |
| 2:00 | Book a visit | The centre `+` action books a real appointment |
| 2:45 | Complete it | The appointment state machine, Upcoming → Past |
| 3:15 | Journal | Editable household feed, grouped by day |
| 3:40 | Profile | Owner, pets, settings, sample data |
| 4:45 | Close | Back to Home |

## 0:00 — Home (35 s)

1. Launch the app. It opens on **Home**.
2. Point out the greeting (`Good morning, My household` — the greeting follows
   the clock) and the `M` avatar. The household is renamed later in the demo.
3. Tap the second pager dot to show **Miso**. Swipe back to **Bella**.
   - Bella: dog, ≈5 yr, 12.4 kg, **Overdue** chip (rabies booster 35 days late).
   - Miso: cat, ≈3 yr, 4.2 kg, **Due soon** chip (FeLV in 10 days).
   - Narration: “This is the whole point of the home screen — one card per pet,
     and exactly one status chip derived from the vaccination rule.”
4. Point at the **LOG SOMETHING** chips (Walk, Fed, Meds, Note), the next-visit
   card (`Paws & Claws Veterinary Clinic — Bella · Annual wellness check`), and
   **Recent** (today’s feeding, yesterday’s walk).
5. Narration: “Offline, single household, SQLite. No accounts, no network.”

## 0:35 — Pet page and booster (65 s)

1. Tap **Bella’s card**.
   - The photo (paper portrait until a real photo is set) covers the whole
     screen. The sheet rests at the bottom with the name, meta line, **Overdue**
     chip, **VACCINES** and one row: Rabies, overdue.
2. Tap the sheet handle (or drag the sheet up).
   - The same photo stays in place and blurs; the sheet rises to reveal both
     vaccines and the **MEDICAL HISTORY** section (ear infection, 25 days ago).
   - Narration: “The photo is painted once and never moves or resizes; only the
     sheet and its blur travel. Clinical notes are append-only.”
3. Tap **+ Add** next to VACCINES.
   - The vaccination form opens with Rabies selected, today’s date and the next
     due date prefilled from the catalog interval (+12 months).
   - Optionally type `Dr. Ana Cruz` in Vet, then tap **Save vaccination**.
4. Back on the raised sheet, the chip is now **Up to date** — the new booster
   outranks the overdue dose.
5. Tap the back arrow. Home reloads and Bella’s card also reads **Up to date**.
   - Narration: “Hospital and household see the same database; the due status is
     one pure rule, not a copy per screen.”

## 1:40 — Log a walk (20 s)

1. With Bella’s card active, tap the **Walk** chip.
2. A snackbar says `Walk logged` and offers **UNDO**; the **Recent** list updates
   immediately with today’s walk.
3. Narration: “One tap stores the kind and now; long-press opens the full form if
   you want a note, duration or another time.”

## 2:00 — Book a visit (45 s)

1. Tap the raised centre **+** button.
2. The **QUICK ACTIONS** sheet shows the three real create flows: *Book a vet
   visit*, *Log an entry*, *Add a health record*.
3. Tap **Book a vet visit**.
4. In the booking sheet:
   - Pet: Bella (default).
   - Clinic: `City Vet`.
   - Purpose: `Booster follow-up`.
   - Date: tomorrow (default); time: 9:30.
   - Tap **Book visit**.
5. The sheet closes with `Appointment booked.` and lands on **Appointments →
   Upcoming**, with the new City Vet visit at the top.

## 2:45 — Complete it (30 s)

1. Tap the new **City Vet** card.
2. The actions sheet offers **Mark completed**, **Cancel appointment**, and
   **Reschedule**; **Mark no-show** is greyed out (“Available after the
   appointment time”) because the visit is in the future.
3. Tap **Mark completed** → `Appointment marked completed.` The visit leaves
   Upcoming.
4. Tap the **Past** segment: the completed City Vet visit is listed with a
   **Completed** chip. Tap it to show the read-only summary: “Completed visits
   cannot be changed.”
5. Tap **Upcoming** again.
   - Narration: “The state machine is enforced in the domain layer and again by
     the repository — terminal visits stay terminal.”

## 3:15 — Journal (25 s)

1. Tap the **Journal** tab.
2. Entries are newest first, grouped **TODAY** / **YESTERDAY** / full date, with
   the walk you just logged at the top.
3. Tap the walk row. The edit sheet opens with time, note and duration.
   Change the note to `Morning loop, sunny`, tap **Save changes** →
   `Entry updated.`
4. Narration: “Journal entries stay editable; clinical records do not leave the
   pet page’s append-only history.”

## 3:40 — Profile (65 s)

1. Tap the **Profile** tab. Point out the owner block, **MY PETS** (Bella, Miso),
   the three **SETTINGS** rows and the version line
   `Version 1.0.0 · 2 pets · 12 records` (counts have grown by the entries made
   in this demo).
2. Tap **Edit** on the owner. Set Name `Maria Santos`, Email
   `maria@example.com`, tap **Save details**. The block updates and the avatar
   becomes `M`.
3. Tap **Add a pet** (the last MY PETS row). Add `Coco`, a dog: pick Sex
   `Female`, choose a date of birth about two years ago, Weight `8.5`, tap
   **Add pet**. MY PETS and the version line now include Coco.
4. Toggle **Sample data** off: Bella, Miso and their demo records disappear,
   Coco stays, and the version line drops. Toggle it on: the demo household
   returns.
   - Narration: “Demo rows live at ids 9000+ and are seeded behind a persisted
     toggle; clearing them can never touch the owner’s own rows.”
5. Optionally tap **Due-soon window → 60 days** to show the same due rule
   reacting to the setting (Bella’s next-due dates re-read accordingly).

## 4:45 — Close

1. Tap **Home**. The greeting now reads `Good … , Maria Santos`; the demo
   household (plus Coco) is back.
2. One sentence: “Tested with the real SQLite schema; analyze clean and the full
   suite green.”

## If something goes wrong

- **A list looks stale** — pull down to refresh (Home, Journal, Appointments).
- **Demo data was edited too much** — Profile → Sample data off, then on.
- **Nothing loads** — quit and relaunch; the database and settings are seeded on
  first launch, and the app never talks to a network.
- **Accidental deletion** — Home quick logs offer **UNDO** for the entry just
  saved; the demo household can always be reseeded with the sample-data toggle.
