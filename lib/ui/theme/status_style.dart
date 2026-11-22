/// Maps domain status enums to their approved colour pair.
///
/// Kept in the UI layer so `lib/domain` stays free of Flutter imports.
library;

import 'package:flutter/material.dart';

import '../../domain/models/appointment.dart';
import '../../domain/rules/vaccination_due.dart';
import 'app_theme.dart';

/// A tinted pair: readable foreground on a soft background.
class StatusPalette {
  const StatusPalette({required this.foreground, required this.background});

  final Color foreground;
  final Color background;
}

const StatusPalette neutralStatus = StatusPalette(
  foreground: AppColors.secondary,
  background: AppColors.paper,
);

const StatusPalette overdueStatus = StatusPalette(
  foreground: AppColors.overdue,
  background: AppColors.overdueSurface,
);

const StatusPalette dueSoonStatus = StatusPalette(
  foreground: AppColors.dueSoon,
  background: AppColors.dueSoonSurface,
);

const StatusPalette upToDateStatus = StatusPalette(
  foreground: AppColors.upToDate,
  background: AppColors.upToDateSurface,
);

/// Overdue / due soon / up to date (the 30-day window rule).
StatusPalette vaccinationStatusPalette(VaccinationDueStatus status) {
  return switch (status) {
    VaccinationDueStatus.overdue => overdueStatus,
    VaccinationDueStatus.dueSoon => dueSoonStatus,
    VaccinationDueStatus.upToDate => upToDateStatus,
  };
}

/// Appointment chips: scheduled is accent, completed/up-to-date, no-show
/// overdue, cancelled neutral.
StatusPalette appointmentStatusPalette(AppointmentStatus status) {
  return switch (status) {
    AppointmentStatus.scheduled => StatusPalette(
      foreground: AppColors.accent,
      background: Color.alphaBlend(
        AppColors.accent.withValues(alpha: 0.10),
        AppColors.surface,
      ),
    ),
    AppointmentStatus.completed => upToDateStatus,
    AppointmentStatus.cancelled => neutralStatus,
    AppointmentStatus.noShow => overdueStatus,
  };
}
