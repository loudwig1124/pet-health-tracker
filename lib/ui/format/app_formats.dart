/// Date and time presentation shared by every screen (`intl`).
///
/// Rule of thumb: calendar dates print day-first ("21 Nov 2026"), instants are
/// converted to local time before printing, and relative day labels are the
/// caller's job (Today / Yesterday) so tests can inject a fixed "today".
library;

import 'package:intl/intl.dart';

/// "21 Nov"
String formatDayMonth(DateTime date) => DateFormat('d MMM').format(date);

/// "21 Nov 2026"
String formatFullDate(DateTime date) => DateFormat('d MMM yyyy').format(date);

/// "Sat" — the weekday block on an appointment card.
String formatWeekdayShort(DateTime date) => DateFormat('EEE').format(date);

/// "21" — the day block on an appointment card.
String formatDayOfMonth(DateTime date) => DateFormat('d').format(date);

/// "Nov" — the month block on an appointment card.
String formatMonthShort(DateTime date) => DateFormat('MMM').format(date);

/// "9:30 AM" in the device's local time zone.
String formatTimeOfDay(DateTime instant) =>
    DateFormat.jm().format(instant.toLocal());

/// "21 Nov · 9:30 AM" in the device's local time zone.
String formatDateTimeLabel(DateTime instant) {
  final DateTime local = instant.toLocal();
  return '${DateFormat('d MMM').format(local)} · ${DateFormat.jm().format(local)}';
}

/// "Today", "Yesterday", then "21 Nov 2026".
String formatRelativeDay(DateTime date, DateTime today) {
  final DateTime day = DateTime(date.year, date.month, date.day);
  final DateTime reference = DateTime(today.year, today.month, today.day);
  final int diff = reference.difference(day).inDays;
  return switch (diff) {
    0 => 'Today',
    1 => 'Yesterday',
    _ => formatFullDate(day),
  };
}
