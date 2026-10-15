import 'ot_booking_models.dart';
import '../services/referrer_service.dart';
import '../services/ot_slot_service.dart';

/// `/ot/appointments/form-data` location entry. Field key uncertain (tracker
/// says `name`, but the existing OPD `PatientLocation` model reads `city`
/// for the same conceptual field) — reads either defensively until verified
/// against a live API response.
class OtAppointmentLocation {
  final int id;
  final String name;
  final String? district;
  final String? state;

  const OtAppointmentLocation({required this.id, required this.name, this.district, this.state});

  factory OtAppointmentLocation.fromJson(Map<String, dynamic> j) => OtAppointmentLocation(
        id: j['id'] as int,
        name: j['name'] as String? ?? j['city'] as String? ?? '',
        // `district`/`state` are eager-loaded Eloquent relations on the API
        // response (MasterCity::with(['district', 'state'])), so they arrive
        // as nested {id, name, ...} objects, not plain strings.
        district: (j['district'] as Map<String, dynamic>?)?['name'] as String?,
        state: (j['state'] as Map<String, dynamic>?)?['name'] as String?,
      );
}

class OtAppointmentItem {
  final int id;
  final String appointmentNumber;
  final String appointmentType; // phone | walk_in | online | referral
  final String appointmentDate;
  final String? appointmentTime;
  final OtNamedRef? doctor;
  final OtAppointmentLocation? location;
  final String patientName;
  final String? middleName;
  final String surname;
  final String mobileNo;
  final String? whatsappNo;
  final int age;
  final String gender;
  final String? occupation;
  final int? referrerId;
  final String status; // booked | confirmed | cancelled | completed
  // Web pull 2026-10-07 — Booked tab: always "Booked". Completed tab: the
  // converted patient's live workflow stage (Primary Exam → ... →
  // Discharge), not the old OT-booking-specific 16-stage system.
  final String stageLabel;
  final String stageBadgeClass;
  final String? stageSub;
  // Web pull 2026-09-29 — web's Action column dropped the Confirm/Cancel
  // icons entirely in favor of a single "Walk-In" button, matching
  // `OtAppointment::canWalkIn()`: status booked/confirmed AND not already
  // converted to a patient. Needed to replicate that same gate here.
  final int? convertedPatientId;

  bool get canWalkIn => (status == 'booked' || status == 'confirmed') && convertedPatientId == null;

  const OtAppointmentItem({
    required this.id,
    required this.appointmentNumber,
    required this.appointmentType,
    required this.appointmentDate,
    this.appointmentTime,
    this.doctor,
    this.location,
    required this.patientName,
    this.middleName,
    required this.surname,
    required this.mobileNo,
    this.whatsappNo,
    required this.age,
    required this.gender,
    this.occupation,
    this.referrerId,
    required this.status,
    required this.stageLabel,
    required this.stageBadgeClass,
    this.stageSub,
    this.convertedPatientId,
  });

  String get fullName => [patientName, middleName, surname].where((s) => s != null && s.isNotEmpty).join(' ');

  factory OtAppointmentItem.fromJson(Map<String, dynamic> j) => OtAppointmentItem(
        id: j['id'] as int,
        appointmentNumber: j['appointment_number'] as String? ?? '',
        appointmentType: j['appointment_type'] as String? ?? '',
        appointmentDate: j['appointment_date'] as String? ?? '',
        appointmentTime: j['appointment_time'] as String?,
        doctor: j['doctor'] != null ? OtNamedRef.fromJson(j['doctor'] as Map<String, dynamic>) : null,
        location: j['location'] != null ? OtAppointmentLocation.fromJson(j['location'] as Map<String, dynamic>) : null,
        patientName: j['patient_name'] as String? ?? '',
        middleName: j['middle_name'] as String?,
        surname: j['surname'] as String? ?? '',
        mobileNo: j['mobile_no'] as String? ?? '',
        whatsappNo: j['whatsapp_no'] as String?,
        age: j['age'] as int? ?? 0,
        gender: j['gender'] as String? ?? '',
        occupation: j['occupation'] as String?,
        referrerId: j['referrer_id'] as int?,
        status: j['status'] as String? ?? 'booked',
        stageLabel: j['stage_label'] as String? ?? '',
        stageBadgeClass: j['stage_badge_class'] as String? ?? '',
        stageSub: j['stage_sub'] as String?,
        convertedPatientId: j['converted_patient_id'] as int?,
      );
}

class OtAppointmentFormData {
  final List<OtNamedRef> doctors;
  final List<OtAppointmentLocation> locations;
  final List<ReferrerItem> referrers;
  final List<OtSlotItem> slots;
  final String nextAppointmentNumber;

  const OtAppointmentFormData({
    required this.doctors,
    required this.locations,
    required this.referrers,
    required this.slots,
    required this.nextAppointmentNumber,
  });

  factory OtAppointmentFormData.fromJson(Map<String, dynamic> j) => OtAppointmentFormData(
        doctors: (j['doctors'] as List? ?? []).map((e) => OtNamedRef.fromJson(e as Map<String, dynamic>)).toList(),
        locations: (j['locations'] as List? ?? []).map((e) => OtAppointmentLocation.fromJson(e as Map<String, dynamic>)).toList(),
        referrers: (j['referrers'] as List? ?? []).map((e) => ReferrerItem.fromJson(e as Map<String, dynamic>)).toList(),
        slots: (j['slots'] as List? ?? []).map((e) => OtSlotItem.fromJson(e as Map<String, dynamic>)).toList(),
        nextAppointmentNumber: j['next_appointment_number'] as String? ?? '',
      );
}

class OtAppointmentSearchResult {
  final bool found;
  final List<OtAppointmentItem> appointments;

  const OtAppointmentSearchResult({required this.found, required this.appointments});

  factory OtAppointmentSearchResult.fromJson(Map<String, dynamic> j) => OtAppointmentSearchResult(
        found: j['found'] as bool? ?? false,
        appointments: (j['appointments'] as List? ?? []).map((e) => OtAppointmentItem.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// One row from `slot-appointments` — double-booking check for the create/
/// edit form.
class OtSlotAppointmentConflict {
  final int id;
  final String name;
  final String status;

  const OtSlotAppointmentConflict({required this.id, required this.name, required this.status});

  factory OtSlotAppointmentConflict.fromJson(Map<String, dynamic> j) => OtSlotAppointmentConflict(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        status: j['status'] as String? ?? '',
      );
}
