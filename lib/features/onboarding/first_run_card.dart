/// First-run onboarding: name the owner and add the first pet.
///
/// Shown by Home only when the household is genuinely empty — with the sample
/// data on there is already something to look at, so this never interrupts it.
library;

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../domain/models/owner.dart';
import '../../domain/models/pet.dart';
import '../../domain/rules/owner_validation.dart';
import '../../domain/rules/pet_validation.dart';
import '../../domain/species.dart';
import '../../ui/kit/app_card.dart';
import '../../ui/kit/primary_button.dart';
import '../../ui/theme/app_theme.dart';
import '../pets/forms/form_fields.dart';

class FirstRunCard extends StatefulWidget {
  const FirstRunCard({
    super.key,
    required this.services,
    required this.onDone,
  });

  final AppServices services;
  final VoidCallback onDone;

  @override
  State<FirstRunCard> createState() => _FirstRunCardState();
}

class _FirstRunCardState extends State<FirstRunCard> {
  final TextEditingController _owner = TextEditingController();
  final TextEditingController _pet = TextEditingController();
  String _species = 'Dog';
  final TextEditingController _weight = TextEditingController(text: '5');
  late DateTime _birthday = widget.services.today().subtract(
    const Duration(days: 365),
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _owner.dispose();
    _pet.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    // The same rules the Profile and pet forms use: no field is trusted just
    // because it is the first screen the user sees.
    final double? weight = parseWeightInput(_weight.text);
    final String? weightError = weight == null
        ? 'Weight should be between 0 and ${kMaxWeightKg.toInt()} kg, '
              'with up to 2 decimals.'
        : null;

    final OwnerValidationResult ownerCheck = validateOwnerDraft(
      OwnerDraft(name: _owner.text),
    );
    final String? nameError = ownerCheck[OwnerField.name];

    final PetValidationResult petCheck = validatePetDraft(
      PetDraft(
        name: _pet.text,
        species: _species,
        sex: PetSex.unknown,
        dateOfBirth: _birthday,
        weightKg: weight ?? 1,
      ),
      today: widget.services.today(),
    );
    // The weight is reported once, with its own message.
    final String? petError =
        petCheck[PetField.name] ?? petCheck[PetField.species];

    final String? error = nameError ?? petError ?? weightError;
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Keep whatever contact details the household already had: the welcome
      // card only asks for a name.
      final Owner current = await widget.services.owners.load();
      await widget.services.owners.save(
        OwnerDraft(
          name: _owner.text.trim(),
          email: current.email,
          phone: current.phone,
        ),
      );
      await widget.services.pets.create(
        PetDraft(
          name: _pet.text.trim(),
          species: _species.trim(),
          sex: PetSex.unknown,
          dateOfBirth: _birthday,
          weightKg: weight!,
        ),
      );
      widget.onDone();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = 'Could not save that. Please try again.';
      });
    }
  }

  Future<void> _useSampleHousehold() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.services.setSampleDataEnabled(true);
      widget.onDone();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = 'Could not load the sample household. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const ValueKey<String>('first-run-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('Welcome', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your household\'s notebook. Start with your name and one pet — '
            'everything else can wait.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            key: const ValueKey<String>('first-run-owner'),
            controller: _owner,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Your name'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey<String>('first-run-pet'),
            controller: _pet,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Pet\'s name'),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const ValueKey<String>('first-run-species'),
                  isExpanded: true,
                  initialValue: _species,
                  decoration: const InputDecoration(labelText: 'Species'),
                  items: <DropdownMenuItem<String>>[
                    for (final String species in kCommonSpecies)
                      DropdownMenuItem<String>(
                        value: species,
                        child: Text(species),
                      ),
                  ],
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() => _species = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 110,
                child: TextField(
                  key: const ValueKey<String>('first-run-weight'),
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'kg'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FormDateField(
            key: const ValueKey<String>('first-run-birthday'),
            label: 'Date of birth · approximate is fine',
            value: _birthday,
            firstDate: DateTime(2000),
            lastDate: widget.services.today(),
            onChanged: (DateTime picked) => setState(() => _birthday = picked),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: AppTextStyles.caption.copyWith(color: AppColors.overdue),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            key: const ValueKey<String>('first-run-create'),
            label: _saving ? 'Setting up…' : 'Create my household',
            onPressed: _saving ? null : _create,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            key: const ValueKey<String>('first-run-sample'),
            onPressed: _saving ? null : _useSampleHousehold,
            child: const Text('Or start with the sample household'),
          ),
        ],
      ),
    );
  }
}
