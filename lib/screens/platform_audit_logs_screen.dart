import 'package:flutter/material.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/app_text_styles.dart';
import '../models/platform_admin_models.dart';
import '../models/platform_audit_log_models.dart';
import '../services/platform_audit_log_service.dart';
import '../utils/app_decorations.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_pagination_bar.dart';
import '../widgets/skeleton.dart';

/// Tablet Platform Audit Logs — collapsible left filter panel instead of
/// mobile's filter bottom sheet, matching the Reports screen's convention
/// (closed by default, opens on tap). Business logic (action/hospital/date
/// filters, pagination) ported unchanged from
/// eye_care_app/lib/screens/platform_audit_logs_screen.dart.
class PlatformAuditLogsScreen extends StatefulWidget {
  final PlatformAdmin admin;

  const PlatformAuditLogsScreen({super.key, required this.admin});

  @override
  State<PlatformAuditLogsScreen> createState() => _PlatformAuditLogsScreenState();
}

class _PlatformAuditLogsScreenState extends State<PlatformAuditLogsScreen> {
  bool _loading = true;
  String? _error;
  PlatformAuditLogListResult? _result;
  int _page = 1;

  final _actionCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  int? _tenantIdFilter;
  bool _filterOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _actionCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() { _loading = true; _error = null; });
    final result = await PlatformAuditLogService.instance.getLogs(action: _actionCtrl.text.trim().isEmpty ? null : _actionCtrl.text.trim(), tenantId: _tenantIdFilter, from: _fromCtrl.text.trim().isEmpty ? null : _fromCtrl.text.trim(), to: _toCtrl.text.trim().isEmpty ? null : _toCtrl.text.trim(), page: page);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _page = page;
      if (result == null) {
        _error = 'Could not load audit logs.';
      } else {
        _result = result;
      }
    });
  }

  void _clearFilters() {
    _actionCtrl.clear();
    _fromCtrl.clear();
    _toCtrl.clear();
    setState(() => _tenantIdFilter = null);
    _load();
  }

  bool get _hasActiveFilters => _actionCtrl.text.isNotEmpty || _tenantIdFilter != null || _fromCtrl.text.isNotEmpty || _toCtrl.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= AppBreakpoints.medium;
      final filterPanel = _buildFilterPanel();
      final content = _buildContent();
      if (!wide) {
        return Column(children: [filterPanel, const SizedBox(height: 16), Expanded(child: content)]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 300, child: filterPanel), const SizedBox(width: 20), Expanded(child: content)]);
    });
  }

  Widget _buildFilterPanel() {
    final tenants = _result?.tenants ?? [];
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _filterOpen = !_filterOpen),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Row(children: [
              Icon(Icons.filter_list_rounded, size: 18, color: _hasActiveFilters ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(child: Text(_hasActiveFilters ? 'Filters Applied' : 'Filter Logs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _hasActiveFilters ? AppColors.primary : AppColors.textPrimary))),
              if (_hasActiveFilters) TextButton(onPressed: _clearFilters, child: Text('Clear', style: TextStyle(color: AppColors.red, fontSize: 12))),
              Icon(_filterOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20, color: AppColors.textSecondary),
            ]),
          ),
          if (_filterOpen) ...[
            const SizedBox(height: 14),
            Text('Action', style: AppTextStyles.sectionLabel),
            const SizedBox(height: 6),
            TextField(controller: _actionCtrl, decoration: AppDecorations.inputDecoration(hintText: 'e.g. hospital.suspended', isDense: true)),
            const SizedBox(height: 14),
            Text('Hospital', style: AppTextStyles.sectionLabel),
            const SizedBox(height: 6),
            DropdownButtonFormField<int?>(
              key: ValueKey(_tenantIdFilter),
              initialValue: _tenantIdFilter,
              decoration: AppDecorations.inputDecoration(hintText: 'All Hospitals', isDense: true),
              items: [const DropdownMenuItem(value: null, child: Text('All Hospitals')), ...tenants.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name, overflow: TextOverflow.ellipsis)))],
              onChanged: (v) => setState(() => _tenantIdFilter = v),
            ),
            const SizedBox(height: 14),
            Text('Date Range', style: AppTextStyles.sectionLabel),
            const SizedBox(height: 6),
            TextField(controller: _fromCtrl, decoration: AppDecorations.inputDecoration(hintText: 'From (YYYY-MM-DD)', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: _toCtrl, decoration: AppDecorations.inputDecoration(hintText: 'To (YYYY-MM-DD)', isDense: true)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(onPressed: () => _load(), icon: const Icon(Icons.search_rounded, size: 16), label: const Text('Apply Filters'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Row(children: [
          Text('Audit Logs', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
          if (_result != null) ...[const SizedBox(width: 10), Text('${_result!.total} entries', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600))],
          const Spacer(),
          IconButton(onPressed: _loading ? null : () => _load(page: _page), icon: Icon(Icons.refresh_rounded, color: AppColors.primary)),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const AppSkeletonList(count: 6, itemHeight: 84)
              : _error != null
                  ? AppErrorState(message: _error!, onRetry: _load)
                  : (_result?.logs.isEmpty ?? true)
                      ? AppEmptyState(message: 'No audit logs found.', icon: Icons.history_outlined, onRefresh: _load)
                      : Column(children: [
                          Expanded(
                            child: ListView.separated(
                              itemCount: _result!.logs.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (_, i) => _AuditLogCard(log: _result!.logs[i]),
                            ),
                          ),
                          if (_result!.lastPage > 1) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: AppPaginationBar(currentPage: _page, totalPages: _result!.lastPage, onPageChange: (p) => _load(page: p))),
                        ]),
        ),
      ],
    );
  }
}

class _AuditLogCard extends StatelessWidget {
  final PlatformAuditLog log;
  const _AuditLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final color = log.actionColor;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full)), child: Text(log.action, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color))),
            const Spacer(),
            if (log.createdAt != null) Text(_formatDateTime(log.createdAt!), style: AppTextStyles.cardSubtitle),
          ]),
          if (log.description != null && log.description!.isNotEmpty) ...[const SizedBox(height: 6), Text(log.description!, style: AppTextStyles.bodyMedium)],
          const SizedBox(height: 6),
          Row(children: [
            if (log.tenantName != null) ...[_chip(Icons.local_hospital_outlined, log.tenantName!, AppColors.secondary), const SizedBox(width: 6)] else _chip(Icons.shield_outlined, 'Platform', AppColors.primary),
            if (log.adminName != null) ...[const SizedBox(width: 6), _chip(Icons.person_outline_rounded, log.adminName!, AppColors.textSecondary)],
            if (log.ipAddress != null) ...[const Spacer(), Text(log.ipAddress!, style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textDisabled))],
          ]),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 11, color: color), const SizedBox(width: 3), Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color))]);
  }

  String _formatDateTime(DateTime dt) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${m[dt.month - 1]}, $h:$min';
  }
}
