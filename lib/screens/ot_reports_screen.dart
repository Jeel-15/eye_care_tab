import 'package:flutter/material.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/ot_report_models.dart';
import '../services/ot_report_service.dart';
import '../widgets/app_error_state.dart';
import 'ot_report_viewer_screen.dart';

class _ReportMeta {
  final IconData icon;
  final Color color;
  const _ReportMeta(this.icon, this.color);
}

Map<String, _ReportMeta> get _itemMeta => <String, _ReportMeta>{
  'appointments': _ReportMeta(Icons.event_note_rounded, AppColors.primary),
  'registration': _ReportMeta(Icons.assignment_ind_rounded, AppColors.green),
  'doctor-consultation': _ReportMeta(Icons.medical_services_rounded, AppColors.orange),
  'counselling': _ReportMeta(Icons.support_agent_rounded, AppColors.teal),
  'billing': _ReportMeta(Icons.receipt_long_rounded, AppColors.blue),
  'ot': _ReportMeta(Icons.local_hospital_rounded, AppColors.purple),
  'discharge': _ReportMeta(Icons.assignment_turned_in_rounded, AppColors.tealDark),
  'hospital-report': _ReportMeta(Icons.description_rounded, AppColors.primary),
  'surgery-wise': _ReportMeta(Icons.cut_rounded, AppColors.orange),
  'doctor-wise': _ReportMeta(Icons.person_rounded, AppColors.teal),
  'lens-usage': _ReportMeta(Icons.remove_red_eye_rounded, AppColors.blue),
  'complications': _ReportMeta(Icons.warning_amber_rounded, const Color(0xFFE74C3C)),
  'daily-collection': _ReportMeta(Icons.today_rounded, AppColors.primary),
  'monthly-revenue': _ReportMeta(Icons.calendar_month_rounded, AppColors.teal),
  'package-wise': _ReportMeta(Icons.card_giftcard_rounded, AppColors.purple),
  'pending-payments': _ReportMeta(Icons.pending_actions_rounded, const Color(0xFFE74C3C)),
};
_ReportMeta get _defaultItemMeta => _ReportMeta(Icons.insights_rounded, AppColors.primary);
_ReportMeta _metaFor(String key) => _itemMeta[key] ?? _defaultItemMeta;

class _GroupMeta {
  final IconData icon;
  final Color color;
  const _GroupMeta(this.icon, this.color);
}

Map<String, _GroupMeta> get _groupMeta => <String, _GroupMeta>{
  'Operational Registers': _GroupMeta(Icons.list_alt_rounded, AppColors.primary),
  'Clinical Reports': _GroupMeta(Icons.medical_information_rounded, AppColors.purple),
  'Financial Reports': _GroupMeta(Icons.payments_rounded, AppColors.green),
};
_GroupMeta get _defaultGroupMeta => _GroupMeta(Icons.folder_rounded, AppColors.primary);
_GroupMeta _groupMetaFor(String title) => _groupMeta[title] ?? _defaultGroupMeta;

/// Tablet OT Reports hub — Pattern A (list+detail split), matching
/// masters_screen.dart's convention: left pane groups report types under
/// colored pill section headers with a 2-column icon-tile grid, right pane
/// embeds the selected report's viewer (OtReportViewerScreen, no push
/// navigation). Previously used a plain single-column list + full pushed
/// route per report (Pattern C) — converted for consistency with the rest
/// of the tablet app (2026-08-25, user-reported: "design bau kharab 6e").
class OtReportsScreen extends StatefulWidget {
  const OtReportsScreen({super.key});

  @override
  State<OtReportsScreen> createState() => _OtReportsScreenState();
}

class _OtReportsScreenState extends State<OtReportsScreen> {
  bool _loading = true;
  String? _error;
  List<OtReportTypeGroup> _groups = [];
  OtReportType? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final groups = await OtReportService.instance.fetchReportTypes();
      if (mounted) setState(() { _groups = groups; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _groups.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null && _groups.isEmpty) {
      return AppErrorState(message: _error!, onRetry: _load);
    }

    return LayoutBuilder(builder: (context, c) {
      final listPane = _buildListPane();
      final detailPane = _buildDetailPane();
      if (c.maxWidth < AppBreakpoints.medium) {
        return _selected == null
            ? listPane
            : Column(children: [
                TextButton.icon(
                  onPressed: () => setState(() => _selected = null),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back to OT Reports'),
                ),
                Expanded(child: detailPane),
              ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 320, child: listPane),
        const SizedBox(width: 20),
        Expanded(child: detailPane),
      ]);
    });
  }

  Widget _buildListPane() {
    final totalCount = _groups.fold(0, (sum, g) => sum + g.types.length);
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Expanded(child: Text('OT Reports', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(AppRadius.full), boxShadow: [BoxShadow(color: AppColors.teal.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))]),
              child: Text('$totalCount reports', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5)),
            ),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            children: [
              for (final group in _groups) ...[
                _sectionHeader(group),
                const SizedBox(height: 10),
                _itemGrid(group.types),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  Widget _sectionHeader(OtReportTypeGroup group) {
    final meta = _groupMetaFor(group.group);
    final c = meta.color;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: c.withValues(alpha: 0.14))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [c, c.withValues(alpha: 0.72)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(AppRadius.full), boxShadow: [BoxShadow(color: c.withValues(alpha: 0.32), blurRadius: 8, offset: const Offset(0, 2))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(meta.icon, color: Colors.white, size: 12),
            const SizedBox(width: 5),
            Text(group.group.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
          ]),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: c.withValues(alpha: 0.20))),
          child: Text('${group.types.length}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c)),
        ),
      ]),
    );
  }

  // 2-column icon-button grid — mirrors masters_screen.dart's _itemGrid.
  Widget _itemGrid(List<OtReportType> items) {
    return LayoutBuilder(builder: (_, c) {
      final w = (c.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final item in items) SizedBox(width: w, child: _tile(item))],
      );
    });
  }

  Widget _tile(OtReportType item) {
    final active = _selected?.key == item.key;
    final meta = _metaFor(item.key);
    final c = meta.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selected = item),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            color: active ? c.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: active ? c.withValues(alpha: 0.35) : c.withValues(alpha: 0.14), width: active ? 1.5 : 1),
            boxShadow: [BoxShadow(color: c.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c.withValues(alpha: active ? 0.90 : 0.14), c.withValues(alpha: active ? 0.65 : 0.04)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: c.withValues(alpha: 0.18)),
              ),
              child: Icon(meta.icon, color: active ? Colors.white : c, size: 18),
            ),
            const SizedBox(height: 7),
            Text(item.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w800 : FontWeight.w700, color: active ? c : AppColors.darkNavy, height: 1.25)),
            const SizedBox(height: 3),
            Icon(Icons.chevron_right_rounded, size: 12, color: c.withValues(alpha: active ? 0.55 : 0.35)),
          ]),
        ),
      ),
    );
  }

  Widget _buildDetailPane() {
    final item = _selected;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      child: item == null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.insights_rounded, size: 56, color: AppColors.primaryA22),
                const SizedBox(height: 12),
                Text('Select a report to view', style: TextStyle(fontSize: 13, color: AppColors.primaryA55)),
              ]),
            )
          : OtReportViewerScreen(
              key: ValueKey(item.key),
              type: item.key,
              label: item.label,
              icon: _metaFor(item.key).icon,
              accentColor: _metaFor(item.key).color,
            ),
    );
  }
}
