import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';

/// The "Showing X to Y of Z entries ... Previous [n] Next" footer every
/// web-parity data table renders below its rows — factored out so this
/// exact row isn't hand-duplicated per screen (OT Appointments, both OT
/// Counsellor panels, and any future one).
class TablePaginationFooter extends StatelessWidget {
  final int total;
  final int currentPage;
  final int lastPage;
  final int start;
  final int end;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const TablePaginationFooter({
    super.key,
    required this.total,
    required this.currentPage,
    required this.lastPage,
    required this.start,
    required this.end,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox(height: 8);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.primaryA08))),
      child: Row(children: [
        Text('Showing $start to $end of $total entries', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const Spacer(),
        if (lastPage > 1) ...[
          _pageBtn('Previous', enabled: currentPage > 1, onTap: onPrev),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Text('$currentPage', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          _pageBtn('Next', enabled: currentPage < lastPage, onTap: onNext),
        ],
      ]),
    );
  }

  Widget _pageBtn(String label, {required bool enabled, required VoidCallback onTap}) {
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), side: BorderSide(color: AppColors.primaryA22)),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: enabled ? AppColors.primary : AppColors.textDisabled)),
    );
  }
}
