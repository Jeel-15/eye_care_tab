import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/role_models.dart';

/// Web parity (`permission_matrix.blade.php`'s cross-permission JS,
/// confirmed 2026-09-21): granting Secondary Exam also grants OT → Surgery
/// → Recommend — a doctor authorized for secondary exams is assumed to
/// also be authorized to recommend surgery. One-way: revoking Secondary
/// Exam does NOT revoke Surgery Recommend, matching web exactly.
void _applyExamSecondaryCoupling(Map<String, PermissionModuleGroup> permissions, String toggledAction, bool granted) {
  if (toggledAction != 'exam_secondary' || !granted) return;
  for (final module in permissions.values) {
    for (final feature in module.features.values) {
      for (var i = 0; i < feature.permissions.length; i++) {
        if (feature.permissions[i].action == 'ot_surgery_recommend') {
          feature.permissions[i] = feature.permissions[i].copyWith(isGranted: true);
        }
      }
    }
  }
}

/// Renders a role's permissions as module → feature → toggle pill, in a
/// single full-width column — web-parity redesign (2026-09-21) of what was
/// previously a 2-column card grid of `CheckboxListTile` rows (one
/// permission per line). That layout read badly once a module has dozens
/// of features (Masters/Config alone has ~40 sub-sections, ~150
/// permissions) — a 2-col grid squeezed each card to half width, forcing
/// long vertical lists of checkbox rows. Mirrors web's own Edit Role page
/// (`hospital/roles/edit.blade.php` + `partials/permission_matrix.blade.php`,
/// confirmed 2026-09-21): one full-width row per module, sub-section labels
/// in small grey caps, permissions as rounded pill toggles that flow
/// several-per-line via `Wrap` — using this app's own [AppColors] tokens
/// instead of web's literal hex, per this project's normalize-not-copy
/// convention for visual redesigns.
///
/// Used by the Role editor pane for both the create-role and edit-role
/// flows — same widget either way, just fed a differently-sourced but
/// identically-shaped `Map<String, PermissionModuleGroup>` (role_models.dart's
/// dual-shape parsing already normalizes both backend endpoints into this
/// one shape before it reaches here).
///
/// Mutates [permissions]' nested lists in place and manages its own
/// setState for the toggle UI — the caller reads the final grants back
/// out through the same map reference when saving, so no change callback
/// is needed.
class PermissionTreeEditor extends StatefulWidget {
  final Map<String, PermissionModuleGroup> permissions;
  final bool enabled;

  const PermissionTreeEditor({
    super.key,
    required this.permissions,
    this.enabled = true,
  });

  @override
  State<PermissionTreeEditor> createState() => _PermissionTreeEditorState();
}

class _PermissionTreeEditorState extends State<PermissionTreeEditor> {
  // Module keys the user has manually collapsed — every module starts
  // expanded (this app's own established doctrine: every permission
  // visible/toggleable at once, unlike mobile's accordion) but the giant
  // Masters/Config module benefits from an escape hatch once the user is
  // done with it.
  final Set<String> _collapsed = {};

  List<RolePermissionItem> get _allPermissions =>
      widget.permissions.values.expand((m) => m.allPermissions).toList();

  void _setAll(bool granted) {
    setState(() {
      for (final module in widget.permissions.values) {
        _setModule(module, granted);
      }
    });
  }

  void _setModule(PermissionModuleGroup module, bool granted) {
    for (final feature in module.features.values) {
      for (var i = 0; i < feature.permissions.length; i++) {
        feature.permissions[i] = feature.permissions[i].copyWith(isGranted: granted);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _allPermissions;
    final grantedCount = all.where((p) => p.isGranted).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(grantedCount, all.length),
        const SizedBox(height: 14),
        for (final entry in widget.permissions.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildModuleSection(entry.key, entry.value),
          ),
      ],
    );
  }

