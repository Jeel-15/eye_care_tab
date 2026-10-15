import 'patient_models.dart';
import 'ot_appointment_models.dart';

class DashboardData {
  final int? subscriptionDaysLeft;
  final bool isDoctor;
  final bool isOtDoctor;
  final bool isReceptionist;
  final int myTodayPatients;
  final int myPrimaryPending;
  final int mySecondaryPending;
  final int todayPatients;
  final int pendingExams;
  final int primaryQueueCount;
  final int secondaryQueueCount;
  final int todayWalkin;
  final int todayPhone;
  final int todayRegistrations;
  final double revenueToday;
  final double revenueMonth;
  final double revenueYear;
  final int otToday;
  final int otOperated;
  final int otPending;
  final int totalStaff;
  final int totalDoctors;
  final int totalReceptions;
  final int todayPrimary;
  final int todaySecondary;
  final int otTotalToday;
  // Web pull 2026-09-29 (WEB_ADMIN_RECEPTIONIST_DASHBOARD_AUDIT.md finding
  // #1) — admin's "Staff" (ALL roles, distinct from totalStaff's doctors+
  // receptionists-only) and "Medicines" bento cards.
  final int totalUsersAllRoles;
  final int totalMedicines;
  // Web pull 2026-10-14 — admin's new "Lens Report" quick-link card.
  final int totalLensToday;
  final List<QueuePatient> primaryQueue;
  final List<ReceptionistStat> receptionists;
  final WaitThresholds waitThresholds;
  final ReceptionistStats? receptionistStats;
  final List<DoctorCard> doctorCards;
  final int? pendingShareRequestsCount;
  final int? accountantPendingCount;
  final int? accountantRefundsCount;
  final int? accountantCompletedCount;
  final int? wardPendingCount;
  final int? wardCompletedCount;
  final int? otAssistantPendingCount;
  final int? otAssistantCompletedCount;
  final List<OtAssistantPeer> otAssistantPeers;
  final int? dischargePendingCount;
  final int? dischargeCompletedCount;
  final int? counsellingPendingCount;
  final int? counsellingCompletedCount;
  final int? counsellingPaymentCount;
  final int? otAppointmentPendingCount;
  final int? otAppointmentCompletedCount;

