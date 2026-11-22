/// The single source of visual truth: palette, radii, type scale and the
/// Material 3 theme built from them.
///
/// Feature screens must use these constants (and the `lib/ui/kit` widgets)
/// instead of hard-coded hex values, font sizes or radii.
library;

import 'package:flutter/material.dart';

/// Warm, paper-first palette from the approved style tile.
abstract final class AppColors {
  /// App background — warm paper.
  static const Color paper = Color(0xFFFAF8F5);

  /// Cards, sheets and rows that sit on the paper.
  static const Color surface = Color(0xFFFFFFFF);

  /// Primary text.
  static const Color ink = Color(0xFF1B1A18);

  /// Secondary text, captions, inactive icons.
  static const Color secondary = Color(0xFF6B6660);

  /// 1 px separators and card outlines.
  static const Color hairline = Color(0xFFECE7E1);

  /// Brand accent: links, selected tabs, primary buttons.
  static const Color accent = Color(0xFF0E6B5F);

  /// Overdue status: foreground on [overdueSurface].
  static const Color overdue = Color(0xFFB3261E);
  static const Color overdueSurface = Color(0xFFFCEBEA);

  /// Due-soon status: foreground on [dueSoonSurface].
  static const Color dueSoon = Color(0xFFA16000);
  static const Color dueSoonSurface = Color(0xFFFDF3E3);

  /// Up-to-date status: foreground on [upToDateSurface].
  static const Color upToDate = Color(0xFF2F6B3F);
  static const Color upToDateSurface = Color(0xFFEAF3EC);
}

/// Corner radii. Cards 20, bottom sheets 28, chips 16.
abstract final class AppRadii {
  static const double card = 20;
  static const double sheet = 28;
  static const double chip = 16;

  static BorderRadius get cardRadius => BorderRadius.circular(card);
  static BorderRadius get sheetRadius =>
      const BorderRadius.vertical(top: Radius.circular(sheet));
  static BorderRadius get chipRadius => BorderRadius.circular(chip);
}

/// Spacing scale (4-based). Use these instead of magic numbers.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Standard horizontal screen inset.
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: xl);
}

/// Type scale: 30 display, 27 name, 15 body, 12 caption, tracked caps for
/// section labels.
abstract final class AppTextStyles {
  static const TextStyle display = TextStyle(
    fontSize: 30,
    height: 1.12,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: AppColors.ink,
  );

  static const TextStyle name = TextStyle(
    fontSize: 27,
    height: 1.15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: AppColors.ink,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 1.35,
    color: AppColors.ink,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.3,
    color: AppColors.secondary,
  );

  /// Tracked caps: uppercase at the call site by `SectionLabel`.
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
    color: AppColors.secondary,
  );
}

/// Builds the app theme. Keep [ThemeData] construction in one place.
abstract final class AppTheme {
  static const ColorScheme _scheme = ColorScheme.light(
    primary: AppColors.accent,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    error: AppColors.overdue,
    onError: Colors.white,
    outline: AppColors.hairline,
    outlineVariant: AppColors.hairline,
    surfaceContainerHighest: AppColors.paper,
  );

  static const TextTheme _textTheme = TextTheme(
    displayLarge: AppTextStyles.display,
    displayMedium: AppTextStyles.display,
    headlineLarge: AppTextStyles.name,
    headlineMedium: AppTextStyles.name,
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 15,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    bodyLarge: AppTextStyles.body,
    bodyMedium: AppTextStyles.body,
    bodySmall: AppTextStyles.caption,
    labelLarge: TextStyle(
      fontSize: 15,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: AppColors.secondary,
    ),
    labelSmall: AppTextStyles.caption,
  );

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _scheme,
      scaffoldBackgroundColor: AppColors.paper,
      canvasColor: AppColors.paper,
      textTheme: _textTheme,
      iconTheme: const IconThemeData(color: AppColors.ink),
      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.ink,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
          side: BorderSide(color: AppColors.hairline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.hairline,
          disabledForegroundColor: AppColors.secondary,
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.chip)),
          ),
          textStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(44, 44),
          textStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.surface,
        side: BorderSide(color: AppColors.hairline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.chip)),
        ),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: AppTextStyles.body.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.chip)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        labelStyle: AppTextStyles.caption,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.secondary),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.chip)),
          borderSide: BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.chip)),
          borderSide: BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.chip)),
          borderSide: BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.chip)),
          borderSide: BorderSide(color: AppColors.overdue),
        ),
      ),
      splashColor: const Color(0x0F0E6B5F),
      highlightColor: const Color(0x080E6B5F),
    );
  }
}
