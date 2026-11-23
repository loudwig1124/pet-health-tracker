/// The one full-width accent button.
library;

import 'package:flutter/material.dart';

/// 52 px filled accent button with the chip radius. Use exactly one per screen
/// as the primary action; secondary actions use a text button or a chip.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final Widget button = icon == null
        ? FilledButton(onPressed: onPressed, child: Text(label))
        : FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 20),
            label: Text(label),
          );
    return SizedBox(
      width: expand ? double.infinity : null,
      child: ConstrainedBox(
        // A fixed 52 clipped the label at iOS accessibility text sizes; a
        // minimum keeps the rhythm and lets the button grow.
        constraints: const BoxConstraints(minHeight: 52),
        child: button,
      ),
    );
  }
}

/// Text-only secondary action that still respects the 44 px tap target.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: onPressed, child: Text(label));
  }
}
