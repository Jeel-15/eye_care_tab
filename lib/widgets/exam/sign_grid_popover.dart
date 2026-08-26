import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_radius.dart';
import '../../services/exam_masters_service.dart';

/// SPH/CYL sign-toggle grid picker (PG/ST). Content-only widget shown via
/// `PopoverController.show`. Mobile shows this as a full-screen dialog;
/// tablet shows it as a popover anchored to the field (PRD §8.2).
class SignGridPopover extends StatefulWidget {
  final List<ExamMasterItem> items;
  final String current;
  final void Function(String value) onApply;
  final VoidCallback onClose;

  const SignGridPopover({super.key, required this.items, required this.current, required this.onApply, required this.onClose});

  @override
  State<SignGridPopover> createState() => _SignGridPopoverState();
}

class _SignGridPopoverState extends State<SignGridPopover> {
  late String _sign;
  late String _selected;
  final _customCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sign = widget.current.startsWith('-') ? '-' : '+';
    _selected = widget.current;
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gridItems = widget.items.where((i) {
      final n = double.tryParse(i.value.replaceAll(RegExp(r'[+\-]'), ''));
      return n != null && n > 0;
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
          child: Row(children: [
            Expanded(child: Text(_sign == '-' ? '− Negative Values' : '+ Positive Values', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary))),
            IconButton(icon: const Icon(Icons.close_rounded, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: widget.onClose),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(children: [
            for (final s in ['-', '+'])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      final prev = _sign;
                      _sign = s;
                      if (_selected.isNotEmpty && _selected != '0.00') {
                        final abs = _selected.startsWith(prev) ? _selected.substring(prev.length) : _selected;
                        _selected = '$s$abs';
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: _sign == s ? AppColors.primary : Colors.white, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: _sign == s ? AppColors.primary : AppColors.primaryA20)),
                      child: Text(s == '-' ? 'Minus (−)' : 'Plus (+)', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _sign == s ? Colors.white : AppColors.primary)),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                ...gridItems.map((i) {
                  final v = '$_sign${i.value}';
                  final sel = _selected == v;
                  return _chip(v, sel, i.isFavourite, () => setState(() => _selected = v));
                }),
                _zeroChip(),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.primaryA12))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _customCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(hintText: 'Custom (e.g. $_sign 1.75)', isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm))),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  final custom = _customCtrl.text.trim();
                  String? result;
                  if (custom.isNotEmpty) {
                    final stripped = (custom.startsWith('+') || custom.startsWith('-')) ? custom.substring(1) : custom;
                    result = '$_sign$stripped';
                  } else if (_selected.isNotEmpty) {
                    result = _selected;
                  }
                  if (result != null) widget.onApply(result);
                  widget.onClose();
                },
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.sm)), child: const Text('Apply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
              ),
            ]),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () { widget.onApply(''); widget.onClose(); },
                child: Text('Clear', style: TextStyle(fontSize: 11, color: Colors.red.shade600, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _chip(String label, bool sel, bool fav, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: sel ? AppColors.primary : (fav ? Colors.amber.shade50 : Colors.grey.shade100), borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: sel ? AppColors.primary : (fav ? Colors.amber.shade300 : Colors.grey.shade300))),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sel ? Colors.white : (fav ? Colors.amber.shade800 : AppColors.primaryA75))),
      ),
    );
  }

  Widget _zeroChip() {
    final sel = _selected == '0.00';
    return GestureDetector(
      onTap: () => setState(() => _selected = '0.00'),
      child: Container(
        width: 54,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: sel ? const Color(0xFF475569) : Colors.grey.shade200, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: sel ? const Color(0xFF475569) : Colors.grey.shade400)),
        child: Text('0.00', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sel ? Colors.white : const Color(0xFF475569))),
      ),
    );
  }
}
