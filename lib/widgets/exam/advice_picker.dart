import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_radius.dart';
import '../../services/exam_masters_service.dart';
import '../../services/simple_master_service.dart';
import '../app_animations.dart';

/// Shared "Advice Library" picker for the exam Advice step — used by BOTH
/// Primary and Secondary exam screens. Previously each screen had its own,
/// visually different implementation (Primary: a plain pill `Wrap` with no
/// favourites grouping; Secondary: this richer card) even though web's own
/// advice picker (`exam/primary.blade.php` / `secondary.blade.php`) uses
/// the exact same markup in both. Extracted here so both screens share one
/// design, matching web.
///
/// Web always joins selected advice items with `, ` (comma-space), never a
/// newline — every join/split below uses `, ` to match (the old per-screen
/// implementations used `\n`, which is why the advice textarea used to show
/// one item per line instead of inline like web).
class AdviceLibraryPicker extends StatefulWidget {
  final TextEditingController adviceCtrl;
  final List<ExamMasterItem> masters;
  final ValueChanged<List<ExamMasterItem>> onMastersChanged;
  final String masterType;

  const AdviceLibraryPicker({
    super.key,
    required this.adviceCtrl,
    required this.masters,
    required this.onMastersChanged,
    this.masterType = 'advices',
  });

  @override
  State<AdviceLibraryPicker> createState() => _AdviceLibraryPickerState();
}

class _AdviceLibraryPickerState extends State<AdviceLibraryPicker> {
  String _search = '';
  final _addCtrl = TextEditingController();

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  void _appendAdviceText(String text) {
    final existing = widget.adviceCtrl.text.trimRight();
    widget.adviceCtrl.text = existing.isEmpty ? text : '$existing, $text';
    widget.adviceCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.adviceCtrl.text.length),
    );
  }

  // Best-effort removal — drops every comma-separated part whose trimmed
  // text exactly matches [value]. Free-typed prose that doesn't exactly
  // match a library value is never touched.
  void _removeAdviceLine(String value) {
    final target = value.trim();
    final remaining = widget.adviceCtrl.text
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty && p != target)
        .join(', ');
    widget.adviceCtrl.text = remaining;
    widget.adviceCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.adviceCtrl.text.length),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      fontSize: 12,
      color: AppColors.primary.withValues(alpha: 0.35),
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.18)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.18)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Wrapping the whole picker in this ValueListenableBuilder (not just the
    // textarea) means a tick also updates when the doctor hand-types/deletes
    // text directly in the textarea, not only when tapping a tile here.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.adviceCtrl,
      builder: (_, val, _) {
        final includedParts = val.text
            .split(',')
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toSet();
        bool included(String value) => includedParts.contains(value.trim());

        final query = _search.trim().toLowerCase();
        final filtered = widget.masters
            .where(
              (i) => query.isEmpty || i.value.toLowerCase().contains(query),
            )
            .toList();
        final favs = filtered.where((i) => i.isFavourite).toList();
        final others = filtered.where((i) => !i.isFavourite).toList();

        void toggleInclude(ExamMasterItem item) {
          setState(() {
            if (included(item.value)) {
              _removeAdviceLine(item.value);
            } else {
              _appendAdviceText(item.value);
            }
          });
        }

        Future<void> toggleFav(ExamMasterItem item) async {
          try {
            final newFav = await SimpleMasterService.instance.toggleFavourite(
              'masters/detail/${widget.masterType}',
              item.id,
            );
            if (!mounted) return;
            final updated = [...widget.masters];
            final i = updated.indexWhere((e) => e.id == item.id);
            if (i >= 0)
              updated[i] = ExamMasterItem(
                id: item.id,
                value: item.value,
                isFavourite: newFav,
              );
            widget.onMastersChanged(updated);
          } catch (_) {}
        }

        Widget tile(ExamMasterItem item) {
          final done = included(item.value);
          return PressScaleWrapper(
            onTap: () => toggleInclude(item),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: done ? AppColors.tealA10 : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: done
                      ? AppColors.teal.withValues(alpha: 0.35)
                      : AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    done ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 15,
                    color: done
                        ? AppColors.teal
                        : AppColors.primary.withValues(alpha: 0.25),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.value,
                      style: TextStyle(
                        fontSize: 12,
                        color: done ? AppColors.tealDark : AppColors.primary,
                        fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  PressScaleWrapper(
                    onTap: () => toggleFav(item),
                    child: Icon(
                      item.isFavourite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 15,
                      color: item.isFavourite
                          ? Colors.amber.shade600
                          : AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    size: 14,
                    color: AppColors.teal,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ADVICE LIBRARY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.primary.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(fontSize: 12),
                decoration: _deco('Search advice…'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: _deco('New advice text…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PressScaleWrapper(
                    onTap: () async {
                      final text = _addCtrl.text.trim();
                      if (text.isEmpty) return;
                      try {
                        final created = await SimpleMasterService.instance
                            .create(
                              'masters/detail/${widget.masterType}',
                              text,
                            );
                        final newItem = ExamMasterItem(
                          id: created.id,
                          value: created.value,
                          isFavourite: created.isFavourite,
                        );
                        widget.onMastersChanged([...widget.masters, newItem]);
                        setState(() => _appendAdviceText(newItem.value));
                        _addCtrl.clear();
                      } catch (_) {}
                    },
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FA),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.08),
                  ),
                ),
                child: (favs.isEmpty && others.isEmpty)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            query.isEmpty
                                ? 'No advice items yet.'
                                : 'No match for "${_search.trim()}".',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      )
                    : ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          if (favs.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 4,
                                left: 2,
                              ),
                              child: Text(
                                '★ Favourites',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber.shade700,
                                ),
                              ),
                            ),
                            ...favs.map(tile),
                            const SizedBox(height: 4),
                          ],
                          if (others.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 4,
                                left: 2,
                              ),
                              child: Text(
                                'All',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            ...others.map(tile),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
