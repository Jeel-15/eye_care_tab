import 'package:flutter/material.dart';

/// Splash-screen loader themed around the app's eye-care identity: a pupil
/// that gently dilates/constricts (like a real eye reacting to light), with
/// a soft ring pulsing outward from it — replaces a generic spinner with
/// something that's actually "ours". Self-contained, no new packages;
/// mirrors the pulse-animation pattern already used by WaitPill.
class PulsingPupilLoader extends StatefulWidget {
  final double size;
  final Color color;

  const PulsingPupilLoader({super.key, this.size = 64, this.color = Colors.white});

  @override
  State<PulsingPupilLoader> createState() => _PulsingPupilLoaderState();
}

class _PulsingPupilLoaderState extends State<PulsingPupilLoader> with TickerProviderStateMixin {
  late final AnimationController _pupilCtrl;
  late final Animation<double> _pupilScale;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pupilCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    _pupilScale = Tween<double>(begin: 0.8, end: 1.15).animate(CurvedAnimation(parent: _pupilCtrl, curve: Curves.easeInOut));

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..repeat();
    _pulseScale = Tween<double>(begin: 1.0, end: 1.8).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
    _pulseOpacity = Tween<double>(begin: 0.5, end: 0.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pupilCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final irisSize = widget.size * 0.62;
    final pupilSize = widget.size * 0.34;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pupilCtrl, _pulseCtrl]),
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outward light-reaction pulse ring
              Transform.scale(
                scale: _pulseScale.value,
                child: Opacity(
                  opacity: _pulseOpacity.value,
                  child: Container(
                    width: irisSize,
                    height: irisSize,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.color, width: 1.5)),
                  ),
                ),
              ),
              // Iris ring — static, faint
              Container(
                width: irisSize,
                height: irisSize,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.color.withValues(alpha: 0.30), width: 2)),
              ),
              // Pupil — dilates/constricts
              Transform.scale(
                scale: _pupilScale.value,
                child: Container(
                  width: pupilSize,
                  height: pupilSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                    boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.55), blurRadius: 10, spreadRadius: 1)],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
