import 'package:flutter/material.dart';
import '../screens/access_restricted_screen.dart';
import '../screens/login_screen.dart';
import '../screens/splash_screen.dart';

/// Global handler for "your access is blocked" conditions — a hospital's
/// plan expired/suspended/pending, or the login session itself expired.
/// Fires once regardless of how many concurrent API calls discover it (every
/// screen makes its own independent call, so several can fail at once),
/// using the app-level navigatorKey so it can navigate from inside services
/// rather than requiring every screen's catch block to check for it.
/// See ACCESS_CONTROL_AND_DATA_SYNC_PLAN.md Phase 2.
class AccessGuard {
  AccessGuard._();
  static final AccessGuard instance = AccessGuard._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _showing = false;
  bool get isBlocking => _showing;

  /// Tenant-level block (plan expired/suspended/pending). Doesn't clear the
  /// session — the token stays valid for whenever access is restored.
  void showAccessBlocked(String message) {
    if (_showing) return;
    _showing = true;
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => AccessRestrictedScreen(message: message, onRetry: _retryToSplash),
      ),
      (route) => false,
    );
  }

  /// The login token itself is no longer valid (401). Goes straight to
  /// login — a "Retry" screen wouldn't help here, only logging in again does.
  void showSessionExpired() {
    if (_showing) return;
    _showing = true;
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(initialError: 'Session expired. Please log in again.'),
      ),
      (route) => false,
    );
  }

  void _retryToSplash() {
    _showing = false;
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }
}
