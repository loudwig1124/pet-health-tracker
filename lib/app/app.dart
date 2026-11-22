/// The app widget: services in scope, theme applied, router attached.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/theme/app_theme.dart';
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
        routerConfig: _router,
      ),
    );
  }
}
