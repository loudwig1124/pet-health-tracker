/// The full journal-entry form behind a long-press on a quick-log chip.
///
/// The chip itself saves only the kind and "now"; anything else the owner wants
/// to record (when, note, duration) is entered here.
library;

import 'package:flutter/material.dart';

import '../../../domain/models/journal_entry.dart';
import '../../../domain/models/pet.dart';
import '../../../ui/format/app_formats.dart';
import '../../../ui/kit/app_chip.dart';
import '../../../ui/kit/app_sheet.dart';
import '../../../ui/kit/primary_button.dart';
import '../../../ui/kit/section_label.dart';
import '../../../ui/theme/app_theme.dart';
import 'journal_kind_badge.dart';

/// Opens the form and resolves to the saved entry, or null when dismissed.
Future<JournalEntry?> showQuickLogForm(
  BuildContext context, {
  required Pet pet,
  required JournalKind kind,
  required DateTime initialWhen,
  required Future<JournalEntry> Function(JournalDraft draft) onSave,
}) {
  return showAppSheet<JournalEntry>(
    context,
    (BuildContext context) => _QuickLogForm(
      pet: pet,
      initialKind: kind,
      initialWhen: initialWhen,
      onSave: onSave,
    ),
  );
}

class _QuickLogForm extends StatefulWidget {
  const _QuickLogForm({
    required this.pet,
    required this.initialKind,
    required this.initialWhen,
    required this.onSave,
  });

  final Pet pet;
  final JournalKind initialKind;
  final DateTime initialWhen;
  final Future<JournalEntry> Function(JournalDraft draft) onSave;

  @override
  State<_QuickLogForm> createState() => _QuickLogFormState();
}

class _QuickLogFormState extends State<_QuickLogForm> {
  late JournalKind _kind = widget.initialKind;
  late DateTime _when = widget.initialWhen;
  final TextEditingController _note = TextEditingController();
  final TextEditingController _duration = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _when = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _when.hour,
        _when.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _when = DateTime(
        _when.year,
        _when.month,
        _when.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final JournalEntry entry = await widget.onSave(
        JournalDraft(
          petId: widget.pet.id,
          kind: _kind,
          occurredAt: _when,
          note: _note.text,
          durationMinutes: int.tryParse(_duration.text.trim()),
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(entry);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Couldn't save the entry.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetBody(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Log for ${widget.pet.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'The chip saves the kind and now. Everything else goes here.',
              style: AppTextStyles.caption,
            ),
            const SectionLabel(
              'Kind',
              padding: EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.sm),
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final JournalKind kind in JournalKind.values)
                  AppChip(
                    key: ValueKey<String>('form-kind-${kind.wire}'),
                    label: kind.label,
                    dense: true,
                    tone: _kind == kind
                        ? AppChipTone.accent
                        : AppChipTone.neutral,
                    icon: Icon(
                      _kind == kind ? Icons.check : journalKindIcon(kind),
                      color: AppColors.accent,
                    ),
                    onTap: () => setState(() => _kind = kind),
                  ),
              ],
            ),
            const SectionLabel(
              'When',
              padding: EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.sm),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey<String>('form-date'),
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(formatFullDate(_when)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey<String>('form-time'),
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(formatTimeOfDay(_when)),
                  ),
                ),
              ],
            ),
            const SectionLabel(
              'Note',
              padding: EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.sm),
            ),
            TextField(
              key: const ValueKey<String>('form-note'),
              controller: _note,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'What happened?'),
            ),
            const SectionLabel(
              'Duration',
              padding: EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.sm),
            ),
            TextField(
              key: const ValueKey<String>('form-duration'),
              controller: _duration,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Minutes (optional)'),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Save entry',
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
