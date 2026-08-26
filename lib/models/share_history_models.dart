class HistoryPatient {
  final int id;
  final String patientCode;
  final String firstName;
  final String lastName;
  final String? doctorName;
  final String appointmentDate;
  final String contactNo;
  final int age;
  final bool isOwn;
  final String? tenantName;
  final int tenantId;
  final String allPatientIds;

  const HistoryPatient({
    required this.id,
    required this.patientCode,
    required this.firstName,
    required this.lastName,
    this.doctorName,
    required this.appointmentDate,
    required this.contactNo,
    required this.age,
    required this.isOwn,
    this.tenantName,
    required this.tenantId,
    required this.allPatientIds,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory HistoryPatient.fromJson(Map<String, dynamic> j) => HistoryPatient(
        id: j['id'] as int,
        patientCode: (j['patient_code'] as String?) ?? '',
        firstName: (j['first_name'] as String?) ?? '',
        lastName: (j['last_name'] as String?) ?? '',
        doctorName: (j['doctor'] as Map<String, dynamic>?)?['name'] as String?,
        appointmentDate: (j['appointment_date'] as String?) ?? '',
        contactNo: (j['contact_no'] as String?) ?? '',
        age: (j['age'] as num?)?.toInt() ?? 0,
        isOwn: (j['is_own'] as bool?) ?? true,
        tenantName: (j['tenant'] as Map<String, dynamic>?)?['name'] as String?,
        tenantId: (j['tenant_id'] as num?)?.toInt() ?? 0,
        allPatientIds: (j['all_patient_ids'] as String?) ?? '${j['id']}',
      );
}

class ShareHospital {
  final int id;
  final String name;
  final String? city;
  final String? district;
  final String? state;
  final String? logoPath;
  final String status;
  final ShareRequestInfo? requestInfo;

  const ShareHospital({
    required this.id,
    required this.name,
    this.city,
    this.district,
    this.state,
    this.logoPath,
    required this.status,
    this.requestInfo,
  });

  factory ShareHospital.fromJson(Map<String, dynamic> j) => ShareHospital(
        id: j['id'] as int,
        name: (j['name'] as String?) ?? '',
        city: j['city'] as String?,
        district: j['district'] as String?,
        state: j['state'] as String?,
        logoPath: j['logo_path'] as String?,
        status: (j['status'] as String?) ?? '',
        requestInfo: j['request_info'] != null
            ? ShareRequestInfo.fromJson(j['request_info'] as Map<String, dynamic>)
            : null,
      );
}

class ShareRequestInfo {
  final int id;
  final String status;    // 'pending', 'accepted', 'rejected'
  final String direction; // 'sent', 'received'

  const ShareRequestInfo({
    required this.id,
    required this.status,
    required this.direction,
  });

  factory ShareRequestInfo.fromJson(Map<String, dynamic> j) => ShareRequestInfo(
        id: j['id'] as int,
        status: (j['status'] as String?) ?? '',
        direction: (j['direction'] as String?) ?? '',
      );
}

class HospitalDetail {
  final int id;
  final String name;
  final String city;
  final String state;
  final String adminEmail;
  final int doctorsCount;
  final int staffCount;
  final int patientsCount;

  const HospitalDetail({
    required this.id,
    required this.name,
    required this.city,
    required this.state,
    required this.adminEmail,
    required this.doctorsCount,
    required this.staffCount,
    required this.patientsCount,
  });

  factory HospitalDetail.fromJson(Map<String, dynamic> j) => HospitalDetail(
        id: j['id'] as int,
        name: (j['name'] as String?) ?? '',
        city: (j['city'] as String?) ?? '',
        state: (j['state'] as String?) ?? '',
        adminEmail: (j['admin_email'] as String?) ?? '',
        doctorsCount: (j['doctors_count'] as num?)?.toInt() ?? 0,
        staffCount: (j['staff_count'] as num?)?.toInt() ?? 0,
        patientsCount: (j['patients_count'] as num?)?.toInt() ?? 0,
      );
}

class ShareConnection {
  final int id;
  final SharePartner partner;

  const ShareConnection({required this.id, required this.partner});

  factory ShareConnection.fromJson(Map<String, dynamic> j) => ShareConnection(
        id: j['id'] as int,
        partner: SharePartner.fromJson(j['partner'] as Map<String, dynamic>),
      );
}

class SharePartner {
  final int id;
  final String name;
  final String? city;
  final String? state;

  const SharePartner({
    required this.id,
    required this.name,
    this.city,
    this.state,
  });

  factory SharePartner.fromJson(Map<String, dynamic> j) => SharePartner(
        id: j['id'] as int,
        name: (j['name'] as String?) ?? '',
        city: j['city'] as String?,
        state: j['state'] as String?,
      );
}

class IncomingRequest {
  final int id;
  final SharePartner fromTenant;
  final String createdAt;

  const IncomingRequest({
    required this.id,
    required this.fromTenant,
    required this.createdAt,
  });

  factory IncomingRequest.fromJson(Map<String, dynamic> j) => IncomingRequest(
        id: j['id'] as int,
        fromTenant: SharePartner.fromJson(j['from_tenant'] as Map<String, dynamic>),
        createdAt: (j['created_at'] as String?) ?? '',
      );
}

class SentRequest {
  final int id;
  final SharePartner toTenant;
  final String status;
  final String createdAt;

  const SentRequest({
    required this.id,
    required this.toTenant,
    required this.status,
    required this.createdAt,
  });

  factory SentRequest.fromJson(Map<String, dynamic> j) => SentRequest(
        id: j['id'] as int,
        toTenant: SharePartner.fromJson(j['to_tenant'] as Map<String, dynamic>),
        status: (j['status'] as String?) ?? 'pending',
        createdAt: (j['created_at'] as String?) ?? '',
      );
}

class ConnectionsData {
  final List<ShareConnection> accepted;
  final List<IncomingRequest> incoming;
  final List<SentRequest> sent;

  const ConnectionsData({
    required this.accepted,
    required this.incoming,
    required this.sent,
  });
}

class ShareHistoryMeta {
  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;

  const ShareHistoryMeta({
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
  });

  factory ShareHistoryMeta.fromJson(Map<String, dynamic> j) => ShareHistoryMeta(
        total: (j['total'] as num?)?.toInt() ?? 0,
        perPage: (j['per_page'] as num?)?.toInt() ?? 20,
        currentPage: (j['current_page'] as num?)?.toInt() ?? 1,
        lastPage: (j['last_page'] as num?)?.toInt() ?? 1,
      );
}
