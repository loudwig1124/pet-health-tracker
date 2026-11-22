/// The one route table: a four-destination shell with retained tab state, plus
/// the full-page pet detail route.
///
/// Feature screens live in `lib/features/**`; this file only wires them into the
/// shell. The pet page is a top-level route (outside the shell) so its photo
/// covers the whole screen, including the bottom bar.
library;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/appointments/appointments_screen.dart';
import '../features/home/home_screen.dart';
import '../features/journal/journal_screen.dart';
import '../features/pets/pet_routes.dart';
import '../features/profile/profile_screen.dart';
import 'shell/app_shell.dart';

/// Route paths, in one place so screens never hard-code strings.
abstract final class Routes {
  static const String home = '/home';
  static const String journal = '/journal';
  static const String appointments = '/appointments';
  static const String profile = '/profile';

  static const String homeName = 'home';
  static const String journalName = 'journal';
  static const String appointmentsName = 'appointments';
  static const String profileName = 'profile';
}

/// Builds the route table. Branches are kept alive by
/// `StatefulShellRoute.indexedStack`, so each tab keeps its scroll position,
/// form drafts and controller state while the user moves around.
GoRouter buildRouter({String initialLocation = Routes.home}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) => AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.home,
                name: Routes.homeName,
                builder: (BuildContext context, GoRouterState state) =>
                    HomeScreen(
                      onOpenPet: (pet) => PetRoutes.open(context, pet.id),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.journal,
                name: Routes.journalName,
                builder: (BuildContext context, GoRouterState state) =>
                    const JournalScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.appointments,
                name: Routes.appointmentsName,
                builder: (BuildContext context, GoRouterState state) =>
                    const AppointmentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.profile,
                name: Routes.profileName,
                builder: (BuildContext context, GoRouterState state) =>
                    const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      // Outside the shell: the pet page's photo covers the bottom bar.
      PetRoutes.route(),
    ],
  );
}
