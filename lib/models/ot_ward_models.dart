import 'ot_booking_models.dart';
import 'ot_inventory_models.dart';

/// Ward status options for `pre_op_status` — matches `OtPreOp` constants.
const kOtPreOpStatuses = ['preparing', 'ready_for_surgery', 'hold', 'complicated', 'not_fit'];

String otPreOpStatusLabel(String status) => switch (status) {
      'preparing' => 'Preparing',
      'ready_for_surgery' => 'Ready for Surgery',
      'hold' => 'Hold',
      'complicated' => 'Complicated',
      'not_fit' => 'Not Fit',
      _ => status,
    };

/// `GET .../vitals` → `{ latest: <row or null> }`. No history — one row per
/// booking (server does `updateOrCreate`), see build PRD §7 gotcha.
class OtVitalsItem {
  final String? bp;
  final int? pulse;
  final double? rbs;
  final double? temperature;
  final double? spo2;
  final double? hba1c;
  final String preOpStatus;
  final OtNamedRef? enteredBy;

  const OtVitalsItem({
    this.bp,
    this.pulse,
    this.rbs,
    this.temperature,
    this.spo2,
    this.hba1c,
    required this.preOpStatus,
    this.enteredBy,
  });

  factory OtVitalsItem.fromJson(Map<String, dynamic> j) => OtVitalsItem(
        bp: j['bp'] as String?,
        pulse: j['pulse'] as int?,
        rbs: numOrStringToDouble(j['rbs']),
        temperature: numOrStringToDouble(j['temperature']),
        spo2: numOrStringToDouble(j['spo2']),
        hba1c: numOrStringToDouble(j['hba1c']),
        preOpStatus: j['pre_op_status'] as String? ?? 'preparing',
        // Contract doc describes this as "enteredBy" (inline prose, not a
        // literal JSON sample) — using snake_case here for consistency with
        // every other confirmed relation key (ot_doctor, ot_assistant, etc.)
        // per Laravel's default JSON-serialization convention. Verify once
        // the backend is reachable (§1 open question).
        enteredBy: j['entered_by'] != null ? OtNamedRef.fromJson(j['entered_by'] as Map<String, dynamic>) : null,
      );
}

class OtEyeDropEntry {
  final int id;
  final String medicineName;
  final String eye; // RE | LE
  final int doseNumber;
  final String? administeredAt;
  final OtNamedRef? administeredBy;
  final String? remarks;

  const OtEyeDropEntry({
    required this.id,
    required this.medicineName,
    required this.eye,
    required this.doseNumber,
    this.administeredAt,
    this.administeredBy,
    this.remarks,
  });

  factory OtEyeDropEntry.fromJson(Map<String, dynamic> j) => OtEyeDropEntry(
        id: j['id'] as int,
        medicineName: j['medicine_name'] as String? ?? '',
        eye: j['eye'] as String? ?? 'RE',
        doseNumber: j['dose_number'] as int? ?? 1,
        administeredAt: j['administered_at'] as String?,
        administeredBy: j['administered_by'] != null ? OtNamedRef.fromJson(j['administered_by'] as Map<String, dynamic>) : null,
        remarks: j['remarks'] as String?,
      );
}

class OtVerificationHeader {
  final String uhid;
  final String patientName;
  final String? surgeryType;
  final String? eye;
  // Web pre-fills the Doctor/OT Assistant selects on the Patient Status
  // form from the booking's currently-assigned staff on every reload — this
  // is the app equivalent (see OT_WEB_PARITY_FIX_PRD.md §4).
  final OtNamedRef? otDoctor;
  final OtNamedRef? otAssistant;
  // Eye Drop Register medicine picker source (Medicine Master, OT scope
  // only) — replaces free-text entry (web pull 2026-08-07). See
  // WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §8.
  final List<OtNamedRef> otMedicines;

  const OtVerificationHeader({required this.uhid, required this.patientName, this.surgeryType, this.eye, this.otDoctor, this.otAssistant, this.otMedicines = const []});

  factory OtVerificationHeader.fromJson(Map<String, dynamic> j) => OtVerificationHeader(
        uhid: j['uhid'] as String? ?? '',
        patientName: j['patient_name'] as String? ?? '',
        surgeryType: j['surgery_type'] as String?,
        eye: j['eye'] as String?,
        otDoctor: j['ot_doctor'] != null ? OtNamedRef.fromJson(j['ot_doctor'] as Map<String, dynamic>) : null,
        otAssistant: j['ot_assistant'] != null ? OtNamedRef.fromJson(j['ot_assistant'] as Map<String, dynamic>) : null,
        otMedicines: (j['ot_medicines'] as List? ?? []).map((e) => OtNamedRef.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
