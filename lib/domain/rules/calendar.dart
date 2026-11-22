/// Calendar arithmetic used by the pure rules (no Flutter, no `intl`).
library;

/// Strips the time of day, keeping the calendar fields. Returns a UTC midnight
/// so date-only values compare consistently regardless of the device zone.
DateTime dateOnly(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

/// Adds calendar months, clamping the day to the target month's last day
/// (31 Jan + 1 month = 28/29 Feb, not 3 Mar).
DateTime addMonths(DateTime value, int months) {
  final int monthIndex = value.month - 1 + months;
  // Dart's `%` is non-negative, so this is floor division for negative months.
  final int year = value.year + (monthIndex - (monthIndex % 12)) ~/ 12;
  final int month = monthIndex % 12 + 1;
  final int lastDay = DateTime.utc(year, month + 1, 0).day;
  final int day = value.day <= lastDay ? value.day : lastDay;
  return DateTime.utc(year, month, day);
}

/// Whole days from [from] to [to] (negative when [to] is earlier).
int daysBetween(DateTime from, DateTime to) =>
    dateOnly(to).difference(dateOnly(from)).inDays;

/// Age in whole years, from a date of birth.
int ageInYears(DateTime dateOfBirth, DateTime today) {
  final DateTime birth = dateOnly(dateOfBirth);
  final DateTime reference = dateOnly(today);
  int years = reference.year - birth.year;
  final bool beforeBirthday =
      reference.month < birth.month ||
      (reference.month == birth.month && reference.day < birth.day);
  if (beforeBirthday) {
    years -= 1;
  }
  return years < 0 ? 0 : years;
}

/// Short age label: "3 wk", "8 mo", "2 yr 4 mo", "5 yr".
String ageLabel(DateTime dateOfBirth, DateTime today) {
  final DateTime birth = dateOnly(dateOfBirth);
  final DateTime reference = dateOnly(today);
  if (birth.isAfter(reference)) {
    return '—';
  }
  final int totalDays = reference.difference(birth).inDays;
  if (totalDays < 28) {
    final int weeks = totalDays ~/ 7;
    return weeks <= 1 ? '$totalDays d' : '$weeks wk';
  }
  final int years = ageInYears(birth, reference);
  if (years < 1) {
    final int months =
        (reference.year - birth.year) * 12 +
        reference.month -
        birth.month -
        (reference.day < birth.day ? 1 : 0);
    return '${months == 0 ? 1 : months} mo';
  }
  int months = reference.month - birth.month;
  if (reference.day < birth.day) {
    months -= 1;
  }
  if (months < 0) {
    months += 12;
  }
  return months == 0 ? '$years yr' : '$years yr $months mo';
}
