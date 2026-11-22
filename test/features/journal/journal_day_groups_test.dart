import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/models/journal_entry.dart';
import 'package:pet_health_tracker/features/journal/journal_day_groups.dart';

JournalEntry entry(int id, DateTime occurredAt) {
  final DateTime utc = occurredAt.toUtc();
  return JournalEntry(
    id: id,
    petId: 1,
    kind: JournalKind.walk,
    occurredAt: utc,
    createdAt: utc,
    updatedAt: utc,
  );
}

void main() {
  final DateTime today = DateTime(2026, 11, 21);

  test(
    'groups by local day, newest first, labelled Today / Yesterday / date',
    () {
      final List<JournalDayGroup> groups = groupJournalEntriesByDay(
        <JournalEntry>[
          entry(1, DateTime(2026, 11, 21, 7, 10)),
          entry(2, DateTime(2026, 11, 21, 18, 0)),
          entry(3, DateTime(2026, 11, 20, 9, 0)),
          entry(4, DateTime(2026, 11, 18, 8, 30)),
        ],
        today,
      );

      expect(
        groups.map((JournalDayGroup group) => group.label).toList(),
        <String>['Today', 'Yesterday', '18 Nov 2026'],
      );
      expect(
        groups
            .map(
              (JournalDayGroup group) =>
                  group.entries.map((JournalEntry item) => item.id).toList(),
            )
            .toList(),
        <List<int>>[
          <int>[2, 1],
          <int>[3],
          <int>[4],
        ],
      );
      expect(groups.first.day, DateTime(2026, 11, 21));
      expect(groups.last.day, DateTime(2026, 11, 18));
    },
  );

  test('sorts unsorted input newest first, inside and across days', () {
    final List<JournalDayGroup> groups = groupJournalEntriesByDay(
      <JournalEntry>[
        entry(1, DateTime(2026, 11, 18, 8, 0)),
        entry(2, DateTime(2026, 11, 21, 6, 0)),
        entry(3, DateTime(2026, 11, 21, 20, 0)),
      ],
      today,
    );

    expect(
      groups
          .expand((JournalDayGroup group) => group.entries)
          .map((JournalEntry item) => item.id)
          .toList(),
      <int>[3, 2, 1],
    );
  });

  test('one group per day even when several entries share it', () {
    final List<JournalDayGroup> groups = groupJournalEntriesByDay(
      <JournalEntry>[
        entry(1, DateTime(2026, 11, 20, 7, 0)),
        entry(2, DateTime(2026, 11, 20, 12, 0)),
        entry(3, DateTime(2026, 11, 20, 21, 0)),
      ],
      today,
    );

    expect(groups, hasLength(1));
    expect(groups.single.label, 'Yesterday');
    expect(groups.single.entries, hasLength(3));
  });

  test('an instant just before midnight stays with its local day', () {
    final List<JournalDayGroup> groups = groupJournalEntriesByDay(
      <JournalEntry>[
        entry(1, DateTime(2026, 11, 20, 23, 59)),
        entry(2, DateTime(2026, 11, 21, 0, 1)),
      ],
      today,
    );

    expect(groups, hasLength(2));
    expect(groups.first.entries.single.id, 2);
    expect(groups.last.entries.single.id, 1);
  });

  test('empty input yields no groups', () {
    expect(groupJournalEntriesByDay(const <JournalEntry>[], today), isEmpty);
  });

  test('an older day is labelled with its full date', () {
    final List<JournalDayGroup> groups = groupJournalEntriesByDay(
      <JournalEntry>[entry(1, DateTime(2025, 1, 5, 8, 0))],
      today,
    );

    expect(groups.single.label, '5 Jan 2025');
  });
}
