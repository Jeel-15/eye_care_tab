// Patient-related models for OPD screens

import '../utils/date_format.dart';
import '../utils/json_parse.dart';

class PatientStats {
  final int total;
  final int waiting;
  final int primaryDone;
  final int completed;

  const PatientStats({
    required this.total,
    required this.waiting,
    required this.primaryDone,
    required this.completed,
  });

  factory PatientStats.fromJson(Map<String, dynamic> j) => PatientStats(
        total: j['total'] as int? ?? 0,
        waiting: j['waiting'] as int? ?? 0,
        primaryDone: j['primary_done'] as int? ?? 0,
        completed: j['completed'] as int? ?? 0,
      );

  PatientStats copyWith({int? total, int? waiting, int? primaryDone, int? completed}) =>
      PatientStats(
        total: total ?? this.total,
        waiting: waiting ?? this.waiting,
        primaryDone: primaryDone ?? this.primaryDone,
        completed: completed ?? this.completed,
      );
}

class PatientMeta {
  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;

  const PatientMeta({
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
  });

  factory PatientMeta.fromJson(Map<String, dynamic> j) => PatientMeta(
        total: j['total'] as int? ?? 0,
        perPage: j['per_page'] as int? ?? 25,
        currentPage: j['current_page'] as int? ?? 1,
        lastPage: j['last_page'] as int? ?? 1,
      );
}

class PatientDoctor {
  final int id;
  final String name;
  // Web's "DR INDEX" column on the receptionist dashboard's Today Added
  // Patients table formats as `{doctor_prefix}-{doctor_patient_no}` when the
  // doctor has a prefix configured, else `#{doctor_patient_no}` — the
  // `/dashboard/today-patients` API already eager-loads this column
  // (`doctor:id,name,doctor_prefix`), just wasn't parsed here yet.
  final String? doctorPrefix;

  const PatientDoctor({required this.id, required this.name, this.doctorPrefix});

  factory PatientDoctor.fromJson(Map<String, dynamic> j) =>
      PatientDoctor(id: j['id'] as int, name: j['name'] as String? ?? '', doctorPrefix: j['doctor_prefix'] as String?);
}

PatientLocation? _readLocation(dynamic raw) {
  if (raw is! Map) return null;
  final j = Map<String, dynamic>.from(raw);
  final id = jsonIntOrNull(j['id']);
  final city = j['city']?.toString() ?? '';
  final district = j['district']?.toString() ?? '';
  final state = j['state']?.toString() ?? '';
  if (id == null && city.isEmpty && district.isEmpty && state.isEmpty) return null;
  return PatientLocation(id: id ?? -1, city: city, district: district, state: state);
}

class PatientLocation {
  final int id;
  final String city;
  final String district;
  final String state;

  const PatientLocation({
    required this.id,
    required this.city,
    required this.district,
    required this.state,
  });

  factory PatientLocation.fromJson(Map<String, dynamic> j) => PatientLocation(
        id: j['id'] as int,
        city: j['city'] as String? ?? '',
        district: j['district'] as String? ?? '',
        state: j['state'] as String? ?? '',
      );

  String get display => [city, district, state].where((s) => s.isNotEmpty).join(', ');
}

class PatientCaseType {
  final int id;
  final String caseType;

  const PatientCaseType({required this.id, required this.caseType});

  factory PatientCaseType.fromJson(Map<String, dynamic> j) =>
      PatientCaseType(id: j['id'] as int, caseType: j['case_type'] as String? ?? '');
}

class PatientReferrer {
  final int id;
  final String name;

  const PatientReferrer({required this.id, required this.name});

  factory PatientReferrer.fromJson(Map<String, dynamic> j) =>
      PatientReferrer(id: j['id'] as int, name: j['name'] as String? ?? '');
}

class PatientPrimaryExam {
  final int id;
  final Map<String, dynamic>? examData;
  final int? dilationTime;
  final DateTime? updatedAt;
  // OT Counselling "View" parity (web pull 2026-09-30) —
  // `_patient-view-modal.blade.php`'s Examination section shows who examined
  // the patient and when, not just a done/pending flag. Only populated by
  // endpoints that eager-load `primaryExamination.doctor`.
  final DateTime? examinedAt;
  final String? doctorName;

