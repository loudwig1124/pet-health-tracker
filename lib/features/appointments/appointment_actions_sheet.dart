/// The actions sheet for one appointment: complete, cancel (with a reason),
/// no-show (only after the scheduled time) and reschedule.
///
/// Terminal appointments show a read-only summary — no further transitions.
library;

import 'package:flutter/material.dart';

import '../../domain/models/appointment.dart';
import '../../domain/rules/appointment_rules.dart';
import '../../ui/format/app_formats.dart';
import '../../ui/kit/app_chip.dart';
import '../../ui/kit/app_sheet.dart';
import '../../ui/kit/list_row.dart';
import '../../ui/kit/primary_button.dart';
import '../../ui/kit/section_label.dart';
import '../../ui/theme/app_theme.dart';
import 'appointment_cancel_sheet.dart';
import 'appointment_reschedule_sheet.dart';
import 'appointments_controller.dart';

/// Confirmation text the screen shows after a successful action.
class AppointmentActionResult {
  const AppointmentActionResult(this.message);

  final String message;
}

/// Opens the actions sheet for [appointment].
Future<AppointmentActionResult?> showAppointmentActionsSheet(
  BuildContext context, {
  required Appointment appointment,
  required AppointmentsController controller,
}) {
  return showAppSheet<AppointmentActionResult>(
    context,
    (BuildContext _) => AppointmentActionsSheet(
      appointment: appointment,
      controller: controller,
    ),
  );
}

/// Sheet body. Every action runs through the controller, which uses the same
/// domain state machine as the repository.
class AppointmentActionsSheet extends StatefulWidget {
  const AppointmentActionsSheet({
    super.key,
    required this.appointment,
    required this.controller,
  });

  final Appointment appointment;
  final AppointmentsController controller;

  @override
  State<AppointmentActionsSheet> createState() =>
      _AppointmentActionsSheetState();
}

class _AppointmentActionsSheetState extends State<AppointmentActionsSheet> {
  bool _isBusy = false;

  bool get _canNoShow => widget.controller
      .availableTransitions(widget.appointment)
      .contains(AppointmentStatus.noShow);

  Future<void> _run(Future<void> Function() action, String message) async {
    setState(() => _isBusy = true);
    try {
      await action();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(AppointmentActionResult(message));
    } on AppointmentRuleException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.block.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update this appointment.')),
      );
    }
  }

  Future<void> _complete() {
    return _run(() async {
      await widget.controller.complete(widget.appointment.id);
    }, 'Appointment marked completed.');
  }

  Future<void> _cancel() async {
    final String? reason = await showAppointmentCancelSheet(
      context,
      appointment: widget.appointment,
      petLabel: widget.controller.petLabelFor(widget.appointment.petId),
    );
    if (reason == null || !mounted) {
      return;
    }
    await _run(() async {
      await widget.controller.cancel(widget.appointment.id, reason);
    }, 'Appointment cancelled.');
  }

  Future<void> _noShow() {
    return _run(() async {
      await widget.controller.markNoShow(widget.appointment.id);
    }, 'Appointment marked as a no-show.');
  }

  Future<void> _reschedule() async {
    final DateTime? newScheduledAt = await showAppointmentRescheduleSheet(
      context,
      appointment: widget.appointment,
      petLabel: widget.controller.petLabelFor(widget.appointment.petId),
    );
    if (newScheduledAt == null || !mounted) {
      return;
    }
    await _run(() async {
      await widget.controller.reschedule(
        widget.appointment.id,
        newScheduledAt: newScheduledAt,
      );
    }, 'Appointment rescheduled.');
  }

  @override
  Widget build(BuildContext context) {
    final Appointment appointment = widget.appointment;
    final String petLabel = widget.controller.petLabelFor(appointment.petId);
    return AppSheetBody(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SectionLabel(
              'Visit',
              trailing: AppChip.appointment(appointment.status),
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            ),
            Text(
              appointment.clinicName,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              '${appointment.purpose} · '
              '${formatDateTimeLabel(appointment.scheduledAt)}',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 2),
            Text(petLabel, style: AppTextStyles.caption),
            if (appointment.status == AppointmentStatus.cancelled) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Reason: ${appointment.cancelReason ?? 'Not recorded'}',
                style: AppTextStyles.caption.copyWith(color: AppColors.overdue),
              ),
            ],
            if (appointment.completedAt != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Completed ${formatDateTimeLabel(appointment.completedAt!)}',
                style: AppTextStyles.caption,
              ),
            ],
            if (appointment.status.isTerminal) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              const SectionLabel(
                'Closed',
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
              ),
              Text(
                '${appointment.status.label} visits cannot be changed.',
                style: AppTextStyles.body.copyWith(color: AppColors.secondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                key: const ValueKey<String>('appointment-actions-close'),
                label: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ] else ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              const SectionLabel(
                'Actions',
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
              ),
              ListRow(
                key: const ValueKey<String>('appointment-action-complete'),
                title: 'Mark completed',
                subtitle: 'The visit happened',
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.accent,
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.secondary,
                ),
                onTap: _isBusy ? null : _complete,
              ),
              ListRow(
                key: const ValueKey<String>('appointment-action-cancel'),
                title: 'Cancel appointment',
                subtitle: 'The reason stays on the record',
                leading: const Icon(
                  Icons.cancel_outlined,
                  color: AppColors.overdue,
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.secondary,
                ),
                onTap: _isBusy ? null : _cancel,
              ),
              ListRow(
                key: const ValueKey<String>('appointment-action-no-show'),
                title: 'Mark no-show',
                subtitle: _canNoShow
                    ? 'The visit was missed'
                    : 'Available after the appointment time',
                leading: Icon(
                  Icons.person_off_outlined,
                  color: _canNoShow ? AppColors.overdue : AppColors.secondary,
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.secondary,
                ),
                onTap: _isBusy || !_canNoShow ? null : _noShow,
              ),
              ListRow(
                key: const ValueKey<String>('appointment-action-reschedule'),
                title: 'Reschedule',
                subtitle: 'Cancels this visit and books a new one',
                leading: const Icon(
                  Icons.event_repeat_outlined,
                  color: AppColors.accent,
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.secondary,
                ),
                showDivider: false,
                onTap: _isBusy ? null : _reschedule,
              ),
              const SizedBox(height: AppSpacing.lg),
              SecondaryButton(
                key: const ValueKey<String>('appointment-actions-dismiss'),
                label: 'Keep as is',
                onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
