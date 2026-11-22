/// The pager's last page: a dashed "Add a pet" card.
library;

import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../ui/kit/app_card.dart';
import '../../../ui/kit/app_chip.dart';
import '../../../ui/theme/app_theme.dart';

/// Opens the pet form (the Profile add-pet flow or a caller-provided handler).
class AddPetCard extends StatelessWidget {
  const AddPetCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: CustomPaint(
        painter: const _DashedBorderPainter(
          color: AppColors.hairline,
          radius: AppRadii.card - AppSpacing.sm,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: statusBackground(
                      AppColors.accent,
                      AppColors.surface,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 26,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Add a pet',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Photo, name, and a birthday',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded rectangle drawn as dashes, inset by the card's padding.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  /// Dash and gap lengths of the inner edge.
  static const double _dash = 6;
  static const double _gap = 5;

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + _dash), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
