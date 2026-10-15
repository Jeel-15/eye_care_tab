import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/ot_booking_models.dart';
import '../../utils/date_format.dart';
import '../../utils/view_facts.dart';
import '../detail_card_kit.dart';
import 'ot_booking_view_dialog.dart';

/// Accountant "View" — package, paid and balance sit in the header.
/// The sheet holds the patient, the surgery and the receipt table.
(String, Color) _detailStatus(OtBookingSummary item) {
  if (item.otStatus == OtStatus.surgeryRefused) {
    if (item.isFullyRefunded ?? false) return ('Fully Refunded', AppColors.green);
    if ((item.refundableBalance ?? 0) > 0) return ('Refund Pending', AppColors.red);
    return ('Surgery Refused', AppColors.textDisabled);
  }
  return switch (item.paymentStatus) {
    'paid' => ('Payment Completed', AppColors.green),
    'partially_paid' => ('Partially Paid', AppColors.blue),
    'unpriced' => ('Package Not Set', AppColors.textDisabled),
    _ => ('Payment Pending', AppColors.orange),
  };
}

Widget _paymentsTable(List<OtPaymentEntry> payments) {
  Widget cell(String text, {bool header = false, bool end = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(text, textAlign: end ? TextAlign.right : TextAlign.left, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: header ? 12 : 13, fontWeight: header ? FontWeight.w700 : FontWeight.w600, color: header ? AppColors.textSecondary : AppColors.textPrimary)),
      );
  return Table(
    columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(1.4), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1)},
    children: [
      TableRow(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.primaryA12))), children: [
        cell('Receipt', header: true),
        cell('Date', header: true),
        cell('Mode', header: true),
        cell('Amount', header: true, end: true),
      ]),
      for (final pay in payments)
        TableRow(children: [
          cell(pay.receiptNumber ?? '—'),
          cell(pay.paidAt != null ? formatDateTimeString(pay.paidAt) : '—'),
          cell(pay.paymentMode.isEmpty ? '—' : pay.paymentMode[0].toUpperCase() + pay.paymentMode.substring(1)),
          cell(money(pay.packageAmount), end: true),
        ]),
    ],
  );
}

void showOtAccountantBookingDetail(BuildContext context, OtBookingSummary item) {
  final p = item.patient;
  final isRefused = item.otStatus == OtStatus.surgeryRefused;
  final (statusLabel, statusColor) = _detailStatus(item);
  final counselledBy = item.counselling?.counsellorName == null
      ? null
      : '${item.counselling!.counsellorName}${item.counselling?.counselledAt != null ? ' · ${toDisplayDate(toHospitalTime(item.counselling!.counselledAt!))}' : ''}';

  showRecordView(
    context,
    name: p?.fullName ?? 'Patient',
    avatarColors: const [AppColors.teal, AppColors.tealDark],
    pills: [
      ...patientIdentityPills(p),
      Pill(statusLabel, bg: statusColor.withValues(alpha: 0.10), fg: statusColor, outlined: true),
      Pill(OtStatus.label(item.otStatus), bg: AppColors.primaryA08, fg: AppColors.primary, outlined: true),
    ],
    facts: [
      HeaderFact('Package', money(item.packageAmount)),
      HeaderFact('Paid', money(item.totalPaid)),
      if (isRefused) HeaderFact('Refunded', money(item.totalRefunded)) else HeaderFact('Balance', money(item.remainingBalance)),
      HeaderFact('OT Date', formatPlainDate(item.surgeryDate)),
    ],
    sections: [
      FactSection('Patient', patientRecordFacts(p, visitDate: true)),
      FactSection('Surgery & Counselling', [
        Fact('Eye', item.eye),
        Fact('Surgery', item.otType),
        Fact('Diagnosis', item.counselling?.diagnosis),
        Fact('Package', counsellingPackageLine(item.counselling)),
        Fact('Lens', counsellingLensLine(item.counselling)),
        Fact('Mediclaim', yesNo(item.counselling?.mediclaim ?? item.hasMediclaim)),
        Fact('OT Doctor', doctorDisplayName(item.otDoctor?.name)),
        Fact('Counselled By', counselledBy),
      ]),
      FactSection(
        'Payments',
        const [],
        trailing: item.payments.isEmpty ? const SheetNote('No payment recorded yet.') : _paymentsTable(item.payments),
      ),
    ],
  );
}
