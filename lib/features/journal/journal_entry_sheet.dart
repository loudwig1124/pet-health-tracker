/// The journal edit sheet: time, note, optional duration and delete.
///
/// Journal entries are editable; clinical notes live in Health Records and are
/// append-only, so this sheet never touches them.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/journal_entry.dart';
import '../../ui/format/app_formats.dart';
import '../../ui/kit/app_sheet.dart';
import '../../ui/kit/list_row.dart';
import '../../ui/kit/primary_button.dart';
import '../../ui/kit/section_label.dart';
import '../../ui/theme/app_theme.dart';
import 'journal_controller.dart';

/// What the edit sheet did when it closed.
enum JournalEntrySheetResult { saved, deleted }

/// Opens the edit sheet for [entry].
Future<JournalEntrySheetResult?> showJournalEntryEditSheet(
  BuildContext context, {
  required JournalEntry entry,
  required JournalController controller,
}) {
  return showAppSheet<JournalEntrySheetResult>(
    context,
    (BuildContext _) =>
        JournalEntryEditSheet(entry: entry, controller: controller),
  );
}

/// Sheet body. Saving calls the controller and pops with the outcome.
class JournalEntryEditSheet extends StatefulWidget {
  const JournalEntryEditSheet({
    super.key,
    required this.entry,
    required this.controller,
  });

  final JournalEntry entry;
  final JournalController controller;

  @override
  State<JournalEntryEditSheet> createState() => _JournalEntryEditSheetState();
}

class _JournalEntryEditSheetState extends State<JournalEntryEditSheet> {
  late final TextEditingController _note = TextEditingController(
    text: widget.entry.note ?? '',
  );
  late final TextEditingController _duration = TextEditingController(
    text: widget.entry.durationMinutes?.toString() ?? '',
  );
  late DateTime _occurredAt = widget.entry.occurredAt;
  String? _durationError;
  bool _isSaving = false;

  @override
  void dispose() {
    _note.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final DateTime local = _occurredAt.toLocal();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _occurredAt = DateTime(
        local.year,
        local.month,
        local.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _onDurationChanged(String value) {
    final String text = value.trim();
    final int? minutes = int.tryParse(text);
    setState(() {
      if (text.isEmpty) {
        _durationError = null;
      } else if (minutes == null || minutes <= 0) {
        _durationError = 'Enter minutes as a whole number';
      } else {
        _durationError = null;
      }
    });
  }

  Future<void> _save() async {
    if (_isSaving || _durationError != null) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.controller.updateEntry(
        widget.entry.id,
        JournalDraft(
          petId: widget.entry.petId,
          kind: widget.entry.kind,
          occurredAt: _occurredAt,
          note: _note.text,
          durationMinutes: int.tryParse(_duration.text.trim()),
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(JournalEntrySheetResult.saved);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this entry.')),
      );
    }
  }

  Future<void> _delete() async {
    if (_isSaving) {
      return;
    }
    // One tap used to erase an entry for good; ask first.
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text(
          'It is removed from the journal, and this cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            key: const ValueKey<String>('journal-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.overdue),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.controller.deleteEntry(widget.entry.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(JournalEntrySheetResult.deleted);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete this entry.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime local = widget.entry.occurredAt.toLocal();
    return AppSheetBody(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SectionLabel(
              widget.entry.kind.label,
              trailing: Text(
                formatFullDate(local),
                style: AppTextStyles.caption,
              ),
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            ),
            ListRow(
              key: const ValueKey<String>('journal-edit-time'),
              title: formatTimeOfDay(_occurredAt),
              subtitle: 'Tap to change the time',
              leading: const Icon(Icons.schedule, color: AppColors.accent),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.secondary,
              ),
              showDivider: false,
              onTap: _isSaving ? null : _pickTime,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const ValueKey<String>('journal-edit-note'),
              controller: _note,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'What happened?',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const ValueKey<String>('journal-edit-duration'),
              controller: _duration,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: _onDurationChanged,
              decoration: InputDecoration(
                labelText: 'Duration (minutes, optional)',
                errorText: _durationError,
                suffixText: 'min',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              key: const ValueKey<String>('journal-edit-save'),
              label: _isSaving ? 'Saving…' : 'Save changes',
              onPressed: _isSaving ? null : _save,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              key: const ValueKey<String>('journal-edit-delete'),
              style: TextButton.styleFrom(foregroundColor: AppColors.overdue),
              onPressed: _isSaving ? null : _delete,
              child: const Text('Delete entry'),
            ),
          ],
        ),
      ),
    );
  }
}
