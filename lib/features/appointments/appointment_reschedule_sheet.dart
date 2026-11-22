/// The reschedule step for an appointment: pick the new date and time.
library;

import 'package:flutter/material.dart';

import '../../domain/models/appointment.dart';
import '../../ui/format/app_formats.dart';
import '../../ui/kit/app_sheet.dart';
import '../../ui/kit/list_row.dart';
import '../../ui/kit/primary_button.dart';
import '../../ui/kit/section_label.dart';
import '../../ui/theme/app_theme.dart';

/// Returns the new scheduled instant in local time, or null when dismissed.
Future<DateTime?> showAppointmentRescheduleSheet(
  BuildContext context, {
  required Appointment appointment,
  required String petLabel,
}) {
  return showAppSheet<DateTime>(
    context,
    (BuildContext _) => AppointmentRescheduleSheet(
      appointment: appointment,
      petLabel: petLabel,
    ),
  );
}

/// Sheet body. The repository cancels the old row and books the new one in one
/// transaction, so a half-rescheduled visit is impossible.
class AppointmentRescheduleSheet extends StatefulWidget {
  const AppointmentRescheduleSheet({
    super.key,
    required this.appointment,
    required this.petLabel,
  });

  final Appointment appointment;
  final String petLabel;

  @override
  State<AppointmentRescheduleSheet> createState() =>
      _AppointmentRescheduleSheetState();
}

class _AppointmentRescheduleSheetState
    extends State<AppointmentRescheduleSheet> {
  late DateTime _date = widget.appointment.scheduledAt.toLocal();
  late TimeOfDay _time = TimeOfDay.fromDateTime(
    widget.appointment.scheduledAt.toLocal(),
  );

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _time = picked);
  }

  void _confirm() {
    Navigator.of(context).pop(
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetBody(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SectionLabel(
              'Reschedule visit',
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
            ),
            Text(
              '${widget.petLabel} · ${widget.appointment.purpose}',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.sm),
            ListRow(
              key: const ValueKey<String>('appointment-reschedule-date'),
              title: formatFullDate(_date),
              subtitle: 'Tap to change the date',
              leading: const Icon(
                Icons.calendar_today_outlined,
                color: AppColors.accent,
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.secondary,
              ),
              onTap: _pickDate,
            ),
            ListRow(
              key: const ValueKey<String>('appointment-reschedule-time'),
              title: formatTimeOfDay(
                DateTime(2000, 1, 1, _time.hour, _time.minute),
              ),
              subtitle: 'Tap to change the time',
              leading: const Icon(Icons.schedule, color: AppColors.accent),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.secondary,
              ),
              showDivider: false,
              onTap: _pickTime,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              key: const ValueKey<String>('appointment-reschedule-confirm'),
              label: 'Reschedule visit',
              onPressed: _confirm,
            ),
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Keep as is',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
