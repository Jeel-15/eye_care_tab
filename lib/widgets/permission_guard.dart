import 'package:flutter/material.dart';
import '../services/permission_service.dart';
import 'app_animations.dart';

/// Wraps a pushed screen so live permission changes reach it.
///
/// - Permissions still allow the screen: every widget below is rebuilt, so
///   buttons that read [PermissionService] in `build` appear/disappear.
/// - [allowed] turns false: shows a short message and pops back to the first
///   route (the tablet shell).
/// - Permissions cleared (logout / session expired): does nothing —
///   AccessGuard owns that navigation.
class PermissionGuard extends StatefulWidget {
  const PermissionGuard({super.key, required this.allowed, required this.child});

  final bool Function(PermissionService p) allowed;
  final Widget child;

  @override
  State<PermissionGuard> createState() => _PermissionGuardState();
}

class _PermissionGuardState extends State<PermissionGuard> {
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    PermissionService.instance.addListener(_onPermissionsChanged);
  }

  @override
  void dispose() {
    PermissionService.instance.removeListener(_onPermissionsChanged);
    super.dispose();
  }

  void _onPermissionsChanged() {
    final p = PermissionService.instance;
    if (_leaving || !mounted || !p.isLoaded) return;

    if (widget.allowed(p)) {
      rebuildPermissionSubtree(context);
      return;
    }

    _leaving = true;
    showAppSnackBar(context, 'Your access to this screen was removed.', isError: true);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Screens read [PermissionService] directly (not via an InheritedWidget), so
/// a permission change invalidates no dependency — cached/const children would
/// keep stale buttons. Marks every element below [context] dirty instead.
void rebuildPermissionSubtree(BuildContext context) {
  (context as Element).visitChildren(_rebuild);
}

void _rebuild(Element element) {
  element.markNeedsBuild();
  element.visitChildren(_rebuild);
}
