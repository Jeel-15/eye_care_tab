import 'ot_booking_models.dart';
import 'ot_inventory_models.dart';

/// Ward status options for `pre_op_status` — matches web's real, current 4
/// selectable options exactly (`ward/show.blade.php`). 'not_fit' is NOT a
/// selectable option on web — it was an old status merged into
/// 'complicated' and kept only as a display fallback for records already
/// saved with it. See OT_BUGS_ROUND4_AUDIT.md Bug #4.
const kOtPreOpStatuses = ['preparing', 'ready_for_surgery', 'hold', 'complicated'];

String otPreOpStatusLabel(String status) => switch (status) {
      'preparing' => 'Preparing',
      'ready_for_surgery' => 'Ready for Surgery',
      'hold' => 'Hold',
      'complicated' => 'Complicated',
      // Legacy value — web displays it identically to 'complicated' rather
      // than as its own status. Not a selectable option any more.
      'not_fit' => 'Complicated',
      _ => status,
    };

/// `GET .../vitals` → `{ latest: <row or null> }`. No history — one row per
/// booking (server does `updateOrCreate`), see build PRD §7 gotcha.
///
/// `pulse` is a **string** on web/API (`nullable|string|max:20`) — Laravel
/// may serialize it as `"72"`; never cast with `as int?`.
class OtVitalsItem {
  final String? bp;
  final String? pulse;
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
        bp: switch (j['bp']) { String s => s, num n => n.toString(), _ => null },
        pulse: switch (j['pulse']) { String s => s, num n => n.toString(), _ => null },
        rbs: numOrStringToDouble(j['rbs']),
        temperature: numOrStringToDouble(j['temperature']),
        spo2: numOrStringToDouble(j['spo2']),
        hba1c: numOrStringToDouble(j['hba1c']),
        preOpStatus: j['pre_op_status'] as String? ?? 'preparing',
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
  // Ward "View" parity (web pull 2026-09-30) — a real `ot_dilation_entries`
  // column the web modal's Eye Drop Register table shows, but this app's
  // own `addEyeDrop` form never collects (nullable).
  final int? dropsCount;
  // Web pull 2026-10-10 — "Dilate?" Yes/No + minutes, shown alongside the
  // other dose fields on the ward form and as a column in the register.
  final String? dilate; // 'Yes' | 'No' | null
  final int? dilationTime;

  const OtEyeDropEntry({
    required this.id,
    required this.medicineName,
    required this.eye,
    required this.doseNumber,
    this.administeredAt,
    this.administeredBy,
    this.remarks,
    this.dropsCount,
    this.dilate,
    this.dilationTime,
  });

  factory OtEyeDropEntry.fromJson(Map<String, dynamic> j) => OtEyeDropEntry(
        id: switch (j['id']) { int v => v, num n => n.toInt(), String s => int.tryParse(s) ?? 0, _ => 0 },
        medicineName: j['medicine_name'] as String? ?? '',
        eye: j['eye'] as String? ?? 'RE',
        doseNumber: switch (j['dose_number']) { int v => v, num n => n.toInt(), String s => int.tryParse(s) ?? 1, _ => 1 },
        administeredAt: j['administered_at'] as String?,
        administeredBy: j['administered_by'] != null ? OtNamedRef.fromJson(j['administered_by'] as Map<String, dynamic>) : null,
        remarks: j['remarks'] as String?,
        dropsCount: switch (j['drops_count']) { int v => v, num n => n.toInt(), String s => int.tryParse(s), _ => null },
        dilate: j['dilate'] as String?,
        dilationTime: switch (j['dilation_time']) { int v => v, num n => n.toInt(), String s => int.tryParse(s), _ => null },
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
  final OtNamedRef? opdDoctor;
  final OtNamedRef? otAssistant;
  // Web pull 2026-10-12 — the OT Assistant picker is gone from the Status
  // form entirely; Ready for OT auto-resolves the assistant from the linked
  // doctor's own "Connected OT Assistant" profile field. This is who that
  // resolves to right now, shown read-only instead of a dropdown.
  final OtNamedRef? defaultOtAssistant;
  // Eye Drop Register medicine picker source (Medicine Master, OT scope
  // only) — replaces free-text entry (web pull 2026-08-07). See
  // WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §8.
  final List<OtNamedRef> otMedicines;

  const OtVerificationHeader({
    required this.uhid,
    required this.patientName,
    this.surgeryType,
    this.eye,
    this.otDoctor,
    this.opdDoctor,
    this.otAssistant,
    this.defaultOtAssistant,
    this.otMedicines = const [],
  });

  factory OtVerificationHeader.fromJson(Map<String, dynamic> j) => OtVerificationHeader(
        uhid: j['uhid'] as String? ?? '',
        patientName: j['patient_name'] as String? ?? '',
        surgeryType: j['surgery_type'] as String?,
        eye: j['eye'] as String?,
        otDoctor: j['ot_doctor'] != null ? OtNamedRef.fromJson(j['ot_doctor'] as Map<String, dynamic>) : null,
        opdDoctor: j['opd_doctor'] != null ? OtNamedRef.fromJson(j['opd_doctor'] as Map<String, dynamic>) : null,
        otAssistant: j['ot_assistant'] != null ? OtNamedRef.fromJson(j['ot_assistant'] as Map<String, dynamic>) : null,
        defaultOtAssistant: j['default_ot_assistant'] != null ? OtNamedRef.fromJson(j['default_ot_assistant'] as Map<String, dynamic>) : null,
        otMedicines: (j['ot_medicines'] as List? ?? []).map((e) => OtNamedRef.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
