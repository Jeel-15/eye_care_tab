import 'ot_assistant_models.dart';
import 'ot_booking_models.dart';
import 'ot_inventory_models.dart';

/// `ot_counselling` is read via a raw `DB::table()` query (not an Eloquent
/// model) on the Surgery Record endpoint (`surgeryFormData()`), so Laravel's
/// `boolean` cast never applies there — MySQL/PDO hands back a raw `1`/`0`
/// (or `"1"`/`"0"`), not `true`/`false`. Other endpoints that DO go through
/// the Eloquent `OtCounselling` model send real booleans. `as bool?` throws
/// on the int/string form ("type 'int' is not a subtype of type 'bool?'") —
/// this coerces either shape safely.
bool _jsonBool(dynamic v, {bool fallback = false}) => switch (v) {
      bool b => b,
      num n => n != 0,
      String s => s == '1' || s.toLowerCase() == 'true',
      _ => fallback,
    };

/// A package suggestion returned by `package-lookup` — a lighter shape than
/// the full `OtPackageMasterItem` (no id/lens_cost/room_category, since the
/// caller already supplied those as query params).
class OtPackageLookupSuggestion {
  final String packageName;
  final double otCharges;
  final double surgeonCharges;
  final double nursingCharges;
  final double consumablesCharges;

  const OtPackageLookupSuggestion({
    required this.packageName,
    required this.otCharges,
    required this.surgeonCharges,
    required this.nursingCharges,
    required this.consumablesCharges,
  });

  factory OtPackageLookupSuggestion.fromJson(Map<String, dynamic> j) => OtPackageLookupSuggestion(
        packageName: j['package_name'] as String? ?? '',
        otCharges: numOrStringToDouble(j['ot_charges']) ?? 0,
        surgeonCharges: numOrStringToDouble(j['surgeon_charges']) ?? 0,
        nursingCharges: numOrStringToDouble(j['nursing_charges']) ?? 0,
        consumablesCharges: numOrStringToDouble(j['consumables_charges']) ?? 0,
      );
}

/// The counselling record attached to a booking. `toJson()` builds the
/// `POST .../counselling` body exactly.
class OtCounsellingItem {
  final String? diagnosis;
  final String eye; // RE | LE | Both
  // Replaces the old surgery_type_confirmed checkbox — must match an active
  // ot_surgery_types.surgery_name (web pull 2026-08-07). See
  // WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §7.
  final String? otType;
  final bool mediclaim;
  final String? lensCategory; // standard | premium
  final String? lensCompany;
  final String? lensModel;
  final String? lensType;
  final double? estimatedPower;
  final double? lensCost;
  final String? packageName;
  // Surgery Record form's Section A "Package" display source — web:
  // `$counselling?->package_amount ?? $booking->package_amount`. See
  // OT_SURGERY_RECORD_WEB_PARITY_FIX_PLAN.md TASK 2.1.
  final double? packageAmount;
  final String roomCategory; // general | private
  final double otCharges;
  final double surgeonCharges;
  final double nursingCharges;
  final double consumablesCharges;
  final String paymentMode; // mediclaim | cash | online
  final bool bloodReportsVerified;
  final bool bloodReportsNormal;
  final String? notes;
  final double? totalEstimate;

  const OtCounsellingItem({
    this.diagnosis,
    required this.eye,
    this.otType,
    required this.mediclaim,
    this.lensCategory,
    this.lensCompany,
    this.lensModel,
    this.lensType,
    this.estimatedPower,
    this.lensCost,
    this.packageName,
    this.packageAmount,
    required this.roomCategory,
    required this.otCharges,
    required this.surgeonCharges,
    required this.nursingCharges,
    required this.consumablesCharges,
    required this.paymentMode,
    this.bloodReportsVerified = false,
    this.bloodReportsNormal = false,
    this.notes,
    this.totalEstimate,
  });

