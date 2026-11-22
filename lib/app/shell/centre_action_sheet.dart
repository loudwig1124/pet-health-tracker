/// The sheet opened by the raised centre action: the household's three
/// create flows.
///
/// Every row closes this sheet and opens the real form, so the shell never
/// owns form state. Booking lands on Appointments; logging lands on Journal.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/journal_entry.dart';
import '../../domain/models/pet.dart';
import '../../features/appointments/appointment_form_sheet.dart';
import '../../features/home/widgets/quick_log_form_sheet.dart';
import '../../features/pets/forms/health_record_form_sheet.dart';
import '../../features/pets/pet_chooser_sheet.dart';
import '../../ui/kit/app_sheet.dart';
import '../../ui/kit/list_row.dart';
import '../../ui/kit/primary_button.dart';
import '../../ui/kit/section_label.dart';
import '../../ui/theme/app_theme.dart';
import '../app_scope.dart';
import '../app_services.dart';
import '../router.dart';

/// One choice from the centre-action sheet.
enum CentreAction { bookVisit, logEntry, healthRecord }

/// Opens the centre-action sheet and runs the chosen flow.
Future<void> showCentreActionSheet(BuildContext context) async {
  final AppServices services = AppScope.of(context);
  final CentreAction? action = await showAppSheet<CentreAction>(
    context,
    (BuildContext _) => const CentreActionSheet(),
  );
  if (action == null || !context.mounted) {
    return;
  }
  switch (action) {
    case CentreAction.bookVisit:
      await _bookVisit(context, services);
    case CentreAction.logEntry:
      await _logEntry(context, services);
    case CentreAction.healthRecord:
      await _addHealthRecord(context, services);
  }
}

Future<void> _bookVisit(BuildContext context, AppServices services) async {
  final bool? saved = await showAppointmentBookingSheet(
    context,
    services: services,
  );
  if (saved != true || !context.mounted) {
    return;
  }
  _showMessage(context, 'Appointment booked.');
  GoRouter.of(context).go(Routes.appointments);
}

Future<void> _logEntry(BuildContext context, AppServices services) async {
  final Pet? pet = await showPetChooserSheet(
    context,
    services: services,
    title: 'Log an entry',
    message: 'Which pet is this for?',
  );
  if (pet == null || !context.mounted) {
    return;
  }
  final JournalEntry? entry = await showQuickLogForm(
    context,
    pet: pet,
    kind: JournalKind.note,
    initialWhen: services.now().toLocal(),
    onSave: services.journal.create,
  );
  if (entry == null || !context.mounted) {
    return;
  }
  _showMessage(context, '${entry.kind.label} logged.');
  GoRouter.of(context).go(Routes.journal);
}

Future<void> _addHealthRecord(
  BuildContext context,
  AppServices services,
) async {
  final Pet? pet = await showPetChooserSheet(
    context,
    services: services,
    title: 'New health record',
    message: 'Which pet is this note for?',
  );
  if (pet == null || !context.mounted) {
    return;
  }
  final bool? saved = await showHealthRecordForm(
    context,
    services: services,
    petId: pet.id,
  );
  if (saved != true || !context.mounted) {
    return;
  }
  _showMessage(context, 'Health record saved for ${pet.name}.');
}

void _showMessage(BuildContext context, String message) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(message)));
}

/// The sheet body: three real create flows, no placeholders.
class CentreActionSheet extends StatelessWidget {
  const CentreActionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    void choose(CentreAction action) =>
        Navigator.of(context).pop<CentreAction>(action);

    return AppSheetBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SectionLabel(
            'Quick actions',
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
          ),
          Text(
            'Log a moment, book a visit or add a health note.',
            style: AppTextStyles.body.copyWith(color: AppColors.secondary),
          ),
          const SizedBox(height: AppSpacing.md),
          ListRow(
            key: const ValueKey<String>('centre-action-book'),
            title: 'Book a vet visit',
            subtitle: 'Pick a pet, a clinic and a time',
            leading: const Icon(Icons.event_outlined, color: AppColors.accent),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.secondary,
            ),
            onTap: () => choose(CentreAction.bookVisit),
          ),
          ListRow(
            key: const ValueKey<String>('centre-action-log'),
            title: 'Log an entry',
            subtitle: 'Walk, feeding, note or symptom',
            leading: const Icon(
              Icons.edit_note_outlined,
              color: AppColors.accent,
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.secondary,
            ),
            onTap: () => choose(CentreAction.logEntry),
          ),
          ListRow(
            key: const ValueKey<String>('centre-action-health'),
            title: 'Add a health record',
            subtitle: 'A clinical note for one pet',
            leading: const Icon(
              Icons.medical_information_outlined,
              color: AppColors.accent,
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.secondary,
            ),
            showDivider: false,
            onTap: () => choose(CentreAction.healthRecord),
          ),
          const SizedBox(height: AppSpacing.lg),
          SecondaryButton(
            label: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
