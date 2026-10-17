class DoctorDashStats {
  final int assignedToday;
  final int primaryDone;
  final int secondaryDone;

  const DoctorDashStats({
    required this.assignedToday,
    required this.primaryDone,
    required this.secondaryDone,
  });

  factory DoctorDashStats.fromJson(Map<String, dynamic> j) => DoctorDashStats(
        assignedToday: (j['assigned_today'] as num?)?.toInt() ?? 0,
        primaryDone:   (j['primary_done']   as num?)?.toInt() ?? 0,
        secondaryDone: (j['secondary_done'] as num?)?.toInt() ?? 0,
      );
}

class DoctorCardInfo {
  final int id;
  final String name;
  final bool isSelf;
  final int assignedToday;
  final int primaryCount;
  final int secondaryCount;

  const DoctorCardInfo({
    required this.id,
    required this.name,
    required this.isSelf,
    required this.assignedToday,
    required this.primaryCount,
    required this.secondaryCount,
  });

  factory DoctorCardInfo.fromJson(Map<String, dynamic> j) => DoctorCardInfo(
        id:             (j['id'] as num).toInt(),
        name:           j['name'] as String? ?? '',
        isSelf:         j['is_self'] == true,
        assignedToday:  (j['assigned_today']  as num?)?.toInt() ?? 0,
        primaryCount:   (j['primary_count']   as num?)?.toInt() ?? 0,
        secondaryCount: (j['secondary_count'] as num?)?.toInt() ?? 0,
      );
}

class OtDoctorCardInfo {
  final int id;
  final String name;
  final bool isSelf;
  final int otCounterPending;
  final int otPaymentComplete;
  final int otDischarged;

  const OtDoctorCardInfo({
    required this.id,
    required this.name,
    required this.isSelf,
    required this.otCounterPending,
    required this.otPaymentComplete,
    required this.otDischarged,
  });

  factory OtDoctorCardInfo.fromJson(Map<String, dynamic> j) => OtDoctorCardInfo(
        id:         (j['id'] as num).toInt(),
        name:       j['name'] as String? ?? '',
        isSelf:     j['is_self'] == true,
        otCounterPending:  (j['ot_counter_pending']  as num?)?.toInt() ?? 0,
        otPaymentComplete: (j['ot_payment_complete'] as num?)?.toInt() ?? 0,
        otDischarged:      (j['ot_discharged']       as num?)?.toInt() ?? 0,
      );
}

/// A single row in the OT tab's Pending/Completed patient lists (web pull
/// 2026-10-13, doctoredashboard.blade.php's `.ot-only` tables). Read-only —
/// its "Review"/"View" action reuses the existing DoctorOtListScreen rather
/// than duplicating assign/refuse logic inline, matching web's own
/// Review/View links which simply navigate to the `doctor-ot` page.
class OtQueueItem {
  final int id;
  final String? patientCode;
  final String patientName;
  final String? gender;
  final int? age;
  final String? city;
  final String otStatus;
  final String statusLabel;
  final String statusTone;
  final bool isConsultPending;
  final String? assistantName;

  const OtQueueItem({
    required this.id,
    this.patientCode,
    required this.patientName,
    this.gender,
    this.age,
    this.city,
    required this.otStatus,
    required this.statusLabel,
    required this.statusTone,
    required this.isConsultPending,
    this.assistantName,
  });

  factory OtQueueItem.fromJson(Map<String, dynamic> j) => OtQueueItem(
        id:          (j['id'] as num).toInt(),
        patientCode: j['patient_code'] as String?,
        patientName: j['patient_name'] as String? ?? '',
        gender:      j['gender'] as String?,
        age:         (j['age'] as num?)?.toInt(),
        city:        j['city'] as String?,
        otStatus:     j['ot_status'] as String? ?? '',
        statusLabel:  j['status_label'] as String? ?? '',
        statusTone:   j['status_tone'] as String? ?? '#64748b',
        isConsultPending: j['is_consult_pending'] == true,
        assistantName: j['ot_assistant_name'] as String?,
      );
}

class PrimaryPatient {
  final int id;
  final String patientCode;
  final int? doctorId;
  final String patientName;
  final String drIndexNo;
  final int? age;
  final String? gender;
  final String city;
  final DateTime registeredAt;
  final bool hasHistory;

