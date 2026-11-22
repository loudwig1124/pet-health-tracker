/// Small status dot: the compact face of a domain status.
library;

import 'package:flutter/material.dart';

import '../../domain/models/appointment.dart';
import '../../domain/rules/vaccination_due.dart';
import '../theme/app_theme.dart';
import '../theme/status_style.dart';

/// A 6–10 px filled circle. Use next to a label or alone in dense lists.
class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    required this.color,
    this.size = 6,
    this.semanticsLabel,
  });

  /// Dot for the shared vaccination due rule.
  StatusDot.due(VaccinationDueStatus status, {super.key, this.size = 6})
    : color = vaccinationStatusPalette(status).foreground,
      semanticsLabel = status.label;

  /// Dot for an appointment state.
  StatusDot.appointment(AppointmentStatus status, {super.key, this.size = 6})
    : color = appointmentStatusPalette(status).foreground,
      semanticsLabel = status.label;

  final Color color;
  final double size;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.hairline, width: 0.5),
        ),
      ),
    );
  }
}
