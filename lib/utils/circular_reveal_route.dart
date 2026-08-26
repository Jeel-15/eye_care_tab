import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Returns a [PageRoute] that reveals [page] with a circle expanding from
/// [center] (defaults to screen center — the spinner position on splash).
PageRoute<T> circularRevealRoute<T>({
  required Widget page,
  Offset? center,
  Duration duration = const Duration(milliseconds: 650),
}) {
  return PageRouteBuilder<T>(
    transitionDuration: duration,
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (context, animation, _, child) {
      final size = MediaQuery.of(context).size;
      final origin = center ?? Offset(size.width / 2, size.height * 0.18);
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );
      return AnimatedBuilder(
        animation: curved,
        builder: (_, _) => ClipPath(
          clipper: _CircularRevealClipper(
            fraction: curved.value,
            center: origin,
            size: size,
          ),
          child: child,
        ),
      );
    },
  );
}

class _CircularRevealClipper extends CustomClipper<Path> {
  final double fraction;
  final Offset center;
  final Size size;

  const _CircularRevealClipper({
    required this.fraction,
    required this.center,
    required this.size,
  });

  @override
  Path getClip(Size _) {
    // Radius must reach the farthest corner of the screen from [center].
    final maxRadius = math.sqrt(
      math.pow(math.max(center.dx, size.width - center.dx), 2) +
          math.pow(math.max(center.dy, size.height - center.dy), 2),
    );
    return Path()
      ..addOval(
        Rect.fromCircle(center: center, radius: maxRadius * fraction),
      );
  }

  @override
  bool shouldReclip(_CircularRevealClipper old) =>
      fraction != old.fraction || center != old.center;
}
