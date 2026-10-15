import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_radius.dart';
import '../../models/ot_booking_models.dart';
import '../../models/ot_discharge_models.dart';
import '../../utils/date_format.dart';
import '../../utils/view_facts.dart';
import '../detail_card_kit.dart';
import 'ot_booking_view_dialog.dart';

/// Discharge "View" — money sits in the header. Documents, invoice,
/// surgery and the patient stay in the sheet.
(String, Color) _stageStyle(OtBookingSummary item) {
  final isDischarged = item.otStatus.toLowerCase() == 'discharged';
  final hasInvoice = item.hasInvoice ?? false;
  final done = item.dischargePrintsDone ?? 0;
  final total = item.dischargePrintsTotal ?? 3;
  if (isDischarged) return ('Discharged', AppColors.green);
  if (hasInvoice) return ('Printing $done/$total', AppColors.blue);
  return ('Awaiting Invoice', AppColors.orange);
}

(String, Color) _payStyle(String? paymentStatus) => switch (paymentStatus) {
      'paid' => ('Paid', AppColors.green),
      'partially_paid' => ('Partially Paid', AppColors.blue),
      'unpriced' => ('Package Not Set', AppColors.textDisabled),
      _ => ('Payment Pending', AppColors.orange),
    };

class _DischargeDoc {
  final String label;
  final DateTime? printedAt;
  const _DischargeDoc(this.label, this.printedAt);
}

Widget _docRow(_DischargeDoc doc, bool isDischarged) {
  final done = doc.printedAt != null;
  final meta = done
      ? 'Printed ${toDisplayDateTime(doc.printedAt!)}'
      : (isDischarged ? 'Print not recorded (discharged before print tracking)' : 'Not printed yet');
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: done ? AppColors.green.withValues(alpha: 0.06) : Colors.white, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: done ? AppColors.green.withValues(alpha: 0.25) : AppColors.primaryA10)),
    child: Row(children: [
      Icon(done ? Icons.check_circle_rounded : Icons.hourglass_empty_rounded, size: 18, color: done ? AppColors.green : AppColors.orange),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(doc.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: done ? AppColors.green : AppColors.orange)),
        ]),
      ),
    ]),
  );
}

String? _fmtNum(num? v) {
  if (v == null) return null;
  final s = v.toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

Widget _invoiceLineItemsTable(OtInvoiceSummary invoice) {
  Widget cell(String text, {bool header = false, bool end = false, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(text, textAlign: end ? TextAlign.right : TextAlign.left, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: header ? 12 : 13, fontWeight: header || bold ? FontWeight.w700 : FontWeight.w600, color: header ? AppColors.textSecondary : AppColors.textPrimary)),
      );
  return Table(
    columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
    children: [
      TableRow(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.primaryA12))), children: [
        cell('Charge', header: true),
        cell('Amount', header: true, end: true),
      ]),
      for (final li in invoice.lineItems)
        TableRow(children: [cell(li.head), cell(money(li.amount), end: true)]),
      if (invoice.taxAmount > 0) TableRow(children: [cell('Tax'), cell(money(invoice.taxAmount), end: true)]),
      if (invoice.discount > 0) TableRow(children: [cell('Discount'), cell('− ${money(invoice.discount)}', end: true)]),
      TableRow(decoration: BoxDecoration(color: AppColors.primaryA05), children: [cell('Net Amount', bold: true), cell(money(invoice.netAmount), end: true, bold: true)]),
    ],
  );
}

