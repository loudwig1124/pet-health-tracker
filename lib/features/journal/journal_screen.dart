/// The household journal feed: newest first, grouped by day, editable rows.
///
/// No quick-log chips here — the centre action owns creating entries. This
/// screen only reads and edits what already exists.
library;

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/navigation_requests.dart';
import '../../app/shell/app_shell.dart';
import '../../domain/models/journal_entry.dart';
import '../../domain/models/pet.dart';
import '../../ui/format/app_formats.dart';
import '../../ui/kit/app_chip.dart';
import '../../ui/kit/empty_state.dart';
import '../../ui/kit/list_row.dart';
import '../../ui/kit/primary_button.dart';
import '../../ui/kit/section_label.dart';
import '../../ui/theme/app_theme.dart';
import 'journal_controller.dart';
import 'journal_day_groups.dart';
import 'journal_entry_sheet.dart';

/// Journal destination.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  JournalController? _controller;
  bool _branchActive = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The shell keeps every visited branch alive in an offstage TickerMode.
    // Reloading when this branch becomes active picks up entries created from
    // the centre action (or another tab) without losing scroll state.
    final bool active = TickerMode.valuesOf(context).enabled;
    if (_controller == null) {
      final JournalController controller = JournalController(
        AppScope.of(context),
      );
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
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openEditor(BuildContext context, JournalEntry entry) async {
    final JournalEntrySheetResult? result = await showJournalEntryEditSheet(
      context,
      entry: entry,
      controller: _controller!,
    );
    if (result == null || !context.mounted) {
      return;
    }
    final String message = result == JournalEntrySheetResult.deleted
        ? 'Entry deleted.'
        : 'Entry updated.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final JournalController controller = _controller!;
    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (BuildContext context, Widget? child) => _JournalBody(
            controller: controller,
            onEdit: (JournalEntry entry) => _openEditor(context, entry),
          ),
        ),
      ),
    );
  }
}

class _JournalBody extends StatelessWidget {
  const _JournalBody({required this.controller, required this.onEdit});

  final JournalController controller;
  final ValueChanged<JournalEntry> onEdit;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading && controller.entries.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    final String? error = controller.loadError;
    if (error != null && controller.entries.isEmpty) {
      return EmptyState(
        key: const ValueKey<String>('journal-error'),
        icon: Icons.cloud_off_outlined,
        title: 'Could not load the journal',
        message: error,
        action: SecondaryButton(label: 'Try again', onPressed: controller.load),
      );
    }
    final List<JournalDayGroup> groups = groupJournalEntriesByDay(
      controller.visibleEntries,
      controller.localToday,
    );
    final List<Widget> children = <Widget>[
      _JournalPetFilterRow(controller: controller),
    ];
    if (controller.visibleEntries.isEmpty) {
      final bool filtered = controller.petFilterId != null;
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxl, left: AppSpacing.md),
          child: EmptyState(
            key: ValueKey<String>(
              filtered ? 'journal-filter-empty' : 'journal-empty',
            ),
            icon: filtered
                ? Icons.filter_alt_off_outlined
                : Icons.menu_book_outlined,
            title: filtered ? 'Nothing for this pet' : 'No entries yet',
            message: filtered
                ? 'No journal entries for this pet yet — pick another pet or '
                      '“All pets”.'
                : 'Walks, feedings and notes appear here, newest first.',
          ),
        ),
      );
    }
    for (final JournalDayGroup group in groups) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: SectionLabel(group.label),
        ),
      );
      for (int index = 0; index < group.entries.length; index++) {
        final JournalEntry entry = group.entries[index];
        children.add(
          ListRow(
            key: ValueKey<String>('journal-row-${entry.id}'),
            title: entry.title,
            subtitle:
                '${controller.petNameFor(entry.petId)} · '
                '${formatTimeOfDay(entry.occurredAt)}',
            leading: _JournalKindIcon(kind: entry.kind),
            trailing: const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.secondary,
            ),
            showDivider: index < group.entries.length - 1,
            horizontalInset: AppSpacing.md,
            onTap: () => onEdit(entry),
          ),
        );
      }
    }

    return RefreshIndicator(
      onRefresh: controller.load,
      color: AppColors.accent,
      child: ListView(
        key: const ValueKey<String>('journal-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          kShellContentBottomPadding,
        ),
        children: children,
      ),
    );
  }
}


/// "All pets" plus one chip per pet, mirroring the appointments filter.
class _JournalPetFilterRow extends StatelessWidget {
  const _JournalPetFilterRow({required this.controller});

  final JournalController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.pets.length < 2) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            AppChip(
              key: const ValueKey<String>('journal-pet-filter-all'),
              label: 'All pets',
              selected: controller.petFilterId == null,
              onTap: () => controller.selectPet(null),
            ),
            for (final Pet pet in controller.pets)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: AppChip(
                  key: ValueKey<String>('journal-pet-filter-${pet.id}'),
                  label: pet.name,
                  selected: controller.petFilterId == pet.id,
                  onTap: () => controller.selectPet(pet.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 34 px tinted tile carrying the entry's kind icon.
class _JournalKindIcon extends StatelessWidget {
  const _JournalKindIcon({required this.kind});

  final JournalKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: statusBackground(AppColors.accent, AppColors.surface),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Icon(_iconFor(kind), size: 18, color: AppColors.accent),
    );
  }

  static IconData _iconFor(JournalKind kind) {
    return switch (kind) {
      JournalKind.walk => Icons.directions_walk,
      JournalKind.fed => Icons.restaurant_outlined,
      JournalKind.meds => Icons.medication_outlined,
      JournalKind.grooming => Icons.content_cut,
      JournalKind.training => Icons.school_outlined,
      JournalKind.note => Icons.sticky_note_2_outlined,
      JournalKind.symptom => Icons.sick_outlined,
    };
  }
}
