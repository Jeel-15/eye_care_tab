import 'patient_models.dart';

/// OT booking status chain — mirrors `OtBooking::STATUS_*` on the backend.
/// Every OT screen (Counsellor/Ward/Assistant/Accountant/Discharge) gates
/// its view/actions off this value. See OT_WORKFLOW_MOBILE_TABLET_BUILD_PRD.md.
abstract class OtStatus {
  static const booked              = 'booked';
  static const surgeryRecommended  = 'surgery_recommended';
  static const counselled          = 'counselled';
  static const paid                = 'paid';
  static const paymentVerified     = 'payment_verified';
  static const inWard              = 'in_ward';
  static const dilated             = 'dilated';
  static const ready               = 'ready';
  static const operated            = 'operated';
  static const discharged          = 'discharged';
  // Patient refused OT after ward consult — sent to Accounts for a full
  // refund. New status, web pull 2026-08-07. See
  // WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §4/§5.
  static const surgeryRefused      = 'surgery_refused';

  static const _labels = {
    booked: 'Booked',
    surgeryRecommended: 'Surgery Recommended',
    counselled: 'Counselled',
    paid: 'Paid',
    paymentVerified: 'Payment Verified',
    inWard: 'In Ward',
    dilated: 'Dilated',
    ready: 'Ready',
    operated: 'Operated',
    discharged: 'Discharged',
    surgeryRefused: 'Surgery Refused',
  };

  static String label(String status) => _labels[status] ?? status;
}

/// A named `{id, name}` reference — used for otDoctor/otAssistant/bookedBy
/// fields that come eager-loaded on `OtBooking` across every OT API response.
class OtNamedRef {
  final int id;
  final String name;

  const OtNamedRef({required this.id, required this.name});

  factory OtNamedRef.fromJson(Map<String, dynamic> j) => OtNamedRef(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
      );
}

/// Shared booking-summary shape used by the Counsellor/Ward/Assistant/
/// Accountant/Discharge queue-list endpoints (Phases 1, 3, 4, 5, 6). Each
/// phase's own service may still parse extra phase-specific fields from the
/// same JSON row — this covers the fields that are common to all of them.
class OtBookingSummary {
  final int id;
  final Patient? patient;
  final OtNamedRef? otDoctor;
  final OtNamedRef? otAssistant;
  final String otStatus;
  final String? eye;
  final String? surgeryDate;
  final String? appointmentNumber;
  // unpriced | pending | partially_paid | paid — present on the Accountant
  // list endpoint's rows (OT_WEB_PARITY_FIX_PRD.md §6.1); nullable since
  // other OT list endpoints reusing this same model don't send it.
  final String? paymentStatus;
  // Web's Counsellor Dashboard shows both of these (Surgery Type, Package
  // Amount) but the current build never parsed them even though both
  // endpoints already serialize the raw `OtBooking` model, so the JSON keys
  // are always present — see OT_WEB_PARITY_FIX_PRD.md §3.2.
  final String? otType;
  final double? packageAmount;
  // Present on the Accountant list endpoint's `refunds` filter rows (Ot
  // pull 2026-08-07) — nullable since other OT list endpoints reusing this
  // same model don't send them. See WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §4.
  final double? refundableBalance;
  final double? totalRefunded;
  // Ward status label source for the Doctor OT List screen ("Ward" column
  // on web) — present when `preOp` is eager-loaded (Doctor OT List
  // endpoint only). See WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §5.
  final String? preOpStatus;
  // Mediclaim fallback for the Surgery Record form's Section A ("Package &
  // Mediclaim") when no counselling row exists yet — web:
  // `$counselling?->mediclaim ?? $booking->has_mediclaim`. See
  // OT_SURGERY_RECORD_WEB_PARITY_FIX_PLAN.md TASK 2.1.
  final bool? hasMediclaim;
  // Discharge & Invoices queue's Generated/Pending badge — web computes this
  // via `$invoiceBookingIds` membership per row (OtInvoiceController.php:122);
  // present on the Discharge billing list endpoint only. See
  // OT_DISCHARGE_INVOICES_WEB_PARITY_FIX_PLAN.md TASK 2.1.
  final bool? hasInvoice;

