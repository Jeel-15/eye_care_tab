// Models for GET /patients/{id}/history API response.

Map<int, String> _parseDxMasters(Map<String, dynamic>? raw) {
  final dm = <int, String>{};
  raw?.forEach((k, v) => dm[int.tryParse(k) ?? 0] = v as String);
  return dm;
}

String _fmtDate(DateTime dt) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
}

Map<String, List<ExamRecord>> _groupByDate(List<ExamRecord> exams) {
  final map = <String, List<ExamRecord>>{};
  for (final exam in exams) {
    map.putIfAbsent(_fmtDate(exam.examinedAt), () => []).add(exam);
  }
  return map;
}

class ExamHistoryData {
  final PatientHistorySummary patient;
  final List<ExamRecord> exams;
  final Map<int, String> diagnosisMasters;
  final List<PartnerHospitalHistory> partnerHospitals;

  const ExamHistoryData({
    required this.patient,
    required this.exams,
    required this.diagnosisMasters,
    this.partnerHospitals = const [],
  });

  factory ExamHistoryData.fromJson(Map<String, dynamic> j) => ExamHistoryData(
        patient: PatientHistorySummary.fromJson(j['patient'] as Map<String, dynamic>),
        exams: (j['exams'] as List?)
                ?.map((e) => ExamRecord.fromJson(e as Map<String, dynamic>))
                .toList() ?? [],
        diagnosisMasters: _parseDxMasters(j['diagnosis_masters'] as Map<String, dynamic>?),
        partnerHospitals: (j['partner_hospitals'] as List?)
                ?.map((e) => PartnerHospitalHistory.fromJson(e as Map<String, dynamic>))
                .toList() ?? [],
      );

  Map<String, List<ExamRecord>> get byDate => _groupByDate(exams);
}

class PartnerHospitalHistory {
  final String hospitalName;
  final String? hospitalCity;
  final String? hospitalState;
  final List<ExamRecord> exams;
  final Map<int, String> diagnosisMasters;

  const PartnerHospitalHistory({
    required this.hospitalName,
    this.hospitalCity,
    this.hospitalState,
    required this.exams,
    required this.diagnosisMasters,
  });

  factory PartnerHospitalHistory.fromJson(Map<String, dynamic> j) => PartnerHospitalHistory(
        hospitalName:     (j['hospital_name']  as String?) ?? 'Partner Hospital',
        hospitalCity:      j['hospital_city']  as String?,
        hospitalState:     j['hospital_state'] as String?,
        exams: (j['exams'] as List?)
                ?.map((e) => ExamRecord.fromJson(e as Map<String, dynamic>))
                .toList() ?? [],
        diagnosisMasters: _parseDxMasters(j['diagnosis_masters'] as Map<String, dynamic>?),
      );

  String get locationLine {
    return [hospitalCity, hospitalState]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');
  }

  Map<String, List<ExamRecord>> get byDate => _groupByDate(exams);
}

class PatientHistorySummary {
  final int id;
  final String name;
  final String patientCode;
  final String? gender;
  final int? age;
  final String? contactNo;
  final String? location;
  final DateTime? createdAt;
  final int visitDays;

  const PatientHistorySummary({
    required this.id,
    required this.name,
    required this.patientCode,
    this.gender,
    this.age,
    this.contactNo,
    this.location,
    this.createdAt,
    required this.visitDays,
  });

  factory PatientHistorySummary.fromJson(Map<String, dynamic> j) =>
      PatientHistorySummary(
        id:           (j['id'] as num).toInt(),
        name:         (j['name'] as String?) ?? '',
        patientCode:  (j['patient_code'] as String?) ?? '',
        gender:       j['gender'] as String?,
        age:          j['age'] != null ? (j['age'] as num).toInt() : null,
        contactNo:    j['contact_no'] as String?,
        location:     j['location'] as String?,
        createdAt:    j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
        visitDays:    j['visit_days'] != null ? (j['visit_days'] as num).toInt() : 0,
      );
}

class ExamRecord {
  final int id;
  final String type; // 'primary' | 'secondary'
  final DateTime examinedAt;
  final String? doctorName;
  final Map<String, dynamic> examData;
  final List<RxLine> prescriptions;

  const ExamRecord({
    required this.id,
    required this.type,
    required this.examinedAt,
    this.doctorName,
    required this.examData,
    required this.prescriptions,
  });

  bool get isPrimary => type == 'primary';

  factory ExamRecord.fromJson(Map<String, dynamic> j) => ExamRecord(
        id:            (j['id'] as num).toInt(),
        type:          (j['type'] as String?) ?? 'primary',
        examinedAt:    DateTime.parse(j['examined_at'] as String),
        doctorName:    j['doctor'] as String?,
        examData:      (j['exam_data'] as Map<String, dynamic>?) ?? {},
        prescriptions: (j['prescriptions'] as List?)
                ?.map((p) => RxLine.fromJson(p as Map<String, dynamic>))
                .toList() ??
            [],
      );

  // ── exam_data accessors ────────────────────────────────────────────────────

  Map<String, dynamic> get vision    => (examData['vision']  as Map?)?.cast() ?? {};
  Map<String, dynamic> get pg        => (examData['pg']      as Map?)?.cast() ?? {};
  Map<String, dynamic> get st        => (examData['st']      as Map?)?.cast() ?? {};
  Map<String, dynamic> get nct       => (examData['nct']     as Map?)?.cast() ?? {};
  Map<String, dynamic> get oe        => (examData['oe']      as Map?)?.cast() ?? {};
  Map<String, dynamic> get fundus    => (examData['fundus']  as Map?)?.cast() ?? {};
  List<dynamic>        get coRows    => (examData['co_rows']  as List?) ?? [];
  List<dynamic>        get kcoRows   => (examData['kco_rows'] as List?) ?? [];
  List<dynamic>        get diagnoses => (examData['diagnoses'] as List?) ?? [];
  String               get advice    => (examData['advice'] as String?) ?? '';
  String               get dilate    => (examData['dilate'] as String?) ?? 'No';

  Map<String, dynamic> get pgRe => (pg['re'] as Map?)?.cast() ?? {};
  Map<String, dynamic> get pgLe => (pg['le'] as Map?)?.cast() ?? {};
  Map<String, dynamic> get stRe => (st['re'] as Map?)?.cast() ?? {};
  Map<String, dynamic> get stLe => (st['le'] as Map?)?.cast() ?? {};

  List<String> get stBadges {
    final badges = <String>[];
    if (st['bifocal']       == true) badges.add('Bifocal');
    if (st['nd_separate']   == true) badges.add('N&D Separate');
    if (st['progressive']   == true) badges.add('Progressive');
    if (st['computer_uses'] == true) badges.add('Computer Uses');
    return badges;
  }
}

class RxLine {
  final String medicineName;
  final String dosage;
  final String duration;
  final String eye;

  const RxLine({
    required this.medicineName,
    required this.dosage,
    required this.duration,
    required this.eye,
  });

  factory RxLine.fromJson(Map<String, dynamic> j) => RxLine(
        medicineName: (j['medicine_name'] as String?) ?? '-',
        dosage:       (j['dosage']        as String?) ?? '-',
        duration:     (j['duration']      as String?) ?? '-',
        eye:          (j['eye']           as String?) ?? '-',
      );
}