  const DashboardData({
    this.subscriptionDaysLeft,
    this.isDoctor = false,
    this.isOtDoctor = false,
    this.isReceptionist = false,
    this.myTodayPatients = 0,
    this.myPrimaryPending = 0,
    this.mySecondaryPending = 0,
    required this.todayPatients,
    this.pendingExams = 0,
    required this.primaryQueueCount,
    required this.secondaryQueueCount,
    required this.todayWalkin,
    required this.todayPhone,
    required this.todayRegistrations,
    required this.revenueToday,
    required this.revenueMonth,
    required this.revenueYear,
    required this.otToday,
    required this.otOperated,
    required this.otPending,
    required this.totalStaff,
    this.totalDoctors = 0,
    this.totalReceptions = 0,
    this.todayPrimary = 0,
    this.todaySecondary = 0,
    this.otTotalToday = 0,
    this.totalUsersAllRoles = 0,
    this.totalMedicines = 0,
    this.totalLensToday = 0,
    required this.primaryQueue,
    required this.receptionists,
    required this.waitThresholds,
    this.receptionistStats,
    this.doctorCards = const [],
    this.pendingShareRequestsCount,
    this.accountantPendingCount,
    this.accountantRefundsCount,
    this.accountantCompletedCount,
    this.wardPendingCount,
    this.wardCompletedCount,
    this.otAssistantPendingCount,
    this.otAssistantCompletedCount,
    this.otAssistantPeers = const [],
    this.dischargePendingCount,
    this.dischargeCompletedCount,
    this.counsellingPendingCount,
    this.counsellingCompletedCount,
    this.counsellingPaymentCount,
    this.otAppointmentPendingCount,
    this.otAppointmentCompletedCount,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return DashboardData(
      subscriptionDaysLeft: data['subscription_days_left'] as int?,
      isDoctor: data['is_doctor'] as bool? ?? false,
      isOtDoctor: data['is_ot_doctor'] as bool? ?? false,
      isReceptionist: data['is_receptionist'] as bool? ?? false,
      myTodayPatients: data['my_today_patients'] as int? ?? 0,
      myPrimaryPending: data['my_primary_pending'] as int? ?? 0,
      mySecondaryPending: data['my_secondary_pending'] as int? ?? 0,
      todayPatients: data['today_patients'] as int? ?? 0,
      pendingExams: data['pending_exams'] as int? ?? 0,
      primaryQueueCount: data['primary_queue_count'] as int? ?? 0,
      secondaryQueueCount: data['secondary_queue_count'] as int? ?? 0,
      todayWalkin: data['today_walkin'] as int? ?? 0,
      todayPhone: data['today_phone'] as int? ?? 0,
      todayRegistrations: data['today_registrations'] as int? ?? 0,
      revenueToday: (data['revenue_today'] as num? ?? 0).toDouble(),
      revenueMonth: (data['revenue_month'] as num? ?? 0).toDouble(),
      revenueYear: (data['revenue_year'] as num? ?? 0).toDouble(),
      otToday: data['ot_today'] as int? ?? 0,
      otOperated: data['ot_operated'] as int? ?? 0,
      otPending: data['ot_pending'] as int? ?? 0,
      totalStaff: data['total_staff'] as int? ?? 0,
      totalDoctors: data['total_doctors'] as int? ?? 0,
      totalReceptions: data['total_receptions'] as int? ?? 0,
      todayPrimary: data['today_primary'] as int? ?? 0,
      todaySecondary: data['today_secondary'] as int? ?? 0,
      otTotalToday: data['ot_total_today'] as int? ?? 0,
      totalUsersAllRoles: data['total_users_all_roles'] as int? ?? 0,
      totalMedicines: data['total_medicines'] as int? ?? 0,
      totalLensToday: data['total_lens_today'] as int? ?? 0,
      primaryQueue: (data['primary_queue'] as List<dynamic>? ?? [])
          .map((e) => QueuePatient.fromJson(e as Map<String, dynamic>))
          .toList(),
      receptionists: (data['receptionists'] as List<dynamic>? ?? [])
          .map((e) => ReceptionistStat.fromJson(e as Map<String, dynamic>))
          .toList(),
      waitThresholds: WaitThresholds.fromJson(
        data['wait_thresholds'] as Map<String, dynamic>? ?? {},
      ),
      receptionistStats: data['receptionist_stats'] != null
          ? ReceptionistStats.fromJson(
              data['receptionist_stats'] as Map<String, dynamic>,
            )
          : null,
      doctorCards: (data['doctor_cards'] as List<dynamic>? ?? [])
          .map((e) => DoctorCard.fromJson(e as Map<String, dynamic>))
          .toList(),
      pendingShareRequestsCount: data['pending_share_requests_count'] as int?,
      accountantPendingCount: data['accountant_pending_count'] as int?,
      accountantRefundsCount: data['accountant_refunds_count'] as int?,
      accountantCompletedCount: data['accountant_completed_count'] as int?,
      wardPendingCount: data['ward_pending_count'] as int?,
      wardCompletedCount: data['ward_completed_count'] as int?,
      otAssistantPendingCount: data['ot_assistant_pending_count'] as int?,
      otAssistantCompletedCount: data['ot_assistant_completed_count'] as int?,
      otAssistantPeers: (data['ot_assistant_peers'] as List<dynamic>? ?? [])
          .map((e) => OtAssistantPeer.fromJson(e as Map<String, dynamic>))
          .toList(),
      dischargePendingCount: data['discharge_pending_count'] as int?,
      dischargeCompletedCount: data['discharge_completed_count'] as int?,
      counsellingPendingCount: data['counselling_pending_count'] as int?,
      counsellingCompletedCount: data['counselling_completed_count'] as int?,
      counsellingPaymentCount: data['counselling_payment_count'] as int?,
      otAppointmentPendingCount: data['ot_appointment_pending_count'] as int?,
      otAppointmentCompletedCount: data['ot_appointment_completed_count'] as int?,
    );
  }
}

/// Another OT assistant the logged-in assistant can open, matching the web
/// "Other OT Assistants" cards. [assignedCount] is ready-for-surgery only.
class OtAssistantPeer {
  final int id;
  final String name;
  final int assignedCount;

  const OtAssistantPeer({
    required this.id,
    required this.name,
    required this.assignedCount,
  });

  factory OtAssistantPeer.fromJson(Map<String, dynamic> json) =>
      OtAssistantPeer(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? '',
        assignedCount: (json['assigned_count'] as num?)?.toInt() ?? 0,
      );
}

class QueuePatient {
  final int id;
  final String patientCode;
  final String fullName;
  final int? age;
  final String? gender;
  final int? doctorPatientNo;
  final DateTime? checkedInAt;
  final DateTime? registeredAt;
  final String? doctorName;
  final String? doctorPrefix;
  final String? receptionistName;
  final bool hasHistory;

