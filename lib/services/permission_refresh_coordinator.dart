/// Decides whether a permission refresh (GET /auth/me) should actually run.
///
/// - Single-flight: while a refresh is running every trigger reuses it, so a
///   burst of responses carrying a new permissions version makes ONE call.
/// - Debounce: triggers within [debounce] of the last start are ignored.
/// - Resume throttle: app-resume triggers within [resumeThrottle] of the last
///   start are ignored (camera/file-picker/share sheets all fire resume).
/// - Failures are swallowed; callers are fire-and-forget.
class PermissionRefreshCoordinator {
  PermissionRefreshCoordinator({
    required Future<void> Function() refresh,
    DateTime Function()? clock,
    this.debounce = const Duration(seconds: 3),
    this.resumeThrottle = const Duration(seconds: 60),
  })  : _refresh = refresh,
        _clock = clock ?? DateTime.now;

  final Future<void> Function() _refresh;
  final DateTime Function() _clock;
  final Duration debounce;
  final Duration resumeThrottle;

  Future<void>? _inFlight;
  DateTime? _lastStarted;

  bool get isRefreshing => _inFlight != null;

  Future<void> trigger({bool fromResume = false}) {
    final running = _inFlight;
    if (running != null) return running;

    final now = _clock();
    final last = _lastStarted;
    if (last != null) {
      final gap = now.difference(last);
      if (gap < debounce) return Future.value();
      if (fromResume && gap < resumeThrottle) return Future.value();
    }

    _lastStarted = now;
    late final Future<void> run;
    run = Future<void>(() => _refresh())
        .catchError((Object _) {})
        .whenComplete(() {
      if (identical(_inFlight, run)) _inFlight = null;
    });
    _inFlight = run;
    return run;
  }

  /// Forget timing/in-flight state — call on logout so the next session's
  /// first trigger is never debounced by the previous one.
  void reset() {
    _inFlight = null;
    _lastStarted = null;
  }
}
