/// Route metadata for the pet page.
///
/// The app shell's four destinations live in `lib/app/router.dart` (foundation
/// owns that file). The integrator registers [PetRoutes.route] as a top-level
/// route so the page covers the whole screen, including the bottom bar:
///
/// ```dart
/// GoRouter(routes: <RouteBase>[PetRoutes.route(), /* ...shell... */]);
/// ```
library;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'pet_detail_screen.dart';

abstract final class PetRoutes {
  /// "/pets/9001" — path pattern with the pet id parameter.
  static const String detailPath = '/pets/:petId';

  /// Named route used by [open] and by Home's pet cards.
  static const String detailName = 'pet-detail';

  /// Path parameter name.
  static const String petIdParameter = 'petId';

  /// Pushes the pet page on top of the shell and completes when it pops, so a
  /// caller can refresh the data the page may have changed.
  static Future<void> open(BuildContext context, int petId) async {
    await context.pushNamed<void>(
      detailName,
      pathParameters: <String, String>{petIdParameter: '$petId'},
    );
  }

  /// The top-level route the integrator adds to the router.
  ///
  /// Uses a page (not a bare builder) so the push animates: the page slides in
  /// from the right while fading, and reverses on the way back. Without an
  /// explicit transition the route appeared instantly, which reads as a jump.
  static GoRoute route() {
    return GoRoute(
      path: detailPath,
      name: detailName,
      pageBuilder: (BuildContext context, GoRouterState state) {
        final int petId =
            int.tryParse(state.pathParameters[petIdParameter] ?? '') ?? -1;
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: PetDetailScreen(petId: petId),
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 340),
          transitionsBuilder:
              (
                BuildContext context,
                Animation<double> animation,
                Animation<double> secondaryAnimation,
                Widget child,
              ) {
                final Animation<double> eased = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(eased),
                  child: FadeTransition(opacity: eased, child: child),
                );
              },
        );
      },
    );
  }
}