  factory OtCounsellingItem.fromJson(Map<String, dynamic> j) => OtCounsellingItem(
        diagnosis: j['diagnosis'] as String?,
        eye: j['eye'] as String? ?? 'Both',
        otType: j['ot_type'] as String?,
        mediclaim: _jsonBool(j['mediclaim']),
        lensCategory: j['lens_category'] as String?,
        lensCompany: j['lens_company'] as String?,
        lensModel: j['lens_model'] as String?,
        lensType: j['lens_type'] as String?,
        estimatedPower: numOrStringToDouble(j['estimated_power']),
        lensCost: numOrStringToDouble(j['lens_cost']),
        packageName: j['package_name'] as String?,
        packageAmount: numOrStringToDouble(j['package_amount']),
        roomCategory: j['room_category'] as String? ?? 'general',
        otCharges: numOrStringToDouble(j['ot_charges']) ?? 0,
        surgeonCharges: numOrStringToDouble(j['surgeon_charges']) ?? 0,
        nursingCharges: numOrStringToDouble(j['nursing_charges']) ?? 0,
        consumablesCharges: numOrStringToDouble(j['consumables_charges']) ?? 0,
        paymentMode: j['payment_mode'] as String? ?? 'cash',
        bloodReportsVerified: _jsonBool(j['blood_reports_verified']),
        bloodReportsNormal: _jsonBool(j['blood_reports_normal']),
        notes: j['notes'] as String?,
        totalEstimate: numOrStringToDouble(j['total_estimate']),
      );

  Map<String, dynamic> toJson() => {
        'diagnosis': diagnosis,
        'eye': eye,
        'ot_type': otType,
        'mediclaim': mediclaim,
        'lens_category': lensCategory,
        'lens_company': lensCompany,
        'lens_model': lensModel,
        'lens_type': lensType,
        'estimated_power': estimatedPower,
        'lens_cost': lensCost,
        'package_name': packageName,
        'room_category': roomCategory,
        'ot_charges': otCharges,
        'surgeon_charges': surgeonCharges,
        'nursing_charges': nursingCharges,
        'consumables_charges': consumablesCharges,
        'payment_mode': mediclaim ? 'mediclaim' : paymentMode,
        'blood_reports_verified': bloodReportsVerified,
        'blood_reports_normal': bloodReportsNormal,
        'notes': notes,
      };
}

class OtConsentItem {
  final bool consentGiven;
  final String? patientSignatureUrl;
  final String? guardianSignatureUrl;
  final String? witnessName;
  final String? consentDate;

  const OtConsentItem({
    required this.consentGiven,
    this.patientSignatureUrl,
    this.guardianSignatureUrl,
    this.witnessName,
    this.consentDate,
  });

  factory OtConsentItem.fromJson(Map<String, dynamic> j) => OtConsentItem(
        consentGiven: j['consent_given'] as bool? ?? false,
        patientSignatureUrl: j['patient_signature_url'] as String?,
        guardianSignatureUrl: j['guardian_signature_url'] as String?,
        witnessName: j['witness_name'] as String?,
        consentDate: j['consent_date'] as String?,
      );
}

/// `GET .../ot/bookings/{id}/counselling` — full detail for the counselling
/// form screen.
class OtCounsellingDetail {
  final OtBookingSummary booking;
  final OtCounsellingItem? counselling;
  final OtConsentItem? consent;
  final List<OtPackageMasterItem> packageCostOptions;
  // Replaces lens_options — the ot_type dropdown's source list (web pull
  // 2026-08-07). See WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §7.
  final List<OtSurgeryTypeOption> otSurgeryTypes;

  const OtCounsellingDetail({
    required this.booking,
    this.counselling,
    this.consent,
    required this.packageCostOptions,
    required this.otSurgeryTypes,
  });

  factory OtCounsellingDetail.fromJson(Map<String, dynamic> j) => OtCounsellingDetail(
        booking: OtBookingSummary.fromJson(j['booking'] as Map<String, dynamic>),
        counselling: j['counselling'] != null ? OtCounsellingItem.fromJson(j['counselling'] as Map<String, dynamic>) : null,
        consent: j['consent'] != null ? OtConsentItem.fromJson(j['consent'] as Map<String, dynamic>) : null,
        packageCostOptions: (j['package_cost_options'] as List? ?? []).map((e) => OtPackageMasterItem.fromJson(e as Map<String, dynamic>)).toList(),
        otSurgeryTypes: (j['ot_surgery_types'] as List? ?? []).map((e) => OtSurgeryTypeOption.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
