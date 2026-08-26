import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_radius.dart';
import '../../services/exam_masters_service.dart';
import 'anchored_popover.dart';
import 'master_list_popover.dart';
import 'sign_grid_popover.dart';

/// Shared building blocks for Primary/Secondary Exam screens — see
/// EXAMINATIONS_MODULE_PRD.md §6 (picker patterns) and §8.2 (anchored
/// popover decision). Every exam section composes from these instead of
/// hand-rolling its own field chrome.

// ── Section card ─────────────────────────────────────────────────────────

/// One exam section — its own card with its own Save button (PRD §8.1:
/// per-section save kept deliberately, not one combined Save-All).
class ExamSectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onSave;
  final bool saving;
  final bool saved;

  const ExamSectionCard({super.key, required this.title, required this.child, required this.onSave, this.saving = false, this.saved = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.primaryA10), boxShadow: [BoxShadow(color: AppColors.primaryA05, blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary))),
            _SaveButton(onTap: onSave, saving: saving, saved: saved),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool saving;
  final bool saved;
  const _SaveButton({required this.onTap, required this.saving, required this.saved});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ElevatedButton.icon(
        onPressed: saving ? null : onTap,
        icon: saving
            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(saved ? Icons.check_rounded : Icons.save_rounded, size: 14),
        label: Text(saved ? 'Saved' : 'Save', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: saved ? AppColors.green : AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        ),
      ),
    );
  }
}

// ── Text field + popover picker (Vision / O-E / Fundus / NCT) ───────────

class TextPickerField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final List<ExamMasterItem> items;
  final bool showFavourites;
  final bool grid;
  final Future<bool> Function(ExamMasterItem item)? onToggleFavourite;
  final Color Function(String value)? borderColorFor;
  final ValueChanged<String>? onChanged;

  const TextPickerField({
    super.key,
    required this.controller,
    required this.hint,
    required this.items,
    this.showFavourites = false,
    this.grid = false,
    this.onToggleFavourite,
    this.borderColorFor,
    this.onChanged,
  });

  @override
  State<TextPickerField> createState() => _TextPickerFieldState();
}

class _TextPickerFieldState extends State<TextPickerField> {
  final _popover = PopoverController();

  @override
  void dispose() {
    _popover.dispose();
    super.dispose();
  }

  void _open() {
    if (widget.items.isEmpty) return;
    _popover.show(context, (ctx) => MasterListPopover(
          items: widget.items,
          title: widget.hint,
          current: widget.controller.text,
          grid: widget.grid,
          showFavourites: widget.showFavourites,
          onToggleFavourite: widget.onToggleFavourite,
          onSelect: (v) => setState(() { widget.controller.text = v; widget.onChanged?.call(v); }),
          onClose: _popover.close,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.borderColorFor?.call(widget.controller.text) ?? AppColors.primaryA18;
    return CompositedTransformTarget(
      link: _popover.link,
      child: TextFormField(
        controller: widget.controller,
        onTap: _open,
        onChanged: (v) { widget.onChanged?.call(v); setState(() {}); },
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: '—',
          hintStyle: TextStyle(color: AppColors.primaryA30),
          suffixIcon: widget.items.isNotEmpty
              ? IconButton(icon: Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.primaryA55), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: _open)
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: borderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: borderColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
        ),
      ),
    );
  }
}

// ── Search-and-add field (H/O chips, etc.) ───────────────────────────────

/// Chip-mode master picker: tapping opens the full searchable list
/// immediately (matches the web app's "click shows all, type to filter"
/// UX) instead of only showing suggestions after typing. Selecting an item
/// calls [onSelected] and clears the field; typing free text and pressing
/// enter also adds it, since the master list may not cover every case.
class MasterSearchAddField extends StatefulWidget {
  final List<ExamMasterItem> items;
  final String hint;
  final IconData icon;
  final void Function(String value) onSelected;
  final Future<bool> Function(ExamMasterItem item)? onToggleFavourite;

  const MasterSearchAddField({super.key, required this.items, required this.hint, this.icon = Icons.search_rounded, required this.onSelected, this.onToggleFavourite});

  @override
  State<MasterSearchAddField> createState() => _MasterSearchAddFieldState();
}

class _MasterSearchAddFieldState extends State<MasterSearchAddField> {
  final _popover = PopoverController();
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _popover.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _open() {
    if (widget.items.isEmpty) return;
    _popover.show(context, (ctx) => MasterListPopover(
          items: widget.items,
          title: widget.hint,
          current: '',
          showFavourites: true,
          onToggleFavourite: widget.onToggleFavourite,
          onSelect: (v) { widget.onSelected(v); _ctrl.clear(); },
          onClose: _popover.close,
        ));
  }

  void _submitFreeText(String v) {
    if (v.trim().isEmpty) return;
    widget.onSelected(v.trim());
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _popover.link,
      child: TextField(
        controller: _ctrl,
        onTap: _open,
        onSubmitted: _submitFreeText,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(fontSize: 12, color: AppColors.primaryA35),
          prefixIcon: Icon(widget.icon, size: 16),
          suffixIcon: widget.items.isNotEmpty ? IconButton(icon: Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.primaryA55), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: _open) : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: AppColors.primaryA18)),
        ),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

