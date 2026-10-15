import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_radius.dart';
import '../app_error_state.dart';
import '../detail_card_kit.dart';
import '../ot_panel_header.dart';
import '../scaled_data_table.dart';
import '../table_row_action.dart';
import '../segmented_pill_toggle.dart';
import '../skeleton.dart';

/// One tab pill on a [DeskHomePanel] — `key` is the filter value passed
/// straight to the desk's own `fetchBookings(filter: ...)` service call
/// (`queue` / `history` / `refunds`), `label` is the web-parity tab title,
/// `count` is that tab's real total (from the list endpoint's pagination
/// `meta.total`, not just how many rows happen to be fetched for display).
class DeskHomePanelTab {
  final String key;
  final String label;
  final int count;
  const DeskHomePanelTab({required this.key, required this.label, required this.count});
}

/// The compact "desk panel" the hospital dashboard home shows directly below
/// the existing stat cards for the 4 staff-desk roles (Accountant, Ward
/// Management, OT Assistant, Discharge Counter) — web's
/// `accountant-panel.blade.php`/`ward-panel.blade.php`/
/// `ot-assistant-panel.blade.php`/`discharge-panel.blade.php` chrome exactly:
/// a colored header (icon + title + "N patient(s)" + an "Open full page"
/// link), a row of tab pills with per-tab count badges, and a single
/// [ScaledDataTable] for the active tab's rows (no search/pagination — this
/// is the compact preview, not the dedicated full desk screen). Shared
/// chrome only; each role's own `*DeskHomePanel` StatefulWidget owns its own
/// data fetch (via the same service the dedicated desk screen already
/// calls), row/column layout and action buttons, and passes them in here.
class DeskHomePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final int totalCount;
  final VoidCallback onOpenFullPage;
  final List<DeskHomePanelTab> tabs;
  final String activeTab;
  final ValueChanged<String> onTabChanged;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final List<ScaledTableColumn> columns;
  final List<List<Widget>> rows;
  final String emptyMessage;

  const DeskHomePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.totalCount,
    required this.onOpenFullPage,
    required this.tabs,
    required this.activeTab,
    required this.onTabChanged,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.columns,
    required this.rows,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        OtPanelHeader(
          icon: icon,
          title: title,
          subtitle: '$totalCount patient${totalCount == 1 ? '' : 's'}',
          actions: [_openFullPageButton()],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedPillToggle<String>(
              options: tabs.map((t) => (value: t.key, label: '${t.label} (${t.count})')).toList(),
              selected: activeTab,
              onChanged: onTabChanged,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          child: _buildBody(),
        ),
      ]),
    );
  }

  Widget _openFullPageButton() {
    return OutlinedButton.icon(
      onPressed: onOpenFullPage,
      icon: const Icon(Icons.open_in_new_rounded, size: 13, color: Colors.white),
      label: const Text('Open full page', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
    );
  }

  Widget _buildBody() {
    if (loading) return const AppSkeletonList(count: 3, itemHeight: 40, padding: EdgeInsets.symmetric(horizontal: 16));
    if (error != null) return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: AppErrorState(message: error!, onRetry: onRetry));
    return ScaledDataTable(columns: columns, rows: rows, emptyMessage: emptyMessage);
  }
}

/// The "avatar-initial + full name + a second line (patient code / phone)"
/// patient cell every one of web's 4 desk panels opens its row with — shared
/// here so all 4 `*DeskHomePanel` row builders use the exact same layout
/// instead of 4 near-identical copies.
Widget deskPatientNameCell({required String name, String? subLine, List<Color>? avatarColors}) {
  return Row(mainAxisSize: MainAxisSize.min, children: [
    GradientAvatar(name, size: 26, colors: avatarColors),
    const SizedBox(width: 8),
    Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(name, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        if (subLine != null && subLine.isNotEmpty)
          Text(subLine, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
      ]),
    ),
  ]);
}

/// Labeled row action shared by the OT desk home panels. [color] is the
/// old call-site hint (primary = filled, red = danger); null is an outlined
/// secondary action such as View.
Widget deskTableActionBtn({required IconData icon, required String label, Color? color, required VoidCallback onTap}) {
  return TableLabelAction(icon: icon, label: label, onTap: onTap, tone: tableLabelToneFor(color));
}

/// A plain, non-tappable table-action label (e.g. "Payment Completed",
/// "Package Not Set") — same look as the dedicated desk screens' own
/// `_tableActionLabel`.
Widget deskTableActionLabel(String text, {Color? color}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? AppColors.textSecondary)),
  );
}

/// A small colored status/payment pill — same look as the dedicated desk
/// screens' own inline pill `Container`s.
Widget deskStatusPill(String text, Color color) {
  return Align(
    alignment: Alignment.centerLeft,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full)),
        child: Text(text, maxLines: 1, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
      ),
    ),
  );
}
