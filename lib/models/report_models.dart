// Models for the Reports module

class ReportPatient {
  final int id;
  final String patientCode;
  final String fullName;
  final String appointmentDate;
  final String? contactNo;
  final int? age;
  final String? type;
  final String typeLabel;
  final double caseFee;
  final String caseTypeLabel;
  final String? doctorName;
  final String? receptionistName;
  final String? locationCity;

  const ReportPatient({
    required this.id,
    required this.patientCode,
    required this.fullName,
    required this.appointmentDate,
    this.contactNo,
    this.age,
    this.type,
    required this.typeLabel,
    required this.caseFee,
    required this.caseTypeLabel,
    this.doctorName,
    this.receptionistName,
    this.locationCity,
  });

  factory ReportPatient.fromJson(Map<String, dynamic> j) => ReportPatient(
        id: j['id'] as int,
        patientCode: j['patient_code'] as String? ?? 'N/A',
        fullName: j['full_name'] as String? ?? '-',
        appointmentDate: j['appointment_date'] as String? ?? '-',
        contactNo: j['contact_no'] as String?,
        age: j['age'] as int?,
        type: j['type'] as String?,
        typeLabel: j['type_label'] as String? ?? '-',
        caseFee: (j['case_fee'] as num?)?.toDouble() ?? 0.0,
        caseTypeLabel: j['case_type_label'] as String? ?? '-',
        doctorName: (j['doctor'] as Map?)?.get('name'),
        receptionistName: (j['receptionist'] as Map?)?.get('name'),
        locationCity: (j['location'] as Map?)?.get('city'),
      );
}

extension _MapGet on Map {
  String? get(String key) => this[key] as String?;
}

class ReportMeta {
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;

  const ReportMeta({
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.perPage,
  });

  factory ReportMeta.fromJson(Map<String, dynamic> j) => ReportMeta(
        currentPage: j['current_page'] as int? ?? 1,
        lastPage: j['last_page'] as int? ?? 1,
        total: j['total'] as int? ?? 0,
        perPage: j['per_page'] as int? ?? 25,
      );

  bool get hasPrev => currentPage > 1;
  bool get hasNext => currentPage < lastPage;
}

class ReportResult {
  final List<ReportPatient> patients;
  final ReportMeta meta;
  final double totalCollection;

  const ReportResult({
    required this.patients,
    required this.meta,
    required this.totalCollection,
  });

  factory ReportResult.fromJson(Map<String, dynamic> j) => ReportResult(
        patients: (j['data'] as List? ?? [])
            .map((e) => ReportPatient.fromJson(e as Map<String, dynamic>))
            .toList(),
        meta: ReportMeta.fromJson(j['meta'] as Map<String, dynamic>? ?? {}),
        totalCollection: (j['total_collection'] as num?)?.toDouble() ?? 0.0,
      );
}

class ReportFilterOption {
  final int id;
  final String name;

  const ReportFilterOption({required this.id, required this.name});

  factory ReportFilterOption.fromJson(Map<String, dynamic> j, {String nameField = 'name'}) =>
      ReportFilterOption(
        id: j['id'] as int,
        name: j[nameField] as String? ?? '-',
      );
}

/// Filter dropdown payload. `locations` is `MasterCity` rows (`{id, name}`,
/// country-scoped to the tenant) — the old `Location`-table shape (`{id,
/// city}`) is gone as of the backend's TASK 1.2 fix, since patient records
/// are keyed to `MasterCity`, not the legacy `tbl_locations` table.
class ReportFilterOptions {
  final List<ReportFilterOption> doctors;
  final List<ReportFilterOption> assistants;
  final List<ReportFilterOption> receptionists;
  final List<ReportFilterOption> locations;
  final List<ReportFilterOption> caseTypes;

  const ReportFilterOptions({
    required this.doctors,
    this.assistants = const [],
    required this.receptionists,
    required this.locations,
    required this.caseTypes,
  });

  factory ReportFilterOptions.fromJson(Map<String, dynamic> j) => ReportFilterOptions(
        doctors: _parseList(j['doctors']),
        assistants: _parseList(j['assistants']),
        receptionists: _parseList(j['receptionists']),
        locations: _parseList(j['locations']),
        caseTypes: (j['case_types'] as List? ?? [])
            .map((e) => ReportFilterOption.fromJson(e as Map<String, dynamic>, nameField: 'case_type'))
            .toList(),
      );

