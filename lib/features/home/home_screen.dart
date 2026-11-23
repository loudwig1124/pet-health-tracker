/// Home: the household at a glance — pet cards, instant logging and the next
/// visit.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_scope.dart';
import '../../app/navigation_requests.dart';
import '../../app/shell/app_shell.dart';
import '../../app/app_services.dart';
import '../../app/router.dart';
import '../../domain/dashboard.dart';
import '../../domain/models/appointment.dart';
import '../../domain/models/journal_entry.dart';
import '../appointments/appointment_actions_sheet.dart';
import '../appointments/appointments_controller.dart';
import '../journal/journal_controller.dart';
import '../journal/journal_entry_sheet.dart';
import '../../domain/models/owner.dart';
import '../../domain/models/pet.dart';
import '../../domain/rules/calendar.dart';
import '../../ui/format/app_formats.dart';
import '../../ui/kit/app_card.dart';
import '../../ui/kit/app_chip.dart';
import '../../ui/kit/empty_state.dart';
import '../onboarding/first_run_card.dart';
import '../pets/forms/pet_form_sheet.dart';
import '../../ui/kit/list_row.dart';
import '../../ui/kit/primary_button.dart';
import '../../ui/kit/section_label.dart';
import '../../ui/theme/app_theme.dart';
import 'home_controller.dart';
import 'widgets/add_pet_card.dart';
import 'widgets/journal_kind_badge.dart';
import 'widgets/next_appointment_card.dart';
import 'widgets/pet_card.dart';
import 'widgets/pet_page_dots.dart';
import 'widgets/quick_log_form_sheet.dart';
import 'widgets/quick_log_row.dart';

/// The card is 264 tall and 310 of the 390 px screen width; the neighbouring
/// cards peek in the remaining 80 px (40 each side).
const double kPetCardHeight = 264;

/// Cards are 310 wide with a 12 px gap; the page includes the gap so the
/// neighbour peeks in without touching the front card.
const double kPetCardGap = 12;
const double kPetCardViewportFraction = (310 + kPetCardGap) / 390;

