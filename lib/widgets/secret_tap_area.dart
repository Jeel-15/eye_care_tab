import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps [child] with a hidden N-tap-within-window gesture — tap the child
/// [requiredTaps] times within [window] to fire [onTrigger]. Mirrors the
/// existing "5 taps on the login logo" secret entry used for the Platform
/// Admin login, so a hidden dev/debug action stays reachable in release
/// builds (unlike a `kDebugMode`-gated button) without ever being visibly
/// discoverable to a normal user.
class SecretTapArea extends StatefulWidget {
  final Widget child;
  final VoidCallback onTrigger;
  final int requiredTaps;
  final Duration window;

  const SecretTapArea({
    super.key,
    required this.child,
    required this.onTrigger,
    this.requiredTaps = 5,
    this.window = const Duration(seconds: 2),
  });

  @override
  State<SecretTapArea> createState() => _SecretTapAreaState();
}

class _SecretTapAreaState extends State<SecretTapArea> {
  int _count = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTap() {
    _timer?.cancel();
    _count++;

    if (_count >= widget.requiredTaps) {
      _count = 0;
      HapticFeedback.mediumImpact();
      widget.onTrigger();
      return;
    }

    if (_count >= widget.requiredTaps - 2) HapticFeedback.selectionClick();

    _timer = Timer(widget.window, () => _count = 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _onTap, behavior: HitTestBehavior.opaque, child: widget.child);
  }
}
