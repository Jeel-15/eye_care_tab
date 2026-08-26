import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/app_text_styles.dart';
import '../models/platform_admin_models.dart';
import '../models/platform_payment_models.dart';
import '../models/platform_subscription_models.dart';
import '../services/platform_payment_service.dart';
import '../services/platform_subscription_service.dart';
import '../utils/app_decorations.dart';
import '../utils/app_route.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_pagination_bar.dart';
import '../widgets/app_section_header.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_badge.dart';
import 'platform_hospitals_screen.dart';

/// Tablet Platform Billing — embedded content (no own Scaffold/AppBar),
/// segmented Payments/Subscriptions tabs matching mobile. Record Payment
/// uses a Dialog instead of mobile's DraggableScrollableSheet, matching the
/// tablet dialog convention. Business logic (filters/pagination/invoice
/// download/offline payment recording) ported unchanged from
/// eye_care_app/lib/screens/platform_billing_screen.dart.
class PlatformBillingScreen extends StatefulWidget {
  final PlatformAdmin admin;

  const PlatformBillingScreen({super.key, required this.admin});

  @override
  State<PlatformBillingScreen> createState() => _PlatformBillingScreenState();
}

class _PlatformBillingScreenState extends State<PlatformBillingScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Billing', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
          const Spacer(),
          Container(
            height: 40,
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: AppColors.primaryA12)),
            child: Padding(padding: const EdgeInsets.all(3), child: Row(children: [_tabBtn(0, 'Payments', Icons.receipt_long_rounded), _tabBtn(1, 'Subscriptions', Icons.loop_rounded)])),
          ),
        ]),
        const SizedBox(height: 16),
        Expanded(child: _tab == 0 ? const _PaymentsTab() : const _SubscriptionsTab()),
      ],
    );
  }

  Widget _tabBtn(int index, String label, IconData icon) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: selected ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(AppRadius.full)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: selected ? Colors.white : AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Payments Tab
// ═══════════════════════════════════════════════════════════════════════

class _PaymentsTab extends StatefulWidget {
  const _PaymentsTab();

  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  bool _loading = true;
  String? _error;
  PlatformPaymentListResult? _result;
  int _page = 1;
  String? _statusFilter;
  String? _methodFilter;

