import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/app_text_styles.dart';
import '../models/platform_admin_models.dart';
import '../models/platform_notification_models.dart';
import '../services/platform_notification_service.dart';
import '../utils/app_decorations.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_badge.dart';

/// Tablet Platform Notifications — embedded content (no own Scaffold),
/// segmented Compose/History tabs matching mobile. Business logic
/// (recipient selection, live send-count, history) ported unchanged from
/// eye_care_app/lib/screens/platform_notifications_screen.dart.
class PlatformNotificationsScreen extends StatefulWidget {
  final PlatformAdmin admin;

  const PlatformNotificationsScreen({super.key, required this.admin});

  @override
  State<PlatformNotificationsScreen> createState() => _PlatformNotificationsScreenState();
}

class _PlatformNotificationsScreenState extends State<PlatformNotificationsScreen> {
  int _tab = 0;

  bool _loading = true;
  String? _error;
  PlatformNotificationData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final data = await PlatformNotificationService.instance.getNotifications();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (data == null) {
        _error = 'Could not load notifications.';
      } else {
        _data = data;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppSkeletonList(count: 5, itemHeight: 68);
    if (_error != null) return AppErrorState(message: _error!, onRetry: _load);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Notifications', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
          const Spacer(),
          Container(
            width: 240,
            height: 40,
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: AppColors.primaryA12)),
            child: Padding(padding: const EdgeInsets.all(3), child: Row(children: [Expanded(child: _tabBtn(0, 'Compose', Icons.edit_outlined)), Expanded(child: _tabBtn(1, 'History', Icons.history_rounded))])),
          ),
        ]),
        const SizedBox(height: 16),
        Expanded(child: _tab == 0 ? _ComposeView(tenants: _data!.tenants, onSent: _load) : _HistoryView(history: _data!.history, onRefresh: _load)),
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
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 14, color: selected ? Colors.white : AppColors.textSecondary), const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textSecondary))]),
      ),
    );
  }
}

// ── Compose View ─────────────────────────────────────────────────────────

class _ComposeView extends StatefulWidget {
  final List<NotificationTenantOption> tenants;
  final VoidCallback onSent;

  const _ComposeView({required this.tenants, required this.onSent});

  @override
  State<_ComposeView> createState() => _ComposeViewState();
}

class _ComposeViewState extends State<_ComposeView> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  bool _loading = false;
  String _recipient = 'all';
  final Set<int> _selectedIds = {};
  List<NotificationTenantOption> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.tenants;
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() => _filtered = q.isEmpty ? widget.tenants : widget.tenants.where((t) => t.name.toLowerCase().contains(q)).toList());
    });
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _sendCount => _recipient == 'all' ? widget.tenants.length : _selectedIds.length;

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    if (_recipient == 'specific' && _selectedIds.isEmpty) {
      showAppSnackBar(context, 'Select at least one hospital.', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Send Notification', style: AppTextStyles.headingSmall),
        content: Text('This will email $_sendCount hospital admin(s) immediately.\n\nSubject: "${_subjectCtrl.text}"', style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Send', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800))),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);

    final result = await PlatformNotificationService.instance.send(subject: _subjectCtrl.text.trim(), message: _messageCtrl.text.trim(), recipient: _recipient, tenantIds: _recipient == 'specific' ? _selectedIds.toList() : null);

    if (!mounted) return;
    setState(() => _loading = false);
    showAppSnackBar(context, result.message, isSuccess: result.success, isError: !result.success);
    if (result.success) {
      _subjectCtrl.clear();
      _messageCtrl.clear();
      setState(() { _selectedIds.clear(); _recipient = 'all'; });
      widget.onSent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 720;
          final content = ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 560 : double.infinity),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(controller: _subjectCtrl, decoration: AppDecorations.inputDecoration(labelText: 'Subject *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 10),
                TextFormField(controller: _messageCtrl, maxLines: 6, maxLength: 5000, decoration: AppDecorations.inputDecoration(labelText: 'Message *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 10),
                Text('Recipients', style: AppTextStyles.sectionLabel),
                const SizedBox(height: 6),
                Row(
                  children: ['all', 'specific'].map((r) {
                    final selected = _recipient == r;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(r == 'all' ? 'All Hospitals' : 'Specific'),
                          selected: selected,
                          onSelected: (_) => setState(() { _recipient = r; if (r == 'all') _selectedIds.clear(); }),
                          selectedColor: AppColors.primaryA15,
                          labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? AppColors.primary : AppColors.textSecondary),
                          backgroundColor: AppColors.surface,
                          side: BorderSide(color: selected ? AppColors.primary : AppColors.primaryA12),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                if (_recipient == 'specific') ...[
                  TextField(controller: _searchCtrl, decoration: AppDecorations.inputDecoration(hintText: 'Search hospitals...', prefixIcon: const Icon(Icons.search_rounded, size: 18))),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: AppDecorations.card(),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final t = _filtered[i];
                        final checked = _selectedIds.contains(t.id);
                        return CheckboxListTile(
                          dense: true,
                          value: checked,
                          onChanged: (_) => setState(() { if (checked) { _selectedIds.remove(t.id); } else { _selectedIds.add(t.id); } }),
                          title: Text(t.name, style: AppTextStyles.cardTitle, overflow: TextOverflow.ellipsis),
                          subtitle: Text(t.adminEmail, style: AppTextStyles.cardSubtitle, overflow: TextOverflow.ellipsis),
                          activeColor: AppColors.primary,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA15)),
                  child: Row(children: [Icon(Icons.campaign_rounded, size: 16, color: AppColors.primary), const SizedBox(width: 8), Text('Sending to: $_sendCount hospital(s)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary))]),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _send,
                    icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_loading ? 'Sending...' : 'Send Notification', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)), elevation: 0),
                  ),
                ),
              ],
            ),
          );
          return wide ? Center(child: content) : content;
        }),
      ),
    );
  }
}

// ── History View ─────────────────────────────────────────────────────────

class _HistoryView extends StatelessWidget {
  final List<PlatformNotificationItem> history;
  final VoidCallback onRefresh;

  const _HistoryView({required this.history, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return AppEmptyState(message: 'No notifications sent yet.', icon: Icons.campaign_outlined, onRefresh: onRefresh);
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => onRefresh(),
      child: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 2 : 1;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 8, crossAxisSpacing: 12, childAspectRatio: cols == 2 ? 2.8 : 3.6),
          itemCount: history.length,
          itemBuilder: (_, i) => _NotificationHistoryCard(item: history[i]),
        );
      }),
    );
  }
}

class _NotificationHistoryCard extends StatelessWidget {
  final PlatformNotificationItem item;
  const _NotificationHistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(item.subject, style: AppTextStyles.cardTitle, overflow: TextOverflow.ellipsis)), const SizedBox(width: 8), StatusBadge.notificationStatus(item.status)]),
          const SizedBox(height: 4),
          Text(item.tenantName ?? 'Platform broadcast', style: AppTextStyles.cardSubtitle),
          if (item.recipientEmail != null) ...[const SizedBox(height: 2), Text(item.recipientEmail!, style: AppTextStyles.cardSubtitle, overflow: TextOverflow.ellipsis)],
          if (item.errorMessage != null) ...[const SizedBox(height: 4), Text(item.errorMessage!, style: TextStyle(fontSize: 11, color: AppColors.red), overflow: TextOverflow.ellipsis)],
          if (item.sentAt != null) ...[const SizedBox(height: 4), Align(alignment: Alignment.centerRight, child: Text(_formatDateTime(item.sentAt!), style: AppTextStyles.cardSubtitle))],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}, $h:$min';
  }
}
