/// The app widget: services in scope, theme applied, router attached.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/theme/app_theme.dart';
import 'phone_frame.dart';
import 'app_scope.dart';
import 'app_services.dart';
import 'router.dart';

/// Root widget. Receives its services from `main()` (or from a test) so the
/// database is never opened during `build`.
class PetHealthTrackerApp extends StatefulWidget {
  const PetHealthTrackerApp({
    super.key,
    required this.services,
    this.initialLocation,
  });

  final AppServices services;

  /// Route to start on; defaults to Home.
  final String? initialLocation;

  @override
  State<PetHealthTrackerApp> createState() => _PetHealthTrackerAppState();
}

class _PetHealthTrackerAppState extends State<PetHealthTrackerApp> {
  late final GoRouter _router = buildRouter(
    initialLocation: widget.initialLocation ?? Routes.home,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      child: MaterialApp.router(
        title: 'Pet Health Tracker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        // On the web the pointer is a mouse: Flutter ignores mouse drags for
        // scrolling by default, which would make the pager and the sheets feel
        // dead in a browser.
        scrollBehavior: const AppScrollBehavior(),
        builder: (BuildContext context, Widget? child) =>
            PhoneFrame(child: child ?? const SizedBox.shrink()),
        routerConfig: _router,
      ),
    );
  }
}

/// Drag devices the app answers to, including the mouse a browser provides.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
