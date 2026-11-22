/// The next-visit card: tinted date block, clinic, purpose and time.
library;

import 'package:flutter/material.dart';

import '../../../domain/models/appointment.dart';
import '../../../ui/format/app_formats.dart';
import '../../../ui/kit/app_card.dart';
import '../../../ui/kit/app_chip.dart';
import '../../../ui/theme/app_theme.dart';

class NextAppointmentCard extends StatelessWidget {
  const NextAppointmentCard({
    super.key,
    required this.appointment,
    this.petName,
    this.onTap,
  });

  final Appointment appointment;

  /// The visit's pet; null when the pet was deleted (the visit stays).
  final String? petName;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final List<String> details = <String>[
      if (petName != null && petName!.isNotEmpty) petName!,
      appointment.purpose,
      formatTimeOfDay(appointment.scheduledAt),
    ];
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          _DateBlock(date: appointment.scheduledAt.toLocal()),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  appointment.clinicName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  details.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.secondary),
        ],
      ),
    );
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: statusBackground(AppColors.accent, AppColors.surface),
        borderRadius: AppRadii.chipRadius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            formatWeekdayShort(date),
            style: AppTextStyles.sectionLabel.copyWith(color: AppColors.accent),
          ),
          Text(
            formatDayOfMonth(date),
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}
