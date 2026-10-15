import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';

/// The "Show [n] entries ... Search: [___]" row every web-parity data
/// table (OT Appointments, OT Counsellor's two panels, and any future one)
/// renders above its table — factored out so this exact row isn't
/// hand-duplicated per screen. Pass `perPage`/`onPerPageChanged` as null to
/// omit the "Show entries" control for a table that doesn't paginate.
class TableToolsBar extends StatelessWidget {
  final int? perPage;
  final List<int> pageSizes;
  final ValueChanged<int>? onPerPageChanged;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final String searchHint;
  final double searchWidth;

  const TableToolsBar({
    super.key,
    this.perPage,
    this.pageSizes = const [10, 25, 50, 100, -1],
    this.onPerPageChanged,
    required this.searchCtrl,
    required this.onSearchChanged,
    this.searchHint = 'Search...',
    this.searchWidth = 220,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(children: [
        if (perPage != null && onPerPageChanged != null) ...[
          Text('Show', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(width: 6),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(border: Border.all(color: AppColors.primaryA22), borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: perPage,
                isDense: true,
                icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.primary),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                items: pageSizes.map((n) => DropdownMenuItem(value: n, child: Text(n == -1 ? 'All' : '$n'))).toList(),
                onChanged: (v) { if (v != null) onPerPageChanged!(v); },
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text('entries', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
        const Spacer(),
        SizedBox(
          width: searchWidth,
          height: 40,
          child: TextField(
            controller: searchCtrl,
            onChanged: onSearchChanged,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: searchHint,
              hintStyle: TextStyle(fontSize: 14, color: AppColors.primaryA55),
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.primaryA55),
              prefixIconConstraints: const BoxConstraints(minWidth: 34),
              isDense: true,
              filled: true,
              fillColor: AppColors.primaryA04,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
            ),
          ),
        ),
      ]),
    );
  }
}
