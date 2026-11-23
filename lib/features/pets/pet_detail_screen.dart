/// A pet's page: the photo is drawn once at full page size and never moves.
/// The sheet travels between two stops; only the blur and the sheet animate.
///
/// Resting (top 560): the photo is clear, the sheet shows the name and the one
/// dose that needs attention. Raised (top 168): the same photo, blurred in
/// place, with every vaccine and the append-only medical history revealed.
library;

import 'dart:ui' as ui;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_services.dart';
import '../../domain/models/health_record.dart';
import '../../domain/models/pet.dart';
import '../../domain/models/vaccination.dart';
import '../../domain/rules/vaccination_due.dart';
import '../../ui/format/app_formats.dart';
import '../../ui/kit/app_card.dart';
import '../../ui/kit/app_chip.dart';
import '../../ui/kit/empty_state.dart';
import '../../ui/kit/primary_button.dart';
import '../../ui/theme/app_theme.dart';
import 'forms/health_record_form_sheet.dart';
import 'forms/pet_form_sheet.dart';
import 'forms/vaccination_form_sheet.dart';
import 'pet_detail_controller.dart';
import 'pet_photo.dart';

/// Resting stop: sheet top edge, from the approved style tile (390 x 844).
/// Resting and raised tops for a given viewport height.
///
/// The fractions are the original 560/168 at the 844 pt design height, so the
/// designed screen is unchanged while shorter surfaces keep a usable sheet.
const double _restingFraction = 560 / 844;
const double _raisedFraction = 168 / 844;

double restingSheetTop(double viewportHeight) => math.max(
  viewportHeight - 300,
  viewportHeight * _restingFraction,
);

double raisedSheetTop(double viewportHeight) => math.min(
  math.max(viewportHeight * _raisedFraction, 96),
  restingSheetTop(viewportHeight) - 180,
);

const double kPetSheetRestingTop = 560;

/// Raised stop: sheet top edge when vaccines and medical history are revealed.
const double kPetSheetRaisedTop = 168;

/// Travel time for the sheet and the blur.
const Duration kPetSheetTravelDuration = Duration(milliseconds: 260);

/// The photo's blur radius when the sheet is raised (same pixels, blurred).
const double kPetPhotoBlurSigma = 10;

/// A full-screen pet page.
class PetDetailScreen extends StatefulWidget {
  const PetDetailScreen({super.key, required this.petId});

  final int petId;

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen> {
  late final AppServices _services;
  late final PetDetailController _controller;
  late final Listenable _listenable;
  bool _raised = false;
  bool _started = false;
  double _sheetDragDistance = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    // `AppScope.of` is a dependency lookup, which initState cannot do; this is
    // the first lifecycle point where the services are available.
    _services = AppScope.of(context);
    _controller = PetDetailController(services: _services, petId: widget.petId);
    _listenable = Listenable.merge(<Listenable>[
      _controller,
      _services.settings,
    ]);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setRaised(bool raised) {
    if (_raised == raised) {
      return;
    }
    setState(() => _raised = raised);
  }

  void _toggleSheet() => _setRaised(!_raised);

  void _onSheetDragStart(DragStartDetails details) {
    _sheetDragDistance = 0;
  }

  void _onSheetDragUpdate(DragUpdateDetails details) {
    _sheetDragDistance += details.delta.dy;
  }

  void _onSheetDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    if (velocity < -150 || _sheetDragDistance < -60) {
      _setRaised(true);
    } else if (velocity > 150 || _sheetDragDistance > 60) {
      _setRaised(false);
    }
    _sheetDragDistance = 0;
  }

  Future<void> _refresh() => _controller.load(showSpinner: false);

  Future<void> _editPet() async {
    final Pet? pet = _controller.pet;
    if (pet == null) {
      return;
    }
    final bool? saved = await showPetForm(
      context,
      services: _services,
      existing: pet,
    );
    if ((saved ?? false) && mounted) {
      await _refresh();
    }
  }

  Future<void> _addVaccination() async {
    final bool? saved = await showVaccinationForm(
      context,
      services: _services,
      petId: widget.petId,
      vaccineTypes: _controller.vaccineTypes,
    );
    if ((saved ?? false) && mounted) {
      await _refresh();
    }
  }

