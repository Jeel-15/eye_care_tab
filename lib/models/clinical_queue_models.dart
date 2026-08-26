class WaitThresholds {
  final int greenMax;
  final int orangeMax;
  final int redMax;

  const WaitThresholds({
    required this.greenMax,
    required this.orangeMax,
    required this.redMax,
  });

  factory WaitThresholds.fromJson(Map<String, dynamic> j) => WaitThresholds(
        greenMax: (j['green'] as num?)?.toInt() ?? 30,
        orangeMax: (j['orange'] as num?)?.toInt() ?? 60,
        redMax: (j['red'] as num?)?.toInt() ?? 120,
      );
}

class AllWaitThresholds {
  final WaitThresholds r;
  final WaitThresholds d;
  final WaitThresholds nd;

  const AllWaitThresholds({
    required this.r,
    required this.d,
    required this.nd,
  });

  factory AllWaitThresholds.fromJson(Map<String, dynamic> j) => AllWaitThresholds(
        r: WaitThresholds.fromJson(j['r'] as Map<String, dynamic>),
        d: WaitThresholds.fromJson(j['d'] as Map<String, dynamic>),
        nd: WaitThresholds.fromJson(j['nd'] as Map<String, dynamic>),
      );

  static const AllWaitThresholds defaults = AllWaitThresholds(
    r:  WaitThresholds(greenMax: 30, orangeMax: 60,  redMax: 120),
    d:  WaitThresholds(greenMax: 40, orangeMax: 90,  redMax: 120),
    nd: WaitThresholds(greenMax: 20, orangeMax: 60,  redMax: 120),
  );
}

class DoctorSummary {
  final int id;
  final String name;
  final String? doctorType;
  final int totalAssigned;
  final int primaryPending;
  final int secondaryPending;

  const DoctorSummary({
    required this.id,
    required this.name,
    this.doctorType,
    required this.totalAssigned,
    required this.primaryPending,
    required this.secondaryPending,
  });

  bool get isAllClear => primaryPending == 0 && secondaryPending == 0;

  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  factory DoctorSummary.fromJson(Map<String, dynamic> j) => DoctorSummary(
        id: j['id'] as int,
        name: (j['name'] as String?) ?? '',
        doctorType: j['doctor_type'] as String?,
        totalAssigned: (j['total_assigned'] as num?)?.toInt() ?? 0,
        primaryPending: (j['primary_pending'] as num?)?.toInt() ?? 0,
        secondaryPending: (j['secondary_pending'] as num?)?.toInt() ?? 0,
      );
}

class QueuePrimaryExam {
  final int id;
  final DateTime? examinedAt;
  final int? dilationTime;
  final String dilate;
  final dynamic diagnosis;

  const QueuePrimaryExam({
    required this.id,
    this.examinedAt,
    this.dilationTime,
    required this.dilate,
    this.diagnosis,
  });

  factory QueuePrimaryExam.fromJson(Map<String, dynamic> j) {
    final examData = j['exam_data'] as Map<String, dynamic>? ?? {};
    return QueuePrimaryExam(
      id: j['id'] as int,
      examinedAt: j['examined_at'] != null
          ? DateTime.parse(j['examined_at'] as String)
          : null,
      dilationTime: (j['dilation_time'] as num?)?.toInt(),
      dilate: (examData['dilate'] as String?) ?? 'No',
      diagnosis: examData['diagnosis'],
    );
  }
}

class QueuePatient {
  final int id;
  final String patientCode;
  final String firstName;
  final String lastName;
  final int age;
  final String gender;
  final String? contactNo;
  final DateTime createdAt;
  final DateTime? primaryDoneAt;
  final String? doctorName;
  final String? caseType;
  final QueuePrimaryExam? primaryExamination;
  final int? unlockTimeMs;

  const QueuePatient({
    required this.id,
    required this.patientCode,
    required this.firstName,
    required this.lastName,
    required this.age,
    required this.gender,
    this.contactNo,
    required this.createdAt,
    this.primaryDoneAt,
    this.doctorName,
    this.caseType,
    this.primaryExamination,
    this.unlockTimeMs,
  });

  String get fullName => '$firstName $lastName'.trim();

  bool get isDilated => primaryExamination?.dilate == 'Yes';

  String get diagnosisText {
    final d = primaryExamination?.diagnosis;
    if (d == null) return 'N/A';
    if (d is List) {
      final parts = d.take(2).map((e) => e.toString()).toList();
      return parts.isEmpty ? 'N/A' : parts.join(', ');
    }
    final s = d.toString().trim();
    return s.isNotEmpty ? s : 'N/A';
  }

  factory QueuePatient.fromJson(Map<String, dynamic> j) => QueuePatient(
        id: j['id'] as int,
        patientCode: (j['patient_code'] as String?) ?? '',
        firstName: (j['first_name'] as String?) ?? '',
        lastName: (j['last_name'] as String?) ?? '',
        age: (j['age'] as num?)?.toInt() ?? 0,
        gender: (j['gender'] as String?) ?? '',
        contactNo: j['contact_no'] as String?,
        createdAt: j['created_at'] != null
            ? DateTime.parse(j['created_at'] as String)
            : DateTime.now(),
        primaryDoneAt: j['primary_done_at'] != null
            ? DateTime.parse(j['primary_done_at'] as String)
            : null,
        doctorName:
            (j['doctor'] as Map<String, dynamic>?)?['name'] as String?,
        caseType:
            (j['case_type'] as Map<String, dynamic>?)?['case_type'] as String?,
        primaryExamination: j['primary_examination'] != null
            ? QueuePrimaryExam.fromJson(
                j['primary_examination'] as Map<String, dynamic>)
            : null,
        unlockTimeMs: (j['unlock_time_ms'] as num?)?.toInt(),
      );
}

class QueueData {
  final String filterDate;
  final AllWaitThresholds thresholds;
  final List<DoctorSummary> doctors;
  final List<QueuePatient> primaryQueue;
  final List<QueuePatient> dilationQueue;
  final List<QueuePatient> secondaryQueue;

  const QueueData({
    required this.filterDate,
    required this.thresholds,
    required this.doctors,
    required this.primaryQueue,
    required this.dilationQueue,
    required this.secondaryQueue,
  });

  int get totalPrimary   => primaryQueue.length;
  int get totalDilation  => dilationQueue.length;
  int get totalSecondary => secondaryQueue.length;
  int get total          => totalPrimary + totalDilation + totalSecondary;
}
