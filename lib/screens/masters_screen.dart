import 'package:flutter/material.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../services/permission_service.dart';
import 'case_type_master_screen.dart';
import 'generic_master_screen.dart';
import 'location_master_screen.dart';
import 'ot_charge_head_master_screen.dart';
import 'ot_lens_inventory_master_screen.dart';
import 'ot_lens_option_master_screen.dart';
import 'ot_lens_power_master_screen.dart';
import 'ot_package_master_screen.dart';
import 'ot_slot_master_screen.dart';
import 'ot_surgery_type_master_screen.dart';
import 'ot_type_master_screen.dart';
import 'referrer_master_screen.dart';

class _MasterItem {
  final IconData icon;
  final String label;
  final Color color;
  final String? slug;
  final bool hasFavourite;
  final bool hasSeeded;
  const _MasterItem(this.icon, this.label, this.color, {this.slug, this.hasFavourite = false, this.hasSeeded = false});
}

class _MasterGroup {
  final String label;
  final List<_MasterItem> items;
  const _MasterGroup(this.label, this.items);
}

/// A top-level list-pane section (colored pill header + count badge).
/// [subGroups] holds one or more label+items pairs — Basic/OT masters have
/// exactly one pair with an empty subLabel (rendered flat), Eye Exam masters
/// have four, each rendered under its own left-accent sub-label, mirroring
/// eye_care_app/lib/screens/masters_screen.dart's _SectionCard/_SubGroup split.
class _MasterSection {
  final String title;
  final IconData icon;
  final Color color;
  final List<_MasterGroup> subGroups;
  const _MasterSection(this.title, this.icon, this.color, this.subGroups);
  int get itemCount => subGroups.fold(0, (sum, g) => sum + g.items.length);
}

/// Tablet Masters hub — Pattern A (list+detail split): left pane groups
/// master types (Basic / OT / Eye Exam), right pane embeds the selected
/// type's editor (GenericMasterScreen for the ~26 simple {value,favourite}
/// masters, or one of the 6 custom-field screens). Ported from
/// eye_care_app/lib/screens/masters_screen.dart.
class MastersScreen extends StatefulWidget {
  const MastersScreen({super.key});

  @override
  State<MastersScreen> createState() => _MastersScreenState();
}

class _MastersScreenState extends State<MastersScreen> {
  _MasterItem? _selected;

