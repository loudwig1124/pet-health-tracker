/// One swipeable pet card: avatar, name, the single due chip, the stat row and
/// the "Last visit" line with its chevron.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../../domain/dashboard.dart';
import '../../../domain/models/pet.dart';
import '../../../ui/format/app_formats.dart';
import '../../../ui/kit/app_card.dart';
import '../../../ui/kit/app_chip.dart';
import '../../../ui/theme/app_theme.dart';

/// Sized by the pager (310 x 264 on a 390-wide screen); the caller supplies the
/// age and weight labels so the screen keeps the domain rules and settings.
class PetCard extends StatelessWidget {
  const PetCard({
    super.key,
    required this.overview,
    required this.ageLabel,
    required this.weightLabel,
    this.onTap,
    this.dueLabel,
  });

  final PetOverview overview;
  final String ageLabel;
  final String weightLabel;
  final VoidCallback? onTap;

  /// "Rabies · 6 days overdue"; null falls back to the plain status label.
  final String? dueLabel;

  @override
  Widget build(BuildContext context) {
    final Pet pet = overview.pet;
    final DateTime? lastVisit = overview.lastVisit;
    final String lastVisitLabel = lastVisit == null
        ? 'No visits yet'
        : 'Last visit · ${formatDayMonth(lastVisit)}';

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _PetAvatar(
                key: ValueKey<String>('pet-avatar-${pet.id}'),
                pet: pet,
              ),
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
                      style: AppTextStyles.name,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pet.speciesLabel} · $ageLabel · $weightLabel',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Exactly one status chip per pet: the shared vaccination due rule.
          Align(
            alignment: Alignment.centerLeft,
            child: AppChip.due(overview.dueStatus, label: dueLabel),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _Stat(label: 'Age', value: ageLabel),
              ),
              Expanded(
                child: _Stat(label: 'Weight', value: weightLabel),
              ),
              Expanded(
                child: _Stat(label: 'Sex', value: pet.sex.label),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  lastVisitLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A 62 px round photo avatar; placeholder art until a real photo exists.
class _PetAvatar extends StatelessWidget {
  const _PetAvatar({super.key, required this.pet});

  final Pet pet;

  static const double _size = 62;

  @override
  Widget build(BuildContext context) {
    final Widget placeholder = Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: statusBackground(AppColors.dueSoon, AppColors.paper),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.pets, size: _size * 0.42, color: AppColors.dueSoon),
    );

    final String? photoPath = pet.photoPath;
    if (photoPath == null || photoPath.isEmpty) {
      return placeholder;
    }
    return ClipOval(
      child: Image.file(
        File(photoPath),
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) => placeholder,
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.sectionLabel,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