  const OtBookingSummary({
    required this.id,
    this.patient,
    this.otDoctor,
    this.otAssistant,
    required this.otStatus,
    this.eye,
    this.surgeryDate,
    this.appointmentNumber,
    this.paymentStatus,
    this.otType,
    this.packageAmount,
    this.refundableBalance,
    this.totalRefunded,
    this.preOpStatus,
    this.hasMediclaim,
    this.hasInvoice,
  });

  factory OtBookingSummary.fromJson(Map<String, dynamic> j) => OtBookingSummary(
        id: j['id'] as int,
        patient: j['patient'] != null ? Patient.fromJson(j['patient'] as Map<String, dynamic>) : null,
        otDoctor: j['ot_doctor'] != null ? OtNamedRef.fromJson(j['ot_doctor'] as Map<String, dynamic>) : null,
        otAssistant: j['ot_assistant'] != null ? OtNamedRef.fromJson(j['ot_assistant'] as Map<String, dynamic>) : null,
        otStatus: j['ot_status'] as String? ?? '',
        eye: j['eye'] as String?,
        surgeryDate: j['surgery_date'] as String?,
        appointmentNumber: j['appointment_number'] as String?,
        paymentStatus: j['payment_status'] as String?,
        otType: j['ot_type'] as String?,
        preOpStatus: (j['pre_op'] as Map<String, dynamic>?)?['pre_op_status'] as String?,
        // Laravel's `decimal:2` cast serializes to JSON as a STRING (e.g.
        // "1234.00"), not a number — `as num?` throws on it.
        packageAmount: switch (j['package_amount']) { num n => n.toDouble(), String s => double.tryParse(s), _ => null },
        refundableBalance: switch (j['refundable_balance']) { num n => n.toDouble(), String s => double.tryParse(s), _ => null },
        totalRefunded: switch (j['total_refunded']) { num n => n.toDouble(), String s => double.tryParse(s), _ => null },
        hasMediclaim: j['has_mediclaim'] as bool?,
        hasInvoice: j['has_invoice'] as bool?,
      );
}

/// Standard Laravel paginator meta fields (`current_page`/`last_page`/
/// `total`/`per_page` sit directly on the same object as `data[]` — not
/// nested under an extra `meta` key, unlike the older OPD patient-list
/// endpoint). Shared across every paginated OT list endpoint (Appointments,
/// Counsellor/Ward/Assistant/Accountant/Discharge queues).
class OtPaginationMeta {
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;

  const OtPaginationMeta({required this.currentPage, required this.lastPage, required this.total, required this.perPage});

  factory OtPaginationMeta.fromJson(Map<String, dynamic> j) => OtPaginationMeta(
        currentPage: j['current_page'] as int? ?? 1,
        lastPage: j['last_page'] as int? ?? 1,
        total: j['total'] as int? ?? 0,
        perPage: j['per_page'] as int? ?? 25,
      );
}

/// `GET /dashboard/ot-receptionist` — the 3 KPI cards on the OT Home
/// Dashboard (web's `hospital.ot.dashboard`, previously missing from both
/// apps — see OT_WEB_PARITY_FIX_PRD.md §8).
class OtReceptionistDashboardStats {
  final int totalOtToday;
  final int pendingCounselling;
  final int readyForSurgery;

  const OtReceptionistDashboardStats({required this.totalOtToday, required this.pendingCounselling, required this.readyForSurgery});

  factory OtReceptionistDashboardStats.fromJson(Map<String, dynamic> j) => OtReceptionistDashboardStats(
        totalOtToday: j['total_ot_today'] as int? ?? 0,
        pendingCounselling: j['pending_counselling'] as int? ?? 0,
        readyForSurgery: j['ready_for_surgery'] as int? ?? 0,
      );
}

/// Result of `POST /ot/recommend-surgery/{patientId}` — the doctor's exam-
/// screen handoff into the OT workflow (Round 3.5). This is the call that
/// actually creates/updates the `OtBooking` row every other OT screen reads.
class OtRecommendSurgeryResult {
  final int bookingId;
  final String otStatus;

  const OtRecommendSurgeryResult({required this.bookingId, required this.otStatus});

  factory OtRecommendSurgeryResult.fromJson(Map<String, dynamic> j) => OtRecommendSurgeryResult(
        bookingId: j['booking_id'] as int,
        otStatus: j['ot_status'] as String? ?? '',
      );
}