// ── Chip field (PG/ST refraction cells: SPH / CYL / Axis / VN) ──────────

class ChipPickerField extends StatefulWidget {
  final TextEditingController controller;
  final List<ExamMasterItem> items;
  final bool isSignField; // true = SPH/CYL (opens SignGridPopover), false = Axis/VN (opens MasterListPopover)
  final bool disabled;
  final VoidCallback? onChanged;

  const ChipPickerField({super.key, required this.controller, required this.items, required this.isSignField, this.disabled = false, this.onChanged});

  @override
  State<ChipPickerField> createState() => _ChipPickerFieldState();
}

class _ChipPickerFieldState extends State<ChipPickerField> {
  final _popover = PopoverController();

  @override
  void dispose() {
    _popover.dispose();
    super.dispose();
  }

  void _open() {
    if (widget.disabled) return;
    if (widget.isSignField) {
      _popover.show(context, (ctx) => SignGridPopover(
            items: widget.items,
            current: widget.controller.text,
            onApply: (v) => setState(() { widget.controller.text = v; widget.onChanged?.call(); }),
            onClose: _popover.close,
          ), width: 300, maxHeight: 380);
    } else {
      if (widget.items.isEmpty) return;
      _popover.show(context, (ctx) => MasterListPopover(
            items: widget.items,
            title: 'Select value',
            current: widget.controller.text,
            onSelect: (v) => setState(() { widget.controller.text = v; widget.onChanged?.call(); }),
            onClose: _popover.close,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.controller.text.trim();
    final isEmpty = t.isEmpty;
    Color bg, bd, fg;
    if (widget.disabled) {
      bg = AppColors.primaryA04; bd = AppColors.primaryA08; fg = AppColors.primaryA30;
    } else if (widget.isSignField) {
      final isMinus = t.startsWith('-');
      final isZero = t == '0.00';
      bg = isEmpty ? Colors.grey.shade50 : isZero ? Colors.grey.shade200 : isMinus ? const Color(0xFFFFF0F0) : const Color(0xFFF0FFF4);
      bd = isEmpty ? Colors.grey.shade300 : isZero ? Colors.grey.shade400 : isMinus ? const Color(0xFFFFB3B3) : const Color(0xFF86EFAC);
      fg = isEmpty ? Colors.grey.shade400 : isZero ? const Color(0xFF475569) : isMinus ? const Color(0xFFB91C1C) : const Color(0xFF15803D);
    } else {
      bg = isEmpty ? Colors.grey.shade50 : AppColors.primaryA08;
      bd = isEmpty ? Colors.grey.shade300 : AppColors.primaryA40;
      fg = isEmpty ? Colors.grey.shade400 : AppColors.primary;
    }
    return CompositedTransformTarget(
      link: _popover.link,
      child: GestureDetector(
        onTap: _open,
        child: Container(
          height: 38,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: bd)),
          alignment: Alignment.center,
          child: Text(isEmpty ? '—' : t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
        ),
      ),
    );
  }
}

// ── Readonly mirror cell (ST near CYL/Axis) ──────────────────────────────

class MirrorCell extends StatelessWidget {
  final String value;
  const MirrorCell({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value.trim();
    return Container(
      height: 38,
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: Colors.grey.shade300)),
      alignment: Alignment.center,
      child: Text(v.isEmpty ? '—' : v, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: v.isEmpty ? Colors.grey.shade400 : AppColors.primaryA40)),
    );
  }
}

// ── Favourite chip row (C/O, K/C/O, H/O) ─────────────────────────────────

class FavouriteChipRow extends StatelessWidget {
  final List<ExamMasterItem> favourites;
  final void Function(ExamMasterItem) onTapAdd;
  final void Function(ExamMasterItem)? onUnfavourite;

  const FavouriteChipRow({super.key, required this.favourites, required this.onTapAdd, this.onUnfavourite});

  @override
  Widget build(BuildContext context) {
    if (favourites.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: Colors.amber.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.star_rounded, size: 12, color: Colors.amber.shade700),
            const SizedBox(width: 5),
            Text('FAVOURITES — TAP TO ADD', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.amber.shade800, letterSpacing: 0.4)),
          ]),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: favourites.map((item) => Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: Colors.amber.shade300)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    GestureDetector(onTap: () => onTapAdd(item), child: Padding(padding: const EdgeInsets.only(left: 10, top: 5, bottom: 5, right: 4), child: Text(item.value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber.shade900)))),
                    if (onUnfavourite != null) GestureDetector(onTap: () => onUnfavourite!(item), child: Padding(padding: const EdgeInsets.only(right: 8, top: 5, bottom: 5), child: Icon(Icons.star_rounded, size: 12, color: Colors.amber.shade600))),
                  ]),
                )).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Table cell helpers (refraction / O-E / fundus headers) ──────────────

Widget examTh(String text, {TextAlign align = TextAlign.center}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(text, textAlign: align, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryA62)),
    );

Widget examRowLabel(String text) => Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary));