  static List<ReportFilterOption> _parseList(dynamic raw) => (raw as List? ?? [])
      .map((e) => ReportFilterOption.fromJson(e as Map<String, dynamic>))
      .toList();
}

class ReportFilter {
  final String dateRange;
  final int? receptionistId;
  final int? doctorId;
  final int? locationId;
  final int? caseId;
  final String? type; // 'walkin' | 'phone' | null — only meaningful for the OPD landing/export screen

  const ReportFilter({
    this.dateRange = '',
    this.receptionistId,
    this.doctorId,
    this.locationId,
    this.caseId,
    this.type,
  });

  ReportFilter copyWith({
    String? dateRange,
    Object? receptionistId = _sentinel,
    Object? doctorId = _sentinel,
    Object? locationId = _sentinel,
    Object? caseId = _sentinel,
    Object? type = _sentinel,
  }) =>
      ReportFilter(
        dateRange: dateRange ?? this.dateRange,
        receptionistId: receptionistId == _sentinel ? this.receptionistId : receptionistId as int?,
        doctorId: doctorId == _sentinel ? this.doctorId : doctorId as int?,
        locationId: locationId == _sentinel ? this.locationId : locationId as int?,
        caseId: caseId == _sentinel ? this.caseId : caseId as int?,
        type: type == _sentinel ? this.type : type as String?,
      );

  Map<String, String> toQueryParams({int page = 1}) {
    final m = <String, String>{'page': '$page'};
    if (dateRange.isNotEmpty) m['date_range'] = dateRange;
    if (receptionistId != null) m['reception_id'] = '$receptionistId';
    if (doctorId != null) m['doctor_id'] = '$doctorId';
    if (locationId != null) m['location_id'] = '$locationId';
    if (caseId != null) m['case_id'] = '$caseId';
    if (type != null) m['type'] = type!;
    return m;
  }

  bool get isEmpty =>
      dateRange.isEmpty &&
      receptionistId == null &&
      doctorId == null &&
      locationId == null &&
      caseId == null &&
      type == null;

  static const _sentinel = Object();
}

/// `GET reports/channel-counts` — the 3 tappable channel tiles + the
/// full-dataset walk-in collection banner on the OPD Reports landing page.
class ReportChannelCounts {
  final double totalCollection;
  final int otAppointment;
  final int walkin;
  final int phone;

  const ReportChannelCounts({
    required this.totalCollection,
    required this.otAppointment,
    required this.walkin,
    required this.phone,
  });

  factory ReportChannelCounts.fromJson(Map<String, dynamic> j) => ReportChannelCounts(
        totalCollection: (j['total_collection'] as num?)?.toDouble() ?? 0.0,
        otAppointment: j['ot_appointment'] as int? ?? 0,
        walkin: j['walkin'] as int? ?? 0,
        phone: j['phone'] as int? ?? 0,
      );
}

/// `GET reports/channel/{channel}` — a per-channel drill-down. Bundles the
/// full filter-form payload (doctors/assistants/receptionists/locations/case
/// types) in one response so the channel screen needs no separate
/// `filter-data` round trip.
class ReportChannelResult {
  final String channel;
  final String label;
  final List<ReportPatient> patients;
  final ReportMeta meta;
  final ReportFilterOptions filterOptions;

  const ReportChannelResult({
    required this.channel,
    required this.label,
    required this.patients,
    required this.meta,
    required this.filterOptions,
  });

  factory ReportChannelResult.fromJson(Map<String, dynamic> j) => ReportChannelResult(
        channel: j['channel'] as String? ?? '',
        label: j['label'] as String? ?? '',
        patients: (j['patients'] as List? ?? [])
            .map((e) => ReportPatient.fromJson(e as Map<String, dynamic>))
            .toList(),
        meta: ReportMeta.fromJson(j['meta'] as Map<String, dynamic>? ?? {}),
        filterOptions: ReportFilterOptions.fromJson(j),
      );
}
