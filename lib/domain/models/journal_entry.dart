/// The everyday household log.
library;

/// The seven allowed journal kinds (mirrors the DDL CHECK).
enum JournalKind {
  walk('walk', 'Walk'),
  fed('fed', 'Fed'),
  meds('meds', 'Meds'),
  grooming('grooming', 'Grooming'),
  training('training', 'Training'),
  note('note', 'Note'),
  symptom('symptom', 'Symptom');

  const JournalKind(this.wire, this.label);

  final String wire;
  final String label;

  /// The four chips offered by Home's quick-log row.
  static const List<JournalKind> quickLog = <JournalKind>[
    walk,
    fed,
    meds,
    note,
  ];

  static JournalKind fromWire(String value) => values.firstWhere(
    (JournalKind kind) => kind.wire == value,
    orElse: () => JournalKind.note,
  );
}

/// What a journal form submits. Quick-log saves only kind + occurredAt.
class JournalDraft {
  const JournalDraft({
    required this.petId,
    required this.kind,
    required this.occurredAt,
    this.note,
    this.durationMinutes,
  });

  final int petId;
  final JournalKind kind;
  final DateTime occurredAt;
  final String? note;
  final int? durationMinutes;
}

/// The persisted journal entry.
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.petId,
    required this.kind,
    required this.occurredAt,
    this.note,
    this.durationMinutes,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int petId;
  final JournalKind kind;
  final DateTime occurredAt;
  final String? note;
  final int? durationMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// "Walk · 30 min" / "Fed" — the row title on the Journal feed.
  String get title {
    final int? minutes = durationMinutes;
    if (minutes == null || minutes <= 0) {
      return kind.label;
    }
    return '${kind.label} · $minutes min';
  }

  JournalDraft toDraft() => JournalDraft(
    petId: petId,
    kind: kind,
    occurredAt: occurredAt,
    note: note,
    durationMinutes: durationMinutes,
  );
}
