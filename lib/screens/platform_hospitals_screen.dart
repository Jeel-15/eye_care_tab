import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/app_text_styles.dart';
import '../models/platform_admin_models.dart';
import '../models/platform_tenant_models.dart';
import '../services/platform_tenant_service.dart';
import '../utils/app_decorations.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_pagination_bar.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/app_section_header.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_badge.dart';
import 'platform_hospital_form_screen.dart';

/// Tablet Platform Hospitals — Pattern A (list + detail split), consolidating
/// mobile's 3 separate screens (list, detail, form) into one hub, matching
/// the Patients/Users/FOC convention used throughout the hospital-side app.
/// Business logic (search/filter/paginate, lifecycle actions) ported
/// unchanged from eye_care_app/lib/screens/platform_hospitals_screen.dart +
/// platform_hospital_detail_screen.dart.
class PlatformHospitalsScreen extends StatefulWidget {
  final PlatformAdmin admin;

  const PlatformHospitalsScreen({super.key, required this.admin});

  @override
  State<PlatformHospitalsScreen> createState() => _PlatformHospitalsScreenState();
}

enum _PaneMode { view, add, edit }

class _PlatformHospitalsScreenState extends State<PlatformHospitalsScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  List<TenantSummary> _hospitals = [];
  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;
  String? _statusFilter;

  int? _selectedId;
  _PaneMode _paneMode = _PaneMode.view;

  static const _filters = [null, 'trial', 'active', 'grace', 'suspended', 'inactive'];
  static const _filterLabels = ['All', 'Trial', 'Active', 'Grace', 'Suspended', 'Inactive'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() { _loading = true; _error = null; });
    final result = await PlatformTenantService.instance.list(search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(), status: _statusFilter, page: page);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result == null) {
        _error = 'Could not load hospitals. Check your connection.';
      } else {
        _hospitals = result.hospitals;
        _currentPage = page;
        _lastPage = result.lastPage;
        _total = result.total;
      }
    });
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load());
  }

  void _selectHospital(TenantSummary t) => setState(() { _selectedId = t.id; _paneMode = _PaneMode.view; });
  void _openAdd() => setState(() { _selectedId = null; _paneMode = _PaneMode.add; });
  void _openEdit(int id) => setState(() { _selectedId = id; _paneMode = _PaneMode.edit; });
  void _cancelForm() => setState(() => _paneMode = _PaneMode.view);
  void _onFormSaved() {
    setState(() => _paneMode = _PaneMode.view);
    _load(page: _currentPage);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final splitView = constraints.maxWidth >= AppBreakpoints.medium;
      final listPane = _buildListPane();
      final detailPane = _buildDetailPane();
      if (!splitView) {
        return _selectedId != null || _paneMode != _PaneMode.view
            ? Column(children: [
                TextButton.icon(onPressed: () => setState(() { _selectedId = null; _paneMode = _PaneMode.view; }), icon: const Icon(Icons.arrow_back_rounded, size: 18), label: const Text('Back to list')),
                Expanded(child: detailPane),
              ])
            : listPane;
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 380, child: listPane), const SizedBox(width: 20), Expanded(child: detailPane)]);
    });
  }

  // ── List pane ────────────────────────────────────────────────────────

  Widget _buildListPane() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hospitals', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
                if (_total > 0) Text('$_total hospitals', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ]),
              const Spacer(),
              IconButton(icon: Icon(Icons.add_business_rounded, color: AppColors.primary, size: 22), tooltip: 'New Hospital', onPressed: _openAdd),
            ]),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: AppSearchBar(controller: _searchCtrl, hint: 'Search hospitals, admin, city...', onChanged: _onSearch, onClear: () => _load())),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final selected = _statusFilter == _filters[i];
                return ChoiceChip(
                  label: Text(_filterLabels[i]),
                  selected: selected,
                  onSelected: (_) { setState(() => _statusFilter = _filters[i]); _load(); },
                  selectedColor: AppColors.primaryA15,
                  labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textSecondary),
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: selected ? AppColors.primary : AppColors.primaryA12),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Expanded(child: _buildList()),
          if (_lastPage > 1) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: AppPaginationBar(currentPage: _currentPage, totalPages: _lastPage, onPageChange: (p) => _load(page: p))),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const AppSkeletonList(count: 5, itemHeight: 68);
    if (_error != null) return AppErrorState(message: _error!, onRetry: () => _load(page: _currentPage));
    if (_hospitals.isEmpty) return AppEmptyState(message: 'No hospitals found.', icon: Icons.local_hospital_outlined, onRefresh: () => _load());
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _hospitals.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.primaryA08),
      itemBuilder: (_, i) {
        final t = _hospitals[i];
        return _HospitalListTile(tenant: t, selected: t.id == _selectedId, onTap: () => _selectHospital(t));
      },
    );
  }

  // ── Detail pane ─────────────────────────────────────────────────────────

  Widget _buildDetailPane() {
    if (_paneMode == _PaneMode.add) {
      return _panelBox(child: PlatformHospitalFormScreen(onSaved: _onFormSaved, onCancel: _cancelForm));
    }
    if (_selectedId == null) {
      return _panelBox(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_hospital_outlined, size: 56, color: AppColors.primaryA22),
            const SizedBox(height: 12),
            Text('Select a hospital to view details', style: TextStyle(fontSize: 13, color: AppColors.primaryA55)),
          ]),
        ),
      );
    }
    return _panelBox(
      child: _HospitalDetailPane(
        key: ValueKey(_selectedId),
        tenantId: _selectedId!,
        editMode: _paneMode == _PaneMode.edit,
        onEdit: () => _openEdit(_selectedId!),
        onSaved: _onFormSaved,
        onCancelEdit: () => setState(() => _paneMode = _PaneMode.view),
        onArchived: () {
          setState(() { _selectedId = null; _paneMode = _PaneMode.view; });
          _load(page: _currentPage);
        },
        onChanged: () => _load(page: _currentPage),
      ),
    );
  }

  Widget _panelBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      child: child,
    );
  }
}

