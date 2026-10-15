import 'dart:math' as math;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';

/// Drop-in replacement for the built-in [RefreshIndicator] — same
/// `child`/`onRefresh`/`color` contract, but with a fully custom,
/// gesture-driven indicator:
///
/// - **Interacting** — an arrow fades in and rotates 0°→180° in lock-step
///   with the pull distance, while a progress ring fills in around it.
/// - **Armed** — once the pull crosses the trigger threshold, a light
///   haptic fires and the indicator does a quick elastic "pop" to signal
///   release-to-refresh.
/// - **Refreshing** — the arrow fades out and the ring becomes a smooth
///   continuous spinner.
/// - **Complete** — the ring and a checkmark pop in briefly in success
///   green before the indicator retracts.
class AppRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? color;

  const AppRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.color,
  });

  @override
  State<AppRefreshIndicator> createState() => _AppRefreshIndicatorState();
}

class _AppRefreshIndicatorState extends State<AppRefreshIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  late final AnimationController _popCtrl;
  late final AnimationController _checkCtrl;
  late final IndicatorController _indicatorCtrl;

  bool _hapticFired = false;
  bool _checkFired = false;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _popCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _indicatorCtrl = IndicatorController()..addListener(_onIndicatorChanged);
  }

  // Driven off the pull/refresh state directly — not from inside
  // `builder` (which runs during build), so starting one-shot animations
  // never happens as a build-time side effect.
  void _onIndicatorChanged() {
    final c = _indicatorCtrl;

    if (c.isArmed) {
      if (!_hapticFired) {
        _hapticFired = true;
        HapticFeedback.mediumImpact();
        _popCtrl.forward(from: 0);
      }
    } else if (c.isDragging || c.isCanceling || c.isIdle) {
      _hapticFired = false;
    }

    if (c.isLoading || c.isFinalizing) {
      if (!_spinCtrl.isAnimating) _spinCtrl.repeat();
    } else if (_spinCtrl.isAnimating) {
      _spinCtrl.stop();
    }

    if (c.isComplete) {
      if (!_checkFired) {
        _checkFired = true;
        _checkCtrl.forward(from: 0);
      }
    } else if (c.isIdle) {
      _checkFired = false;
      _checkCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _indicatorCtrl.removeListener(_onIndicatorChanged);
    _indicatorCtrl.dispose();
    _spinCtrl.dispose();
    _popCtrl.dispose();
    _checkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = widget.color ?? AppColors.primary;
    final track = brand.withValues(alpha: 0.16);
    final success = AppColors.green;
    final surface = Theme.of(context).cardColor;

    return CustomRefreshIndicator(
      controller: _indicatorCtrl,
      onRefresh: widget.onRefresh,
      builder: (context, child, controller) {
        return Stack(
          children: [
            child,
            PositionedIndicatorContainer(
              controller: controller,
              displacement: 56,
              child: AnimatedBuilder(
                animation:
                    Listenable.merge([controller, _spinCtrl, _popCtrl, _checkCtrl]),
                builder: (context, _) {
                  final pull = controller.value.clamp(0.0, 1.0);
                  final overpull = (controller.value - 1.0).clamp(0.0, 0.5);
                  final loading = controller.isLoading || controller.isFinalizing;
                  final armedPhase = controller.isArmed ||
                      controller.isSettling ||
                      loading ||
                      controller.isComplete;

                  final pop = armedPhase
                      ? Tween<double>(begin: 0.86, end: 1.0)
                          .transform(Curves.elasticOut.transform(_popCtrl.value))
                      : 1.0;
                  final scale =
                      (0.55 + 0.45 * pull + overpull * 0.1) * pop;

                  final arrowColor = Color.lerp(
                        Theme.of(context).colorScheme.outline,
                        brand,
                        pull,
                      ) ??
                      brand;
                  final arrowOpacity =
                      controller.isComplete ? 0.0 : (loading ? 0.0 : (0.35 + 0.65 * pull));
                  final arrowAngle = math.pi * pull;

                  final ringColor = controller.isComplete ? success : brand;
                  final ringSweep = controller.isComplete
                      ? 1.0
                      : (loading ? 0.72 : (0.1 + 0.8 * pull));
                  final ringRotation =
                      loading ? _spinCtrl.value * 2 * math.pi : 0.0;

                  final checkT = Curves.elasticOut.transform(_checkCtrl.value);

                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(44, 44),
                            painter: _RingPainter(
                              trackColor: track,
                              color: ringColor,
                              sweep: ringSweep,
                              rotation: ringRotation,
                            ),
                          ),
                          Opacity(
                            opacity: arrowOpacity.clamp(0.0, 1.0),
                            child: Transform.rotate(
                              angle: arrowAngle,
                              child: Icon(
                                Icons.arrow_downward_rounded,
                                color: arrowColor,
                                size: 20,
                              ),
                            ),
                          ),
                          if (_checkCtrl.value > 0)
                            Opacity(
                              opacity: _checkCtrl.value.clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: checkT,
                                child: Icon(
                                  Icons.check_rounded,
                                  color: success,
                                  size: 22,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color trackColor;
  final Color color;
  final double sweep;
  final double rotation;

  _RingPainter({
    required this.trackColor,
    required this.color,
    required this.sweep,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.09;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -math.pi / 2 + rotation,
      sweep * 2 * math.pi,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.trackColor != trackColor ||
      oldDelegate.color != color ||
      oldDelegate.sweep != sweep ||
      oldDelegate.rotation != rotation;
}