  const PrimaryPatient({
    required this.id,
    required this.patientCode,
    this.doctorId,
    required this.patientName,
    required this.drIndexNo,
    this.age,
    this.gender,
    required this.city,
    required this.registeredAt,
    required this.hasHistory,
  });

  factory PrimaryPatient.fromJson(Map<String, dynamic> j) => PrimaryPatient(
        id:          (j['id'] as num).toInt(),
        patientCode: j['patient_code'] as String? ?? '',
        doctorId:    (j['doctor_id'] as num?)?.toInt(),
        patientName: j['patient_name'] as String? ?? '',
        drIndexNo:   j['dr_index_no']  as String? ?? '-',
        age:         (j['age'] as num?)?.toInt(),
        gender:      j['gender'] as String?,
        city:        j['city'] as String? ?? '',
        registeredAt: DateTime.parse(j['registered_at'] as String).toLocal(),
        hasHistory:  j['has_history'] == true,
      );
}

class SecondaryPatient extends PrimaryPatient {
  final DateTime? primaryDoneAt;
  final bool isDilated;
  final int dilationLockMinutes;

  const SecondaryPatient({
    required super.id,
    required super.patientCode,
    super.doctorId,
    required super.patientName,
    required super.drIndexNo,
    super.age,
    super.gender,
    required super.city,
    required super.registeredAt,
    required super.hasHistory,
    this.primaryDoneAt,
    required this.isDilated,
    required this.dilationLockMinutes,
  });

  factory SecondaryPatient.fromJson(Map<String, dynamic> j) => SecondaryPatient(
        id:          (j['id'] as num).toInt(),
        patientCode: j['patient_code'] as String? ?? '',
        doctorId:    (j['doctor_id'] as num?)?.toInt(),
        patientName: j['patient_name'] as String? ?? '',
        drIndexNo:   j['dr_index_no']  as String? ?? '-',
        age:         (j['age'] as num?)?.toInt(),
        gender:      j['gender'] as String?,
        city:        j['city'] as String? ?? '',
        registeredAt: DateTime.parse(j['registered_at'] as String).toLocal(),
        hasHistory:  j['has_history'] == true,
        primaryDoneAt: j['primary_done_at'] != null
            ? DateTime.parse(j['primary_done_at'] as String).toLocal()
            : null,
        isDilated:            j['is_dilated'] == true,
        dilationLockMinutes:  (j['dilation_lock_minutes'] as num?)?.toInt() ?? 40,
      );
}

class WaitThresholds {
  final int rGreen, rOrange, rRed;
  final int dGreen, dOrange, dRed;
  final int ndGreen, ndOrange, ndRed;

  const WaitThresholds({
    required this.rGreen,
    required this.rOrange,
    required this.rRed,
    required this.dGreen,
    required this.dOrange,
    required this.dRed,
    required this.ndGreen,
    required this.ndOrange,
    required this.ndRed,
  });

  static const defaults = WaitThresholds(
    rGreen: 30, rOrange: 60, rRed: 120,
    dGreen: 40, dOrange: 90, dRed: 120,
    ndGreen: 20, ndOrange: 60, ndRed: 120,
  );

  factory WaitThresholds.fromJson(Map<String, dynamic>? j) {
    if (j == null) return defaults;
    return WaitThresholds(
      rGreen:  (j['r_green']  as num?)?.toInt() ?? defaults.rGreen,
      rOrange: (j['r_orange'] as num?)?.toInt() ?? defaults.rOrange,
      rRed:    (j['r_red']    as num?)?.toInt() ?? defaults.rRed,
      dGreen:  (j['d_green']  as num?)?.toInt() ?? defaults.dGreen,
      dOrange: (j['d_orange'] as num?)?.toInt() ?? defaults.dOrange,
      dRed:    (j['d_red']    as num?)?.toInt() ?? defaults.dRed,
      ndGreen: (j['nd_green']  as num?)?.toInt() ?? defaults.ndGreen,
      ndOrange:(j['nd_orange'] as num?)?.toInt() ?? defaults.ndOrange,
      ndRed:   (j['nd_red']    as num?)?.toInt() ?? defaults.ndRed,
    );
  }
}

List<OtQueueItem> _otQueue(dynamic v) =>
    (v as List<dynamic>? ?? []).map((e) => OtQueueItem.fromJson(e as Map<String, dynamic>)).toList();