// ── Full-screen detail route (pushed from Billing's subscription cards,
// which aren't inside the Hospitals list+detail pane) ────────────────────

class PlatformHospitalDetailRoute extends StatefulWidget {
  final int tenantId;

  const PlatformHospitalDetailRoute({super.key, required this.tenantId});

  @override
  State<PlatformHospitalDetailRoute> createState() => _PlatformHospitalDetailRouteState();
}

class _PlatformHospitalDetailRouteState extends State<PlatformHospitalDetailRoute> {
  bool _editMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, title: const Text('Hospital Detail')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _HospitalDetailPane(
          key: ValueKey(_editMode),
          tenantId: widget.tenantId,
          editMode: _editMode,
          onEdit: () => setState(() => _editMode = true),
          onSaved: () => setState(() => _editMode = false),
          onCancelEdit: () => setState(() => _editMode = false),
          onArchived: () => Navigator.pop(context),
          onChanged: () {},
        ),
      ),
    );
  }
}

// ── List tile ──────────────────────────────────────────────────────────

class _HospitalListTile extends StatelessWidget {
  final TenantSummary tenant;
  final bool selected;
  final VoidCallback onTap;

  const _HospitalListTile({required this.tenant, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = tenant;
    return Material(
      color: selected ? AppColors.primaryA08 : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.primaryA10, borderRadius: BorderRadius.circular(AppRadius.sm)), child: Center(child: Text(t.name.isNotEmpty ? t.name[0].toUpperCase() : '?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary), overflow: TextOverflow.ellipsis),
                Text('/${t.slug}${t.adminName != null ? ' · ${t.adminName}' : ''}', style: TextStyle(fontSize: 11, color: AppColors.primaryA55), overflow: TextOverflow.ellipsis),
              ]),
            ),
            const SizedBox(width: 8),
            StatusBadge.hospitalStatus(t.status),
          ]),
        ),
      ),
    );
  }
}

// ── Detail pane (fetches TenantDetail by id) ──────────────────────────────

class _HospitalDetailPane extends StatefulWidget {
  final int tenantId;
  final bool editMode;
  final VoidCallback onEdit;
  final VoidCallback onSaved;
  final VoidCallback onCancelEdit;
  final VoidCallback onArchived;
  final VoidCallback onChanged;

  const _HospitalDetailPane({super.key, required this.tenantId, required this.editMode, required this.onEdit, required this.onSaved, required this.onCancelEdit, required this.onArchived, required this.onChanged});

  @override
  State<_HospitalDetailPane> createState() => _HospitalDetailPaneState();
}

