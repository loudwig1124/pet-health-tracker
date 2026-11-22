/// Day grouping for the household journal feed: newest first, one section per
/// device-local calendar day.
library;

import '../../domain/models/journal_entry.dart';
import '../../ui/format/app_formats.dart';

/// Entries for one calendar day, plus the label shown as the section break.
class JournalDayGroup {
  const JournalDayGroup({
    required this.day,
    required this.label,
    required this.entries,
  });

  /// Local calendar day (midnight in the device zone) the group covers.
  final DateTime day;

  /// "Today", "Yesterday", then "18 Nov 2026".
  final String label;

  /// Newest first.
  final List<JournalEntry> entries;
}

/// Groups [entries] by the device-local day of `occurred_at`, newest group
/// first and newest entry first inside each group.
///
/// [today] is a local calendar day, so the caller controls the clock in tests.
List<JournalDayGroup> groupJournalEntriesByDay(
  Iterable<JournalEntry> entries,
  DateTime today,
) {
  final List<JournalEntry> sorted = entries.toList()
    ..sort(
      (JournalEntry a, JournalEntry b) => b.occurredAt.compareTo(a.occurredAt),
    );
  final Map<DateTime, List<JournalEntry>> byDay =
      <DateTime, List<JournalEntry>>{};
  for (final JournalEntry entry in sorted) {
    final DateTime local = entry.occurredAt.toLocal();
    final DateTime day = DateTime(local.year, local.month, local.day);
    byDay.putIfAbsent(day, () => <JournalEntry>[]).add(entry);
  }
  final List<DateTime> days = byDay.keys.toList()
    ..sort((DateTime a, DateTime b) => b.compareTo(a));
  return <JournalDayGroup>[
    for (final DateTime day in days)
      JournalDayGroup(
        day: day,
        label: formatRelativeDay(day, today),
        entries: byDay[day]!,
      ),
  ];
}
