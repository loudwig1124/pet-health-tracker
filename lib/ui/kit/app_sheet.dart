/// Bottom-sheet helpers shared by forms and action sheets.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Opens the app's standard sheet: surface, 28 px top radius, drag handle,
/// safe area and full height when the keyboard is involved.
Future<T?> showAppSheet<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
    ),
    builder: builder,
  );
}

/// Standard sheet padding: 20 px sides, keyboard-aware bottom inset.
class AppSheetBody extends StatelessWidget {
  const AppSheetBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom)
          .add(padding),
      child: child,
    );
  }
}
