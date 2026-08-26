import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';

// ─────────────────────────────────────────────────────────────────────────────

/// [AnimatedSwitcher.layoutBuilder] that stacks children top-aligned instead
/// of the default [Alignment.center]. Without this, any screen whose content
/// is shorter than the shell's available height (e.g. a narrow-layout screen
/// with a fixed-height inner section) gets vertically centered inside the
/// switcher's Stack, leaving equal blank bands above and below it instead of
/// starting at the top like every other screen.
Widget topAlignedSwitcherLayout(Widget? currentChild, List<Widget> previousChildren) {
  return Stack(
    alignment: Alignment.topCenter,
    children: [
      ...previousChildren,
      ?currentChild,
    ],
  );
}

/// Wraps any widget with a press-down scale (0.96×) and springs back on release.
/// Works with GestureDetector — does not conflict with inner button tap handling
/// when [onTap] is provided; otherwise touches pass through to children.
class PressScaleWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressScale;

  const PressScaleWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.pressScale = 0.96,
  });

  @override
  State<PressScaleWrapper> createState() => _PressScaleWrapperState();
}

class _PressScaleWrapperState extends State<PressScaleWrapper> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressScale : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Pulsing dot — scale 1.0 → 1.5 → 1.0 with fade over 1400ms, repeating.
/// Use to indicate an actively waiting / live state.
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulseDot({super.key, required this.color, this.size = 8.0});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final t = _ctrl.value;
        final pulse = t < 0.5 ? t * 2.0 : (1.0 - t) * 2.0;
        return Opacity(
          opacity: 1.0 - 0.7 * pulse,
          child: Transform.scale(
            scale: 1.0 + 0.5 * pulse,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Staggered entrance for list items: first [maxStagger] items slide up 4% and
/// fade in, each delayed by 30ms × index. Items at or beyond [maxStagger]
/// appear instantly (no controller overhead).
class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final int maxStagger;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.maxStagger = 6,
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    final curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _opacity = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(curve);

    if (widget.index < widget.maxStagger) {
      Future.delayed(Duration(milliseconds: widget.index * 30), () {
        if (mounted) _ctrl.forward();
      });
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.index >= widget.maxStagger) return widget.child;
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Spring slide-up snackbar with consistent styling.
/// [isError] → red, [isSuccess] → green, default → orange.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  bool isSuccess = false,
  Duration duration = const Duration(seconds: 3),
}) {
  final color = isError
      ? AppColors.red
      : isSuccess
          ? AppColors.green
          : AppColors.orange;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      duration: duration,
    ),
  );
}
