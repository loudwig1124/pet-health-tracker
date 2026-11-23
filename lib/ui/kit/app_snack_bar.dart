/// The app's one toast: three seconds, never persistent.
///
/// Material's default is four seconds, and a SnackBar that carries an action
/// persists until dismissed unless told otherwise — so every confirmation goes
/// through here instead of calling `showSnackBar` directly.
library;

import 'package:flutter/material.dart';

/// Default time on screen. Short enough not to sit over the next interaction.
const Duration kSnackDuration = Duration(seconds: 3);

void showAppSnack(
  BuildContext context,
  String message, {
  SnackBarAction? action,
}) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: kSnackDuration,
      persist: false,
      action: action,
    ),
  );
}
