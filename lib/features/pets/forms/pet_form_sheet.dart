/// Add or edit a pet. Creates the pet from the Profile "Add a pet" row and
/// edits it from the pet page's "Edit" action.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../ui/kit/app_snack_bar.dart';

import '../../../app/app_services.dart';
import '../../../domain/models/pet.dart';
import '../../../domain/rules/pet_validation.dart';
import '../../../domain/species.dart';
import '../../../ui/kit/app_chip.dart';
import '../../../ui/kit/app_sheet.dart';
import '../../../ui/kit/primary_button.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../data/pet_photos.dart';
import '../pet_photo.dart';
import 'form_fields.dart';

/// Opens the pet form as a modal sheet. Resolves true when a pet was saved.
Future<bool?> showPetForm(
  BuildContext context, {
  required AppServices services,
  Pet? existing,
}) {
  return showAppSheet<bool>(
    context,
    (BuildContext sheetContext) =>
        PetFormSheet(services: services, existing: existing),
  );
}

class PetFormSheet extends StatefulWidget {
  const PetFormSheet({super.key, required this.services, this.existing});

  final AppServices services;

  /// When provided the form edits this pet; otherwise it creates one.
  final Pet? existing;

  @override
  State<PetFormSheet> createState() => _PetFormSheetState();
}

