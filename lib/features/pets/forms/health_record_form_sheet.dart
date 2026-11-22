/// Append a clinical note to a pet's medical history. There is no edit path:
/// once saved the record is immutable.
library;

import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../domain/models/health_record.dart';
import '../../../ui/kit/app_sheet.dart';
import '../../../ui/kit/primary_button.dart';
import '../../../ui/theme/app_theme.dart';
import 'form_fields.dart';

/// Opens the clinical-note form as a modal sheet. Resolves true when appended.
Future<bool?> showHealthRecordForm(
  BuildContext context, {
  required AppServices services,
  required int petId,
}) {
  return showAppSheet<bool>(
    context,
    (BuildContext sheetContext) =>
        HealthRecordFormSheet(services: services, petId: petId),
  );
}

class HealthRecordFormSheet extends StatefulWidget {
  const HealthRecordFormSheet({
    super.key,
    required this.services,
    required this.petId,
  });

  final AppServices services;
  final int petId;

  @override
  State<HealthRecordFormSheet> createState() => _HealthRecordFormSheetState();
}

class _HealthRecordFormSheetState extends State<HealthRecordFormSheet> {
  final TextEditingController _condition = TextEditingController();
  final TextEditingController _diagnosis = TextEditingController();
  final TextEditingController _treatment = TextEditingController();
  final TextEditingController _medication = TextEditingController();
  final TextEditingController _vet = TextEditingController();

  late DateTime _date;
  bool _saving = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _date = calendarDate(widget.services.today());
  }

  @override
  void dispose() {
    _condition.dispose();
    _diagnosis.dispose();
    _treatment.dispose();
    _medication.dispose();
    _vet.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String? condition = trimmedOrNull(_condition.text);
    final String? diagnosis = trimmedOrNull(_diagnosis.text);
    if (condition == null && diagnosis == null) {
      setState(() => _formError = 'Add a condition or a diagnosis.');
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      await widget.services.healthRecords.append(
        HealthRecordDraft(
          petId: widget.petId,
          recordedOn: _date,
          condition: condition,
          diagnosis: diagnosis,
          treatment: trimmedOrNull(_treatment.text),
          prescribedMedication: trimmedOrNull(_medication.text),
          vetName: trimmedOrNull(_vet.text),
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _formError = 'Could not save this note. Check the date and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetBody(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'New health record',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Clinical notes are append-only: they cannot be edited or '
              'deleted after saving.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.lg),
            FormDateField(
              key: const ValueKey<String>('health-record-form-date'),
              label: 'Date',
              value: _date,
              lastDate: widget.services.today(),
              onChanged: (DateTime date) => setState(() => _date = date),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('health-record-form-condition'),
              controller: _condition,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (String value) => setState(() => _formError = null),
              decoration: const InputDecoration(
                labelText: 'Condition',
                hintText: 'e.g. Ear infection',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('health-record-form-diagnosis'),
              controller: _diagnosis,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (String value) => setState(() => _formError = null),
              decoration: const InputDecoration(
                labelText: 'Diagnosis',
                hintText: 'Condition or diagnosis — at least one',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('health-record-form-treatment'),
              controller: _treatment,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Treatment (optional)',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('health-record-form-medication'),
              controller: _medication,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Prescribed medication (optional)',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('health-record-form-vet'),
              controller: _vet,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Vet (optional)'),
            ),
            if (_formError != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                _formError!,
                style: AppTextStyles.body.copyWith(color: AppColors.overdue),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              key: const ValueKey<String>('health-record-form-save'),
              label: 'Save record',
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
