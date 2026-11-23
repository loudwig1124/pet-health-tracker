/// Entry point: open the database, seed the first launch, run the app.
library;

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'app/boot_failure_app.dart';
import 'app/di.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await boot();
}

/// Opens the services and runs the app; a failure shows a retry screen instead
/// of a blank window.
Future<void> boot() async {
  try {
    final AppServices services = await openAppServices();
    runApp(PetHealthTrackerApp(services: services));
  } catch (error) {
    runApp(BootFailureApp(error: error, onRetry: () => boot()));
  }
}
