-- =============================================================================
-- Pet Health Tracker — SQLite schema for the offline Flutter app
--
-- Purpose : the single source of truth for the local database. The app applies
--           this file from the asset bundle on first launch; the CLI smoke test
--           is `sqlite3 :memory: ".read db/schema.sql"`.
-- Engine  : SQLite (sqflite on the phone). SQLite has no ENUM type, so enum
--           columns are TEXT with a CHECK constraint listing the allowed values.
-- Tables  : 7 — owner, pet, journal_entry, health_record, vaccination,
--           appointment, vaccine_type.
--
-- DATE FORMATS
--   date-only columns  : TEXT 'YYYY-MM-DD'  (date_of_birth, recorded_on,
--                                            vaccination_date, next_due_date)
--   instants           : TEXT ISO-8601 UTC with milliseconds and a trailing Z,
--                        e.g. 2026-11-21T08:30:00.000Z (occurred_at,
--                        scheduled_at, completed_at, created_at, updated_at).
--   SQLite has no ON UPDATE CURRENT_TIMESTAMP: writers set updated_at
--   explicitly. Date-only values compare correctly as strings because the
--   format is fixed-width and zero-padded.
--
-- KEY INVARIANTS (also enforced by the app; these are the seatbelts)
--   * microchip is UNIQUE and nullable — a chip belongs to at most one pet.
--   * a vaccination's next_due_date is strictly after its vaccination_date.
--   * appointment.status is one of scheduled|completed|cancelled|no_show, and
--     completed_at is non-null exactly when status = 'completed'.
--   * cancellation always carries a reason ('rescheduled' for a reschedule).
--   * journal_entry.kind is one of the seven allowed kinds.
--   * deleting a pet cascades to its journal, health records and vaccinations;
--     an appointment keeps its history (pet_id becomes NULL).
--   * health_record is append-only: UPDATE is always rejected and DELETE is
--     rejected while the parent pet still exists. The one allowed delete is the
--     pet-delete cascade, which is referential cleanup, not an edit.
--   * exactly one `owner` row (the household); no auth, no accounts.
-- =============================================================================

-- Per connection: sqflite's onConfigure sets foreign_keys and busy_timeout on
-- every connection, which is where they take effect (CREATE-time pragmas inside
-- a transaction are no-ops). They stay here so the CLI smoke test imports the
-- file exactly as the app does.
--
-- No WAL: the app opens one connection and never reads while another writes, so
-- write-ahead logging would add two sidecar files for no benefit.
PRAGMA foreign_keys = ON;
PRAGMA busy_timeout = 5000;