class _HospitalDetailPaneState extends State<_HospitalDetailPane> {
  bool _loading = true;
  String? _error;
  TenantDetail? _tenant;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final detail = await PlatformTenantService.instance.getDetail(widget.tenantId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (detail == null) {
        _error = 'Could not load hospital details.';
      } else {
        _tenant = detail;
      }
    });
  }

  Future<void> _confirmAndAct({required String title, required String body, required String actionLabel, required Color actionColor, required Future<({bool success, String message})> Function() action}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(title, style: AppTextStyles.headingSmall),
        content: Text(body, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(actionLabel, style: TextStyle(color: actionColor, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await action();
    if (!mounted) return;
    showAppSnackBar(context, result.message, isSuccess: result.success, isError: !result.success);
    if (result.success) {
      _load();
      widget.onChanged();
    }
  }

  Future<void> _extendGrace() async {
    int days = 7;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: const Text('Extend Grace Period', style: AppTextStyles.headingSmall),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose number of days to extend:'),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(icon: const Icon(Icons.remove_rounded), onPressed: days > 1 ? () => set(() => days--) : null),
                Container(width: 60, height: 40, decoration: AppDecorations.card(), child: Center(child: Text('$days', style: AppTextStyles.headingSmall))),
                IconButton(icon: const Icon(Icons.add_rounded), onPressed: days < 90 ? () => set(() => days++) : null),
              ]),
              Text('days', style: AppTextStyles.bodySmall),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Extend', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await PlatformTenantService.instance.extendGrace(widget.tenantId, days);
    if (!mounted) return;
    showAppSnackBar(context, result.message, isSuccess: result.success, isError: !result.success);
    if (result.success) {
      _load();
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) return AppErrorState(message: _error!, onRetry: _load);
    final t = _tenant!;
    if (widget.editMode) {
      return PlatformHospitalFormScreen(tenant: t, onSaved: widget.onSaved, onCancel: widget.onCancelEdit);
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(t.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary))),
            if (!t.isArchived) IconButton(onPressed: widget.onEdit, icon: const Icon(Icons.edit_outlined), tooltip: 'Edit', color: AppColors.primary),
          ]),
          const SizedBox(height: 16),
          _buildStatusStrip(t),
          const SizedBox(height: 16),
          const AppSectionHeader(title: 'Hospital Info'),
          _buildInfoCard(t),
          const SizedBox(height: 16),
          if (!t.isArchived) ...[const AppSectionHeader(title: 'Quick Actions'), _buildQuickActions(t), const SizedBox(height: 16)],
          const AppSectionHeader(title: 'Subscription History'),
          _buildSubscriptions(t.subscriptions),
          const SizedBox(height: 16),
          const AppSectionHeader(title: 'Payment History'),
          _buildPayments(t.payments),
        ],
      ),
    );
  }

  Widget _buildStatusStrip(TenantDetail t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppDecorations.card(),
      child: Column(children: [
        Row(children: [Expanded(child: _stripItem('Status', '', badge: StatusBadge.hospitalStatus(t.status))), Expanded(child: _stripItem('Trial Ends', t.trialEndsAt != null ? _formatDate(t.trialEndsAt!) : '—'))]),
        const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, thickness: 0.5)),
        Row(children: [Expanded(child: _stripItem('Subscriptions', '${t.subscriptions.length}')), Expanded(child: _stripItem('Payments', '${t.payments.length}'))]),
      ]),
    );
  }

  Widget _stripItem(String label, String value, {Widget? badge}) {
    return Column(children: [
      badge ?? Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 3),
      Text(label, style: AppTextStyles.cardSubtitle, textAlign: TextAlign.center),
    ]);
  }

  Widget _buildInfoCard(TenantDetail t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(),
      child: Column(children: [
        _infoRow('Hospital Name', t.name),
        _infoRow('Slug', '/${t.slug}'),
        if (t.hospitalCode != null) _infoRow('Hospital Code', t.hospitalCode!),
        _infoRow('Admin Name', t.adminName ?? '—'),
        _infoRow('Admin Email', t.adminEmail ?? '—'),
        _infoRow('Admin Phone', t.adminPhone ?? '—'),
        _infoRow('City', t.city ?? '—'),
        _infoRow('State', t.state ?? '—'),
        _infoRow('Country', t.country ?? '—'),
        _infoRow('Timezone', t.timezone ?? '—'),
        _infoRow('Registered', t.createdAt != null ? _formatDateTime(t.createdAt!) : '—'),
        _infoRow('Setup Done', t.isSetupDone ? 'Yes' : 'No', isLast: true),
      ]),
    );
  }

  Widget _infoRow(String label, String value, {bool isLast = false}) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
        ]),
      ),
      if (!isLast) Divider(height: 1, color: AppColors.primaryA05),
    ]);
  }

  Widget _buildQuickActions(TenantDetail t) {
    final actions = <_QuickAction>[];
    final status = t.status;

    if (status == 'trial' || status == 'grace' || status == 'inactive') {
      actions.add(_QuickAction('Activate', Icons.check_circle_outline_rounded, AppColors.green, () => _confirmAndAct(title: 'Activate Hospital', body: "Activate '${t.name}'? They will get full access.", actionLabel: 'Activate', actionColor: AppColors.green, action: () => PlatformTenantService.instance.activate(t.id))));
    }
    if (status == 'active' || status == 'trial') {
      actions.add(_QuickAction('Suspend', Icons.block_rounded, AppColors.red, () => _confirmAndAct(title: 'Suspend Hospital', body: "Suspend '${t.name}'? All staff will lose access immediately.", actionLabel: 'Suspend', actionColor: AppColors.red, action: () => PlatformTenantService.instance.suspend(t.id))));
    }
    if (status == 'suspended') {
      actions.add(_QuickAction('Reactivate', Icons.refresh_rounded, AppColors.secondary, () => _confirmAndAct(title: 'Reactivate Hospital', body: "Reactivate '${t.name}'?", actionLabel: 'Reactivate', actionColor: AppColors.secondary, action: () => PlatformTenantService.instance.reactivate(t.id))));
    }
    if (status != 'suspended' && status != 'inactive') {
      actions.add(_QuickAction('Extend Grace', Icons.hourglass_bottom_rounded, AppColors.orange, _extendGrace));
    }
    actions.add(_QuickAction('Re-seed Masters', Icons.refresh_rounded, AppColors.teal, () => _confirmAndAct(title: 'Re-seed Default Masters', body: "Re-seed default masters for '${t.name}'? This will re-run the master seeder job.", actionLabel: 'Re-seed', actionColor: AppColors.teal, action: () => PlatformTenantService.instance.reseedMasters(t.id))));
    actions.add(_QuickAction('Archive', Icons.archive_outlined, AppColors.textSecondary, () => _confirmAndAct(
          title: 'Archive Hospital',
          body: "Archive '${t.name}'? Data is retained for 30 days.",
          actionLabel: 'Archive',
          actionColor: AppColors.red,
          action: () async {
            final r = await PlatformTenantService.instance.archive(t.id);
            if (r.success) widget.onArchived();
            return r;
          },
        )));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions.map((a) => OutlinedButton.icon(
        onPressed: a.onTap,
        icon: Icon(a.icon, size: 15),
        label: Text(a.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(foregroundColor: a.color, side: BorderSide(color: a.color.withValues(alpha: 0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), visualDensity: VisualDensity.compact),
      )).toList(),
    );
  }

  Widget _buildSubscriptions(List<SubscriptionItem> subs) {
    if (subs.isEmpty) {
      return Container(padding: const EdgeInsets.symmetric(vertical: 20), decoration: AppDecorations.card(), child: const AppEmptyState(message: 'No subscriptions yet.', icon: Icons.receipt_long_outlined));
    }
    return Container(
      decoration: AppDecorations.card(),
      child: Column(
        children: subs.asMap().entries.map((e) {
          final s = e.value;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.cycle.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)), Text('${_formatDate2(s.startsAt)} – ${_formatDate2(s.endsAt)}', style: AppTextStyles.cardSubtitle)])),
                Text('₹${s.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(width: 8),
                StatusBadge.subscriptionStatus(s.status),
              ]),
            ),
            if (e.key < subs.length - 1) Divider(height: 1, color: AppColors.primaryA05),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildPayments(List<PaymentItem> payments) {
    if (payments.isEmpty) {
      return Container(padding: const EdgeInsets.symmetric(vertical: 20), decoration: AppDecorations.card(), child: const AppEmptyState(message: 'No payments yet.', icon: Icons.payment_outlined));
    }
    return Container(
      decoration: AppDecorations.card(),
      child: Column(
        children: payments.asMap().entries.map((e) {
          final p = e.value;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: AppDecorations.pill(color: p.method == 'offline' ? AppColors.orange : AppColors.secondary), child: Text(p.method.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: p.method == 'offline' ? AppColors.orange : AppColors.secondary))),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.cycle.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)), if (p.transactionId != null) Text(p.transactionId!, style: AppTextStyles.cardSubtitle)])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('₹${p.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)), StatusBadge.paymentStatus(p.status)]),
              ]),
            ),
            if (e.key < payments.length - 1) Divider(height: 1, color: AppColors.primaryA05),
          ]);
        }).toList(),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  String _formatDate2(DateTime? dt) => dt == null ? '—' : _formatDate(dt);

  String _formatDateTime(DateTime dt) => _formatDate(dt);
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(this.label, this.icon, this.color, this.onTap);
}