  const QueuePatient({
    required this.id,
    required this.patientCode,
    required this.fullName,
    this.age,
    this.gender,
    this.doctorPatientNo,
    this.checkedInAt,
    this.registeredAt,
    this.doctorName,
    this.doctorPrefix,
    this.receptionistName,
    this.hasHistory = false,
  });

  factory QueuePatient.fromJson(Map<String, dynamic> json) {
    return QueuePatient(
      id: json['id'] as int,
      patientCode: json['patient_code'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      doctorPatientNo: json['doctor_patient_no'] as int?,
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.tryParse(json['checked_in_at'] as String)
          : null,
      registeredAt: json['registered_at'] != null
          ? DateTime.tryParse(json['registered_at'] as String)
          : null,
      doctorName: json['doctor_name'] as String?,
      doctorPrefix: json['doctor_prefix'] as String?,
      receptionistName: json['receptionist_name'] as String?,
      hasHistory: json['has_history'] as bool? ?? false,
    );
  }

  int waitMinutes() {
    final ref = checkedInAt ?? registeredAt;
    if (ref == null) return 0;
    return DateTime.now().difference(ref).inMinutes.clamp(0, 9999);
  }
}

class ReceptionistStat {
  final int id;
  final String name;
  final int todayCount;
  final double todayGross;
  final double todayFoc;
  final double todayNet;

  const ReceptionistStat({
    required this.id,
    required this.name,
    required this.todayCount,
    required this.todayGross,
    required this.todayFoc,
    required this.todayNet,
  });

  factory ReceptionistStat.fromJson(Map<String, dynamic> json) {
    return ReceptionistStat(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      todayCount: json['today_count'] as int? ?? 0,
      todayGross: (json['today_gross'] as num? ?? 0).toDouble(),
      todayFoc: (json['today_foc'] as num? ?? 0).toDouble(),
      todayNet: (json['today_net'] as num? ?? 0).toDouble(),
    );
  }
}

class ReceptionistStats {
  final int myPatientsToday;
  final int myTotalPatients;
  final int myWalkin;
  final int myPhone;
  // Web pull 2026-10-06 — today-only phone count under the Phone Appt card.
  // Distinct from `myPhone` above, which is a lifetime total.
  final int myPhoneToday;
  final double todayCollection;
  final int pendingPhoneCheckin;
  // Web pull 2026-09-29 (WEB_ADMIN_RECEPTIONIST_DASHBOARD_AUDIT.md finding
  // #2) — the receptionist row's 6th "OT Counselling" card. Null when the
  // viewer lacks `ot_counselling_fill` (API sends null, matching web's own
  // `?? 0` fallback only applying once the card is actually shown).
  final int? counsellingPending;

  const ReceptionistStats({
    required this.myPatientsToday,
    required this.myTotalPatients,
    required this.myWalkin,
    required this.myPhone,
    required this.myPhoneToday,
    required this.todayCollection,
    required this.pendingPhoneCheckin,
    this.counsellingPending,
  });

  factory ReceptionistStats.fromJson(Map<String, dynamic> json) {
    return ReceptionistStats(
      myPatientsToday: json['my_patients_today'] as int? ?? 0,
      myTotalPatients: json['my_total_patients'] as int? ?? 0,
      myWalkin: json['my_walkin'] as int? ?? 0,
      myPhone: json['my_phone'] as int? ?? 0,
      myPhoneToday: json['my_phone_today'] as int? ?? 0,
      todayCollection: (json['today_collection'] as num? ?? 0).toDouble(),
      pendingPhoneCheckin: json['pending_phone_checkin'] as int? ?? 0,
      counsellingPending: json['counselling_pending'] as int?,
    );
  }
}

class DoctorCard {
  final int id;
  final String name;
  final String? doctorType;
  final String? roleSlug;
  final int assignedToday;
  final int primaryCount;
  final int secondaryCount;

  const DoctorCard({
    required this.id,
    required this.name,
    this.doctorType,
    this.roleSlug,
    required this.assignedToday,
    required this.primaryCount,
    required this.secondaryCount,
  });

  factory DoctorCard.fromJson(Map<String, dynamic> json) {
    return DoctorCard(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      doctorType: json['doctor_type'] as String?,
      roleSlug: json['role_slug'] as String?,
      assignedToday: json['assigned_today'] as int? ?? 0,
      primaryCount: json['primary_count'] as int? ?? 0,
      secondaryCount: json['secondary_count'] as int? ?? 0,
    );
  }
}

class WaitThresholds {
  final int rGreen;
  final int rOrange;
  final int rRed;

