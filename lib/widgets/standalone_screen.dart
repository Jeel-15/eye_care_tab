import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/permission_service.dart';
import 'permission_guard.dart';

/// Wraps a shell-rail-only screen body (one that returns bare content like
/// `SplitPaneScaffold`/`Column` with no `Scaffold` of its own, because it's
/// normally embedded directly in `TabletShell`'s own `Scaffold`) so it can
/// also be pushed as a standalone route via `Navigator.push` — e.g. from a
/// dashboard stat-card deep link. Without this, pushing those bodies
/// directly crashes with "No Material widget found" (no `Scaffold`
/// ancestor) the moment they render an `InkWell`/`TextField`/`TabBar`/etc.
/// See dashboard_screen.dart's stat-card `onTap` handlers.
///
/// [allowed] is the same gate that made the entry visible; when a live
/// permission refresh turns it false the screen pops back to the shell.
class StandaloneScreen extends StatelessWidget {
  final String title;
  final Widget child;
  final bool Function(PermissionService p)? allowed;

  const StandaloneScreen({super.key, required this.title, required this.child, this.allowed});

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              IconButton(tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop(), icon: Icon(Icons.arrow_back_rounded, color: AppColors.primary)),
              const SizedBox(width: 4),
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary))),
            ]),
            const SizedBox(height: 8),
            Expanded(child: child),
          ]),
        ),
      ),
    );
    final gate = allowed;
    return gate == null ? scaffold : PermissionGuard(allowed: gate, child: scaffold);
  }
}
