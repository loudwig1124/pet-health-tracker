/// Regression tests for the kit's filter/segmented chip.
///
/// The selected state used to paint the accent as both foreground and
/// background, so every selected pill rendered an invisible label and every
/// filter row looked empty. These tests pin the contrast and the distinction
/// from the unselected state, and prove the tone palettes did not move.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/ui/kit/app_chip.dart';
import 'package:pet_health_tracker/ui/theme/app_theme.dart';

/// WCAG relative-luminance contrast ratio between two opaque colours.
double _contrastRatio(Color a, Color b) {
  final double luminanceA = a.computeLuminance();
  final double luminanceB = b.computeLuminance();
  final double lighter = luminanceA > luminanceB ? luminanceA : luminanceB;
  final double darker = luminanceA > luminanceB ? luminanceB : luminanceA;
  return (lighter + 0.05) / (darker + 0.05);
}

class _ChipColors {
  const _ChipColors({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color border;
}

/// Pumps one chip and reads the colours the chip actually painted.
Future<_ChipColors> _pumpChip(
  WidgetTester tester, {
  required String label,
  bool selected = false,
  AppChipTone tone = AppChipTone.neutral,
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: AppChip(
            label: label,
            selected: selected,
            tone: tone,
            onTap: onTap,
          ),
        ),
      ),
    ),
  );

  final Text text = tester.widget<Text>(find.text(label));
  // The pill is painted by Ink (so the press highlight inherits its radius),
  // not by the Material's shape.
  final Ink ink = tester.widget<Ink>(
    find.ancestor(of: find.text(label), matching: find.byType(Ink)).first,
  );
  final BoxDecoration decoration = ink.decoration! as BoxDecoration;
  expect(decoration.borderRadius, isNotNull);
  return _ChipColors(
    foreground: text.style!.color!,
    background: decoration.color!,
    border: (decoration.border! as Border).top.color,
  );
}

void main() {
  testWidgets('a selected chip keeps a legible label', (
    WidgetTester tester,
  ) async {
    final _ChipColors colors = await _pumpChip(
      tester,
      label: 'Walk',
      selected: true,
    );

    // Selected = solid accent with the surface (white) label, not accent on
    // accent (which was a 1:1, invisible pairing).
    expect(colors.foreground, AppColors.surface);
    expect(colors.background, AppColors.accent);
    expect(colors.border, AppColors.accent);
    expect(
      _contrastRatio(colors.foreground, colors.background),
      greaterThanOrEqualTo(4.5),
      reason: 'selected chip text must reach WCAG AA on its background',
    );
  });

  testWidgets('selected and unselected chips stay visually distinct', (
    WidgetTester tester,
  ) async {
    final _ChipColors selected = await _pumpChip(
      tester,
      label: 'Upcoming',
      selected: true,
    );
    final _ChipColors unselected = await _pumpChip(tester, label: 'Upcoming');

    expect(selected.background, isNot(unselected.background));
    expect(selected.foreground, isNot(unselected.foreground));
    expect(selected.border, isNot(unselected.border));

    // The unselected neutral chip keeps its original ink-on-surface face.
    expect(unselected.foreground, AppColors.ink);
    expect(unselected.background, AppColors.surface);
    expect(
      _contrastRatio(unselected.foreground, unselected.background),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('tone chips keep their palettes', (WidgetTester tester) async {
    final _ChipColors overdue = await _pumpChip(
      tester,
      label: 'Rabies',
      tone: AppChipTone.overdue,
    );
    expect(overdue.foreground, AppColors.overdue);
    expect(overdue.background, AppColors.overdueSurface);

    final _ChipColors dueSoon = await _pumpChip(
      tester,
      label: 'FeLV',
      tone: AppChipTone.dueSoon,
    );
    expect(dueSoon.foreground, AppColors.dueSoon);
    expect(dueSoon.background, AppColors.dueSoonSurface);

    final _ChipColors accent = await _pumpChip(
      tester,
      label: 'Next week',
      tone: AppChipTone.accent,
    );
    expect(accent.foreground, AppColors.accent);
    expect(accent.background, isNot(AppColors.accent));
  });

  testWidgets('a selected chip is still tappable and toggles nothing itself', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await _pumpChip(
      tester,
      label: 'Walk',
      selected: true,
      onTap: () => taps += 1,
    );

    await tester.tap(find.text('Walk'));
    await tester.pump();

    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
