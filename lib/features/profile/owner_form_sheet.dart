/// Edit the household owner shown on Profile. One owner, no accounts.
library;

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../domain/models/owner.dart';
import '../../domain/rules/owner_validation.dart';
import '../../ui/kit/app_sheet.dart';
import '../../ui/kit/primary_button.dart';
import '../../ui/theme/app_theme.dart';

/// Opens the owner form as a modal sheet. Resolves true when saved.
Future<bool?> showOwnerForm(
  BuildContext context, {
  required AppServices services,
  required Owner owner,
}) {
  return showAppSheet<bool>(
    context,
    (BuildContext sheetContext) =>
        OwnerFormSheet(services: services, owner: owner),
  );
}

class OwnerFormSheet extends StatefulWidget {
  const OwnerFormSheet({
    super.key,
    required this.services,
    required this.owner,
  });

  final AppServices services;
  final Owner owner;

  @override
  State<OwnerFormSheet> createState() => _OwnerFormSheetState();
}

class _OwnerFormSheetState extends State<OwnerFormSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();

  bool _saving = false;
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _name.text = widget.owner.name;
    _email.text = widget.owner.email;
    _phone.text = widget.owner.phone;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final OwnerDraft draft = OwnerDraft(
      name: _name.text,
      email: _email.text,
      phone: _phone.text,
    );
    final OwnerValidationResult validation = validateOwnerDraft(draft);
    setState(() {
      _nameError = validation[OwnerField.name];
      _emailError = validation[OwnerField.email];
      _phoneError = validation[OwnerField.phone];
    });
    if (!validation.isValid) {
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.services.owners.save(
        OwnerDraft(
          name: draft.name.trim(),
          email: draft.email.trim(),
          phone: draft.phone.trim(),
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
        _saveError = 'Could not save the profile. Try again.';
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
              'Edit your details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const ValueKey<String>('owner-form-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              onChanged: (String value) => setState(() => _nameError = null),
              decoration: InputDecoration(
                labelText: 'Name',
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('owner-form-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              onChanged: (String value) => setState(() => _emailError = null),
              decoration: InputDecoration(
                labelText: 'Email',
                errorText: _emailError,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('owner-form-phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              onChanged: (String value) => setState(() => _phoneError = null),
              decoration: InputDecoration(
                labelText: 'Phone',
                errorText: _phoneError,
              ),
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
              key: const ValueKey<String>('owner-form-save'),
              label: 'Save details',
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
