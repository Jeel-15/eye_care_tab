import 'package:flutter/material.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/auth_models.dart';
import '../models/foc_models.dart';
import '../services/foc_service.dart';
import '../services/permission_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_empty_state.dart';

/// Tablet FOC (Free of Charge) module — Pattern A (list + detail split)
/// replacing mobile's inline-action card list. The list pane stays scannable
/// (patient, fee, status only); Accept/Reject actions and the full record
/// (reason, rejection note, accepted-by, timestamps) live in the detail pane
/// on the right. Business logic (fetch/filter/create/accept/reject) ported
/// unchanged from eye_care_app/lib/screens/foc_screen.dart.
class FocScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;

  const FocScreen({super.key, required this.user, required this.hospital});

  @override
  State<FocScreen> createState() => _FocScreenState();
}

class _FocScreenState extends State<FocScreen> {
  final _p = PermissionService.instance;

  bool _loading = false;
  String? _error;
  FocListResult? _result;
  String? _filterStatus; // null = all, 'pending', 'accepted', 'rejected'
  int? _selectedId;

  bool get _canCreate => _p.can(Perm.opdFocCreate);
  bool get _canAccept => _p.can(Perm.opdFocAccept);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await FocService.instance.fetchFocs(status: _filterStatus);
      if (mounted) setState(() { _result = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  void _setFilter(String? status) {
    setState(() => _filterStatus = status);
    _load();
  }

  // ── Create FOC Dialog (doctor action) ─────────────────────────────────────

  Future<void> _showCreateDialog() async {
    final patientIdCtrl = TextEditingController();
    final focFeeCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: Text('New FOC Request', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
          content: SizedBox(
            width: 380,
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _dialogField(patientIdCtrl, 'Patient ID', hint: 'Enter patient ID', keyboardType: TextInputType.number, validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 12),
                _dialogField(focFeeCtrl, 'FOC Fee (₹)', hint: '0.00', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) return 'Enter valid amount';
                  return null;
                }),
                const SizedBox(height: 12),
                _dialogField(reasonCtrl, 'Reason', hint: 'Reason for waiving fee…', maxLines: 3, validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDlg(() => submitting = true);
                      try {
                        await FocService.instance.createFoc(patientId: int.parse(patientIdCtrl.text.trim()), focFee: double.parse(focFeeCtrl.text.trim()), reason: reasonCtrl.text.trim());
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                        if (mounted) showAppSnackBar(context, 'FOC request submitted.', isSuccess: true);
                      } catch (e) {
                        setDlg(() => submitting = false);
                        if (ctx.mounted) showAppSnackBar(ctx, e.toString().replaceFirst('Exception: ', ''), isError: true);
                      }
                    },
              child: submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    patientIdCtrl.dispose();
    focFeeCtrl.dispose();
    reasonCtrl.dispose();
  }

  // ── Reject Dialog (reception action) ──────────────────────────────────────

  Future<void> _showRejectDialog(FocItem foc) async {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: Text('Reject FOC Request', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.red)),
          content: SizedBox(
            width: 380,
            child: Form(key: formKey, child: _dialogField(reasonCtrl, 'Reason for rejection', maxLines: 3, validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDlg(() => submitting = true);
                      try {
                        await FocService.instance.rejectFoc(foc.id, reasonCtrl.text.trim());
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      } catch (e) {
                        setDlg(() => submitting = false);
                        if (ctx.mounted) showAppSnackBar(ctx, e.toString().replaceFirst('Exception: ', ''), isError: true);
                        _load();
                      }
                    },
              child: submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Reject'),
            ),
          ],
        ),
      ),
    );
    reasonCtrl.dispose();
  }

  // ── Accept (reception action) ──────────────────────────────────────────────

  Future<void> _accept(FocItem foc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Accept FOC Request'),
        content: Text('Accept FOC for ${foc.patient?.fullName ?? "Patient #${foc.patientId}"}?\nFee of ₹${foc.focFee.toStringAsFixed(2)} will be waived.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text('Accept')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FocService.instance.acceptFoc(foc.id);
      _load();
      if (mounted) showAppSnackBar(context, 'FOC accepted. Fee waived.', isSuccess: true);
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      _load();
    }
  }

  Widget _dialogField(TextEditingController ctrl, String label, {String? hint, int? maxLines, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines ?? 1,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final splitView = constraints.maxWidth >= AppBreakpoints.medium;
      final listPane = _buildListPane();
      final detailPane = _buildDetailPane();
      if (!splitView) {
        return _selectedId != null
            ? Column(children: [
                TextButton.icon(onPressed: () => setState(() => _selectedId = null), icon: const Icon(Icons.arrow_back_rounded, size: 18), label: const Text('Back to list')),
                Expanded(child: detailPane),
              ])
            : listPane;
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 380, child: listPane),
          const SizedBox(width: 20),
          Expanded(child: detailPane),
        ],
      );
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
                Text('FOC Requests', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
                if (!_loading && _error == null) Text('${_result?.total ?? 0} request${(_result?.total ?? 0) == 1 ? '' : 's'}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ]),
              const Spacer(),
              IconButton(icon: Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20), tooltip: 'Refresh', onPressed: _load),
              if (_canCreate) IconButton(icon: Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 22), tooltip: 'New Request', onPressed: _showCreateDialog),
            ]),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _buildFilterChips()),
          const SizedBox(height: 6),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final statuses = <String?>[null, 'pending', 'accepted', 'rejected'];
    final labels = ['All', 'Pending', 'Accepted', 'Rejected'];
    final colors = [AppColors.primary, AppColors.orange, AppColors.green, AppColors.red];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(statuses.length, (i) {
          final sel = _filterStatus == statuses[i];
          final color = colors[i];
          return Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 4),
            child: ChoiceChip(
              label: Text(labels[i], style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? Colors.white : color)),
              selected: sel,
              selectedColor: color,
              backgroundColor: color.withValues(alpha: 0.08),
              side: BorderSide(color: sel ? color : color.withValues(alpha: 0.30)),
              onSelected: (_) => _setFilter(statuses[i]),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.red),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _load, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), child: const Text('Retry')),
          ]),
        ),
      );
    }
    if (_result == null || _result!.items.isEmpty) {
      return const AppEmptyState(message: 'No FOC requests found.', icon: Icons.receipt_long_outlined);
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _result!.items.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.primaryA08),
      itemBuilder: (_, i) {
        final foc = _result!.items[i];
        return _FocListTile(foc: foc, selected: foc.id == _selectedId, onTap: () => setState(() => _selectedId = foc.id));
      },
    );
  }

  // ── Detail pane ─────────────────────────────────────────────────────────

  Widget _buildDetailPane() {
    final selected = _result?.items.where((f) => f.id == _selectedId).firstOrNull;
    if (selected == null) {
      return _panelBox(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.receipt_long_outlined, size: 56, color: AppColors.primaryA22),
            const SizedBox(height: 12),
            Text('Select a request to view details', style: TextStyle(fontSize: 13, color: AppColors.primaryA55)),
          ]),
        ),
      );
    }
    return _panelBox(child: _FocDetailView(foc: selected, canAccept: _canAccept, onAccept: () => _accept(selected), onReject: () => _showRejectDialog(selected)));
  }

  Widget _panelBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      child: child,
    );
  }
}

