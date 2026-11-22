/// Inherited access to the app's services.
///
/// Screens do `final AppServices services = AppScope.of(context);` and pass the
/// repositories they need to their own `ChangeNotifier` controllers.
library;

import 'package:flutter/widgets.dart';

import 'app_services.dart';

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final AppScope? scope = context
        .dependOnInheritedWidgetOfExactType<AppScope>();
    assert(
      scope != null,
      'AppScope missing: wrap the app in PetHealthTrackerApp/AppScope.',
    );
    return scope!.services;
  }

  static AppServices? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()?.services;

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.services != services;
}