  Future<void> _addHealthRecord() async {
    final bool? saved = await showHealthRecordForm(
      context,
      services: _services,
      petId: widget.petId,
    );
    if ((saved ?? false) && mounted) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: ListenableBuilder(
        listenable: _listenable,
        builder: (BuildContext context, Widget? child) {
          final Pet? pet = _controller.pet;
          if (_controller.isLoading && pet == null) {
            return Stack(
              children: <Widget>[_topBar(pet: null), const _Loading()],
            );
          }
          if (pet == null) {
            final bool missing = _controller.isNotFound;
            return Stack(
              children: <Widget>[
                _topBar(pet: null),
                SafeArea(
                  child: EmptyState(
                    icon: Icons.pets_outlined,
                    title: missing
                        ? 'Pet not found'
                        : 'Could not load this pet',
                    message: missing
                        ? 'This pet is no longer part of the household. It '
                              'may have been removed on the Profile screen.'
                        : 'Something went wrong reading this pet from the '
                              'household notebook.',
                    action: SecondaryButton(
                      label: missing ? 'Go back' : 'Try again',
                      onPressed: missing
                          ? () => Navigator.maybePop(context)
                          : _controller.load,
                    ),
                  ),
                ),
              ],
            );
          }
          return _page(context, pet);
        },
      ),
    );
  }

  /// The photo layer, the fixed top shade, the back/edit controls and the
  /// travelling sheet. Only the sheet's `top` and the blur change.
  Widget _page(BuildContext context, Pet pet) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: RepaintBoundary(
            key: const ValueKey<String>('pet-photo'),
            child: ColoredBox(
              color: AppColors.paper,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0,
                  end: _raised ? kPetPhotoBlurSigma : 0,
                ),
                duration: kPetSheetTravelDuration,
                curve: Curves.easeOutCubic,
                builder: (BuildContext context, double sigma, Widget? child) {
                  if (sigma < 0.1) {
                    return child!;
                  }
                  return ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: sigma,
                      sigmaY: sigma,
                      tileMode: TileMode.clamp,
                    ),
                    child: child,
                  );
                },
                child: PetPhoto(photoPath: pet.photoPath, petName: pet.name),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 180,
          child: IgnorePointer(
            child: DecoratedBox(decoration: BoxDecoration(gradient: _topShade)),
          ),
        ),
        _topBar(pet: pet),
        AnimatedPositioned(
          // Stops are fractions of the viewport with a floor, so a small
          // screen (or a short web frame) still shows a usable sheet instead of
          // collapsing it to zero height.
          top: _raised
              ? raisedSheetTop(MediaQuery.sizeOf(context).height)
              : restingSheetTop(MediaQuery.sizeOf(context).height),
          left: 0,
          right: 0,
          bottom: 0,
          duration: kPetSheetTravelDuration,
          curve: Curves.easeOutCubic,
          child: GestureDetector(
            key: const ValueKey<String>('pet-sheet'),
            onVerticalDragStart: _onSheetDragStart,
            onVerticalDragUpdate: _onSheetDragUpdate,
            onVerticalDragEnd: _onSheetDragEnd,
            child: ClipRRect(
              borderRadius: AppRadii.sheetRadius,
              child: ColoredBox(
                color: AppColors.paper,
                child: Column(
                  children: <Widget>[
                    _SheetHandle(
                      raised: _raised,
                      onTap: _toggleSheet,
                      onDragStart: _onSheetDragStart,
                      onDragUpdate: _onSheetDragUpdate,
                      onDragEnd: _onSheetDragEnd,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: _raised
                            ? const ClampingScrollPhysics()
                            : const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          0,
                          AppSpacing.xl,
                          _raised ? AppSpacing.xxl : AppSpacing.sm,
                        ),
                        child: _sections(pet, raised: _raised),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _topBar({required Pet? pet}) {
    final bool overPhoto = pet != null;
    final Color foreground = overPhoto ? Colors.white : AppColors.ink;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            AppSpacing.xs,
            AppSpacing.md,
            0,
          ),
          child: Row(
            children: <Widget>[
              IconButton(
                key: const ValueKey<String>('pet-back'),
                onPressed: () => Navigator.maybePop(context),
                tooltip: 'Back',
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: foreground,
                ),
              ),
              const Spacer(),
              if (pet != null)
                TextButton(
                  key: const ValueKey<String>('pet-edit'),
                  onPressed: _editPet,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size(44, 44),
                  ),
                  child: const Text('Edit'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sections(Pet pet, {required bool raised}) {
    final List<Vaccination> vaccinations = _controller.vaccinations;
    final List<HealthRecord> records = _controller.healthRecords;
    final int visibleVaccinations = raised ? vaccinations.length : 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          pet.name,
          key: const ValueKey<String>('pet-name'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.name,
        ),
        const SizedBox(height: 2),
        Text(
          _controller.metaLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppChip.due(_controller.dueStatus),
        Column(
          key: const ValueKey<String>('vaccines-section'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SheetSectionHeader(
              title: 'Vaccines',
              actionLabel: '+ Add',
              actionKey: const ValueKey<String>('add-vaccination'),
              onAction: _addVaccination,
            ),
            if (vaccinations.isEmpty)
              const _SheetHint('No vaccines recorded yet.')
            else
              for (final Vaccination vaccination in vaccinations.take(
                visibleVaccinations,
              )) ...<Widget>[
                _VaccineRow(
                  key: ValueKey<String>('vaccine-row-${vaccination.id}'),
                  vaccination: vaccination,
                  today: _controller.today,
                  windowDays: _controller.dueSoonWindowDays,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ),
        if (!raised)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xs),
            child: Center(
              child: Text(
                'Swipe up for full history',
                key: ValueKey<String>('pet-swipe-hint'),
                style: AppTextStyles.caption,
              ),
            ),
          ),
        if (raised)
          Column(
            key: const ValueKey<String>('medical-history-section'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SheetSectionHeader(
                title: 'Medical history',
                actionLabel: '+ New',
                actionKey: const ValueKey<String>('add-health-record'),
                onAction: _addHealthRecord,
              ),
              if (records.isEmpty)
                const _SheetHint('No clinical notes yet.')
              else
                for (final HealthRecord record in records) ...<Widget>[
                  _HealthRecordRow(
                    key: ValueKey<String>('health-record-row-${record.id}'),
                    record: record,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
            ],
          ),
      ],
    );
  }
}

final LinearGradient _topShade = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: <Color>[
    Colors.black.withValues(alpha: 0.38),
    Colors.black.withValues(alpha: 0),
  ],
);

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// The drag handle: tap toggles the stop, swipe changes it.
class _SheetHandle extends StatelessWidget {
  const _SheetHandle({
    required this.raised,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final bool raised;
  final VoidCallback onTap;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: raised ? 'Lower pet details' : 'Raise pet details',
      child: GestureDetector(
        key: const ValueKey<String>('pet-sheet-handle'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onVerticalDragStart: onDragStart,
        onVerticalDragUpdate: onDragUpdate,
        onVerticalDragEnd: onDragEnd,
        child: SizedBox(
          height: 30,
          child: Center(
            child: Container(
              width: 32,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact tracked-caps section header with the "+ Add" / "+ New" action.
class _SheetSectionHeader extends StatelessWidget {
  const _SheetSectionHeader({
    required this.title,
    required this.actionLabel,
    required this.actionKey,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final Key actionKey;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.sectionLabel,
            ),
          ),
          // A pill that hugs its label. Padding plus a stadium shape keeps the
          // ink inside the rounded box, and `padded` keeps the touch target at
          // 48 px even though the visual is compact.
          TextButton(
            key: actionKey,
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.padded,
              shape: const StadiumBorder(),
              textStyle: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _SheetHint extends StatelessWidget {
  const _SheetHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(message, style: AppTextStyles.caption),
    );
  }
}

/// One vaccine row: name, dose/next-due meta and the shared-rule due chip.
class _VaccineRow extends StatelessWidget {
  const _VaccineRow({
    super.key,
    required this.vaccination,
    required this.today,
    required this.windowDays,
  });

  final Vaccination vaccination;
  final DateTime today;
  final int windowDays;

  @override
  Widget build(BuildContext context) {
    final VaccinationDueStatus status = vaccinationDueStatus(
      vaccination.nextDueDate,
      today,
      windowDays: windowDays,
    );
    final DateTime? nextDueDate = vaccination.nextDueDate;
    final String meta = nextDueDate == null
        ? '${formatFullDate(vaccination.vaccinationDate)} · no booster set'
        : '${formatFullDate(vaccination.vaccinationDate)} · next due '
              '${formatFullDate(nextDueDate)}';
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 10,
      ),
      radius: AppRadii.chip,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  vaccination.vaccineName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppChip.due(status),
        ],
      ),
    );
  }
}

/// One clinical note. There is no edit or delete affordance by design: the
/// records are append-only at the repository and schema level.
class _HealthRecordRow extends StatelessWidget {
  const _HealthRecordRow({super.key, required this.record});

  final HealthRecord record;

  @override
  Widget build(BuildContext context) {
    final String? vetName = record.vetName?.trim();
    final String meta = vetName == null || vetName.isEmpty
        ? formatDayMonth(record.recordedOn)
        : '${formatDayMonth(record.recordedOn)} · $vetName';
    final String? treatment = record.treatment?.trim();
    final String? medication = record.prescribedMedication?.trim();
    final String detail = <String?>[
      medication == null || medication.isEmpty ? null : 'Rx $medication',
      treatment == null || treatment.isEmpty ? null : treatment,
    ].whereType<String>().join(' · ');
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 10,
      ),
      radius: AppRadii.chip,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            record.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption,
          ),
          if (detail.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }
}