// ── Status helpers ────────────────────────────────────────────────────────

(Color, Color, String) _statusStyle(String status) {
  switch (status) {
    case 'accepted':
      return (AppColors.green, AppColors.green.withValues(alpha: 0.10), 'Accepted');
    case 'rejected':
      return (AppColors.red, AppColors.red.withValues(alpha: 0.10), 'Rejected');
    default:
      return (AppColors.orange, AppColors.orange.withValues(alpha: 0.12), 'Pending');
  }
}

// ── List tile ──────────────────────────────────────────────────────────

class _FocListTile extends StatelessWidget {
  final FocItem foc;
  final bool selected;
  final VoidCallback onTap;

  const _FocListTile({required this.foc, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusBg, statusLabel) = _statusStyle(foc.status);
    return Material(
      color: selected ? AppColors.primaryA08 : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Icon(Icons.receipt_long_rounded, color: statusColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(foc.patient?.fullName ?? 'Patient #${foc.patientId}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary), overflow: TextOverflow.ellipsis),
                Text('₹${foc.focFee.toStringAsFixed(2)}${foc.doctor != null ? ' · Dr. ${foc.doctor!.name}' : ''}', style: TextStyle(fontSize: 11, color: AppColors.primaryA55), overflow: TextOverflow.ellipsis),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(AppRadius.xl)),
              child: Text(statusLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Detail view ────────────────────────────────────────────────────────

class _FocDetailView extends StatelessWidget {
  final FocItem foc;
  final bool canAccept;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _FocDetailView({required this.foc, required this.canAccept, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusBg, statusLabel) = _statusStyle(foc.status);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.center,
              child: Icon(Icons.receipt_long_rounded, color: statusColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(foc.patient?.fullName ?? 'Patient #${foc.patientId}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(AppRadius.xl)), child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor))),
                  if (foc.patient != null && foc.patient!.patientCode.isNotEmpty) _chip(foc.patient!.patientCode, AppColors.primaryA10, AppColors.primary),
                  _chip('₹${foc.focFee.toStringAsFixed(2)}', AppColors.orangeA12, AppColors.orange),
                ]),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          _infoCard(bg: AppColors.primaryA06, title: 'Request Details', items: [
            if (foc.doctor != null) _InfoRow(Icons.medical_services_outlined, 'Requested by', 'Dr. ${foc.doctor!.name}'),
            _InfoRow(Icons.notes_rounded, 'Reason', foc.reason),
            _InfoRow(Icons.schedule_outlined, 'Requested on', foc.createdAt),
          ]),
          if (foc.isRejected && foc.rejectedReason != null) ...[
            const SizedBox(height: 12),
            _infoCard(bg: AppColors.red.withValues(alpha: 0.06), title: 'Rejection', items: [_InfoRow(Icons.cancel_outlined, 'Reason', foc.rejectedReason!)]),
          ],
          if (foc.isAccepted && foc.acceptedByUser != null) ...[
            const SizedBox(height: 12),
            _infoCard(bg: AppColors.green.withValues(alpha: 0.06), title: 'Acceptance', items: [
              _InfoRow(Icons.check_circle_outline_rounded, 'Accepted by', foc.acceptedByUser!.name),
              if (foc.acceptedAt != null) _InfoRow(Icons.schedule_outlined, 'Accepted on', foc.acceptedAt!),
            ]),
          ],
          if (canAccept && foc.isPending) ...[
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.red, side: BorderSide(color: AppColors.red), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Reject'),
                  onPressed: onReject,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Accept'),
                  onPressed: onAccept,
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
      );

  Widget _infoCard({required Color bg, required String title, required List<_InfoRow> items}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.3)),
        const SizedBox(height: 10),
        ...items,
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        Expanded(child: Text(value, style: TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}