class DoctorDashboardData {
  final DoctorDashStats stats;
  final List<DoctorCardInfo> doctorCards;
  final List<OtDoctorCardInfo> otDoctorCards;
  final DoctorCardInfo? viewingDoctor;
  final List<PrimaryPatient> primaryQueue;
  final List<SecondaryPatient> secondaryQueue;
  final int tenantTodayPatients;
  final int tenantTodayPrimary;
  final int tenantTodaySecondary;
  // 4th pill on web's top bar (doctoredashboard.blade.php:1017, tooltip
  // "Today — counselling through OT Assistant") — bookings currently
  // between Counselling and OT Assistant stages today, tenant-wide. Was
  // missing from this API's response entirely (not just unparsed here), so
  // neither app could show it — see DoctorDashboardApiController::dashboard().
  final int tenantTodayOtPipeline;
  final WaitThresholds waitThresholds;

  // OT tab (OPD/OT dashboard switch, web pull 2026-10-13).
  final List<OtQueueItem> otPaymentPendingQueue;
  final List<OtQueueItem> otWardQueue;
  final List<OtQueueItem> otAssistantQueue;
  final int todayOtCounterPending;
  final int todayPaymentComplete;
  final int todayDischarged;
  final int todayOtAppointmentsAdded;

  const DoctorDashboardData({
    required this.stats,
    required this.doctorCards,
    this.otDoctorCards = const [],
    this.viewingDoctor,
    required this.primaryQueue,
    required this.secondaryQueue,
    this.tenantTodayPatients = 0,
    this.tenantTodayPrimary = 0,
    this.tenantTodaySecondary = 0,
    this.tenantTodayOtPipeline = 0,
    this.waitThresholds = WaitThresholds.defaults,
    this.otPaymentPendingQueue = const [],
    this.otWardQueue = const [],
    this.otAssistantQueue = const [],
    this.todayOtCounterPending = 0,
    this.todayPaymentComplete = 0,
    this.todayDischarged = 0,
    this.todayOtAppointmentsAdded = 0,
  });

  factory DoctorDashboardData.fromJson(Map<String, dynamic> j) => DoctorDashboardData(
        stats:       DoctorDashStats.fromJson(j['stats'] as Map<String, dynamic>),
        doctorCards: (j['doctor_cards'] as List<dynamic>? ?? [])
            .map((e) => DoctorCardInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        otDoctorCards: (j['ot_doctor_cards'] as List<dynamic>? ?? [])
            .map((e) => OtDoctorCardInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        viewingDoctor: j['viewing_doctor'] != null
            ? DoctorCardInfo.fromJson(j['viewing_doctor'] as Map<String, dynamic>)
            : null,
        primaryQueue: (j['primary_queue'] as List<dynamic>? ?? [])
            .map((e) => PrimaryPatient.fromJson(e as Map<String, dynamic>))
            .toList(),
        secondaryQueue: (j['secondary_queue'] as List<dynamic>? ?? [])
            .map((e) => SecondaryPatient.fromJson(e as Map<String, dynamic>))
            .toList(),
        tenantTodayPatients:  (j['tenant_today_patients']  as num?)?.toInt() ?? 0,
        tenantTodayPrimary:   (j['tenant_today_primary']   as num?)?.toInt() ?? 0,
        tenantTodaySecondary: (j['tenant_today_secondary'] as num?)?.toInt() ?? 0,
        tenantTodayOtPipeline: (j['tenant_today_ot_pipeline'] as num?)?.toInt() ?? 0,
        waitThresholds: WaitThresholds.fromJson(j['wait_thresholds'] as Map<String, dynamic>?),
        otPaymentPendingQueue: _otQueue(j['ot_payment_pending_queue']),
        otWardQueue:           _otQueue(j['ot_ward_queue']),
        otAssistantQueue:      _otQueue(j['ot_assistant_queue']),
        todayOtCounterPending:    (j['today_ot_counter_pending']    as num?)?.toInt() ?? 0,
        todayPaymentComplete:     (j['today_payment_complete']      as num?)?.toInt() ?? 0,
        todayDischarged:          (j['today_discharged']            as num?)?.toInt() ?? 0,
        todayOtAppointmentsAdded: (j['today_ot_appointments_added'] as num?)?.toInt() ?? 0,
      );
}
