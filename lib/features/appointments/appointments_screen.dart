/// Appointments destination: Upcoming/Past segmented control, a quiet pet
/// filter and one card per visit with a single status chip.
library;

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/navigation_requests.dart';
import '../../app/shell/app_shell.dart';
import '../../domain/models/appointment.dart';
import '../../domain/models/pet.dart';
import '../../ui/format/app_formats.dart';
import '../../ui/kit/app_card.dart';
import '../../ui/kit/app_chip.dart';
import '../../ui/kit/empty_state.dart';
import '../../ui/kit/primary_button.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/theme/status_style.dart';
import 'appointment_actions_sheet.dart';
import 'appointments_controller.dart';

/// Appointments destination.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  AppointmentsController? _controller;
  bool _branchActive = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload when the shell makes this branch active again: a visit booked
    // from the centre action shows up without a manual pull-to-refresh.
    final bool active = TickerMode.valuesOf(context).enabled;
    if (_controller == null) {
      final AppointmentsController controller = AppointmentsController(
        AppScope.of(context),
      );
      _controller = controller;
        NavigationRequests.householdRevision.addListener(_onHouseholdWrite);
      _branchActive = active;
      if (active) {
        controller.load();
        _applyRequestedFilter();
      }
      return;
    }
    if (active && !_branchActive) {
      _controller!.load();
    }
    _branchActive = active;
    if (active) {
      _applyRequestedFilter();
    }
  }

  /// A tap on Home's appointment card asks for one pet; take it and clear it.
  void _applyRequestedFilter() {
    final PetFilterRequest? pending = NavigationRequests.appointmentsFilter.value;
    if (pending == null) {
      return;
    }
    NavigationRequests.appointmentsFilter.value = null;
    // A null pet id means "this visit is the household's": show everything
    // rather than leaving whatever filter was applied last time.
    _controller?.selectPet(pending.petId);
  }

  /// Another screen wrote something: refresh, but only while this branch is
  /// the visible one — an inactive branch reloads when it becomes active.
  void _onHouseholdWrite() {
    if (!mounted || !TickerMode.valuesOf(context).enabled) {
      return;
    }
    _controller?.load();
  }

  @override
  void dispose() {
    NavigationRequests.householdRevision.removeListener(_onHouseholdWrite);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openActions(
    BuildContext context,
    Appointment appointment,
  ) async {
    final AppointmentActionResult? result = await showAppointmentActionsSheet(
      context,
      appointment: appointment,
      controller: _controller!,
    );
    if (result == null || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    final AppointmentsController controller = _controller!;
    return Scaffold(
      appBar: AppBar(title: const Text('Appointments')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (BuildContext context, Widget? child) => Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: SegmentedButton<AppointmentsTab>(
                  segments: const <ButtonSegment<AppointmentsTab>>[
                    ButtonSegment<AppointmentsTab>(
                      value: AppointmentsTab.upcoming,
                      label: Text(
                        'Upcoming',
                        key: ValueKey<String>('appointments-tab-upcoming'),
                      ),
                    ),
                    ButtonSegment<AppointmentsTab>(
                      value: AppointmentsTab.past,
                      label: Text(
                        'Past',
                        key: ValueKey<String>('appointments-tab-past'),
                      ),
                    ),
                  ],
                  selected: <AppointmentsTab>{controller.tab},
                  onSelectionChanged: (Set<AppointmentsTab> selection) {
                    controller.selectTab(selection.first);
                  },
                  showSelectedIcon: false,
                  expandedInsets: EdgeInsets.zero,
                  style: const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll<Size>(Size(0, 44)),
                  ),
                ),
              ),
              if (controller.pets.isNotEmpty)
                _PetFilterRow(controller: controller),
              Expanded(
                child: _AppointmentsBody(
                  controller: controller,
                  onOpen: (Appointment appointment) =>
                      _openActions(context, appointment),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal "All pets" + one chip per pet. Quiet: chips, not a second bar.
class _PetFilterRow extends StatelessWidget {
  const _PetFilterRow({required this.controller});

  final AppointmentsController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          AppChip(
            key: const ValueKey<String>('appointment-pet-filter-all'),
            label: 'All pets',
            selected: controller.petFilterId == null,
            onTap: () => controller.selectPet(null),
          ),
          for (final Pet pet in controller.pets)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: AppChip(
                key: ValueKey<String>('appointment-pet-filter-${pet.id}'),
                label: pet.name,
                selected: controller.petFilterId == pet.id,
                onTap: () => controller.selectPet(pet.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _AppointmentsBody extends StatelessWidget {
  const _AppointmentsBody({required this.controller, required this.onOpen});

  final AppointmentsController controller;
  final ValueChanged<Appointment> onOpen;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading && controller.appointments.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    final String? error = controller.loadError;
    if (error != null && controller.appointments.isEmpty) {
      return EmptyState(
        key: const ValueKey<String>('appointments-error'),
        icon: Icons.cloud_off_outlined,
        title: 'Could not load appointments',
        message: error,
        action: SecondaryButton(label: 'Try again', onPressed: controller.load),
      );
    }
    if (controller.appointments.isEmpty) {
      final bool upcoming = controller.tab == AppointmentsTab.upcoming;
      return EmptyState(
        key: const ValueKey<String>('appointments-empty'),
        icon: upcoming ? Icons.event_available_outlined : Icons.history,
        title: upcoming ? 'No upcoming visits' : 'No past visits',
        message: upcoming
            ? 'Booked vet visits show up here.'
            : 'Completed and closed visits land here.',
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      color: AppColors.accent,
      child: ListView.separated(
        key: const ValueKey<String>('appointments-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          kShellContentBottomPadding,
        ),
        itemCount: controller.appointments.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (BuildContext context, int index) {
          final Appointment appointment = controller.appointments[index];
          return _AppointmentCard(
            key: ValueKey<String>('appointment-card-${appointment.id}'),
            appointment: appointment,
            petLabel: controller.petLabelFor(appointment.petId),
            onTap: () => onOpen(appointment),
          );
        },
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    super.key,
    required this.appointment,
    required this.petLabel,
    required this.onTap,
  });

  final Appointment appointment;
  final String petLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DateTime local = appointment.scheduledAt.toLocal();
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _DateBlock(appointment: appointment),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  petLabel,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  appointment.clinicName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // A non-breaking space keeps "· 9:30 AM" together, so the
                  // separator never dangles at the end of a wrapped line.
                  '${appointment.purpose} ·\u00A0${formatTimeOfDay(local)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppChip.appointment(appointment.status),
        ],
      ),
    );
  }
}

/// Tinted weekday + day block; its colours come from the status palette.
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final DateTime local = appointment.scheduledAt.toLocal();
    final StatusPalette palette = appointmentStatusPalette(appointment.status);
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: AppRadii.chipRadius,
      ),
      child: Column(
        children: <Widget>[
          Text(
            formatWeekdayShort(local).toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: palette.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatDayOfMonth(local),
            style: Theme.of(context).textTheme.titleLarge!
                .copyWith(color: palette.foreground),
          ),
        ],
      ),
    );
  }
}
