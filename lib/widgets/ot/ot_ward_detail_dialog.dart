import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/ot_booking_models.dart';
import '../../models/ot_ward_models.dart';
import '../../utils/date_format.dart';
import '../../utils/view_facts.dart';
import '../detail_card_kit.dart';
import 'ot_booking_view_dialog.dart';

/// Ward "View" — header carries the surgery glance facts. The sheet holds
/// vitals, patient, surgery detail and the eye-drop register.
(String, Color) _stageStyle(String otStatus) => switch (otStatus) {
      OtStatus.paymentVerified => ('Awaiting Ward Entry', AppColors.orange),
      OtStatus.inWard => ('In Ward', AppColors.blue),
      OtStatus.dilated => ('Dilated', AppColors.purple),
      OtStatus.ready => ('Ready for OT', AppColors.primary),
      OtStatus.operated => ('Operated', AppColors.green),
      OtStatus.discharged => ('Discharged', AppColors.textSecondary),
      _ => (OtStatus.label(otStatus), AppColors.textSecondary),
    };

(String, Color) _payStyle(String? paymentStatus) => switch (paymentStatus) {
      'paid' => ('Paid', AppColors.green),
      'partially_paid' => ('Partially Paid', AppColors.blue),
      'unpriced' => ('Package Not Set', AppColors.textDisabled),
      _ => ('Payment Pending', AppColors.orange),
    };

Widget _eyeDropsTable(List<OtEyeDropEntry> drops) {
  Widget cell(String text, {bool header = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: header ? 12 : 13, fontWeight: header ? FontWeight.w700 : FontWeight.w600, color: header ? AppColors.textSecondary : AppColors.textPrimary)),
      );
  return Table(
    columnWidths: const {0: FlexColumnWidth(1.3), 1: FlexColumnWidth(1.3), 2: FlexColumnWidth(0.7), 3: FlexColumnWidth(0.7), 4: FlexColumnWidth(0.8), 5: FlexColumnWidth(1.1), 6: FlexColumnWidth(1.1)},
    children: [
      TableRow(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.primaryA12))), children: [
        cell('Time', header: true),
        cell('Medicine', header: true),
        cell('Eye', header: true),
        cell('Dose', header: true),
        cell('Drops', header: true),
        cell('Given by', header: true),
        cell('Dilate', header: true),
      ]),
      // API returns doses oldest-first (administered_at asc, matching web);
      // reversed so the most recent dose shows first instead of scrolled
      // furthest away.
      for (final d in drops.reversed)
        TableRow(children: [
          cell(d.administeredAt != null ? formatDateTimeString(d.administeredAt) : '—'),
          cell(d.medicineName.isEmpty ? '—' : d.medicineName),
          cell(d.eye),
          cell('${d.doseNumber}'),
          cell(d.dropsCount?.toString() ?? '—'),
          cell(d.administeredBy?.name ?? '—'),
          cell(d.dilate == 'Yes' ? 'Yes${d.dilationTime != null ? ' · ${d.dilationTime}m' : ''}' : '—'),
        ]),
    ],
  );
}

void showOtWardBookingDetail(BuildContext context, OtBookingSummary item) {
  final p = item.patient;
  final (stageLabel, stageColor) = _stageStyle(item.otStatus);
  final (payLabel, payColor) = _payStyle(item.paymentStatus);
  final preOp = item.preOp;
  final vitalsEmpty = preOp == null || [preOp.bp, preOp.pulse, preOp.rbs?.toString(), preOp.temperature?.toString(), preOp.spo2?.toString(), preOp.hba1c?.toString()].every((v) => v == null || v.isEmpty);

  showRecordView(
    context,
    name: p?.fullName ?? 'Patient',
    avatarColors: [AppColors.blue, AppColors.primary],
    pills: [
      ...patientIdentityPills(p),
      Pill(stageLabel, bg: stageColor.withValues(alpha: 0.10), fg: stageColor, outlined: true),
      Pill(payLabel, bg: payColor.withValues(alpha: 0.10), fg: payColor, outlined: true),
    ],
    facts: [
      HeaderFact('OT Date', formatPlainDate(item.surgeryDate)),
      HeaderFact('Eye', item.eye),
      HeaderFact('Surgery', item.otType),
      // `ot_doctor_id` is only ever set once Ward saves Status (it's copied
      // straight from the patient's own OPD doctor at that point — see
      // OtWardApiController's assign_staff save) — before that it's null,
      // showing "—" for a doctor that's really just not synced yet. The
      // patient's own consulting doctor is the same person and known from
      // day one, so it's the correct fallback, not a stand-in.
      HeaderFact('Doctor', doctorDisplayName(item.otDoctor?.name ?? p?.doctor?.name)),
    ],
    sections: [
      FactSection('Pre-Op Vitals', [
        Fact('Status', preOp?.preOpStatus == null ? null : otPreOpStatusLabel(preOp!.preOpStatus)),
        Fact('BP', preOp?.bp),
        Fact('Pulse', preOp?.pulse),
        Fact('RBS', preOp?.rbs?.toString()),
        Fact('Temp', preOp?.temperature?.toString()),
        Fact('SpO2', preOp?.spo2 == null ? null : '${preOp!.spo2}%'),
        Fact('HbA1c', preOp?.hba1c?.toString()),
      ], trailing: vitalsEmpty ? const SheetNote('Vitals not recorded yet.') : null),
      FactSection('Patient', patientRecordFacts(p)),
      FactSection('Surgery & OT', [
        Fact('Diagnosis', item.counselling?.diagnosis),
        Fact('Lens', counsellingLensLine(item.counselling)),
        Fact('Package', counsellingPackageLine(item.counselling)),
        Fact('Mediclaim', yesNo(item.counselling?.mediclaim ?? item.hasMediclaim)),
        Fact('Payment', '$payLabel · ${money(item.totalPaid)} / ${money(item.packageAmount)}'),
        Fact('OT Assistant', item.otAssistant?.name),
      ]),
      FactSection(
        'Eye Drop Register',
        const [],
        trailing: item.dilationEntries.isEmpty ? const SheetNote('No eye drops given yet.') : _eyeDropsTable(item.dilationEntries),
      ),
    ],
  );
}