  const WaitThresholds({this.rGreen = 30, this.rOrange = 60, this.rRed = 120});

  factory WaitThresholds.fromJson(Map<String, dynamic> json) {
    return WaitThresholds(
      rGreen: json['r_green'] as int? ?? 30,
      rOrange: json['r_orange'] as int? ?? 60,
      rRed: json['r_red'] as int? ?? 120,
    );
  }
}

/// Dilation-specific wait thresholds ("D" = dilated, "ND" = not dilated) —
/// only used by the receptionist "Today Added Patients" widget, matching
/// web's `wait_d_*`/`wait_nd_*` settings (distinct from the plain "R"
/// registration-wait thresholds above).
class TodayPatientsThresholds {
  final int rGreen, rOrange, rRed;
  final int dGreen, dOrange, dRed;
  final int ndGreen, ndOrange, ndRed;

  const TodayPatientsThresholds({
    this.rGreen = 30,
    this.rOrange = 60,
    this.rRed = 120,
    this.dGreen = 40,
    this.dOrange = 90,
    this.dRed = 120,
    this.ndGreen = 20,
    this.ndOrange = 60,
    this.ndRed = 120,
  });

  factory TodayPatientsThresholds.fromJson(Map<String, dynamic> json) =>
      TodayPatientsThresholds(
        rGreen: json['r_green'] as int? ?? 30,
        rOrange: json['r_orange'] as int? ?? 60,
        rRed: json['r_red'] as int? ?? 120,
        dGreen: json['d_green'] as int? ?? 40,
        dOrange: json['d_orange'] as int? ?? 90,
        dRed: json['d_red'] as int? ?? 120,
        ndGreen: json['nd_green'] as int? ?? 20,
        ndOrange: json['nd_orange'] as int? ?? 60,
        ndRed: json['nd_red'] as int? ?? 120,
      );
}

/// One row of the receptionist "Today Added Patients" widget — either a
/// real `Patient` this receptionist registered today, or an unconverted
/// `OtAppointmentItem` (OT pre-registration lead) merged in alongside it.
/// Reuses both existing models directly (see WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md
/// §9) so the row can be handed straight to the existing check-in/print/OT-edit
/// screens without a parallel data shape.
class TodayPatientRow {
  final Patient? patient;
  final OtAppointmentItem? otAppointment;

  const TodayPatientRow({this.patient, this.otAppointment});

  bool get isOt => otAppointment != null;

  factory TodayPatientRow.fromJson(Map<String, dynamic> json) {
    if (json['source'] == 'ot_appointment') {
      return TodayPatientRow(otAppointment: OtAppointmentItem.fromJson(json));
    }
    return TodayPatientRow(patient: Patient.fromJson(json));
  }
}

/// Admin "Total Collection" drill-down — web's AdminCollectionController /
/// GET /dashboard/collection: one row per receptionist, patients seen +
/// fees collected over the resolved date range (defaults to today).
class CollectionRow {
  final int id;
  final String name;
  final int count;
  final double total;

  const CollectionRow({
    required this.id,
    required this.name,
    required this.count,
    required this.total,
  });