class _PetFormSheetState extends State<PetFormSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _species = TextEditingController();
  final TextEditingController _weight = TextEditingController();
  final TextEditingController _microchip = TextEditingController();
  final TextEditingController _photo = TextEditingController();

  /// The photo the pet had when the form opened, so a replaced or removed file
  /// can be cleaned up after a successful save (never before one).
  String? _originalPhoto;

  PetSex _sex = PetSex.unknown;
  late DateTime _dateOfBirth;
  Map<PetField, String> _errors = const <PetField, String>{};
  bool _saving = false;
  String? _saveError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final Pet? existing = widget.existing;
    if (existing != null) {
      _name.text = existing.name;
      _species.text = existing.species;
      _sex = existing.sex;
      _dateOfBirth = calendarDate(existing.dateOfBirth);
      _weight.text = existing.weightKg.toStringAsFixed(1);
      _microchip.text = existing.microchip ?? '';
      _photo.text = existing.photoPath ?? '';
      _originalPhoto = existing.photoPath;
    } else {
      _dateOfBirth = calendarDate(widget.services.today());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _species.dispose();
    _weight.dispose();
    _microchip.dispose();
    _photo.dispose();
    super.dispose();
  }

  void _clearError(PetField field) {
    if (_errors.containsKey(field)) {
      setState(
        () => _errors = Map<PetField, String>.of(_errors)..remove(field),
      );
    }
  }

  Future<void> _save() async {
    final double weight =
        double.tryParse(_weight.text.trim().replaceAll(',', '.')) ?? 0;
    final PetDraft draft = PetDraft(
      name: _name.text,
      species: _species.text,
      sex: _sex,
      dateOfBirth: _dateOfBirth,
      weightKg: weight,
      microchip: normalizeMicrochip(_microchip.text),
      photoPath: trimmedOrNull(_photo.text),
    );
    final PetValidationResult result = validatePetDraft(
      draft,
      today: widget.services.today(),
    );
    if (!result.isValid) {
      setState(() {
        _errors = result.errors;
        _saveError = null;
      });
      return;
    }
    setState(() {
      _saving = true;
      _errors = const <PetField, String>{};
      _saveError = null;
    });
    try {
      final Pet? existing = widget.existing;
      if (existing == null) {
        await widget.services.pets.create(draft);
      } else {
        await widget.services.pets.update(existing.id, draft);
      }
      final String? previous = _originalPhoto;
      if (previous != null && previous != trimmedOrNull(_photo.text)) {
        // Fire and forget: a stale photo file must never fail a save.
        unawaited(PetPhotos().deleteOwned(previous));
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
        _saveError =
            'Could not save this pet. Check that the microchip is unique.';
      });
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final String? path = await PetPhotos().pickFromLibrary();
      if (!mounted) {
        return;
      }
      if (path == null) {
        // The user backed out of the picker. Say so, so "nothing happened"
        // can be told apart from a failure.
        showAppSnack(context, 'No photo chosen.');
        return;
      }
      setState(() => _photo.text = path);
    } catch (error) {
      if (!mounted) {
        return;
      }
      // Surface the real reason: a plugin that never registered and a missing
      // permission look identical otherwise.
      final String detail = error.toString();
      // The picker's failure text stays a little longer: it is the only clue
      // when the platform plugin misbehaves.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          persist: false,
          content: Text(
            detail.length > 220 ? detail.substring(0, 220) : detail,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // A save in flight must not be dismissed: the write would complete with
    // the sheet gone and no way to show its error.
    return PopScope(
      canPop: !_saving,
      child: AppSheetBody(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _isEdit ? 'Edit pet' : 'Add a pet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const ValueKey<String>('pet-form-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              // Error text is cleared as soon as the field is edited.
              onChanged: (String value) => _clearError(PetField.name),
              decoration: InputDecoration(
                labelText: 'Name',
                errorText: _errors[PetField.name],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              key: const ValueKey<String>('pet-form-species'),
              isExpanded: true,
              initialValue: speciesOptions(_species.text).contains(_species.text)
                  ? _species.text
                  : null,
              decoration: InputDecoration(
                labelText: 'Species',
                errorText: _errors[PetField.species],
              ),
              items: <DropdownMenuItem<String>>[
                for (final String species in speciesOptions(_species.text))
                  DropdownMenuItem<String>(value: species, child: Text(species)),
              ],
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _species.text = value;
                  _clearError(PetField.species);
                });
              },
            ),
            const SizedBox(height: AppSpacing.md),
            FormDateField(
              key: const ValueKey<String>('pet-form-dob'),
              label: 'Date of birth',
              value: _dateOfBirth,
              lastDate: widget.services.today(),
              errorText: _errors[PetField.dateOfBirth],
              onChanged: (DateTime date) {
                setState(() {
                  _dateOfBirth = date;
                  _errors = Map<PetField, String>.of(_errors)
                    ..remove(PetField.dateOfBirth);
                });
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('pet-form-weight'),
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (String value) => _clearError(PetField.weightKg),
              decoration: InputDecoration(
                labelText: 'Weight (kg)',
                suffixText: 'kg',
                errorText: _errors[PetField.weightKg],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SexPicker(
              selected: _sex,
              onSelected: (PetSex sex) => setState(() => _sex = sex),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('pet-form-microchip'),
              controller: _microchip,
              keyboardType: TextInputType.number,
              onChanged: (String value) => _clearError(PetField.microchip),
              decoration: InputDecoration(
                labelText: 'Microchip (optional)',
                hintText: '9–15 digits',
                errorText: _errors[PetField.microchip],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Photo: picked from the library and copied into app storage, not
            // typed as a path.
            Row(
              children: <Widget>[
                PetAvatar(
                  photoPath: trimmedOrNull(_photo.text),
                  petName: _name.text,
                  size: 64,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // The browser build has no filesystem, so the picker
                      // would open and always answer "No photo chosen".
                      if (PetPhotos.supported)
                        SecondaryButton(
                          key: const ValueKey<String>('pet-form-photo'),
                          label: trimmedOrNull(_photo.text) == null
                              ? 'Choose photo'
                              : 'Change photo',
                          onPressed: _pickPhoto,
                        ),
                      if (trimmedOrNull(_photo.text) != null)
                        TextButton(
                          key: const ValueKey<String>('pet-form-photo-clear'),
                          onPressed: () => setState(() => _photo.clear()),
                          child: const Text('Remove photo'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_saveError != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                _saveError!,
                style: AppTextStyles.body.copyWith(color: AppColors.overdue),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              key: const ValueKey<String>('pet-form-save'),
              label: _isEdit ? 'Save changes' : 'Add pet',
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _SexPicker extends StatelessWidget {
  const _SexPicker({required this.selected, required this.onSelected});

  final PetSex selected;
  final ValueChanged<PetSex> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Sex', style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final PetSex sex in PetSex.values)
              SizedBox(
                height: 44,
                child: AppChip(
                  key: ValueKey<String>('pet-form-sex-${sex.wire}'),
                  label: sex.label,
                  selected: selected == sex,
                  onTap: () => onSelected(sex),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