/// Home destination.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenPet, this.onAddPet});

  /// Optional: opens a pet's page. The integrator wires this to the pet route.
  /// Home reloads when the returned future completes, so a vaccination or pet
  /// edit made on that page shows up on the card.
  final Future<void> Function(Pet)? onOpenPet;

  /// Optional: opens the add-pet form. Defaults to the Profile tab, which owns
  /// the "Add a pet" row.
  final VoidCallback? onAddPet;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController(
    viewportFraction: kPetCardViewportFraction,
  );

  AppServices? _services;
  HomeController? _controller;
  int _pageIndex = 0;
  bool _branchActive = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppServices services = AppScope.of(context);
    // The shell keeps visited branches alive offstage. Reload when Home becomes
    // active again so an owner edit or a new pet from Profile shows up here
    // without a manual pull-to-refresh.
    final bool active = TickerMode.valuesOf(context).enabled;
    if (!identical(services, _services)) {
      _services = services;
      _controller?.dispose();
      final HomeController controller = HomeController(services);
      _controller = controller;
        NavigationRequests.householdRevision.addListener(_onHouseholdWrite);
      _branchActive = active;
      if (active) {
        controller.load();
      }
      return;
    }
    if (active && !_branchActive) {
      _controller!.load();
    }
    _branchActive = active;
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
    _pageController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Pet? _activePet() {
    final List<PetOverview> pets =
        _controller?.dashboard?.pets ?? const <PetOverview>[];
    if (pets.isEmpty) {
      return null;
    }
    final int page = _pageIndex.clamp(0, pets.length);
    return page < pets.length ? pets[page].pet : null;
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  /// Switches to Profile through the shell so it gets the same fade as the bar.
  void _openProfile() {
    final AppShellSelection? shell = AppShellSelection.maybeOf(context);
    if (shell != null) {
      shell.select(AppShellSelection.profile);
      return;
    }
    _goTo(Routes.profile);
  }

  /// Opens the same edit sheet the Journal uses, then refreshes this screen.
  Future<void> _editEntry(BuildContext context, JournalEntry entry) async {
    final AppServices services = _services!;
    final JournalController journal = JournalController(services);
    await journal.load();
    if (!context.mounted) {
      journal.dispose();
      return;
    }
    final JournalEntrySheetResult? result = await showJournalEntryEditSheet(
      context,
      entry: entry,
      controller: journal,
    );
    journal.dispose();
    if (result != null) {
      await _controller!.load();
    }
  }

  void _goTo(String location) {
    GoRouter.maybeOf(context)?.go(location);
  }

  Future<void> _openPet(Pet pet) async {
    final Future<void> Function(Pet)? handler = widget.onOpenPet;
    if (handler == null) {
      return;
    }
    await handler(pet);
    if (!mounted) {
      return;
    }
    // The pet page can add a vaccination or edit the pet; refresh on return.
    await _controller?.refresh();
  }

  Future<void> _openAddPet() async {
    final VoidCallback? handler = widget.onAddPet;
    if (handler != null) {
      handler();
      return;
    }
    // Stay on Home and open the form over it, instead of sending the user to
    // Profile to add a pet.
    final bool? saved = await showPetForm(context, services: _services!);
    if (saved == true) {
      await _controller!.load();
    }
  }

  /// Opens the appointment's actions sheet over Home. The sheet's "View in
  /// Appointments" hands off to the tab, filtered to that pet.
  Future<void> _appointmentActions(Appointment appointment) async {
    final AppointmentsController controller = AppointmentsController(
      _services!,
    );
    await controller.load();
    if (!mounted) {
      controller.dispose();
      return;
    }
    final AppointmentActionResult? result = await showAppointmentActionsSheet(
      context,
      appointment: appointment,
      controller: controller,
      showViewInSection: true,
    );
    controller.dispose();
    if (result == null) {
      return;
    }
    if (result.viewInSection) {
      _openAppointments(petId: appointment.petId);
      return;
    }
    await _controller!.load();
    if (mounted && result.message.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  /// Switches to Appointments through the shell (so it fades) and asks it to
  /// focus one pet.
  void _openAppointments({int? petId}) {
    NavigationRequests.appointmentsPetFilter.value = petId;
    final AppShellSelection? shell = AppShellSelection.maybeOf(context);
    if (shell != null) {
      shell.select(AppShellSelection.appointments);
      return;
    }
    _goTo(Routes.appointments);
  }

  Future<void> _quickLog(JournalKind kind) async {
    final Pet? pet = _activePet();
    if (pet == null) {
      return;
    }
    try {
      final JournalEntry entry = await _controller!.quickLog(
        pet: pet,
        kind: kind,
      );
      if (!mounted) {
        return;
      }
      _showUndo(entry);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage("Couldn't save that entry.");
    }
  }

  Future<void> _openForm(JournalKind kind) async {
    final Pet? pet = _activePet();
    if (pet == null) {
      return;
    }
    final JournalEntry? entry = await showQuickLogForm(
      context,
      pet: pet,
      kind: kind,
      initialWhen: _services!.now().toLocal(),
      onSave: _controller!.createEntry,
    );
    if (!mounted || entry == null) {
      return;
    }
    _showUndo(entry);
  }

  Future<void> _undo(JournalEntry entry) async {
    try {
      await _controller!.undo(entry);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage("Couldn't undo that entry.");
    }
  }

  void _showUndo(JournalEntry entry) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${entry.kind.label} logged'),
        // Material's default is `persist = action != null`, so an undo
        // snackbar would stay until dismissed. It should time out like any
        // other confirmation.
        persist: false,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: 'Undo', onPressed: () => _undo(entry)),
      ),
    );
  }

  void _showMessage(String message) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final HomeController controller = _controller!;
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: controller,
          builder: (BuildContext context, Widget? child) {
            final Dashboard? dashboard = controller.dashboard;
            if (dashboard == null) {
              return _HomeStatus(controller: controller);
            }
            return RefreshIndicator(
              onRefresh: controller.refresh,
              color: AppColors.accent,
              backgroundColor: AppColors.surface,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(
                  bottom: kShellContentBottomPadding,
                ),
                children: _bodyChildren(dashboard),
              ),
            );
          },
        ),
      ),
    );
  }

  /// "Rabies · 6 days overdue" — names the dose, which is the point of the chip.
  String? _dueLabelFor(PetOverview overview) {
    final DateTime? due = overview.nextVaccination?.nextDueDate;
    if (due == null) {
      return null;
    }
    final String name = overview.nextVaccination!.vaccineName;
    final int days = dateOnly(due).difference(_services!.today()).inDays;
    if (days < 0) {
      return '$name · ${-days} days overdue';
    }
    if (days == 0) {
      return '$name · due today';
    }
    if (days == 1) {
      return '$name · due tomorrow';
    }
    return '$name · in $days days';
  }

  List<Widget> _bodyChildren(Dashboard dashboard) {
    final List<PetOverview> pets = dashboard.pets;
    final Map<int, String> petNames = <int, String>{
      for (final PetOverview overview in pets)
        overview.pet.id: overview.pet.name,
    };
    final int petPage = pets.isEmpty ? 0 : _pageIndex.clamp(0, pets.length);
    final Pet? activePet = petPage < pets.length ? pets[petPage].pet : null;
    final List<Appointment> upcoming = dashboard.nextAppointments;
    final DateTime now = _controller!.localNow;

    return <Widget>[
      // "Good afternoon" is a greeting for a household that exists. With no pets
      // there is nothing to greet yet — the Welcome card speaks for itself.
      if (pets.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: _GreetingRow(
            owner: dashboard.owner,
            now: now,
            onOpenProfile: _openProfile,
          ),
        ),
      if (pets.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            0,
          ),
          child: FirstRunCard(
            services: _services!,
            onDone: () => _controller!.load(),
          ),
        )
      else ...<Widget>[
        SizedBox(
          height: kPetCardHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: pets.length + 1,
            onPageChanged: (int index) => setState(() => _pageIndex = index),
            itemBuilder: (BuildContext context, int index) {
              if (index >= pets.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kPetCardGap / 2,
                  ),
                  child: AddPetCard(
                    key: const ValueKey<String>('add-pet-card'),
                    onTap: _openAddPet,
                  ),
                );
              }
              final PetOverview overview = pets[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kPetCardGap / 2,
                ),
                child: PetCard(
                  key: ValueKey<String>('pet-card-${overview.pet.id}'),
                  overview: overview,
                  ageLabel: ageLabel(
                    overview.pet.dateOfBirth,
                    _services!.today(),
                  ),
                  weightLabel: _services!.settings.formatWeight(
                    overview.pet.weightKg,
                  ),
                  dueLabel: _dueLabelFor(overview),
                  onTap: widget.onOpenPet == null
                      ? null
                      : () => _openPet(overview.pet),
                ),
              );
            },
          ),
        ),
        if (pets.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: PetPageDots(
              petCount: pets.length,
              currentIndex: petPage,
              onSelected: _goToPage,
            ),
          ),
        if (activePet != null) ...<Widget>[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: SectionLabel('Log something'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: QuickLogRow(onQuickLog: _quickLog, onOpenForm: _openForm),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            0,
          ),
          child: upcoming.isEmpty
              ? _NoUpcomingVisit(onTap: () => _openAppointments())
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (int i = 0; i < upcoming.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          top: i == 0 ? 0 : AppSpacing.sm,
                        ),
                        child: NextAppointmentCard(
                          key: i == 0
                              ? const ValueKey<String>('next-appointment')
                              : ValueKey<String>(
                                  'next-appointment-${upcoming[i].id}',
                                ),
                          appointment: upcoming[i],
                          petName: upcoming[i].petId == null
                              ? null
                              : petNames[upcoming[i].petId],
                          onTap: () => _appointmentActions(upcoming[i]),
                        ),
                      ),
                  ],
                ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: SectionLabel('Recent'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: _RecentEntries(
            entries: dashboard.recentEntries,
            petNames: petNames,
            now: now,
            onTapEntry: (JournalEntry entry) => _editEntry(context, entry),
          ),
        ),
      ],
    ];
  }
}