  static final _basic = [
    _MasterItem(Icons.folder_open_rounded, 'Case Types', AppColors.primary, slug: 'case-types'),
    _MasterItem(Icons.location_on_rounded, 'Locations', AppColors.green, slug: 'locations'),
    _MasterItem(Icons.people_alt_rounded, 'Referrers', AppColors.orange, slug: 'referrers-crud'),
    _MasterItem(Icons.hourglass_bottom_rounded, 'Durations', Color(0xFF7F8C8D), slug: 'durations'),
  ];
  static final _ot = [
    _MasterItem(Icons.remove_red_eye_rounded, 'Lens Options', Color(0xFF2C3E50), slug: 'lens-options'),
    _MasterItem(Icons.schedule_rounded, 'OT Slots', AppColors.primary, slug: 'ot-slots'),
    _MasterItem(Icons.label_rounded, 'OT Types', AppColors.green, slug: 'ot-types'),
    _MasterItem(Icons.cut_rounded, 'Surgery Types', AppColors.orange, slug: 'ot-surgery-types'),
    _MasterItem(Icons.payments_rounded, 'Charge Heads', AppColors.teal, slug: 'ot-charge-heads'),
    _MasterItem(Icons.inventory_2_rounded, 'Lens Inventory', AppColors.blue, slug: 'ot-lens-inventory'),
    _MasterItem(Icons.lens_rounded, 'Lens Powers', AppColors.purple, slug: 'ot-lens-powers'),
    _MasterItem(Icons.card_giftcard_rounded, 'Packages', AppColors.tealDark, slug: 'ot-packages'),
  ];
  static final _clinical = [
    _MasterItem(Icons.assignment_rounded, 'Chief Complaints', Color(0xFFE74C3C), slug: 'complaints', hasFavourite: true),
    _MasterItem(Icons.favorite_rounded, 'K/C/O', AppColors.orange, slug: 'kcos', hasFavourite: true),
    _MasterItem(Icons.history_rounded, 'H/O', AppColors.teal, slug: 'hno', hasFavourite: true),
    _MasterItem(Icons.verified_rounded, 'Diagnoses', AppColors.green, slug: 'diagnoses', hasFavourite: true),
    _MasterItem(Icons.chat_rounded, 'Advice', AppColors.primary, slug: 'advices', hasFavourite: true),
  ];
  static final _vision = [
    _MasterItem(Icons.visibility_rounded, 'V/N', AppColors.teal, slug: 'vn'),
    _MasterItem(Icons.table_rows_rounded, 'Vn C GL', AppColors.primary, slug: 'vngl'),
    _MasterItem(Icons.view_list_rounded, 'Vn C ST', AppColors.primary, slug: 'vnst'),
    _MasterItem(Icons.visibility_off_rounded, 'PH NV/N', AppColors.teal, slug: 'pnvn'),
    _MasterItem(Icons.center_focus_strong_rounded, 'NR V/N', AppColors.teal, slug: 'nrvn'),
    _MasterItem(Icons.lens_rounded, 'SPH / CYL', AppColors.primary, slug: 'sph_cyl', hasSeeded: true),
    _MasterItem(Icons.open_with_rounded, 'Axis', Color(0xFF7F8C8D), slug: 'axis'),
    _MasterItem(Icons.timeline_rounded, 'NCT (IOP)', AppColors.orange, slug: 'nct'),
  ];
  static final _anterior = [
    _MasterItem(Icons.water_drop_rounded, 'SAC', AppColors.teal, slug: 'sac', hasFavourite: true),
    _MasterItem(Icons.visibility_off_rounded, 'Lid', Color(0xFF7F8C8D), slug: 'lid', hasFavourite: true),
    _MasterItem(Icons.circle_rounded, 'Conjunctiva', Color(0xFFE74C3C), slug: 'conj', hasFavourite: true),
    _MasterItem(Icons.radio_button_checked_rounded, 'Cornea', AppColors.primary, slug: 'cornea', hasFavourite: true),
    _MasterItem(Icons.layers_rounded, 'A/C', AppColors.teal, slug: 'ac', hasFavourite: true),
    _MasterItem(Icons.adjust_rounded, 'Iris', AppColors.orange, slug: 'iris', hasFavourite: true),
    _MasterItem(Icons.fiber_manual_record_rounded, 'Pupil', Color(0xFF2C3E50), slug: 'pupil', hasFavourite: true),
    _MasterItem(Icons.camera_rounded, 'Lens', AppColors.green, slug: 'lens', hasFavourite: true),
    _MasterItem(Icons.open_in_full_rounded, 'E/M', Color(0xFF7F8C8D), slug: 'em', hasFavourite: true),
    _MasterItem(Icons.verified_user_rounded, 'Cover Test', AppColors.green, slug: 'covertest', hasFavourite: true),
  ];
  static final _posterior = [
    _MasterItem(Icons.panorama_fish_eye_rounded, 'Disc', Color(0xFF7F8C8D), slug: 'disc', hasFavourite: true),
    _MasterItem(Icons.signal_cellular_alt_rounded, 'F/R', Color(0xFF7F8C8D), slug: 'fr', hasFavourite: true),
  ];

  List<_MasterSection> _visibleSections() {
    final p = PermissionService.instance;
    final basicVisible = <_MasterItem>[
      if (p.can(Perm.masterCaseTypes)) _basic[0],
      if (p.can(Perm.masterLocations)) _basic[1],
      if (p.can(Perm.masterCaseTypes) || p.can(Perm.masterLocations)) _basic[2],
      if (p.can(Perm.masterCaseTypes) || p.can(Perm.masterLocations)) _basic[3],
    ];
    final otVisible = <_MasterItem>[
      if (p.isSuper || p.can(Perm.masterOtSlots) || p.can(Perm.masterOtTypes) || p.can(Perm.masterOtCharges) || p.can(Perm.masterOtInventory)) _ot[0],
      if (p.can(Perm.masterOtSlots)) _ot[1],
      if (p.can(Perm.masterOtTypes)) _ot[2],
      if (p.can(Perm.masterOtTypes)) _ot[3],
      if (p.can(Perm.masterOtCharges)) _ot[4],
      if (p.can(Perm.masterOtInventory)) _ot[5],
      if (p.can(Perm.masterOtInventory)) _ot[6],
      if (p.can(Perm.masterOtInventory)) _ot[7],
    ];
    final showEyeExam = p.can(Perm.masterEyeExam);
    return [
      _MasterSection('Basic Masters', Icons.grid_3x3_rounded, AppColors.primary, [_MasterGroup('', basicVisible)]),
      _MasterSection('OT Masters', Icons.local_hospital_rounded, AppColors.purple, [_MasterGroup('', otVisible)]),
      if (showEyeExam)
        _MasterSection('Eye Exam Masters', Icons.remove_red_eye_rounded, AppColors.teal, [
          _MasterGroup('Clinical', _clinical),
          _MasterGroup('Vision Values', _vision),
          _MasterGroup('Anterior Segment (O/E)', _anterior),
          _MasterGroup('Posterior Segment (Fundus)', _posterior),
        ]),
    ].where((s) => s.itemCount > 0).toList();
  }

