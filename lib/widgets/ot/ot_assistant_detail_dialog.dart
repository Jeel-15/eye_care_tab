import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/ot_booking_models.dart';
import '../../models/ot_ward_models.dart';
import '../../utils/date_format.dart';
import '../../utils/view_facts.dart';
import '../detail_card_kit.dart';
import 'ot_booking_view_dialog.dart';

/// OT Assistant "View" — eye, surgery and doctor sit in the header.
/// Surgery record and lens appear once the case has left Ready.
(String, Color) _stageStyle(String otStatus) => switch (otStatus) {
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

String? _fmtNum(num? v) {
  if (v == null) return null;
  final s = v.toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

void showOtAssistantBookingDetail(BuildContext context, OtBookingSummary item) {
  final p = item.patient;
  final isReady = item.otStatus == OtStatus.ready;
  final (stageLabel, stageColor) = _stageStyle(item.otStatus);
  final (payLabel, payColor) = _payStyle(item.paymentStatus);
  final preOp = item.preOp;
  final surgery = item.surgery;
  final lens = item.lensDetail;
  final vitalsEmpty = preOp == null || [preOp.bp, preOp.pulse, preOp.rbs?.toString(), preOp.temperature?.toString(), preOp.spo2?.toString(), preOp.hba1c?.toString()].every((v) => v == null || v.isEmpty);

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
          Fact('Status', titleWords(surgery.surgeryStatus)),
          Fact('Complication', titleWords(surgery.complicationStatus)),
          Fact('Complication Notes', surgery.complicationNotes),
        ];

  final lensFacts = lens == null
      ? const <Fact>[]
      : <Fact>[
          Fact('Implanted', (lens.isImplanted) ? 'Yes' : null),
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
    avatarColors: const [AppColors.purple, AppColors.blue],
    pills: [
      ...patientIdentityPills(p),
      Pill(stageLabel, bg: stageColor.withValues(alpha: 0.10), fg: stageColor, outlined: true),
      Pill(payLabel, bg: payColor.withValues(alpha: 0.10), fg: payColor, outlined: true),
    ],
    facts: [
      HeaderFact('Eye', item.eye),
      HeaderFact('Surgery', item.otType),
      // `ot_doctor_id` is only ever set once Ward saves Status (it's copied
      // straight from the patient's own OPD doctor at that point — see
      // OtWardApiController's assign_staff save) — before that it's null,
      // showing "—" for a doctor that's really just not synced yet. The
      // patient's own consulting doctor is the same person and known from
      // day one, so it's the correct fallback, not a stand-in.
      HeaderFact('Doctor', doctorDisplayName(item.otDoctor?.name ?? p?.doctor?.name)),
      HeaderFact('OT Date', isReady ? null : formatPlainDate(item.surgeryDate)),
    ],
    sections: [
      if (!isReady)
        FactSection(
          'Surgery Record',
          surgeryFacts,
          trailing: surgeryFacts.every((f) => f.value == null || f.value!.trim().isEmpty) ? const SheetNote('Surgery record not found.') : null,
        ),
      if (!isReady && lensFacts.any((f) => f.value != null && f.value!.trim().isNotEmpty)) FactSection('Implanted Lens', lensFacts),
      FactSection('Surgery Plan', [
        Fact('Diagnosis', item.counselling?.diagnosis),
        Fact('Planned Lens', counsellingLensLine(item.counselling)),
        Fact('Lens Implantation', item.counselling?.lensImplantation == null ? null : (item.counselling!.lensImplantation! ? 'Yes' : 'No')),
        Fact('Package', counsellingPackageLine(item.counselling)),
        Fact('Mediclaim', yesNo(item.counselling?.mediclaim ?? item.hasMediclaim)),
        Fact('Payment', '$payLabel · ${money(item.totalPaid)} / ${money(item.packageAmount)}'),
        Fact('OT Assistant', item.otAssistant?.name),
      ]),
      FactSection('Pre-Op Vitals', [
        Fact('Status', preOp?.preOpStatus == null ? null : otPreOpStatusLabel(preOp!.preOpStatus)),
        Fact('BP', preOp?.bp),
        Fact('Pulse', preOp?.pulse),
        Fact('RBS', preOp?.rbs?.toString()),
        Fact('Temp', preOp?.temperature?.toString()),
        Fact('SpO2', preOp?.spo2 == null ? null : '${preOp!.spo2}%'),
        Fact('HbA1c', preOp?.hba1c?.toString()),
      ], trailing: vitalsEmpty ? const SheetNote('Vitals not recorded.') : null),
      FactSection('Patient', patientRecordFacts(p)),
    ],
  );
}
