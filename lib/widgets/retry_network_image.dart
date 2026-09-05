import 'dart:async';
import 'package:flutter/material.dart';

/// Network image with automatic retry on failure.
///
/// Some transient hiccup (a cold-start network blip, a brief server issue
/// right as a session begins) can make a one-shot `Image.network` load
/// fail. A widget that only builds once per session — like a drawer or
/// nav-rail header — would then show its fallback forever, even after the
/// underlying issue clears up moments later (confirmed: the exact same
/// URL succeeded elsewhere in the same session right after). This widget
/// retries a few times with a short delay before giving up, so a
/// transient failure self-heals instead of sticking for the rest of the
/// session. See LOGO_403_INVESTIGATION.md.
class RetryNetworkImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget Function(BuildContext context) fallbackBuilder;
  final int maxRetries;
  final Duration retryDelay;

  const RetryNetworkImage({
    super.key,
    required this.url,
    required this.fallbackBuilder,
    this.fit = BoxFit.contain,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
  });

  @override
  State<RetryNetworkImage> createState() => _RetryNetworkImageState();
}

class _RetryNetworkImageState extends State<RetryNetworkImage> {
  int _attempt = 0;
  bool _failed = false;
  bool _retryScheduled = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleRetry() {
    if (_retryScheduled) return;
    _retryScheduled = true;
    if (_attempt >= widget.maxRetries) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    _timer = Timer(widget.retryDelay, () {
      if (!mounted) return;
      // Evict the failed entry so the next attempt actually re-fetches
      // over the network instead of reusing a cached failure.
      PaintingBinding.instance.imageCache.evict(NetworkImage(widget.url));
      setState(() {
        _attempt++;
        _retryScheduled = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.fallbackBuilder(context);
    return Image.network(
      widget.url,
      key: ValueKey('${widget.url}#$_attempt'),
      fit: widget.fit,
      errorBuilder: (_, _, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleRetry());
        return widget.fallbackBuilder(context);
      },
    );
  }
}
