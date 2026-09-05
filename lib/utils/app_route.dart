import 'package:flutter/material.dart';

/// Consistent fade + subtle right-to-left slide for all screen navigations.
PageRoute<T> appRoute<T extends Object?>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        ),
      );
    },
  );
}

/// [Navigator.pushReplacement] using the same transition as [appRoute] —
/// exists so login/splash-style replace-navigation doesn't need to hand-roll
/// its own fade transition (which drifts from this one whenever it's tuned).
Future<T?> pushAppRouteReplacement<T extends Object?, TO extends Object?>(
  BuildContext context,
  Widget page, {
  TO? result,
}) {
  return Navigator.of(context).pushReplacement<T, TO>(appRoute<T>(page), result: result);
}
