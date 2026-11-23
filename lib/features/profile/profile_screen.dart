/// The Profile destination: the household owner, the pets list, and the three
/// behaviour settings (due-soon window, weight unit, sample data).
library;

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/shell/app_shell.dart';
import '../../app/app_services.dart';
import '../../app/app_settings.dart';
import '../../domain/models/owner.dart';
import '../../domain/models/pet.dart';
import '../../domain/rules/calendar.dart';
import '../../ui/kit/app_card.dart';
import '../../ui/kit/app_chip.dart';
import '../../ui/kit/app_sheet.dart';
import '../../ui/kit/empty_state.dart';
import '../../ui/kit/list_row.dart';
import '../../ui/kit/primary_button.dart';
import '../../ui/kit/section_label.dart';
import '../../ui/theme/app_theme.dart';
import '../pets/forms/pet_form_sheet.dart';
import '../pets/pet_photo.dart';
import '../pets/pet_routes.dart';
import 'owner_form_sheet.dart';
import 'profile_controller.dart';

/// The app version shown in the Profile footer. Mirrors `pubspec.yaml`; the
/// project has no package-info dependency (offline, no plugins), so this is the
/// one place to bump it when the pubspec version changes.
const String kProfileAppVersion = '1.0.0';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final AppServices _services;
  late final ProfileController _controller;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    // `AppScope.of` cannot run in initState; this is the first safe lookup.
    _services = AppScope.of(context);
    _controller = ProfileController(services: _services)..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _editOwner(Owner owner) async {
    final bool? saved = await showOwnerForm(
      context,
      services: _services,
      owner: owner,
    );
    if ((saved ?? false) && mounted) {
      await _controller.load();
    }
  }

  Future<void> _addPet() async {
    final bool? saved = await showPetForm(context, services: _services);
    if ((saved ?? false) && mounted) {
      await _controller.load();
    }
  }

  Future<void> _setSampleData(bool enabled) async {
    await _controller.setSampleDataEnabled(enabled);
  }

  Future<void> _pickDueSoonWindow() async {
    final int? picked = await _showChoiceSheet<int>(
      context,
      title: 'Due-soon window',
      message: 'Vaccinations due within this many days read as due soon.',
      selected: _controller.settings.dueSoonWindowDays,
      options: const <_ChoiceOption<int>>[
        _ChoiceOption<int>(7, '7 days'),
        _ChoiceOption<int>(14, '14 days'),
        _ChoiceOption<int>(30, '30 days'),
        _ChoiceOption<int>(60, '60 days'),
        _ChoiceOption<int>(90, '90 days'),
      ],
    );
    if (picked != null && mounted) {
      await _controller.setDueSoonWindowDays(picked);
    }
  }

  Future<void> _pickWeightUnit() async {
    final WeightUnit? picked = await _showChoiceSheet<WeightUnit>(
      context,
      title: 'Weight unit',
      selected: _controller.settings.weightUnit,
      options: const <_ChoiceOption<WeightUnit>>[
        _ChoiceOption<WeightUnit>(WeightUnit.kg, 'Kilograms (kg)'),
        _ChoiceOption<WeightUnit>(WeightUnit.lb, 'Pounds (lb)'),
      ],
    );
    if (picked != null && mounted) {
      await _controller.setWeightUnit(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (BuildContext context, Widget? child) {
            final Owner? owner = _controller.owner;
            if (_controller.isLoading && owner == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (owner == null) {
              return EmptyState(
                icon: Icons.person_outline,
                title: 'Could not load your profile',
                message: _controller.loadError == null
                    ? 'The household record is missing.'
                    : 'Something went wrong reading the household record.',
                action: SecondaryButton(
                  label: 'Try again',
                  onPressed: _controller.load,
                ),
              );
            }
            return _content(owner);
          },
        ),
      ),
    );
  }

  Widget _content(Owner owner) {
    final List<Pet> pets = _controller.pets;
    final AppSettings settings = _controller.settings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        kShellContentBottomPadding,
      ),
      children: <Widget>[
        Text('Profile', style: AppTextStyles.display),
        const SizedBox(height: AppSpacing.xl),
        _OwnerBlock(owner: owner, onEdit: () => _editOwner(owner)),
        const SizedBox(height: AppSpacing.md),
        const Divider(height: 1),
        Column(
          key: const ValueKey<String>('profile-pets-section'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SectionLabel(
              'My pets',
              trailing: Text(
                '${pets.length}',
                style: AppTextStyles.sectionLabel,
              ),
            ),
            if (pets.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'No pets yet — add the first one.',
                  key: ValueKey<String>('profile-empty-pets'),
                  style: AppTextStyles.caption,
                ),
              )
            else
              for (final Pet pet in pets) ...<Widget>[
                _PetRow(
                  key: ValueKey<String>('profile-pet-row-${pet.id}'),
                  pet: pet,
                  ageLabel: ageLabel(pet.dateOfBirth, _controller.today()),
                  onTap: () => PetRoutes.open(context, pet.id),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            _AddPetRow(onTap: _addPet),
          ],
        ),
        const SectionLabel('Settings'),
        Column(
          key: const ValueKey<String>('settings-section'),
          children: <Widget>[
            ListRow(
              key: const ValueKey<String>('setting-due-window'),
              title: 'Due-soon window',
              onTap: _pickDueSoonWindow,
              trailing: Text(
                '${settings.dueSoonWindowDays} days',
                style: AppTextStyles.caption,
              ),
            ),
            ListRow(
              key: const ValueKey<String>('setting-weight-unit'),
              title: 'Weight unit',
              onTap: _pickWeightUnit,
              trailing: Text(
                settings.weightUnit.wire,
                style: AppTextStyles.caption,
              ),
            ),
            ListRow(
              key: const ValueKey<String>('setting-sample-data'),
              title: 'Sample data',
              trailing: Switch(
                key: const ValueKey<String>('setting-sample-data-switch'),
                value: settings.sampleDataEnabled,
                onChanged: _setSampleData,
              ),
            ),
            ListRow(
              key: const ValueKey<String>('setting-reset-household'),
              title: 'Reset household',
              subtitle: 'Deletes every pet, record and visit',
              showDivider: false,
              trailing: Text(
                'Reset',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.overdue,
                ),
              ),
              onTap: _resetHousehold,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          _versionLine(pets.length, _controller.recordCount),
          key: const ValueKey<String>('profile-version'),
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  /// Destructive, so it asks first. After a reset the household is empty and
  /// Home shows the Welcome card again.
  Future<void> _resetHousehold() async {
    bool forgetOwner = false;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setLocal) => AlertDialog(
          title: const Text('Reset household?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Every pet, journal entry, vaccination, clinical note and '
                'visit will be deleted.',
              ),
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                key: const ValueKey<String>('reset-forget-owner'),
                value: forgetOwner,
                onChanged: (bool? value) =>
                    setLocal(() => forgetOwner = value ?? false),
                title: const Text('Also forget my name and details'),
                subtitle: const Text('For a genuine first-run'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const ValueKey<String>('reset-household-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Delete everything',
                style: TextStyle(color: AppColors.overdue),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _controller.resetHousehold(forgetOwner: forgetOwner);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Household reset.')),
    );
  }

  static String _versionLine(int pets, int records) {
    return 'Version $kProfileAppVersion · '
        '${_plural(pets, 'pet', 'pets')} · '
        '${_plural(records, 'record', 'records')}';
  }

  static String _plural(int count, String one, String many) =>
      '$count ${count == 1 ? one : many}';
}

class _OwnerBlock extends StatelessWidget {
  const _OwnerBlock({required this.owner, required this.onEdit});

  final Owner owner;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final String email = owner.email.trim();
    final String phone = owner.phone.trim();
    return Row(
      children: <Widget>[
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.alphaBlend(
              AppColors.accent.withValues(alpha: 0.12),
              AppColors.surface,
            ),
          ),
          child: Text(
            owner.initial,
            key: const ValueKey<String>('profile-owner-initial'),
            style: AppTextStyles.display.copyWith(
              fontSize: 26,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                owner.name,
                key: const ValueKey<String>('profile-owner-name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                email.isEmpty ? 'Add an email' : email,
                key: const ValueKey<String>('profile-owner-email'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
              Text(
                phone.isEmpty ? 'Add a phone number' : phone,
                key: const ValueKey<String>('profile-owner-phone'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          height: 44,
          child: AppChip(
            key: const ValueKey<String>('profile-edit-owner'),
            label: 'Edit',
            onTap: onEdit,
          ),
        ),
      ],
    );
  }
}

class _PetRow extends StatelessWidget {
  const _PetRow({
    super.key,
    required this.pet,
    required this.ageLabel,
    required this.onTap,
  });

  final Pet pet;
  final String ageLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          PetAvatar(photoPath: pet.photoPath, petName: pet.name),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  pet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${pet.speciesLabel} · $ageLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.secondary),
        ],
      ),
    );
  }
}

class _AddPetRow extends StatelessWidget {
  const _AddPetRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const ValueKey<String>('profile-add-pet'),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.alphaBlend(
                AppColors.accent.withValues(alpha: 0.12),
                AppColors.surface,
              ),
            ),
            child: const Icon(Icons.add, size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'Add a pet',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceOption<T> {
  const _ChoiceOption(this.value, this.label);

  final T value;
  final String label;
}

Future<T?> _showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  String? message,
  required List<_ChoiceOption<T>> options,
  required T selected,
}) {
  return showAppSheet<T>(
    context,
    (BuildContext sheetContext) => AppSheetBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
          if (message != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(message, style: AppTextStyles.caption),
          ],
          const SizedBox(height: AppSpacing.sm),
          for (int index = 0; index < options.length; index++)
            ListRow(
              key: ValueKey<String>('choice-${options[index].label}'),
              title: options[index].label,
              showDivider: index != options.length - 1,
              onTap: () => Navigator.of(sheetContext).pop(options[index].value),
              trailing: options[index].value == selected
                  ? const Icon(Icons.check, size: 18, color: AppColors.accent)
                  : null,
            ),
        ],
      ),
    ),
  );
}
