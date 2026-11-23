/// A tiny pet chooser used by the shell's centre action before it opens a form
/// that needs one pet (journal entry, health record, vaccination).
library;

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../domain/models/pet.dart';
import '../../domain/rules/calendar.dart';
import '../../ui/kit/app_sheet.dart';
import '../../ui/kit/empty_state.dart';
import '../../ui/kit/list_row.dart';
import '../../ui/kit/primary_button.dart';
import '../../ui/theme/app_theme.dart';
import 'pet_photo.dart';

/// Opens a sheet listing the household pets. Resolves to the chosen pet, or
/// null when dismissed.
Future<Pet?> showPetChooserSheet(
  BuildContext context, {
  required AppServices services,
  required String title,
  String? message,
}) {
  return showAppSheet<Pet>(
    context,
    (BuildContext _) =>
        PetChooserSheet(services: services, title: title, message: message),
  );
}

class PetChooserSheet extends StatefulWidget {
  const PetChooserSheet({
    super.key,
    required this.services,
    required this.title,
    this.message,
  });

  final AppServices services;
  final String title;
  final String? message;

  @override
  State<PetChooserSheet> createState() => _PetChooserSheetState();
}

class _PetChooserSheetState extends State<PetChooserSheet> {
  List<Pet> _pets = const <Pet>[];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final List<Pet> pets = await widget.services.pets.list();
      if (!mounted) {
        return;
      }
      setState(() {
        _pets = pets;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      // Say what happened: an empty list and a failed load look identical.
      setState(() {
        _loading = false;
        _error = 'Could not load your pets.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          if (widget.message != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(widget.message!, style: AppTextStyles.caption),
          ],
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text('Loading the pets…', style: AppTextStyles.caption),
            )
          else if (_error != null)
            EmptyState(
              key: const ValueKey<String>('pet-chooser-error'),
              icon: Icons.cloud_off_outlined,
              title: 'Could not load your pets',
              message: _error!,
              action: SecondaryButton(label: 'Try again', onPressed: _load),
            )
          else if (_pets.isEmpty)
            const EmptyState(
              key: ValueKey<String>('pet-chooser-empty'),
              icon: Icons.pets_outlined,
              title: 'No pets yet',
              message: 'Add a pet from Profile first.',
            )
          else
            for (int index = 0; index < _pets.length; index++)
              ListRow(
                key: ValueKey<String>('pet-chooser-row-${_pets[index].id}'),
                title: _pets[index].name,
                subtitle:
                    '${_pets[index].speciesLabel} · '
                    '${ageLabel(_pets[index].dateOfBirth, widget.services.today())}',
                leading: PetAvatar(
                  photoPath: _pets[index].photoPath,
                  petName: _pets[index].name,
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.secondary,
                ),
                showDivider: index < _pets.length - 1,
                onTap: () => Navigator.of(context).pop(_pets[index]),
              ),
        ],
      ),
    );
  }
}