  const PatientPrimaryExam({
    required this.id,
    this.examData,
    this.dilationTime,
    this.updatedAt,
    this.examinedAt,
    this.doctorName,
  });

  factory PatientPrimaryExam.fromJson(Map<String, dynamic> j) {
    dynamic raw = j['exam_data'];
    Map<String, dynamic>? data;
    if (raw is Map<String, dynamic>) {
      data = raw;
    } else if (raw is String && raw.isNotEmpty) {
      try {
        data = Map<String, dynamic>.from(
            (raw as dynamic).toString() == '' ? {} : {});
      } catch (_) {}
    }
    return PatientPrimaryExam(
      id: j['id'] as int,
      examData: data,
      dilationTime: j['dilation_time'] as int?,
      updatedAt: j['updated_at'] != null
          ? DateTime.tryParse(j['updated_at'] as String)
          : null,
      examinedAt: j['examined_at'] != null ? DateTime.tryParse(j['examined_at'] as String) : null,
      doctorName: (j['doctor'] as Map<String, dynamic>?)?['name'] as String?,
    );
  }
}

/// OT Counselling "View" parity (web pull 2026-09-30) — the secondary exam
/// step needs the same who/when as [PatientPrimaryExam]; only populated by
/// endpoints that eager-load `secondaryExamination.doctor`.
class PatientSecondaryExam {
  final int id;
  final DateTime? examinedAt;
  final String? doctorName;

  const PatientSecondaryExam({required this.id, this.examinedAt, this.doctorName});

  factory PatientSecondaryExam.fromJson(Map<String, dynamic> j) => PatientSecondaryExam(
        id: j['id'] as int,
        examinedAt: j['examined_at'] != null ? DateTime.tryParse(j['examined_at'] as String) : null,
        doctorName: (j['doctor'] as Map<String, dynamic>?)?['name'] as String?,
      );
}

enum PatientStatus { waiting, primaryDone, completed }

class Patient {
  final int id;
  final String patientCode;
  final String firstName;
  final String lastName;
  final String middleName;
  final String fullName;
  final int? age;
  final String? gender;
  final String? contactNo;
  final String? whatsappNo;
  final String? occupation;
  final String? appointmentDate;
  final double? caseFee;
  final String type; // walkin | phone
  final int? caseId;
  final int? slotId;
  final int? doctorPatientNo;
  final int? referrerId;
  final bool isOldPatient;
  final DateTime? checkedInAt;
  final DateTime? primaryDoneAt;
  final DateTime? secondaryDoneAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final PatientDoctor? doctor;
  final PatientLocation? location;
  final PatientCaseType? caseType;
  final PatientReferrer? referrer;
  final PatientPrimaryExam? primaryExamination;
  final bool hasSecondaryExam;
  final PatientSecondaryExam? secondaryExamination;
  final int? unlockTimeMs;
  // Web pull 2026-09-28 — receptionist "Today Added Patients" widget's
  // Patient Status tab. Only populated by DashboardController::todayPatients;
  // other endpoints that return a Patient leave these at their defaults.
  final String? statusLabel;
  final String? statusTone;
  // Web pull 2026-09-29 (WEB_ADMIN_RECEPTIONIST_DASHBOARD_AUDIT.md finding
  // #3) — `workflowStage()`'s secondary line (e.g. "Payment pending",
  // "Partially paid", "Awaiting ward", "In ward", "Dilated") shown under the
  // status badge on the Patient Status tab. The API already sent this in
  // `workflow_stage.sub`; this app just never parsed/rendered it.
  final String? statusSub;
  final List<String> tapGroups;
  // Web pull 2026-09-29 (WEB_VIEW_BUTTONS_PARITY_AUDIT.md finding #2) —
  // exam screens' "Patient Details" modal's Receptionist field. Only
  // populated by endpoints that eager-load the `reception` relation
  // (currently PatientApiController::show) — other endpoints leave it null.
  final String? receptionistName;