  static const _statuses = [null, 'success', 'pending', 'failed'];
  static const _statusLabels = ['All', 'Success', 'Pending', 'Failed'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int page = 1}) async {
    setState(() { _loading = true; _error = null; });
    final result = await PlatformPaymentService.instance.getPayments(status: _statusFilter, method: _methodFilter, page: page);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _page = page;
      if (result == null) {
        _error = 'Could not load payments.';
      } else {
        _result = result;
      }
    });
  }

  Future<void> _downloadInvoice(PlatformPayment payment) async {
    showAppSnackBar(context, 'Preparing invoice...');
    final bytes = await PlatformPaymentService.instance.getInvoiceBytes(payment.id);
    if (!mounted) return;
    if (bytes == null) {
      showAppSnackBar(context, 'Failed to load invoice.', isError: true);
      return;
    }
    await Printing.sharePdf(bytes: bytes, filename: 'invoice_${payment.id}.pdf');
  }

  void _showRecordPaymentDialog() {
    showDialog(context: context, builder: (_) => _RecordPaymentDialog(onSaved: () => _load(page: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _statuses.length + 2,
                separatorBuilder: (ctx, ix) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  if (i < _statuses.length) {
                    final selected = _statusFilter == _statuses[i];
                    return ChoiceChip(
                      label: Text(_statusLabels[i]),
                      selected: selected,
                      onSelected: (_) { setState(() { _statusFilter = _statuses[i]; _methodFilter = null; }); _load(); },
                      selectedColor: AppColors.primaryA15,
                      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textSecondary),
                      backgroundColor: AppColors.surface,
                      side: BorderSide(color: selected ? AppColors.primary : AppColors.primaryA12),
                      visualDensity: VisualDensity.compact,
                    );
                  }
                  final isOnline = i == _statuses.length;
                  final method = isOnline ? 'online' : 'offline';
                  final selected = _methodFilter == method;
                  return ChoiceChip(
                    label: Text(isOnline ? 'Online' : 'Offline'),
                    selected: selected,
                    onSelected: (_) { setState(() => _methodFilter = selected ? null : method); _load(); },
                    selectedColor: AppColors.secondary.withValues(alpha: 0.15),
                    labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppColors.secondary : AppColors.textSecondary),
                    backgroundColor: AppColors.surface,
                    side: BorderSide(color: selected ? AppColors.secondary : AppColors.primaryA12),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(onPressed: _showRecordPaymentDialog, icon: const Icon(Icons.add_rounded, size: 16), label: const Text('Record Payment'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white)),
        ]),
        if (_result != null) Padding(padding: const EdgeInsets.only(top: 10), child: _StatsRow(stats: _result!.stats)),
        Expanded(
          child: _loading
              ? const AppSkeletonList(count: 5, itemHeight: 90)
              : _error != null
                  ? AppErrorState(message: _error!, onRetry: _load)
                  : (_result?.payments.isEmpty ?? true)
                      ? AppEmptyState(message: 'No payments found.', icon: Icons.receipt_outlined, onRefresh: _load)
                      : LayoutBuilder(builder: (context, c) {
                          final cols = c.maxWidth >= 900 ? 2 : 1;
                          return Column(children: [
                            Expanded(
                              child: GridView.builder(
                                padding: const EdgeInsets.only(top: 8),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 8, crossAxisSpacing: 12, childAspectRatio: cols == 2 ? 3.4 : 4.5),
                                itemCount: _result!.payments.length,
                                itemBuilder: (_, i) => _PaymentCard(payment: _result!.payments[i], onDownload: () => _downloadInvoice(_result!.payments[i])),
                              ),
                            ),
                            if (_result!.lastPage > 1) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: AppPaginationBar(currentPage: _page, totalPages: _result!.lastPage, onPageChange: (p) => _load(page: p))),
                          ]);
                        }),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final PlatformPaymentStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _miniStat('Total', '₹${_fmt(stats.totalRevenue)}', AppColors.green),
      const SizedBox(width: 8),
      _miniStat('This Month', '₹${_fmt(stats.thisMonth)}', AppColors.primary),
      const SizedBox(width: 8),
      _miniStat('Pending', '${stats.pendingCount}', AppColors.orange),
    ]);
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: AppDecorations.accentCard(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Container(width: 3, color: color), Expanded(child: Padding(padding: const EdgeInsets.only(left: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)), Text(label, style: AppTextStyles.cardSubtitle)])))])),
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _PaymentCard extends StatelessWidget {
  final PlatformPayment payment;
  final VoidCallback onDownload;

  const _PaymentCard({required this.payment, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    final p = payment;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(p.tenantName ?? '—', style: AppTextStyles.cardTitle, overflow: TextOverflow.ellipsis)), Text('₹${p.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary))]),
          const SizedBox(height: 6),
          Row(children: [
            _badge(p.method.toUpperCase(), p.method == 'offline' ? AppColors.orange : AppColors.secondary),
            const SizedBox(width: 6),
            _badge(p.cycle.toUpperCase(), AppColors.primary),
            const Spacer(),
            StatusBadge.paymentStatus(p.status),
            if (p.status == 'success') ...[
              const SizedBox(width: 8),
              InkWell(onTap: onDownload, borderRadius: BorderRadius.circular(AppRadius.sm), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: AppColors.primaryA10, borderRadius: BorderRadius.circular(AppRadius.sm)), child: Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppColors.primary))),
            ],
          ]),
          if (p.transactionId != null) ...[const SizedBox(height: 4), Text('TXN: ${p.transactionId}', style: AppTextStyles.cardSubtitle, overflow: TextOverflow.ellipsis)],
          if (p.paidAt != null) ...[const SizedBox(height: 2), Text(_fmtDate(p.paidAt!), style: AppTextStyles.cardSubtitle)],
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.full)), child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)));

  String _fmtDate(DateTime dt) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }
}

// ── Record Payment Dialog ────────────────────────────────────────────────

class _RecordPaymentDialog extends StatefulWidget {
  final VoidCallback onSaved;
  const _RecordPaymentDialog({required this.onSaved});

  @override
  State<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<_RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _txnCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  bool _loading = false;
  bool _tenantsLoading = true;
  List<TenantOption> _allTenants = [];
  List<TenantOption> _filteredTenants = [];
  TenantOption? _selected;
  String _cycle = 'monthly';

