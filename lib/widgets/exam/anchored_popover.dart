import 'package:flutter/material.dart';

/// Anchored popover mechanism used by every exam-field picker (Phase 4b/4c
/// decision — see EXAMINATIONS_MODULE_PRD.md §8.2: pickers open as a popover
/// anchored to their field, not a bottom sheet / full-screen dialog like
/// mobile. One controller per field; wrap the field in
/// `CompositedTransformTarget(link: controller.link, child: ...)`.
class PopoverController {
  final LayerLink link = LayerLink();
  OverlayEntry? _entry;

  bool get isOpen => _entry != null;

  void show(BuildContext context, WidgetBuilder builder, {double width = 340, double maxHeight = 420}) {
    close();
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: close)),
          CompositedTransformFollower(
            link: link,
            showWhenUnlinked: false,
            offset: const Offset(0, 46),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
                child: builder(ctx),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_entry!);
  }

  void close() {
    _entry?.remove();
    _entry = null;
  }

  void dispose() => close();
}
