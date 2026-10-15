// Models for GET /patients/{id}/history API response.

import '../utils/date_format.dart';

/// PHP `json_encode([])` is a JSON array; empty assoc arrays become `[]` too.
/// Flutter must tolerate both Map and List for object-shaped fields.
Map<String, dynamic> _asMap(dynamic raw) {
  if (raw is Map) {
    return Map<String, dynamic>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
  }
  return {};
}

Map<int, String> _parseDxMasters(dynamic raw) {
  final dm = <int, String>{};
  if (raw is Map) {
    raw.forEach((k, v) {
      final id = k is int ? k : int.tryParse(k.toString()) ?? 0;
      if (id > 0) dm[id] = v?.toString() ?? '';
    });
  } else if (raw is List) {
    for (final item in raw) {
      if (item is! Map) continue;
      final id = (item['id'] as num?)?.toInt() ?? 0;
      if (id > 0) {
        dm[id] = (item['value'] ?? item['name'] ?? '').toString();
      }
    }
  }
  return dm;
}

List<dynamic> _asList(dynamic raw) {
  if (raw is List) return raw;
  return const [];
}

// Hospital-timezone-aware — also used as the grouping key below, so an exam
// done just after local midnight must land under the correct calendar day,
// not the raw UTC day. See PATIENT_DATE_TIME_DISPLAY_AUDIT.md.
String _fmtDate(DateTime dt) => toDisplayDate(toHospitalTime(dt));

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
        patient: PatientHistorySummary.fromJson(_asMap(j['patient'])),
        exams: _asList(j['exams'])
            .whereType<Map>()
            .map((e) => ExamRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        diagnosisMasters: _parseDxMasters(j['diagnosis_masters']),
        partnerHospitals: _asList(j['partner_hospitals'])
            .whereType<Map>()
            .map((e) => PartnerHospitalHistory.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
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
        hospitalName: (j['hospital_name'] as String?) ?? 'Partner Hospital',
        hospitalCity: j['hospital_city'] as String?,
        hospitalState: j['hospital_state'] as String?,
        exams: _asList(j['exams'])
            .whereType<Map>()
            .map((e) => ExamRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        diagnosisMasters: _parseDxMasters(j['diagnosis_masters']),
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
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? '',
        patientCode: (j['patient_code'] as String?) ?? '',
        gender: j['gender'] as String?,
        age: j['age'] != null ? (j['age'] as num).toInt() : null,
        contactNo: j['contact_no'] as String?,
        location: j['location'] as String?,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
        visitDays: j['visit_days'] != null ? (j['visit_days'] as num).toInt() : 0,
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
        id: (j['id'] as num).toInt(),
        type: (j['type'] as String?) ?? 'primary',
        examinedAt: DateTime.parse(j['examined_at'] as String),
        doctorName: j['doctor'] as String?,
        // Empty exam_data may arrive as [] from PHP — treat as {}.
        examData: _asMap(j['exam_data']),
        prescriptions: _asList(j['prescriptions'])
            .whereType<Map>()
            .map((p) => RxLine.fromJson(Map<String, dynamic>.from(p)))
            .toList(),
      );

  // ── exam_data accessors ────────────────────────────────────────────────────

  Map<String, dynamic> get vision => _asMap(examData['vision']);
  Map<String, dynamic> get pg => _asMap(examData['pg']);
  Map<String, dynamic> get st => _asMap(examData['st']);
  Map<String, dynamic> get nct => _asMap(examData['nct']);
  Map<String, dynamic> get oe => _asMap(examData['oe']);
  Map<String, dynamic> get fundus => _asMap(examData['fundus']);
  List<dynamic> get coRows => _asList(examData['co_rows']);
  List<dynamic> get kcoRows => _asList(examData['kco_rows']);
  List<dynamic> get diagnoses => _asList(examData['diagnoses']);
  String get advice => (examData['advice'] as String?) ?? '';
  String get dilate => (examData['dilate'] as String?) ?? 'No';

  Map<String, dynamic> get pgRe => _asMap(pg['re']);
  Map<String, dynamic> get pgLe => _asMap(pg['le']);
  Map<String, dynamic> get stRe => _asMap(st['re']);
  Map<String, dynamic> get stLe => _asMap(st['le']);

  List<String> get stBadges {
    final badges = <String>[];
    if (st['bifocal'] == true) badges.add('Bifocal');
    if (st['nd_separate'] == true) badges.add('N&D Separate');
    if (st['progressive'] == true) badges.add('Progressive');
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
        dosage: (j['dosage'] as String?) ?? '-',
        duration: (j['duration'] as String?) ?? '-',
        eye: (j['eye'] as String?) ?? '-',
      );
}