  const Patient({
    required this.id,
    required this.patientCode,
    required this.firstName,
    required this.lastName,
    this.middleName = '',
    required this.fullName,
    this.age,
    this.gender,
    this.contactNo,
    this.whatsappNo,
    this.occupation,
    this.appointmentDate,
    this.caseFee,
    this.type = 'walkin',
    this.caseId,
    this.slotId,
    this.doctorPatientNo,
    this.referrerId,
    this.isOldPatient = false,
    this.checkedInAt,
    this.primaryDoneAt,
    this.secondaryDoneAt,
    this.createdAt,
    this.updatedAt,
    this.doctor,
    this.location,
    this.caseType,
    this.referrer,
    this.primaryExamination,
    this.hasSecondaryExam = false,
    this.secondaryExamination,
    this.unlockTimeMs,
    this.statusLabel,
    this.statusTone,
    this.statusSub,
    this.tapGroups = const [],
    this.receptionistName,
  });

  factory Patient.fromJson(Map<String, dynamic> j) => Patient(
        id: j['id'] as int,
        patientCode: j['patient_code'] as String? ?? '',
        firstName: j['first_name'] as String? ?? '',
        lastName: j['last_name'] as String? ?? '',
        middleName: j['middle_name'] as String? ?? '',
        fullName: j['full_name'] as String? ??
            '${j['first_name'] ?? ''} ${j['last_name'] ?? ''}'.trim(),
        age: j['age'] as int?,
        gender: j['gender'] as String?,
        contactNo: j['contact_no'] as String?,
        whatsappNo: j['whatsapp_no'] as String?,
        occupation: j['occupation'] as String?,
        appointmentDate: j['appointment_date']?.toString(),
        caseFee: j['case_fee'] != null
            ? double.tryParse(j['case_fee'].toString())
            : null,
        type: j['type'] as String? ?? 'walkin',
        caseId: j['case_id'] as int?,
        slotId: j['slot_id'] as int?,
        doctorPatientNo: j['doctor_patient_no'] as int?,
        referrerId: j['referrer_id'] as int?,
        isOldPatient: j['is_old_patient'] == true || j['is_old_patient'] == 1 || j['is_old_patient'] == '1',
        checkedInAt: j['checked_in_at'] != null
            ? DateTime.tryParse(j['checked_in_at'] as String)
            : null,
        primaryDoneAt: j['primary_done_at'] != null
            ? DateTime.tryParse(j['primary_done_at'] as String)
            : null,
        secondaryDoneAt: j['secondary_done_at'] != null
            ? DateTime.tryParse(j['secondary_done_at'] as String)
            : null,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
        updatedAt: j['updated_at'] != null
            ? DateTime.tryParse(j['updated_at'] as String)
            : null,
        doctor: j['doctor'] != null
            ? PatientDoctor.fromJson(j['doctor'] as Map<String, dynamic>)
            : null,
        location: _readLocation(j['location']),
        caseType: j['case_type'] != null
            ? PatientCaseType.fromJson(j['case_type'] as Map<String, dynamic>)
            : null,
        referrer: j['referrer'] != null
            ? PatientReferrer.fromJson(j['referrer'] as Map<String, dynamic>)
            : null,
        primaryExamination: j['primary_examination'] != null
            ? PatientPrimaryExam.fromJson(
                j['primary_examination'] as Map<String, dynamic>)
            : null,
        hasSecondaryExam: j['secondary_examination'] != null,
        secondaryExamination: j['secondary_examination'] != null
            ? PatientSecondaryExam.fromJson(j['secondary_examination'] as Map<String, dynamic>)
            : null,
        unlockTimeMs: j['unlock_time_ms'] as int?,
        statusLabel: j['status_label'] as String?,
        statusTone: (j['workflow_stage'] as Map<String, dynamic>?)?['tone'] as String?,
        statusSub: (j['workflow_stage'] as Map<String, dynamic>?)?['sub'] as String?,
        tapGroups: (j['tap_groups'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
        receptionistName: (j['reception'] as Map<String, dynamic>?)?['name'] as String?,
      );

  PatientStatus get status {
    if (secondaryDoneAt != null) return PatientStatus.completed;
    if (primaryDoneAt != null) return PatientStatus.primaryDone;
    return PatientStatus.waiting;
  }

  bool get isDilating {
    if (unlockTimeMs == null) return false;
    return DateTime.now().millisecondsSinceEpoch < unlockTimeMs!;
  }

  String get appointmentTimeFormatted {
    if (createdAt == null) return '';
    final hc = toHospitalTime(createdAt!);
    final h = hc.hour;
    final m = hc.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour12:$m $period';
  }

  String get genderDisplay {
    if (gender == null) return '';
    return gender![0].toUpperCase() + gender!.substring(1);
  }
}

// ─── Master data models ───────────────────────────────────────────────────────

class CaseTypeOption {
  final int id;
  final String name;
  final double fee;

  const CaseTypeOption({required this.id, required this.name, required this.fee});

  factory CaseTypeOption.fromJson(Map<String, dynamic> j) => CaseTypeOption(
        id: jsonInt(j['id']),
        name: j['name'] as String? ?? '',
        fee: double.tryParse(j['fee']?.toString() ?? '0') ?? 0,
      );
}

class DoctorOption {
  final int id;
  final String name;
  final String? doctorType;

  const DoctorOption({required this.id, required this.name, this.doctorType});

  factory DoctorOption.fromJson(Map<String, dynamic> j) => DoctorOption(
        id: jsonInt(j['id']),
        name: j['name'] as String? ?? '',
        doctorType: j['doctor_type'] as String?,
      );
}

class LocationOption {
  final int id;
  final String city;
  final String district;
  final String state;

  const LocationOption({
    required this.id,
    required this.city,
    required this.district,
    required this.state,
  });

  factory LocationOption.fromJson(Map<String, dynamic> j) => LocationOption(
        id: jsonInt(j['id']),
        city: j['city'] as String? ?? '',
        district: j['district'] as String? ?? '',
        state: j['state'] as String? ?? '',
      );
}

class SlotOption {
  final int id;
  final String name;
  final String? startTime;
  final String? endTime;

  const SlotOption({
    required this.id,
    required this.name,
    this.startTime,
    this.endTime,
  });

  factory SlotOption.fromJson(Map<String, dynamic> j) => SlotOption(
        id: jsonInt(j['id']),
        name: j['name'] as String? ?? '',
        startTime: j['start_time'] as String?,
        endTime: j['end_time'] as String?,
      );

  String get display => startTime != null && endTime != null
      ? '$name ($startTime–$endTime)'
      : name;
}

class ReferrerOption {
  final int id;
  final String name;
  final String? contact;

  const ReferrerOption({required this.id, required this.name, this.contact});

  factory ReferrerOption.fromJson(Map<String, dynamic> j) => ReferrerOption(
        id: jsonInt(j['id']),
        name: j['name'] as String? ?? '',
        contact: j['contact'] as String?,
      );
}

class ContactSuggestion {
  final String type; // 'local' | 'shared'
  final String? hospitalName;
  final String firstName;
  final String lastName;
  final String middleName;
  final int? age;
  final String? gender;
  final String? whatsappNo;
  final String? contactNo;
  final String? occupation;
  final int? locationId;

  const ContactSuggestion({
    required this.type,
    this.hospitalName,
    required this.firstName,
    required this.lastName,
    this.middleName = '',
    this.age,
    this.gender,
    this.whatsappNo,
    this.contactNo,
    this.occupation,
    this.locationId,
  });

  factory ContactSuggestion.fromJson(Map<String, dynamic> j) =>
      ContactSuggestion(
        type: j['type'] as String? ?? 'local',
        hospitalName: j['hospital_name'] as String?,
        firstName: j['first_name'] as String? ?? '',
        lastName: j['last_name'] as String? ?? '',
        middleName: j['middle_name'] as String? ?? '',
        age: j['age'] as int?,
        gender: j['gender'] as String?,
        whatsappNo: j['whatsapp_no'] as String?,
        contactNo: j['contact_no'] as String?,
        occupation: j['occupation'] as String?,
        locationId: j['location_id'] as int?,
      );

  String get fullName => '$firstName $lastName'.trim();
}