  factory CollectionRow.fromJson(Map<String, dynamic> json) => CollectionRow(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    count: (json['count'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toDouble() ?? 0,
  );
}

/// Web pull 2026-09-30 — `AdminCollectionController::index()`'s OPD/OT Net
/// breakdown (`HospitalCollectionService::summaryForDateRange()`), backing
/// the 3 summary cards (Grand Total / OPD / OT Net) web shows above the
/// reception-wise table. Was missing from the API entirely — the app's
/// grand total silently excluded OT revenue as a result.
class CollectionBreakdown {
  final double opd;
  final double otCollected;
  final double otRefunded;
  final double otNet;
  final double total;

  const CollectionBreakdown({
    required this.opd,
    required this.otCollected,
    required this.otRefunded,
    required this.otNet,
    required this.total,
  });

  factory CollectionBreakdown.fromJson(Map<String, dynamic> json) =>
      CollectionBreakdown(
        opd: (json['opd'] as num?)?.toDouble() ?? 0,
        otCollected: (json['ot_collected'] as num?)?.toDouble() ?? 0,
        otRefunded: (json['ot_refunded'] as num?)?.toDouble() ?? 0,
        otNet: (json['ot_net'] as num?)?.toDouble() ?? 0,
        total: (json['total'] as num?)?.toDouble() ?? 0,
      );
}

class CollectionSummary {
  final String startDate;
  final String endDate;
  final List<CollectionRow> rows;
  final double grandTotal;
  final CollectionBreakdown? breakdown;

  const CollectionSummary({
    required this.startDate,
    required this.endDate,
    required this.rows,
    required this.grandTotal,
    this.breakdown,
  });

  factory CollectionSummary.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return CollectionSummary(
      startDate: data['start_date'] as String? ?? '',
      endDate: data['end_date'] as String? ?? '',
      rows: (data['rows'] as List<dynamic>? ?? [])
          .map((e) => CollectionRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      grandTotal: (data['grand_total'] as num?)?.toDouble() ?? 0,
      breakdown: data['breakdown'] != null
          ? CollectionBreakdown.fromJson(
              data['breakdown'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

/// One case-type bucket (New / Old / Other) in a receptionist's collection
/// detail — web's AdminCollectionController::show.
class CollectionBucket {
  final String label;
  final int count;
  final double total;

  const CollectionBucket({
    required this.label,
    required this.count,
    required this.total,
  });

  factory CollectionBucket.fromJson(Map<String, dynamic> json) =>
      CollectionBucket(
        label: json['label'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toDouble() ?? 0,
      );
}

/// One row of `AdminCollectionController::show()`'s "Registered Patients"
/// table (`admin_collection_show.blade.php`) — web has no case-type bucket
/// breakdown at all, just this flat, date-ordered patient list.
class CollectionDetailPatient {
  final int id;
  final String patientCode;
  final String name;
  final int? age;
  final String? gender;
  final String? caseType;
  final double caseFee;
  final String? doctor;
  final String? appointmentDate;
  final String stageLabel;
  final String? stageSub;
  final String stageTone;
  final String stageIcon;

  const CollectionDetailPatient({
    required this.id,
    required this.patientCode,
    required this.name,
    this.age,
    this.gender,
    this.caseType,
    required this.caseFee,
    this.doctor,
    this.appointmentDate,
    required this.stageLabel,
    this.stageSub,
    required this.stageTone,
    required this.stageIcon,
  });

  factory CollectionDetailPatient.fromJson(Map<String, dynamic> json) {
    final stage = json['status'] as Map<String, dynamic>? ?? const {};
    return CollectionDetailPatient(
      id: (json['id'] as num?)?.toInt() ?? 0,
      patientCode: json['patient_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      age: (json['age'] as num?)?.toInt(),
      gender: json['gender'] as String?,
      caseType: json['case_type'] as String?,
      caseFee: (json['case_fee'] as num?)?.toDouble() ?? 0,
      doctor: json['doctor'] as String?,
      appointmentDate: json['appointment_date'] as String?,
      stageLabel: stage['label'] as String? ?? '—',
      stageSub: stage['sub'] as String?,
      stageTone: stage['tone'] as String? ?? 'muted',
      stageIcon: stage['icon'] as String? ?? '',
    );
  }
}

class CollectionDetail {
  final String receptionName;
  final String startDate;
  final String endDate;
  final List<CollectionBucket> buckets;
  final int count;
  final double total;
  final List<CollectionDetailPatient> patients;

  const CollectionDetail({
    required this.receptionName,
    this.startDate = '',
    this.endDate = '',
    required this.buckets,
    required this.count,
    required this.total,
    this.patients = const [],
  });

  factory CollectionDetail.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final bucketsJson = data['buckets'] as Map<String, dynamic>? ?? {};
    return CollectionDetail(
      receptionName:
          (data['reception'] as Map<String, dynamic>?)?['name'] as String? ??
          '',
      startDate: data['start_date'] as String? ?? '',
      endDate: data['end_date'] as String? ?? '',
      buckets: bucketsJson.values
          .map((e) => CollectionBucket.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: (data['count'] as num?)?.toInt() ?? 0,
      total: (data['total'] as num?)?.toDouble() ?? 0,
      patients: (data['patients'] as List<dynamic>? ?? [])
          .map(
            (e) => CollectionDetailPatient.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class TodayPatientsData {
  final List<TodayPatientRow> rows;
  final TodayPatientsThresholds thresholds;

  const TodayPatientsData({required this.rows, required this.thresholds});

  factory TodayPatientsData.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as List<dynamic>? ?? [])
        .map((e) => TodayPatientRow.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = json['meta'] as Map<String, dynamic>? ?? {};
    return TodayPatientsData(
      rows: data,
      thresholds: TodayPatientsThresholds.fromJson(
        meta['wait_thresholds'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
