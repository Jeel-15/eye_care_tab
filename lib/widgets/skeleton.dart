import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Animated shimmer skeleton list — one controller keeps all tiles in sync.
class AppSkeletonList extends StatefulWidget {
  final int count;
  final double itemHeight;
  final double itemRadius;
  final EdgeInsets padding;

  const AppSkeletonList({
    super.key,
    this.count = 6,
    this.itemHeight = 90,
    this.itemRadius = 14,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 12),
  });

  @override
  State<AppSkeletonList> createState() => _AppSkeletonListState();
}

class _AppSkeletonListState extends State<AppSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _anim = Tween<double>(begin: 0.0, end: 1.0).animate(_ctrl);
    _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Padding(
        padding: widget.padding,
        child: Column(
          children: List.generate(
            widget.count,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SkeletonTile(
                t: _anim.value,
                height: widget.itemHeight,
                radius: widget.itemRadius,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  final double t;
  final double height;
  final double radius;

  const _SkeletonTile({
    required this.t,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final x = -3.0 + t * 6.0;
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: const [AppColors.skeletonBase, AppColors.skeletonShine, AppColors.skeletonBase],
          begin: Alignment(x, 0),
          end: Alignment(x + 1.0, 0),
        ),
      ),
    );
  }
}