  // Web parity: "Assign Permissions" section header + a single page-level
  // All/None pair (`edit.blade.php`'s #selectAll/#deselectAll, which
  // operate on every `.perm-checkbox` in the DOM regardless of module) —
  // additive to the per-module All/None below, not a replacement for it.
  Widget _buildSectionHeader(int granted, int total) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: AppColors.primaryA10, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Icon(Icons.vpn_key_rounded, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Assign Permissions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
            Text('Choose the modules and actions available to this role.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(AppRadius.full)),
          child: Text('$granted / $total', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ),
        if (widget.enabled) ...[
          const SizedBox(width: 10),
          _smallOutlinedBtn(icon: Icons.check_rounded, label: 'All', onTap: () => _setAll(true)),
          const SizedBox(width: 6),
          _smallOutlinedBtn(icon: Icons.close_rounded, label: 'None', onTap: () => _setAll(false)),
        ],
      ],
    );
  }

  Widget _smallOutlinedBtn({required IconData icon, required String label, required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 13),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primaryA22),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
      ),
    );
  }

  Widget _buildModuleSection(String key, PermissionModuleGroup module) {
    final perms = module.allPermissions;
    final grantedCount = perms.where((p) => p.isGranted).length;
    final allGranted = perms.isNotEmpty && perms.every((p) => p.isGranted);
    final collapsed = _collapsed.contains(key);
    final features = module.features.entries.toList();

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.primaryA07), boxShadow: [BoxShadow(color: AppColors.primaryA05, blurRadius: 10, offset: const Offset(0, 3))]),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (collapsed) {
                _collapsed.remove(key);
              } else {
                _collapsed.add(key);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(children: [
                Icon(Icons.folder_rounded, color: AppColors.blue, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(module.label, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: grantedCount > 0 ? AppColors.green.withValues(alpha: 0.10) : AppColors.primaryA08, borderRadius: BorderRadius.circular(10)),
                  child: Text('$grantedCount / ${perms.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: grantedCount > 0 ? AppColors.green : AppColors.textSecondary)),
                ),
                if (widget.enabled) ...[
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () => setState(() => _setModule(module, !allGranted)),
                    style: TextButton.styleFrom(minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                    child: Text(allGranted ? 'None' : 'All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
                ],
                const SizedBox(width: 2),
                Icon(collapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded, color: AppColors.textSecondary, size: 20),
              ]),
            ),
          ),
          if (!collapsed) ...[
            Divider(height: 1, color: AppColors.primaryA08),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var fi = 0; fi < features.length; fi++) ...[
                    if (features[fi].value.label.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          features[fi].value.label.toUpperCase(),
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: AppColors.primaryA55),
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var pi = 0; pi < features[fi].value.permissions.length; pi++)
                          _PermissionPill(
                            item: features[fi].value.permissions[pi],
                            enabled: widget.enabled,
                            onChanged: (v) => setState(() {
                              final action = features[fi].value.permissions[pi].action;
                              features[fi].value.permissions[pi] = features[fi].value.permissions[pi].copyWith(isGranted: v);
                              _applyExamSecondaryCoupling(widget.permissions, action, v);
                            }),
                          ),
                      ],
                    ),
                    if (fi != features.length - 1) const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One permission toggle — web parity in spirit (a checkbox-style leading
/// indicator inside a rounded pill, pale fill + bold label when granted)
/// using this app's own primary color instead of web's literal
/// `#EAF4FA`/`#123C5A` hex.
class _PermissionPill extends StatelessWidget {
  final RolePermissionItem item;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _PermissionPill({required this.item, required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final on = item.isGranted;
    return InkWell(
      onTap: enabled ? () => onChanged(!on) : null,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppColors.primaryA10 : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: on ? AppColors.primaryA40 : AppColors.primaryA14),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            on ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
            size: 16,
            color: on ? AppColors.primary : AppColors.textDisabled,
          ),
          const SizedBox(width: 6),
          Text(
            item.label,
            style: TextStyle(fontSize: 12.5, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? AppColors.primary : AppColors.textPrimary),
          ),
        ]),
      ),
    );
  }
}
