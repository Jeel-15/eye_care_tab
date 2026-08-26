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

