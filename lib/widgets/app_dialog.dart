/// The one dialog frame every tablet dialog should use: a fixed header, a
/// body that is the only part that scrolls, and a footer whose actions stay
/// visible no matter how long the body gets.
library;

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';

/// The only three dialog widths on tablet.
enum AppDialogSize {
  /// Confirms and 1–3 field master forms.
  small(440),

  /// Detail views and 4–12 field forms.
  medium(640),

  /// Patient, check-in, counselling, surgery and user forms.
  large(920);

  const AppDialogSize(this.width);
  final double width;
}

/// Hosts a full form pane that draws its own header and actions (Patient
/// form, OT appointment, user, counselling, ward, ...), on the same white
/// untinted surface as [AppDialog]. [wide] is for the multi-section panes.
Future<T?> showPaneDialog<T>(
  BuildContext context, {
  required Widget Function(BuildContext dCtx) builder,
  bool wide = false,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dCtx) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: ConstrainedBox(
        constraints: wide ? const BoxConstraints(maxWidth: 920, maxHeight: 800) : const BoxConstraints(maxWidth: 760, maxHeight: 680),
        child: Padding(padding: const EdgeInsets.all(20), child: builder(dCtx)),
      ),
    ),
  );
}

class AppDialog extends StatelessWidget {
  /// Usually an [AppDialogHeader].
  final Widget header;
  final Widget body;

  /// Laid out right-aligned in the footer: Cancel/Close first, the primary
  /// action last.
  final List<Widget> actions;
  final AppDialogSize size;
  final EdgeInsetsGeometry bodyPadding;

  const AppDialog({
    super.key,
    required this.header,
    required this.body,
    this.actions = const [],
    this.size = AppDialogSize.medium,
    this.bodyPadding = const EdgeInsets.fromLTRB(24, 20, 24, 20),
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: size.width, maxHeight: screenHeight * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Flexible(child: SingleChildScrollView(padding: bodyPadding, child: body)),
            if (actions.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.primaryA08))),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  children: actions,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
