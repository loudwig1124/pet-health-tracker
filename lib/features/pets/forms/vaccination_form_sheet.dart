/// Record a vaccination dose. The next due date is prefilled from the catalog
/// interval and can be cleared; the shared due rule then reads "up to date".
library;

import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../domain/models/vaccination.dart';
import '../../../domain/models/vaccine_type.dart';
import '../../../domain/rules/calendar.dart';
import '../../../ui/kit/app_sheet.dart';
import '../../../ui/kit/primary_button.dart';
import '../../../ui/theme/app_theme.dart';
import 'form_fields.dart';

/// Opens the vaccination form as a modal sheet. Resolves true when saved or
/// deleted. Pass [existing] to edit a recorded dose.
Future<bool?> showVaccinationForm(
  BuildContext context, {
  required AppServices services,
  required int petId,
  required List<VaccineType> vaccineTypes,
  Vaccination? existing,
}) {
  return showAppSheet<bool>(
    context,
    (BuildContext sheetContext) => VaccinationFormSheet(
      services: services,
      petId: petId,
      vaccineTypes: vaccineTypes,
      existing: existing,
    ),
  );
}

class VaccinationFormSheet extends StatefulWidget {
  const VaccinationFormSheet({
    super.key,
    required this.services,
    required this.petId,
    required this.vaccineTypes,
    this.existing,
  });

  final AppServices services;
  final int petId;
  final List<VaccineType> vaccineTypes;
  final Vaccination? existing;

  bool get isEditing => existing != null;

  @override
  State<VaccinationFormSheet> createState() => _VaccinationFormSheetState();
}

class _VaccinationFormSheetState extends State<VaccinationFormSheet> {
  final TextEditingController _vet = TextEditingController();

  VaccineType? _type;
  late DateTime _date;
  DateTime? _nextDue;
  bool _nextDueCleared = false;
  bool _saving = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final Vaccination? existing = widget.existing;
    if (existing != null) {
      _type = widget.vaccineTypes
          .where((VaccineType type) => type.id == existing.vaccineTypeId)
          .firstOrNull;
      _type ??= widget.vaccineTypes.isEmpty
          ? null
          : widget.vaccineTypes.first;
      _date = calendarDate(existing.vaccinationDate);
      _nextDue = existing.nextDueDate == null
          ? null
          : calendarDate(existing.nextDueDate!);
      _nextDueCleared = existing.nextDueDate == null;
      _vet.text = existing.vetName ?? '';
      return;
    }
    _type = widget.vaccineTypes.isEmpty ? null : widget.vaccineTypes.first;
    _date = calendarDate(widget.services.today());
    _nextDue = _prefill();
  }

  @override
  void dispose() {
    _vet.dispose();
    super.dispose();
  }

  /// The catalog interval applied to the dose date.
  DateTime? _prefill() {
    final VaccineType? type = _type;
    if (type == null) {
      return null;
    }
    final DateTime? due = type.nextDueFrom(_date);
    return due == null ? null : calendarDate(due);
  }

  void _selectType(VaccineType? type) {
    if (type == null) {
      return;
    }
    setState(() {
      _type = type;
      // Picking a different vaccine restarts the interval, even if the user
      // cleared the previous prefill.
      _nextDueCleared = false;
      _nextDue = _prefill();
      _formError = null;
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _date = date;
      if (!_nextDueCleared) {
        _nextDue = _prefill();
      }
      _formError = null;
    });
  }

  Future<void> _save() async {
    final VaccineType? type = _type;
    if (type == null) {
      setState(() => _formError = 'Pick a vaccine type.');
      return;
    }
    final DateTime? nextDue = _nextDue;
    if (nextDue != null && !dateOnly(nextDue).isAfter(dateOnly(_date))) {
      setState(
        () => _formError = 'The next due date must be after the dose date.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      final VaccinationDraft draft = VaccinationDraft(
        petId: widget.petId,
        vaccineTypeId: type.id,
        vaccineName: type.name,
        vaccinationDate: _date,
        nextDueDate: nextDue,
        vetName: trimmedOrNull(_vet.text),
      );
      final Vaccination? existing = widget.existing;
      if (existing == null) {
        await widget.services.vaccinations.append(draft);
      } else {
        await widget.services.vaccinations.update(existing.id, draft);
      }
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
        _formError = 'Could not save this vaccination. Check the dates.';
      });
    }
  }

  Future<void> _delete() async {
    final Vaccination? existing = widget.existing;
    if (existing == null) {
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      await widget.services.vaccinations.delete(existing.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _formError = 'Could not delete this dose.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasNextDue = _nextDue != null;
    return AppSheetBody(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              widget.isEditing ? 'Edit vaccination' : 'Add a vaccination',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Vaccine'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<VaccineType>(
                  key: const ValueKey<String>('vaccination-form-type'),
                  value: _type,
                  isDense: true,
                  isExpanded: true,
                  hint: const Text('Pick a vaccine'),
                  items: widget.vaccineTypes
                      .map(
                        (VaccineType type) => DropdownMenuItem<VaccineType>(
                          value: type,
                          child: Text(type.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: widget.vaccineTypes.isEmpty ? null : _selectType,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FormDateField(
              key: const ValueKey<String>('vaccination-form-date'),
              label: 'Vaccination date',
              value: _date,
              lastDate: widget.services.today(),
              onChanged: _selectDate,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: FormDateField(
                    key: const ValueKey<String>('vaccination-form-next-due'),
                    label: 'Next due (optional)',
                    value: _nextDue,
                    firstDate: _date.add(const Duration(days: 1)),
                    lastDate: addMonths(_date, 120),
                    onChanged: (DateTime date) => setState(() {
                      _nextDue = date;
                      _nextDueCleared = false;
                      _formError = null;
                    }),
                  ),
                ),
                if (hasNextDue)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.sm,
                      top: AppSpacing.sm,
                    ),
                    child: TextButton(
                      key: const ValueKey<String>(
                        'vaccination-form-clear-next-due',
                      ),
                      onPressed: () => setState(() {
                        _nextDue = null;
                        _nextDueCleared = true;
                        _formError = null;
                      }),
                      child: const Text('Clear'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('vaccination-form-vet'),
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
              key: const ValueKey<String>('vaccination-form-save'),
              label: widget.isEditing ? 'Save changes' : 'Save vaccination',
              onPressed: _saving ? null : _save,
            ),
            if (widget.isEditing) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                key: const ValueKey<String>('vaccination-form-delete'),
                onPressed: _saving ? null : _delete,
                child: const Text(
                  'Delete this dose',
                  style: TextStyle(color: AppColors.overdue),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
