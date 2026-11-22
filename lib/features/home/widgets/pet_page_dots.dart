/// The page-dot rules and the warm pill that paints them.
///
/// Rule: hidden at one pet; two to five pets show exactly one dot each; six or
/// more show a window that grows from five to seven dots as the current page
/// travels inward, and each dot shrinks with its distance from the current one.
library;

import 'package:flutter/material.dart';

import '../../../ui/kit/app_chip.dart';
import '../../../ui/theme/app_theme.dart';

/// Full dot size (one step from the current page or closer).
const double kDotSize = 6;

/// Dot size two steps away.
const double kShavedDotSize = 5;

/// Dot size three or more steps away.
const double kSmallDotSize = 4;

/// Space between dots.
const double kDotGap = 8;

/// Horizontal padding inside the pill.
const double kDotPillInset = 10;

/// The visual pill height.
const double kDotPillHeight = 20;

/// Height of the transparent tap strip around the pill (accessibility).
const double kDotTapHeight = 44;

/// One visible dot in the pager indicator.
class PageDot {
  const PageDot({
    required this.index,
    required this.size,
    required this.isCurrent,
  });

  /// The pet page this dot jumps to.
  final int index;

  /// Visual diameter: 6 current/neighbour, 5 two steps, 4 three or more.
  final double size;

  /// Only the current dot is accent.
  final bool isCurrent;
}

/// The dots to paint for [petCount] pets with [currentIndex] focused.
///
/// [currentIndex] may be the add-a-pet page (== petCount): the window follows
/// the last pet but no dot is current.
List<PageDot> visiblePageDots({
  required int petCount,
  required int currentIndex,
}) {
  if (petCount <= 1) {
    return const <PageDot>[];
  }

  final int focus = currentIndex.clamp(0, petCount - 1);
  int visible;
  if (petCount <= 5) {
    visible = petCount;
  } else {
    final int fromStart = focus;
    final int fromEnd = petCount - 1 - focus;
    final int edgeDistance = fromStart < fromEnd ? fromStart : fromEnd;
    final int desired = edgeDistance >= 2 ? 7 : (edgeDistance == 1 ? 6 : 5);
    visible = desired > petCount ? petCount : desired;
  }

  final int start = (focus - visible ~/ 2).clamp(0, petCount - visible);
  final bool hasCurrentPage = currentIndex >= 0 && currentIndex < petCount;
  return <PageDot>[
    for (int index = start; index < start + visible; index++)
      PageDot(
        index: index,
        size: petCount <= 5
            ? kDotSize
            : _sizeForDistance((index - focus).abs()),
        isCurrent: hasCurrentPage && index == currentIndex,
      ),
  ];
}

double _sizeForDistance(int distance) {
  if (distance <= 1) {
    return kDotSize;
  }
  return distance == 2 ? kShavedDotSize : kSmallDotSize;
}

/// The dot row: a warm pill of 6 px dots with a 44 px tall tap strip. Tapping
/// anywhere on a dot (or on the strip above/below it) jumps to that pet.
class PetPageDots extends StatelessWidget {
  const PetPageDots({
    super.key,
    required this.petCount,
    required this.currentIndex,
    required this.onSelected,
  });

  final int petCount;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final List<PageDot> dots = visiblePageDots(
      petCount: petCount,
      currentIndex: currentIndex,
    );
    if (dots.isEmpty) {
      return const SizedBox.shrink();
    }

    final double contentWidth =
        dots.fold<double>(0, (double sum, PageDot dot) => sum + dot.size) +
        (dots.length - 1) * kDotGap;
    final double pillWidth = contentWidth + kDotPillInset * 2;
    final bool hasCurrent = currentIndex >= 0 && currentIndex < petCount;

    return Semantics(
      container: true,
      label: hasCurrent ? 'Pet ${currentIndex + 1} of $petCount' : 'Pet pages',
      child: Center(
        child: SizedBox(
          height: kDotTapHeight,
          width: pillWidth,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (TapUpDetails details) => onSelected(
              dots[_nearestDot(dots, details.localPosition.dx)].index,
            ),
            child: Center(
              child: Container(
                height: kDotPillHeight,
                padding: const EdgeInsets.symmetric(horizontal: kDotPillInset),
                decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(kDotPillHeight / 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (int i = 0; i < dots.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: kDotGap),
                      _Dot(dot: dots[i]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The dot nearest [x] inside the pill, so the tap strip above and below the
  /// visible dots still selects the dot under the finger.
  int _nearestDot(List<PageDot> dots, double x) {
    double cursor = kDotPillInset;
    int nearest = 0;
    double nearestDistance = double.infinity;
    for (int i = 0; i < dots.length; i++) {
      final double centre = cursor + dots[i].size / 2;
      final double distance = (x - centre).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = i;
      }
      cursor += dots[i].size + kDotGap;
    }
    return nearest;
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.dot});

  final PageDot dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey<String>('pet-dot-${dot.index}'),
      width: dot.size,
      height: dot.size,
      decoration: BoxDecoration(
        color: dot.isCurrent
            ? AppColors.accent
            : statusBackground(AppColors.secondary, AppColors.hairline),
        shape: BoxShape.circle,
      ),
    );
  }
}
