/// Keeps the app phone-shaped on wide windows (the web build), and leaves a
/// phone untouched.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/theme/app_theme.dart';

/// Width the layout was designed for, in logical pixels.
const double kPhoneFrameWidth = 390;
const double kPhoneFrameHeight = 844;

/// Centres the app in a 390 x 844 card when the window is much wider than a
/// phone; otherwise it is a pass-through.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    if (size.width <= 560) {
      return child;
    }
    final double height = math.min(size.height - 48, kPhoneFrameHeight);
    return ColoredBox(
      color: AppColors.hairline,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            width: kPhoneFrameWidth,
            height: height,
            child: MediaQuery(
              // Inside the frame the window is phone-sized.
              data: MediaQuery.of(context).copyWith(
                size: Size(kPhoneFrameWidth, height),
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
                viewInsets: EdgeInsets.zero,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
