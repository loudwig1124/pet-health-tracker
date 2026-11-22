/// The four instant-log chips: tap saves now, long-press opens the full form.
library;

import 'package:flutter/material.dart';

import '../../../domain/models/journal_entry.dart';
import '../../../ui/kit/app_chip.dart';
import '../../../ui/theme/app_theme.dart';
import 'journal_kind_badge.dart';

class QuickLogRow extends StatelessWidget {
  const QuickLogRow({
    super.key,
    required this.onQuickLog,
    required this.onOpenForm,
  });

  /// Tap: save the kind with the current instant, nothing else.
  final ValueChanged<JournalKind> onQuickLog;

  /// Long-press: open the full journal-entry form for the same kind.
  final ValueChanged<JournalKind> onOpenForm;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final JournalKind kind in JournalKind.quickLog)
          AppChip(
            key: ValueKey<String>('quick-log-${kind.wire}'),
            label: kind.label,
            dense: true,
            icon: Icon(journalKindIcon(kind), color: AppColors.accent),
            onTap: () => onQuickLog(kind),
            onLongPress: () => onOpenForm(kind),
          ),
      ],
    );
  }
}
