/// Entry point: open the database, seed the first launch, run the app.
library;

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'app/di.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppServices services = await openAppServices();
  runApp(PetHealthTrackerApp(services: services));
}
