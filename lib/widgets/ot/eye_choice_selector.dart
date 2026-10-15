import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_radius.dart';

/// Highlighted RE/LE/Both selector for OT clinical forms — a wrong tap here
/// means the wrong eye gets operated on, so the chosen option must be
/// unmistakable at a glance (solid color fill + check icon + bold label),
/// not a plain default `ChoiceChip`'s subtle tint.
class EyeChoiceSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String label;

  const EyeChoiceSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Eye',
  });

  static const _options = ['RE', 'LE', 'Both'];
  static const _colors = {
    'RE': AppColors.blue,
    'LE': AppColors.orange,
    'Both': AppColors.purple,
  };
  static const _fullLabels = {
    'RE': 'Right Eye',
    'LE': 'Left Eye',
    'Both': 'Both Eyes',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final e in _options) ...[
              Expanded(child: _option(e)),
              if (e != _options.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  Widget _option(String e) {
    final selected = value == e;
    final color = _colors[e]!;
    return GestureDetector(
      onTap: () => onChanged(e),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color, width: selected ? 0 : 1.6),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.38),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? Colors.white : color,
              size: 18,
            ),
            const SizedBox(height: 4),
            Text(
              _fullLabels[e]!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
