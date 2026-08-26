class FocPatient {
  final int id;
  final String patientCode;
  final String firstName;
  final String lastName;

  const FocPatient({
    required this.id,
    required this.patientCode,
    required this.firstName,
    required this.lastName,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory FocPatient.fromJson(Map<String, dynamic> j) => FocPatient(
        id: j['id'] as int? ?? 0,
        patientCode: j['patient_code'] as String? ?? '',
        firstName: j['first_name'] as String? ?? '',
        lastName: j['last_name'] as String? ?? '',
      );
}

class FocDoctor {
  final int id;
  final String name;

  const FocDoctor({required this.id, required this.name});

  factory FocDoctor.fromJson(Map<String, dynamic> j) =>
      FocDoctor(id: j['id'] as int? ?? 0, name: j['name'] as String? ?? '');
}

class FocItem {
  final int id;
  final int patientId;
  final int? doctorId;
  final double focFee;
  final String status; // pending | accepted | rejected
  final String reason;
  final String? rejectedReason;
  final String? acceptedAt;
  final FocPatient? patient;
  final FocDoctor? doctor;
  final FocDoctor? acceptedByUser;
  final String createdAt;

  const FocItem({
    required this.id,
    required this.patientId,
    this.doctorId,
    required this.focFee,
    required this.status,
    required this.reason,
    this.rejectedReason,
    this.acceptedAt,
    this.patient,
    this.doctor,
    this.acceptedByUser,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';

  factory FocItem.fromJson(Map<String, dynamic> j) => FocItem(
        id: j['id'] as int? ?? 0,
        patientId: j['patient_id'] as int? ?? 0,
        doctorId: j['doctor_id'] as int?,
        focFee: double.tryParse(j['foc_fee']?.toString() ?? '0') ?? 0.0,
        status: j['status'] as String? ?? 'pending',
        reason: j['reason'] as String? ?? '',
        rejectedReason: j['rejected_reason'] as String?,
        acceptedAt: j['accepted_at'] as String?,
        patient: j['patient'] != null
            ? FocPatient.fromJson(j['patient'] as Map<String, dynamic>)
            : null,
        doctor: j['doctor'] != null
            ? FocDoctor.fromJson(j['doctor'] as Map<String, dynamic>)
            : null,
        acceptedByUser: j['accepted_by_user'] != null
            ? FocDoctor.fromJson(j['accepted_by_user'] as Map<String, dynamic>)
            : null,
        createdAt: j['created_at'] as String? ?? '',
      );
}

class FocListResult {
  final List<FocItem> items;
  final int total;
  final int currentPage;
  final int lastPage;

  const FocListResult({
    required this.items,
    required this.total,
    required this.currentPage,
    required this.lastPage,
  });

  factory FocListResult.fromJson(Map<String, dynamic> j) {
    final data = j['data'] as Map<String, dynamic>? ?? {};
    final itemList = data['data'] as List? ?? [];
    return FocListResult(
      items: itemList
          .map((e) => FocItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: data['total'] as int? ?? 0,
      currentPage: data['current_page'] as int? ?? 1,
      lastPage: data['last_page'] as int? ?? 1,
    );
  }
}
