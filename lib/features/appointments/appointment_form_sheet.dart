/// The booking form: pick a pet, a clinic, a purpose and a date/time.
///
/// The Appointments screen lists visits; this sheet is the one place a new one
/// is created. It is opened by the shell's centre action.
library;

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../domain/models/appointment.dart';
import '../../domain/models/pet.dart';
import '../../ui/format/app_formats.dart';
import '../../ui/kit/app_sheet.dart';
import '../../ui/kit/primary_button.dart';
import '../../ui/kit/section_label.dart';
import '../../ui/theme/app_theme.dart';
import '../pets/forms/form_fields.dart';

/// Opens the booking sheet. Resolves true when the appointment was saved.
Future<bool?> showAppointmentBookingSheet(
  BuildContext context, {
  required AppServices services,
  int? initialPetId,
}) {
  return showAppSheet<bool>(
    context,
    (BuildContext _) =>
        AppointmentBookingSheet(services: services, initialPetId: initialPetId),
  );
}

class AppointmentBookingSheet extends StatefulWidget {
  const AppointmentBookingSheet({
    super.key,
    required this.services,
    this.initialPetId,
  });

  final AppServices services;
  final int? initialPetId;

  @override
  State<AppointmentBookingSheet> createState() =>
      _AppointmentBookingSheetState();
}

class _AppointmentBookingSheetState extends State<AppointmentBookingSheet> {
  final TextEditingController _clinic = TextEditingController();
  final TextEditingController _purpose = TextEditingController();

  List<Pet> _pets = const <Pet>[];
  Pet? _pet;
  late DateTime _date;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 30);
  bool _loadingPets = true;
  bool _saving = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _date = calendarDate(widget.services.now().toLocal())
        .add(const Duration(days: 1));
    _loadPets();
  }

  @override
  void dispose() {
    _clinic.dispose();
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _loadPets() async {
    try {
      final List<Pet> pets = await widget.services.pets.list();
      if (!mounted) {
        return;
      }
      setState(() {
        _pets = pets;
        _loadingPets = false;
        _pet = pets.isEmpty
            ? null
            : pets.firstWhere(
                (Pet pet) => pet.id == widget.initialPetId,
                orElse: () => pets.first,
              );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingPets = false;
        _formError = 'Could not load the pets.';
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime today = calendarDate(widget.services.now().toLocal());
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: DateTime(today.year + 3, today.month, today.day),
      helpText: 'Visit date',
    );
    if (picked != null && mounted) {
      setState(() => _date = calendarDate(picked));
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null && mounted) {
      setState(() => _time = picked);
    }
  }

  Future<void> _save() async {
    final Pet? pet = _pet;
    if (pet == null) {
      setState(() => _formError = 'Add a pet before booking a visit.');
      return;
    }
    final String clinic = _clinic.text.trim();
    if (clinic.isEmpty) {
      setState(() => _formError = 'Add the clinic name.');
      return;
    }
    final String purpose = _purpose.text.trim();
    if (purpose.isEmpty) {
      setState(() => _formError = 'Add the reason for the visit.');
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      await widget.services.appointments.create(
        AppointmentDraft(
          petId: pet.id,
          clinicName: clinic,
          purpose: purpose,
          scheduledAt: DateTime(
            _date.year,
            _date.month,
            _date.day,
            _time.hour,
            _time.minute,
          ),
        ),
      );
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
        _formError = "Couldn't book this visit. Check the details and retry.";
      });
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
              'Book a vet visit',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Pet'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Pet>(
                  key: const ValueKey<String>('appointment-form-pet'),
                  value: _pet,
                  isDense: true,
                  isExpanded: true,
                  hint: Text(_loadingPets ? 'Loading pets…' : 'Choose a pet'),
                  items: _pets
                      .map(
                        (Pet pet) => DropdownMenuItem<Pet>(
                          value: pet,
                          child: Text(pet.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _pets.isEmpty
                      ? null
                      : (Pet? pet) => setState(() {
                          _pet = pet;
                          _formError = null;
                        }),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('appointment-form-clinic'),
              controller: _clinic,
              textCapitalization: TextCapitalization.words,
              onChanged: (String _) => setState(() => _formError = null),
              decoration: const InputDecoration(
                labelText: 'Clinic',
                hintText: 'e.g. Paws & Claws Veterinary Clinic',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('appointment-form-purpose'),
              controller: _purpose,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (String _) => setState(() => _formError = null),
              decoration: const InputDecoration(
                labelText: 'Purpose',
                hintText: 'e.g. Annual wellness check',
              ),
            ),
            const SectionLabel(
              'When',
              padding: EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.sm),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey<String>('appointment-form-date'),
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(formatFullDate(_date)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey<String>('appointment-form-time'),
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(
                      formatTimeOfDay(
                        DateTime(2000, 1, 1, _time.hour, _time.minute),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_pets.isEmpty && !_loadingPets) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Add a pet from Profile before booking a visit.',
                style: AppTextStyles.caption.copyWith(color: AppColors.overdue),
              ),
            ],
            if (_formError != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                _formError!,
                style: AppTextStyles.body.copyWith(color: AppColors.overdue),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              key: const ValueKey<String>('appointment-form-save'),
              label: 'Book visit',
              onPressed: _saving || _pets.isEmpty ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