  @override
  Widget build(BuildContext context) {
    final sections = _visibleSections();
    if (sections.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline_rounded, size: 56, color: AppColors.primaryA25),
          const SizedBox(height: 16),
          Text('No Access', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primaryA50)),
          const SizedBox(height: 6),
          Text('Your role has no master data permissions.', style: TextStyle(fontSize: 13, color: AppColors.primaryA35)),
        ]),
      );
    }

    return LayoutBuilder(builder: (context, c) {
      final listPane = _buildListPane(sections);
      final detailPane = _buildDetailPane();
      if (c.maxWidth < AppBreakpoints.medium) {
        return _selected == null
            ? listPane
            : Column(children: [
                TextButton.icon(onPressed: () => setState(() => _selected = null), icon: const Icon(Icons.arrow_back_rounded, size: 18), label: const Text('Back to Masters')),
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

  Widget _buildListPane(List<_MasterSection> sections) {
    final totalCount = sections.fold(0, (sum, s) => sum + s.itemCount);
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Expanded(child: Text('Master Data', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(AppRadius.full), boxShadow: [BoxShadow(color: AppColors.teal.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))]),
              child: Text('$totalCount items', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5)),
            ),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            children: [
              for (final section in sections) ...[
                _sectionHeader(section),
                const SizedBox(height: 10),
                for (final group in section.subGroups) ...[
                  if (group.label.isNotEmpty) ...[
                    _subGroupLabel(group.label, section.color),
                    const SizedBox(height: 8),
                  ],
                  _itemGrid(group.items),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  Widget _sectionHeader(_MasterSection section) {
    final c = section.color;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: c.withValues(alpha: 0.14))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [c, c.withValues(alpha: 0.72)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(AppRadius.full), boxShadow: [BoxShadow(color: c.withValues(alpha: 0.32), blurRadius: 8, offset: const Offset(0, 2))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(section.icon, color: Colors.white, size: 12),
            const SizedBox(width: 5),
            Text(section.title.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
          ]),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: c.withValues(alpha: 0.20))),
          child: Text('${section.itemCount}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c)),
        ),
      ]),
    );
  }

  Widget _subGroupLabel(String label, Color color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 6, 10, 6),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border(left: BorderSide(color: color, width: 3))),
      child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color.withValues(alpha: 0.85), letterSpacing: 0.1)),
    );
  }

  // 2-column icon-button grid — mirrors eye_care_app's _Grid/_Card (icon
  // badge on top, label below), sized for the narrower list pane.
  Widget _itemGrid(List<_MasterItem> items) {
    return LayoutBuilder(builder: (_, c) {
      final w = (c.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final item in items) SizedBox(width: w, child: _tile(item))],
      );
    });
  }

  Widget _tile(_MasterItem item) {
    final active = _selected?.label == item.label;
    final c = item.color;
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
              child: Icon(item.icon, color: active ? Colors.white : c, size: 18),
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
                Icon(Icons.tune_rounded, size: 56, color: AppColors.primaryA22),
                const SizedBox(height: 12),
                Text('Select a master type to manage', style: TextStyle(fontSize: 13, color: AppColors.primaryA55)),
              ]),
            )
          : _screenFor(item),
    );
  }

  Widget _screenFor(_MasterItem item) {
    switch (item.slug) {
      case 'case-types':
        return CaseTypeMasterScreen(key: ValueKey(item.slug), accentColor: item.color);
      case 'referrers-crud':
        return ReferrerMasterScreen(key: ValueKey(item.slug), accentColor: item.color);
      case 'ot-slots':
        return OtSlotMasterScreen(key: ValueKey(item.slug), accentColor: item.color);
      case 'ot-charge-heads':
        return OtChargeHeadMasterScreen(key: ValueKey(item.slug), accentColor: item.color);
      case 'ot-surgery-types':
        return OtSurgeryTypeMasterScreen(key: ValueKey(item.slug), accentColor: item.color);
      case 'lens-options':
        return OtLensOptionMasterScreen(key: ValueKey(item.slug), accentColor: item.color);
      case 'ot-types':
        return OtTypeMasterScreen(key: ValueKey(item.slug), accentColor: item.color);
      case 'ot-lens-inventory':
        return OtLensInventoryMasterScreen(key: ValueKey(item.slug), accentColor: item.color);
      case 'ot-lens-powers':
        return OtLensPowerMasterScreen(key: ValueKey(item.slug), accentColor: item.color);
      case 'ot-packages':
        return OtPackageMasterScreen(key: ValueKey(item.slug), accentColor: item.color);
      case 'locations':
        return LocationMasterScreen(key: ValueKey(item.slug), accentColor: item.color);
      default:
        // Durations falls through here too — treated as a plain
        // masters/detail/{slug} generic master, same as every other simple
        // {value, favourite} type. Lens Options / OT Types now have their
        // own correctly-permissioned screens above (Round 3.5).
        return GenericMasterScreen(key: ValueKey(item.slug), title: item.label, apiPath: 'masters/detail/${item.slug}', accentColor: item.color, icon: item.icon, hasFavourite: item.hasFavourite, hasSeeded: item.hasSeeded);
    }
  }
}

