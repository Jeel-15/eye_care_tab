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
  final int otTotal;
  final int otPending;
  final int otComplete;

  const OtDoctorCardInfo({
    required this.id,
    required this.name,
    required this.isSelf,
    required this.otTotal,
    required this.otPending,
    required this.otComplete,
  });

  factory OtDoctorCardInfo.fromJson(Map<String, dynamic> j) => OtDoctorCardInfo(
        id:         (j['id'] as num).toInt(),
        name:       j['name'] as String? ?? '',
        isSelf:     j['is_self'] == true,
        otTotal:    (j['ot_total'] as num?)?.toInt() ?? 0,
        otPending:  (j['ot_pending'] as num?)?.toInt() ?? 0,
        otComplete: (j['ot_complete'] as num?)?.toInt() ?? 0,
      );
}

class OtSummary {
  final int total;
  final int pending;
  final int complete;

  const OtSummary({required this.total, required this.pending, required this.complete});

  factory OtSummary.fromJson(Map<String, dynamic>? j) => OtSummary(
        total:    (j?['total'] as num?)?.toInt() ?? 0,
        pending:  (j?['pending'] as num?)?.toInt() ?? 0,
        complete: (j?['complete'] as num?)?.toInt() ?? 0,
      );
}

class PrimaryPatient {
  final int id;
  final String patientCode;
  final int? doctorId;
  final String patientName;
  final String drIndexNo;
  final int? age;
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

class DoctorDashboardData {
  final DoctorDashStats stats;
  final List<DoctorCardInfo> doctorCards;
  final List<OtDoctorCardInfo> otDoctorCards;
  final OtSummary otSummary;
  final DoctorCardInfo? viewingDoctor;
  final List<PrimaryPatient> primaryQueue;
  final List<SecondaryPatient> secondaryQueue;

  const DoctorDashboardData({
    required this.stats,
    required this.doctorCards,
    this.otDoctorCards = const [],
    this.otSummary = const OtSummary(total: 0, pending: 0, complete: 0),
    this.viewingDoctor,
    required this.primaryQueue,
    required this.secondaryQueue,
  });

  factory DoctorDashboardData.fromJson(Map<String, dynamic> j) => DoctorDashboardData(
        stats:       DoctorDashStats.fromJson(j['stats'] as Map<String, dynamic>),
        doctorCards: (j['doctor_cards'] as List<dynamic>? ?? [])
            .map((e) => DoctorCardInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        otDoctorCards: (j['ot_doctor_cards'] as List<dynamic>? ?? [])
            .map((e) => OtDoctorCardInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        otSummary: OtSummary.fromJson(j['ot_summary'] as Map<String, dynamic>?),
        viewingDoctor: j['viewing_doctor'] != null
            ? DoctorCardInfo.fromJson(j['viewing_doctor'] as Map<String, dynamic>)
            : null,
        primaryQueue: (j['primary_queue'] as List<dynamic>? ?? [])
            .map((e) => PrimaryPatient.fromJson(e as Map<String, dynamic>))
            .toList(),
        secondaryQueue: (j['secondary_queue'] as List<dynamic>? ?? [])
            .map((e) => SecondaryPatient.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
