import 'medicine_models.dart';
import 'ot_booking_models.dart';
import 'ot_counsellor_models.dart';

class OtSurgeryTypeOption {
  final int id;
  final String surgeryName;

  const OtSurgeryTypeOption({required this.id, required this.surgeryName});

  factory OtSurgeryTypeOption.fromJson(Map<String, dynamic> j) => OtSurgeryTypeOption(
        id: j['id'] as int,
        surgeryName: j['surgery_name'] as String? ?? '',
      );
}

/// Prior verification state, if this booking's surgery was already recorded
/// once (verify + record happen atomically in one call — see build PRD §8
/// gotcha, there's no standalone "verify" step).
class OtVerificationStatus {
  final bool identityVerified;
  final bool consentVerified;
  final bool paymentVerified;
  final bool correctEyeVerified;

  const OtVerificationStatus({
    required this.identityVerified,
    required this.consentVerified,
    required this.paymentVerified,
    required this.correctEyeVerified,
  });

  factory OtVerificationStatus.fromJson(Map<String, dynamic> j) => OtVerificationStatus(
        identityVerified: j['identity_verified'] as bool? ?? false,
        consentVerified: j['consent_verified'] as bool? ?? false,
        paymentVerified: j['payment_verified'] as bool? ?? false,
        correctEyeVerified: j['correct_eye_verified'] as bool? ?? false,
      );
}

class OtSurgeryFormData {
  final OtBookingSummary booking;
  final OtCounsellingItem? counselling;
  final OtVerificationStatus? verification;
  final List<OtSurgeryTypeOption> surgeryTypes;
  final List<String> medicines;
  // Section C "Lens Selection" dropdown options + the OT ward-medicine
  // quick-fill groups, both embedded in this same response (web parity —
  // see OT_SURGERY_RECORD_WEB_PARITY_FIX_PLAN.md TASK 1.3/2.1). Reuses the
  // existing MedGroup/MedGroupItem models — the raw embedded shape parses
  // fine through them (medicine name resolves via the eager-loaded
  // `items.medicine` relation; dosage/route stay null since those relations
  // aren't eager-loaded here, but neither is used by the OT quick-fill).
  final List<String> lensTypes;
  final List<MedGroup> medicineGroups;

  const OtSurgeryFormData({
    required this.booking,
    this.counselling,
    this.verification,
    required this.surgeryTypes,
    required this.medicines,
    this.lensTypes = const [],
    this.medicineGroups = const [],
  });

  factory OtSurgeryFormData.fromJson(Map<String, dynamic> j) => OtSurgeryFormData(
        booking: OtBookingSummary.fromJson(j['booking'] as Map<String, dynamic>),
        counselling: j['counselling'] != null ? OtCounsellingItem.fromJson(j['counselling'] as Map<String, dynamic>) : null,
        verification: j['verification'] != null ? OtVerificationStatus.fromJson(j['verification'] as Map<String, dynamic>) : null,
        surgeryTypes: (j['surgery_types'] as List? ?? []).map((e) => OtSurgeryTypeOption.fromJson(e as Map<String, dynamic>)).toList(),
        medicines: (j['medicines'] as List? ?? []).map((e) => (e as Map<String, dynamic>)['name'] as String? ?? '').toList(),
        lensTypes: (j['lens_types'] as List? ?? []).map((e) => e.toString()).toList(),
        medicineGroups: (j['medicine_groups'] as List? ?? []).map((e) => MedGroup.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// A single `ot_medicines[]` line item in the `POST .../surgery` body.
class OtSurgeryMedicineLine {
  final String medicine;
  final String? dose;

  const OtSurgeryMedicineLine({required this.medicine, this.dose});

  Map<String, dynamic> toJson() => {'medicine': medicine, 'dose': dose};
}

/// OT Assistant "View" parity (web pull 2026-09-30,
/// `_view-modal.blade.php`'s "Surgery Record" section) — the recorded
/// outcome of `storeSurgery()`, read-only display only (the write path
/// still goes through `_AssistantDetailPane`'s own form fields).
class OtSurgeryRecord {
  final int id;
  final String? surgeryName;
  final String? eyeOperated;
  final OtNamedRef? operatedBy;
  final String? otRoom;
  final DateTime? surgeryAt;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? complicationStatus;
  final String? complicationNotes;
  final String? surgeryStatus;

  const OtSurgeryRecord({
    required this.id,
    this.surgeryName,
    this.eyeOperated,
    this.operatedBy,
    this.otRoom,
    this.surgeryAt,
    this.startTime,
    this.endTime,
    this.complicationStatus,
    this.complicationNotes,
    this.surgeryStatus,
  });

  /// Web: `($end - $start + 1440) % 1440`, discarded if 0 or > 720 minutes —
  /// guards against a bad/garbled time pair reading as a near-24h "surgery".
  int? get durationMinutes {
    if (startTime == null || endTime == null) return null;
    final startMin = startTime!.hour * 60 + startTime!.minute;
    final endMin = endTime!.hour * 60 + endTime!.minute;
    final duration = (endMin - startMin + 1440) % 1440;
    return (duration == 0 || duration > 720) ? null : duration;
  }

  factory OtSurgeryRecord.fromJson(Map<String, dynamic> j) => OtSurgeryRecord(
        id: j['id'] as int,
        surgeryName: j['surgery_name'] as String?,
        eyeOperated: j['eye_operated'] as String?,
        operatedBy: j['operated_by'] != null && j['operated_by'] is Map<String, dynamic> ? OtNamedRef.fromJson(j['operated_by'] as Map<String, dynamic>) : null,
        otRoom: j['ot_room'] as String?,
        surgeryAt: j['surgery_at'] != null ? DateTime.tryParse(j['surgery_at'] as String) : null,
        startTime: j['start_time'] != null ? DateTime.tryParse(j['start_time'] as String) : null,
        endTime: j['end_time'] != null ? DateTime.tryParse(j['end_time'] as String) : null,
        complicationStatus: j['complication_status'] as String?,
        complicationNotes: j['complication_notes'] as String?,
        surgeryStatus: j['surgery_status'] as String?,
      );
}

/// OT Assistant "View" parity — the implanted-lens record
/// (`_view-modal.blade.php`'s "Implanted Lens" section).
class OtLensDetailInfo {
  final String? lensName;
  final String? manufacturer;
  final String? lensType;
  final double? lensPower;
  final double? axis;
  final String? serialNumber;
  final bool isImplanted;

  const OtLensDetailInfo({
    this.lensName,
    this.manufacturer,
    this.lensType,
    this.lensPower,
    this.axis,
    this.serialNumber,
    this.isImplanted = false,
  });

  factory OtLensDetailInfo.fromJson(Map<String, dynamic> j) => OtLensDetailInfo(
        lensName: j['lens_name'] as String?,
        manufacturer: j['manufacturer'] as String?,
        lensType: j['lens_type'] as String?,
        lensPower: switch (j['lens_power']) { num n => n.toDouble(), String s => double.tryParse(s), _ => null },
        axis: switch (j['axis']) { num n => n.toDouble(), String s => double.tryParse(s), _ => null },
        serialNumber: j['serial_number'] as String?,
        isImplanted: j['is_implanted'] as bool? ?? false,
      );
}

