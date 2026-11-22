/// Pill chip used for quick-log actions, filters and status faces.
library;

import 'package:flutter/material.dart';

import '../../domain/models/appointment.dart';
import '../../domain/rules/vaccination_due.dart';
import '../theme/app_theme.dart';
import '../theme/status_style.dart';

/// Colour families a chip can use.
enum AppChipTone { neutral, accent, overdue, dueSoon, upToDate }

/// Filter chip for picks, or a status chip when paired with a domain status.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.tone = AppChipTone.neutral,
    this.icon,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.dense = false,
  });

  /// Chip for the shared vaccination due rule.
  factory AppChip.due(VaccinationDueStatus status, {String? label}) => AppChip(
    label: label ?? status.label,
    tone: switch (status) {
      VaccinationDueStatus.overdue => AppChipTone.overdue,
      VaccinationDueStatus.dueSoon => AppChipTone.dueSoon,
      VaccinationDueStatus.upToDate => AppChipTone.upToDate,
    },
  );

  /// Chip for an appointment state.
  factory AppChip.appointment(AppointmentStatus status) => AppChip(
    label: status.label,
    tone: switch (status) {
      AppointmentStatus.scheduled => AppChipTone.accent,
      AppointmentStatus.completed => AppChipTone.upToDate,
      AppointmentStatus.cancelled => AppChipTone.neutral,
      AppointmentStatus.noShow => AppChipTone.overdue,
    },
  );

  final String label;
  final AppChipTone tone;
  final Widget? icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (Color foreground, Color background, Color border) = _colors();
    final BorderRadius radius = AppRadii.chipRadius;
    return Semantics(
      button: onTap != null || onLongPress != null,
      selected: selected,
      label: label,
      // Ink paints the pill inside the material's ink layer, so the press
      // highlight inherits the radius instead of covering a square.
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: background,
            borderRadius: radius,
            border: Border.all(color: border),
          ),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: radius,
            child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: dense ? AppSpacing.md : AppSpacing.lg,
                vertical: dense ? 6 : 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    IconTheme(
                      data: IconThemeData(size: 16, color: foreground),
                      child: icon!,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }

  (Color, Color, Color) _colors() {
    if (selected) {
      // Solid accent with white text (~6.4:1 contrast). Setting the accent as
      // both foreground and background made the label invisible (1:1), which
      // blanked every selected filter and segmented-control pill.
      return (AppColors.surface, AppColors.accent, AppColors.accent);
    }
    return switch (tone) {
      AppChipTone.neutral => (
        AppColors.ink,
        AppColors.surface,
        AppColors.hairline,
      ),
      AppChipTone.accent => (
        AppColors.accent,
        statusBackground(AppColors.accent, AppColors.surface),
        statusBackground(AppColors.accent, AppColors.surface),
      ),
      AppChipTone.overdue => (
        overdueStatus.foreground,
        overdueStatus.background,
        overdueStatus.background,
      ),
      AppChipTone.dueSoon => (
        dueSoonStatus.foreground,
        dueSoonStatus.background,
        dueSoonStatus.background,
      ),
      AppChipTone.upToDate => (
        upToDateStatus.foreground,
        upToDateStatus.background,
        upToDateStatus.background,
      ),
    };
  }
}

/// Soft tint used by accent chips.
Color statusBackground(Color foreground, Color background) =>
    Color.alphaBlend(foreground.withValues(alpha: 0.10), background);