/// Greeting + the owner's initial avatar.
class _GreetingRow extends StatelessWidget {
  const _GreetingRow({
    required this.owner,
    required this.now,
    this.onOpenProfile,
  });

  final Owner owner;
  final DateTime now;
  final VoidCallback? onOpenProfile;

  /// First name only: the greeting is a headline, and a full legal name
  /// ellipsizes on a phone.
  String get _greeting {
    final String part = now.hour < 12
        ? 'Good morning'
        : (now.hour < 18 ? 'Good afternoon' : 'Good evening');
    final String trimmed = owner.name.trim();
    // The placeholder is not a person's name, so it does not belong in a
    // greeting: "Good afternoon, My" would read like a bug.
    if (trimmed.isEmpty || trimmed == kDefaultOwnerName) {
      return part;
    }
    return '$part, ${trimmed.split(RegExp(r'\s+')).first}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text('Your pets', style: AppTextStyles.caption),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Semantics(
          button: onOpenProfile != null,
          label: 'Owner ${owner.name}',
          child: InkWell(
            key: const ValueKey<String>('home-owner-avatar'),
            onTap: onOpenProfile,
            // A 56 px touch disc around a 44 px avatar: the press highlight
            // fills the disc, so it reads as a halo wider than the circle.
            radius: 28,
            customBorder: const CircleBorder(),
            highlightColor: AppColors.accent.withValues(alpha: 0.14),
            splashColor: AppColors.accent.withValues(alpha: 0.10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: statusBackground(AppColors.accent, AppColors.paper),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    owner.initial,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: AppColors.accent),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The two most recent household entries, newest first.
class _RecentEntries extends StatelessWidget {
  const _RecentEntries({
    required this.entries,
    required this.petNames,
    required this.now,
    required this.onTapEntry,
  });

  final List<JournalEntry> entries;
  final Map<int, String> petNames;
  final DateTime now;
  final ValueChanged<JournalEntry> onTapEntry;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.md,
        ),
        child: Text('Nothing logged yet.', style: AppTextStyles.caption),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < entries.length; i++)
          ListRow(
            key: ValueKey<String>('recent-entry-${entries[i].id}'),
            leading: JournalKindBadge(kind: entries[i].kind),
            title: entries[i].title,
            subtitle: petNames[entries[i].petId],
            trailing: Text(
              '${formatRelativeDay(entries[i].occurredAt.toLocal(), now)}, '
              '${formatTimeOfDay(entries[i].occurredAt)}',
              style: AppTextStyles.caption,
            ),
            showDivider: i < entries.length - 1,
            horizontalInset: AppSpacing.md,
            onTap: () => onTapEntry(entries[i]),
          ),
      ],
    );
  }
}

/// Quiet stand-in when nothing is booked.
class _NoUpcomingVisit extends StatelessWidget {
  const _NoUpcomingVisit({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: statusBackground(AppColors.accent, AppColors.surface),
              borderRadius: AppRadii.chipRadius,
            ),
            child: const Icon(
              Icons.event_available_outlined,
              size: 24,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'No upcoming visits',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Book one from the centre button.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.secondary),
        ],
      ),
    );
  }
}

/// Load-in-progress and failure states; both keep the screen chrome-free.
class _HomeStatus extends StatelessWidget {
  const _HomeStatus({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final String? error = controller.loadError;
    if (error == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Text('Loading the household…', style: AppTextStyles.caption),
      );
    }
    return EmptyState(
      icon: Icons.pets_outlined,
      title: 'Home could not load',
      message: error,
      action: PrimaryButton(label: 'Try again', onPressed: controller.refresh),
    );
  }
}
