/// The cancel step for an appointment: a cancellation always carries a reason.
library;

import 'package:flutter/material.dart';

import '../../domain/models/appointment.dart';
import '../../ui/format/app_formats.dart';
import '../../ui/kit/app_sheet.dart';
import '../../ui/kit/primary_button.dart';
import '../../ui/kit/section_label.dart';
import '../../ui/theme/app_theme.dart';

/// Asks for a cancellation reason. Returns the trimmed reason, or null when
/// the user backs out.
Future<String?> showAppointmentCancelSheet(
  BuildContext context, {
  required Appointment appointment,
  required String petLabel,
}) {
  return showAppSheet<String>(
    context,
    (BuildContext _) =>
        AppointmentCancelSheet(appointment: appointment, petLabel: petLabel),
  );
}

/// Sheet body. The confirm button stays disabled until a reason is typed.
class AppointmentCancelSheet extends StatefulWidget {
  const AppointmentCancelSheet({
    super.key,
    required this.appointment,
    required this.petLabel,
  });

  final Appointment appointment;
  final String petLabel;

  @override
  State<AppointmentCancelSheet> createState() => _AppointmentCancelSheetState();
}

class _AppointmentCancelSheetState extends State<AppointmentCancelSheet> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String get _trimmedReason => _reason.text.trim();

  void _confirm() {
    if (_trimmedReason.isEmpty) {
      return;
    }
    Navigator.of(context).pop(_trimmedReason);
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
              'Cancel visit',
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
            ),
            Text(
              '${widget.petLabel} · ${widget.appointment.purpose} — '
              '${formatDateTimeLabel(widget.appointment.scheduledAt)}',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const ValueKey<String>('appointment-cancel-reason'),
              controller: _reason,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (String _) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Why is this visit cancelled?',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              key: const ValueKey<String>('appointment-cancel-confirm'),
              label: 'Cancel appointment',
              onPressed: _trimmedReason.isEmpty ? null : _confirm,
            ),
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Keep appointment',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