  @override
  void initState() {
    super.initState();
    _loadTenants();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() => _filteredTenants = q.isEmpty ? _allTenants : _allTenants.where((t) => t.name.toLowerCase().contains(q) || t.slug.toLowerCase().contains(q)).toList());
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _txnCtrl.dispose();
    _notesCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTenants() async {
    final tenants = await PlatformPaymentService.instance.getTenantOptions();
    if (!mounted) return;
    setState(() { _allTenants = tenants; _filteredTenants = tenants; _tenantsLoading = false; });
  }

  Future<void> _submit() async {
    if (_selected == null) {
      showAppSnackBar(context, 'Please select a hospital.', isError: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final result = await PlatformPaymentService.instance.storeOffline({
      'tenant_id': _selected!.id,
      'amount': double.tryParse(_amountCtrl.text.trim()) ?? 0,
      'cycle': _cycle,
      'transaction_id': _txnCtrl.text.trim().isEmpty ? null : _txnCtrl.text.trim(),
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    });

    if (!mounted) return;
    setState(() => _loading = false);
    showAppSnackBar(context, result.message, isSuccess: result.success, isError: !result.success);
    if (result.success) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: SizedBox(
        width: 480,
        height: 620,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                child: Row(children: [Expanded(child: Text('Record Offline Payment', style: AppTextStyles.headingSmall)), IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context))]),
              ),
              Divider(color: AppColors.primaryA12, height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionHeader(title: 'Hospital'),
                      const SizedBox(height: 8),
                      if (_selected != null) ...[
                        _SelectedTenantChip(tenant: _selected!, onRemove: () => setState(() { _selected = null; _searchCtrl.clear(); })),
                      ] else ...[
                        TextField(controller: _searchCtrl, decoration: AppDecorations.inputDecoration(labelText: 'Search hospitals...', prefixIcon: const Icon(Icons.search_rounded, size: 18))),
                        const SizedBox(height: 8),
                        if (_tenantsLoading)
                          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                        else if (_filteredTenants.isEmpty)
                          const Padding(padding: EdgeInsets.all(12), child: Text('No hospitals found.', style: AppTextStyles.bodySmall))
                        else
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: AppDecorations.card(),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _filteredTenants.length,
                              itemBuilder: (_, i) {
                                final t = _filteredTenants[i];
                                return InkWell(
                                  onTap: () => setState(() { _selected = t; _searchCtrl.clear(); }),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.name, style: AppTextStyles.cardTitle), Text('/${t.slug}', style: AppTextStyles.cardSubtitle)])), StatusBadge.hospitalStatus(t.status)]),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                      const SizedBox(height: 16),
                      const AppSectionHeader(title: 'Payment Details'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        decoration: AppDecorations.inputDecoration(labelText: 'Amount *').copyWith(prefixText: '₹'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final d = double.tryParse(v.trim());
                          if (d == null || d < 1) return 'Enter a valid amount (min ₹1)';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Text('Billing Cycle', style: AppTextStyles.sectionLabel),
                      const SizedBox(height: 6),
                      Row(
                        children: ['monthly', 'quarterly', 'yearly'].map((c) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(c[0].toUpperCase() + c.substring(1)),
                                  selected: _cycle == c,
                                  onSelected: (_) => setState(() => _cycle = c),
                                  selectedColor: AppColors.primaryA15,
                                  labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _cycle == c ? AppColors.primary : AppColors.textSecondary),
                                  backgroundColor: AppColors.surface,
                                  side: BorderSide(color: _cycle == c ? AppColors.primary : AppColors.primaryA12),
                                ),
                              ),
                            )).toList(),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(controller: _txnCtrl, decoration: AppDecorations.inputDecoration(labelText: 'Transaction # (optional)')),
                      const SizedBox(height: 10),
                      TextFormField(controller: _notesCtrl, maxLines: 3, decoration: AppDecorations.inputDecoration(labelText: 'Notes (optional)')),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.secondary.withValues(alpha: 0.25))),
                        child: Row(children: [Icon(Icons.info_outline_rounded, size: 16, color: AppColors.secondary), const SizedBox(width: 8), Expanded(child: Text('This will also activate the hospital if it is not already active.', style: TextStyle(fontSize: 12, color: AppColors.secondary)))]),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)), elevation: 0),
                          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('Record Payment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedTenantChip extends StatelessWidget {
  final TenantOption tenant;
  final VoidCallback onRemove;
  const _SelectedTenantChip({required this.tenant, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA20)),
      child: Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.primaryA15, borderRadius: BorderRadius.circular(AppRadius.sm)), child: Center(child: Text(tenant.name[0].toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tenant.name, style: AppTextStyles.cardTitle), Text('/${tenant.slug}', style: AppTextStyles.cardSubtitle)])),
        IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: onRemove, color: AppColors.textDisabled),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Subscriptions Tab
