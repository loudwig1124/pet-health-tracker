/// The journal kind's icon and its tinted badge, shared by Home's quick-log
/// chips and its recent rows.
library;

import 'package:flutter/material.dart';

import '../../../domain/models/journal_entry.dart';
import '../../../ui/kit/app_chip.dart';
import '../../../ui/theme/app_theme.dart';

/// Material icon for one of the seven journal kinds.
IconData journalKindIcon(JournalKind kind) => switch (kind) {
  JournalKind.walk => Icons.pets,
  JournalKind.fed => Icons.restaurant,
  JournalKind.meds => Icons.medication,
  JournalKind.grooming => Icons.content_cut,
  JournalKind.training => Icons.school_outlined,
  JournalKind.note => Icons.notes,
  JournalKind.symptom => Icons.monitor_heart_outlined,
};

/// 34 px accent-tinted circle with the kind's icon.
class JournalKindBadge extends StatelessWidget {
  const JournalKindBadge({super.key, required this.kind, this.size = 34});

  final JournalKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: statusBackground(AppColors.accent, AppColors.paper),
        shape: BoxShape.circle,
      ),
      child: Icon(
        journalKindIcon(kind),
        size: size * 0.5,
        color: AppColors.accent,
      ),
    );
  }
}
