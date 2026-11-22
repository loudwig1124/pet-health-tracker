/// Small form widgets and helpers shared by the feature sheets.
library;

import 'package:flutter/material.dart';

import '../../../ui/format/app_formats.dart';
import '../../../ui/theme/app_theme.dart';

/// Strips a calendar date to its local Y/M/D fields. Forms keep dates as
/// calendar values; the repositories normalise them to date-only storage.
DateTime calendarDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Trims optional text and turns blank into null.
String? trimmedOrNull(String? value) {
  final String? trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

/// A tappable calendar row: shows the formatted date (or "Not set") and opens
/// the Material date picker.
class FormDateField extends StatelessWidget {
  const FormDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.errorText,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final DateTime? selected = value;
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(AppRadii.chip),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          selected == null ? 'Not set' : formatFullDate(selected),
          style: AppTextStyles.body,
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final DateTime first = calendarDate(firstDate ?? DateTime(2000));
    final DateTime last = calendarDate(lastDate ?? DateTime(2100));
    final DateTime initial = _clamp(calendarDate(value ?? first), first, last);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: label,
    );
    if (picked != null) {
      onChanged(calendarDate(picked));
    }
  }

  DateTime _clamp(DateTime date, DateTime first, DateTime last) {
    if (date.isBefore(first)) {
      return first;
    }
    if (date.isAfter(last)) {
      return last;
    }
    return date;
  }
}