// ═══════════════════════════════════════════════════════════════════════

class _SubscriptionsTab extends StatefulWidget {
  const _SubscriptionsTab();

  @override
  State<_SubscriptionsTab> createState() => _SubscriptionsTabState();
}

class _SubscriptionsTabState extends State<_SubscriptionsTab> {
  bool _loading = true;
  String? _error;
  PlatformSubscriptionListResult? _result;
  int _page = 1;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int page = 1}) async {
    setState(() { _loading = true; _error = null; });
    final result = await PlatformSubscriptionService.instance.getSubscriptions(status: _statusFilter, page: page);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _page = page;
      if (result == null) {
        _error = 'Could not load subscriptions.';
      } else {
        _result = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [null, 'active', 'expired'].map((filter) {
              final label = filter == null ? 'All' : filter[0].toUpperCase() + filter.substring(1);
              final selected = _statusFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) { setState(() => _statusFilter = filter); _load(); },
                  selectedColor: AppColors.primaryA15,
                  labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textSecondary),
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: selected ? AppColors.primary : AppColors.primaryA12),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ),
        if (_result != null) Padding(padding: const EdgeInsets.only(top: 10), child: _SubStatsRow(stats: _result!.stats)),
        Expanded(
          child: _loading
              ? const AppSkeletonList(count: 5, itemHeight: 78)
              : _error != null
                  ? AppErrorState(message: _error!, onRetry: _load)
                  : (_result?.subscriptions.isEmpty ?? true)
                      ? AppEmptyState(message: 'No subscriptions found.', icon: Icons.loop_outlined, onRefresh: _load)
                      : Column(children: [
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.only(top: 8),
                              itemCount: _result!.subscriptions.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (_, i) => _SubscriptionCard(subscription: _result!.subscriptions[i]),
                            ),
                          ),
                          if (_result!.lastPage > 1) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: AppPaginationBar(currentPage: _page, totalPages: _result!.lastPage, onPageChange: (p) => _load(page: p))),
                        ]),
        ),
      ],
    );
  }
}

class _SubStatsRow extends StatelessWidget {
  final PlatformSubscriptionStats stats;
  const _SubStatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _tile('Total', '${stats.total}', AppColors.primary),
      const SizedBox(width: 8),
      _tile('Active', '${stats.active}', AppColors.green),
      const SizedBox(width: 8),
      _tile('Expired', '${stats.expired}', AppColors.red),
    ]);
  }

  Widget _tile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: AppDecorations.accentCard(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Container(width: 3, color: color), Expanded(child: Padding(padding: const EdgeInsets.only(left: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)), Text(label, style: AppTextStyles.cardSubtitle)])))])),
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final PlatformSubscription subscription;
  const _SubscriptionCard({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final s = subscription;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () => Navigator.of(context, rootNavigator: true).push(appRoute(PlatformHospitalDetailRoute(tenantId: s.tenantId))),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: AppDecorations.card(),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.tenantName ?? '—', style: AppTextStyles.cardTitle, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(AppRadius.full)), child: Text(s.cycle.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary))),
                  const SizedBox(width: 6),
                  Text('₹${s.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ]),
                if (s.startsAt != null || s.endsAt != null) ...[const SizedBox(height: 2), Text('${_fmt(s.startsAt)} → ${_fmt(s.endsAt)}', style: AppTextStyles.cardSubtitle)],
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [StatusBadge.subscriptionStatus(s.status), const SizedBox(height: 4), Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textDisabled)]),
          ]),
        ),
      ),
    );
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }
}