-- -----------------------------------------------------------------------------
-- 1. owner — one row, the household profile. No accounts, no auth, no sync.
-- -----------------------------------------------------------------------------
CREATE TABLE owner (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT NOT NULL CHECK (length(trim(name)) > 0),
  email      TEXT NOT NULL DEFAULT '',
  phone      TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- -----------------------------------------------------------------------------
-- 2. pet — the household animals. All of name/species/sex/dob/weight are
--    required by the form; microchip and photo are optional.
-- -----------------------------------------------------------------------------
CREATE TABLE pet (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id      INTEGER NOT NULL REFERENCES owner (id) ON DELETE CASCADE,
  name          TEXT NOT NULL CHECK (length(trim(name)) > 0),
  species       TEXT NOT NULL CHECK (length(trim(species)) > 0),
  breed         TEXT,
  sex           TEXT NOT NULL DEFAULT 'unknown'
                       CHECK (sex IN ('male', 'female', 'unknown')),
  date_of_birth TEXT NOT NULL CHECK (date_of_birth LIKE '____-__-__'),
  weight_kg     REAL NOT NULL CHECK (weight_kg > 0),
  microchip     TEXT UNIQUE,
  photo_path    TEXT,
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL
);

CREATE INDEX idx_pet_owner ON pet (owner_id);

-- -----------------------------------------------------------------------------
-- 3. journal_entry — the everyday log. Editable household entries (walk, fed,
--    meds, grooming, training, note, symptom). No clinical value claims here.
-- -----------------------------------------------------------------------------
CREATE TABLE journal_entry (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  pet_id           INTEGER NOT NULL REFERENCES pet (id) ON DELETE CASCADE,
  kind             TEXT NOT NULL
                        CHECK (kind IN ('walk', 'fed', 'meds', 'grooming',
                                        'training', 'note', 'symptom')),
  occurred_at      TEXT NOT NULL,
  note             TEXT,
  duration_minutes INTEGER CHECK (duration_minutes IS NULL OR duration_minutes > 0),
  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL
);

CREATE INDEX idx_journal_entry_household ON journal_entry (occurred_at DESC);
CREATE INDEX idx_journal_entry_pet ON journal_entry (pet_id, occurred_at DESC);

-- -----------------------------------------------------------------------------
-- 4. health_record — clinical notes. APPEND-ONLY: either condition or
--    diagnosis must be present; there is no updated_at because rows are never
--    edited. See the triggers at the bottom of this file.
-- -----------------------------------------------------------------------------
CREATE TABLE health_record (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  pet_id                INTEGER NOT NULL REFERENCES pet (id) ON DELETE CASCADE,
  recorded_on           TEXT NOT NULL CHECK (recorded_on LIKE '____-__-__'),
  condition             TEXT,
  diagnosis             TEXT,
  treatment             TEXT,
  prescribed_medication TEXT,
  vet_name              TEXT,
  created_at            TEXT NOT NULL,
  CHECK (length(trim(coalesce(condition, ''))) > 0
         OR length(trim(coalesce(diagnosis, ''))) > 0)
);

CREATE INDEX idx_health_record_pet ON health_record (pet_id, recorded_on DESC);

-- -----------------------------------------------------------------------------
-- 5. vaccine_type — the seeded catalog (rabies, DHPP, FVRCP, ...). The app
--    prefills next_due_date from interval_months.
-- -----------------------------------------------------------------------------
CREATE TABLE vaccine_type (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  name            TEXT NOT NULL UNIQUE CHECK (length(trim(name)) > 0),
  interval_months INTEGER CHECK (interval_months IS NULL OR interval_months > 0),
  is_core         INTEGER NOT NULL DEFAULT 1 CHECK (is_core IN (0, 1)),
  sort_order      INTEGER NOT NULL DEFAULT 0
);

-- -----------------------------------------------------------------------------
-- 6. vaccination — one administered dose plus its next due date. The vaccine
--    name is snapshotted so a catalog rename never rewrites history.
-- -----------------------------------------------------------------------------
CREATE TABLE vaccination (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  pet_id          INTEGER NOT NULL REFERENCES pet (id) ON DELETE CASCADE,
  vaccine_type_id INTEGER REFERENCES vaccine_type (id) ON DELETE SET NULL,
  vaccine_name    TEXT NOT NULL CHECK (length(trim(vaccine_name)) > 0),
  vaccination_date TEXT NOT NULL CHECK (vaccination_date LIKE '____-__-__'),
  next_due_date   TEXT CHECK (next_due_date IS NULL OR next_due_date LIKE '____-__-__'),
  vet_name        TEXT,
  created_at      TEXT NOT NULL,
  -- The booster must be due after the dose it follows.
  CHECK (next_due_date IS NULL OR next_due_date > vaccination_date)
);

CREATE INDEX idx_vaccination_pet ON vaccination (pet_id, vaccination_date DESC);
CREATE INDEX idx_vaccination_due ON vaccination (next_due_date);

-- -----------------------------------------------------------------------------
-- 7. appointment — household-wide vet visits. pet_id is SET NULL on pet
--    deletion so the visit history survives; the UI renders "Household" then.
-- -----------------------------------------------------------------------------
CREATE TABLE appointment (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  pet_id        INTEGER REFERENCES pet (id) ON DELETE SET NULL,
  clinic_name   TEXT NOT NULL CHECK (length(trim(clinic_name)) > 0),
  purpose       TEXT NOT NULL CHECK (length(trim(purpose)) > 0),
  scheduled_at  TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'scheduled'
                     CHECK (status IN ('scheduled', 'completed', 'cancelled', 'no_show')),
  completed_at  TEXT,
  cancel_reason TEXT,
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL,
  -- completed_at exists exactly for a completed appointment.
  CHECK ((status = 'completed' AND completed_at IS NOT NULL)
         OR (status <> 'completed' AND completed_at IS NULL)),
  -- A cancellation always explains itself ('rescheduled' included).
  CHECK (status <> 'cancelled' OR length(trim(coalesce(cancel_reason, ''))) > 0)
);

CREATE INDEX idx_appointment_schedule ON appointment (scheduled_at);
CREATE INDEX idx_appointment_pet ON appointment (pet_id, scheduled_at);