void showOtDischargeBookingDetail(BuildContext context, OtBookingSummary item) {
  final p = item.patient;
  final isDischarged = item.otStatus.toLowerCase() == 'discharged';
  final (stageLabel, stageColor) = _stageStyle(item);
  final (payLabel, payColor) = _payStyle(item.paymentStatus);
  final surgery = item.surgery;
  final lens = item.lensDetail;
  final invoice = item.invoice;
  final docs = [
    _DischargeDoc('Bill Summary', item.summaryBillPrintedAt),
    _DischargeDoc('Discharge Summary', item.dischargePrintedAt),
    _DischargeDoc('Surgery Certificate', item.certificatePrintedAt),
  ];
  final duration = surgery?.durationMinutes;
  final surgeryFacts = surgery == null
      ? const <Fact>[]
      : <Fact>[
          Fact('Surgery', surgery.surgeryName),
          Fact('Eye Operated', surgery.eyeOperated),
          Fact('Operated By', doctorDisplayName(surgery.operatedBy?.name)),
          Fact('OT Room', surgery.otRoom),
          Fact('Date', surgery.surgeryAt != null ? toDisplayDate(surgery.surgeryAt!) : (surgery.startTime != null ? toDisplayDate(surgery.startTime!) : null)),
          Fact('Time', surgery.startTime == null ? null : '${formatClock12(surgery.startTime!)}${surgery.endTime != null ? ' – ${formatClock12(surgery.endTime!)}' : ''}'),
          Fact('Duration', duration == null ? null : '$duration min'),
          Fact('Complication', titleWords(surgery.complicationStatus)),
          Fact('Complication Notes', surgery.complicationNotes),
        ];
  final lensFacts = lens == null
      ? const <Fact>[]
      : <Fact>[
          Fact('Implanted', lens.isImplanted ? 'Yes' : null),
          Fact('Lens', lens.lensName),
          Fact('Manufacturer', lens.manufacturer),
          Fact('Type', lens.lensType),
          Fact('Power', lens.lensPower == null ? null : '${_fmtNum(lens.lensPower)} D'),
          Fact('Axis', lens.axis == null || lens.axis == 0 ? null : '${_fmtNum(lens.axis)}°'),
          Fact('Serial No.', lens.serialNumber),
        ];

  showRecordView(
    context,
    name: p?.fullName ?? 'Patient',
    avatarColors: const [AppColors.orange, AppColors.red],
    pills: [
      ...patientIdentityPills(p),
      Pill(stageLabel, bg: stageColor.withValues(alpha: 0.10), fg: stageColor, outlined: true),
      Pill(payLabel, bg: payColor.withValues(alpha: 0.10), fg: payColor, outlined: true),
    ],
    facts: [
      HeaderFact('Package', money(item.packageAmount)),
      HeaderFact('Paid', money(item.totalPaid)),
      HeaderFact('Balance', money(item.remainingBalance)),
      HeaderFact('Invoice', invoice == null ? null : money(invoice.netAmount)),
    ],
    sections: [
      FactSection('Discharge Documents', const [], trailing: Column(children: [for (final d in docs) _docRow(d, isDischarged)])),
      if (invoice != null)
        FactSection('Invoice', [
          Fact('Invoice No.', invoice.invoiceNumber),
          Fact('Generated On', invoice.createdAt == null ? null : formatDateTimeString(invoice.createdAt)),
          Fact('Generated By', invoice.generatedBy?.name),
          Fact('Follow-up', formatPlainDate(invoice.followUpDate)),
          Fact('Discharged On', isDischarged && item.dischargedAt != null ? toDisplayDateTime(item.dischargedAt!) : null),
        ], trailing: invoice.lineItems.isEmpty ? null : _invoiceLineItemsTable(invoice)),
      FactSection(
        'Surgery Record',
        surgeryFacts,
        trailing: surgeryFacts.every((f) => f.value == null || f.value!.trim().isEmpty) ? const SheetNote('Surgery record not found.') : null,
      ),
      if (lensFacts.any((f) => f.value != null && f.value!.trim().isNotEmpty)) FactSection('Implanted Lens', lensFacts),
      FactSection('Surgery Plan', [
        Fact('OT Date', formatPlainDate(item.surgeryDate)),
        Fact('Eye', item.eye),
        Fact('Surgery', item.otType),
        Fact('Diagnosis', item.counselling?.diagnosis),
        Fact('Planned Lens', counsellingLensLine(item.counselling)),
        Fact('Package', counsellingPackageLine(item.counselling)),
        Fact('Mediclaim', yesNo(item.counselling?.mediclaim ?? item.hasMediclaim)),
        Fact('OT Doctor', doctorDisplayName(item.otDoctor?.name)),
        Fact('OT Assistant', item.otAssistant?.name),
      ]),
      FactSection('Patient', patientRecordFacts(p)),
    ],
  );
}
