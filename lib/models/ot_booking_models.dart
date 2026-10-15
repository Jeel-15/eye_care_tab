import 'ot_assistant_models.dart';
import 'ot_counsellor_models.dart';
import 'ot_discharge_models.dart';
import 'ot_ward_models.dart';
import 'patient_models.dart';

/// Guards every nested-object field below against a value that's present and
/// non-null but isn't actually a JSON object — e.g. a raw scalar column
/// value landing under a key that elsewhere means a loaded relation,
/// depending on which endpoint built this JSON and what it eager-loaded.
/// Treats that case as "not present" (null) instead of throwing a hard
/// TypeError that red-screens the whole list — one malformed nested field is
/// better shown as missing than crashing the entire screen it appeared on.
Map<String, dynamic>? _asJsonMap(dynamic v) => v is Map<String, dynamic> ? v : null;

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

/// A single payment record — the Accountant "View" modal's Payments table
/// row (`_payment-view-modal.blade.php`: Receipt / Date / Mode / Amount) and
/// the payment-receipt screen's source. Moved here (from
/// `ot_accountant_models.dart`) so [OtBookingSummary] can carry a booking's
/// full payment list without a circular-feeling re-import.
class OtPaymentEntry {
  final int id;
  final double packageAmount;
  final String? receiptNumber;
  final String paymentMode; // cash | online | mediclaim
  final bool hasMediclaim;
  // Web's receipt uses `paid_at` (the business "when was this paid"
  // timestamp, set explicitly in storePayment()) — not `created_at`, which
  // is just Eloquent's row-insert timestamp and can read a few ms earlier.
  final String? paidAt;
  final OtNamedRef? recordedBy;

  const OtPaymentEntry({
    required this.id,
    required this.packageAmount,
    this.receiptNumber,
    required this.paymentMode,
    this.hasMediclaim = false,
    this.paidAt,
    this.recordedBy,
  });

  factory OtPaymentEntry.fromJson(Map<String, dynamic> j) => OtPaymentEntry(
        id: j['id'] as int,
        packageAmount: switch (j['package_amount']) { num n => n.toDouble(), String s => double.tryParse(s) ?? 0, _ => 0 },
        receiptNumber: j['receipt_number'] as String?,
        paymentMode: j['payment_mode'] as String? ?? 'cash',
        hasMediclaim: j['has_mediclaim'] as bool? ?? false,
        paidAt: j['paid_at'] as String? ?? j['created_at'] as String?,
        recordedBy: j['recorded_by'] != null && j['recorded_by'] is Map<String, dynamic> ? OtNamedRef.fromJson(j['recorded_by'] as Map<String, dynamic>) : null,
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
  // Accountant list appends remaining_balance; used for partial-pay UI.
  final double? remainingBalance;
  // Latest payment id from eager-loaded payments[] — Receipt button without
  // a second payment-status API call (web uses $booking->payments on the
  // dashboard row itself).
  final int? latestPaymentId;
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
  // Accountant "View" parity (web pull 2026-09-30) — the amounts row's
  // "Paid" figure; nullable since other OT list endpoints reusing this same
  // model don't append it.
  final double? totalPaid;
  // Same web pull — whether a surgery-refused booking's refund is fully
  // settled (`OtBooking::isFullyRefunded()`, a plain method so it can't be
  // appended as a model accessor — the controller adds it as a real key).
  final bool? isFullyRefunded;
  // Accountant "View" parity — full counselling record (diagnosis, package,
  // lens, mediclaim, counsellor) for the "Surgery & Counselling" section.
  // Only present when the endpoint eager-loads `counselling`.
  final OtCounsellingItem? counselling;
  // Accountant "View" parity — the Payments table (Receipt/Date/Mode/
  // Amount). Only present when the endpoint eager-loads `payments`.
  final List<OtPaymentEntry> payments;
  // Ward "View" parity (web pull 2026-09-30, `_view-modal.blade.php`'s
  // "Pre-Op Vitals" / "Eye Drop Register" sections). Only present when the
  // endpoint eager-loads `preOp`/`dilationEntries`.
  final OtVitalsItem? preOp;
  final List<OtEyeDropEntry> dilationEntries;
  // OT Assistant "View" parity (web pull 2026-09-30, `_view-modal.blade.php`'s
  // "Surgery Record" / "Implanted Lens" sections). Only present when the
  // endpoint eager-loads `surgery`/`lensDetail`.
  final OtSurgeryRecord? surgery;
  final OtLensDetailInfo? lensDetail;
  // Discharge "View" parity (web pull 2026-09-30, `_view-modal.blade.php`'s
  // "Invoice" section). Only present when the endpoint eager-loads `invoice`.
  final OtInvoiceSummary? invoice;
  // Same web pull — the "Discharged On" field. Real `discharged_at` column,
  // present on every endpoint that serializes the raw booking (not just the
  // discharge desk).
  final DateTime? dischargedAt;
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
  // Web pull 2026-09-28 — discharge print-gate: the booking only becomes
  // `discharged` once all 3 documents are printed (invoice existing is no
  // longer enough). Present on the Discharge billing list endpoint only,
  // same as [hasInvoice] above.
  final int? dischargePrintsDone;
  final int? dischargePrintsTotal;
  final DateTime? summaryBillPrintedAt;
  final DateTime? dischargePrintedAt;
  final DateTime? certificatePrintedAt;

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
    this.remainingBalance,
    this.latestPaymentId,
    this.otType,
    this.packageAmount,
    this.refundableBalance,
    this.totalRefunded,
    this.totalPaid,
    this.isFullyRefunded,
    this.counselling,
    this.payments = const [],
    this.preOp,
    this.dilationEntries = const [],
    this.surgery,
    this.lensDetail,
    this.invoice,
    this.dischargedAt,
    this.preOpStatus,
    this.hasMediclaim,
    this.hasInvoice,
    this.dischargePrintsDone,
    this.dischargePrintsTotal,
    this.summaryBillPrintedAt,
    this.dischargePrintedAt,
    this.certificatePrintedAt,
  });

  factory OtBookingSummary.fromJson(Map<String, dynamic> j) => OtBookingSummary(
        id: j['id'] as int,
        patient: _asJsonMap(j['patient']) != null ? Patient.fromJson(_asJsonMap(j['patient'])!) : null,
        otDoctor: _asJsonMap(j['ot_doctor']) != null ? OtNamedRef.fromJson(_asJsonMap(j['ot_doctor'])!) : null,
        otAssistant: _asJsonMap(j['ot_assistant']) != null ? OtNamedRef.fromJson(_asJsonMap(j['ot_assistant'])!) : null,
        otStatus: j['ot_status'] as String? ?? '',
        eye: j['eye'] as String?,
        surgeryDate: j['surgery_date'] as String?,
        appointmentNumber: j['appointment_number'] as String?,
        paymentStatus: j['payment_status'] as String?,
        remainingBalance: switch (j['remaining_balance']) { num n => n.toDouble(), String s => double.tryParse(s), _ => null },
        latestPaymentId: () {
          final payments = j['payments'] as List?;
          if (payments == null || payments.isEmpty) return null;
          int? maxId;
          for (final p in payments) {
            if (p is! Map) continue;
            final id = p['id'];
            final n = id is int ? id : (id is num ? id.toInt() : int.tryParse('$id'));
            if (n == null) continue;
            if (maxId == null || n > maxId) maxId = n;
          }
          return maxId;
        }(),
        otType: j['ot_type'] as String?,
        preOpStatus: _asJsonMap(j['pre_op'])?['pre_op_status'] as String?,
        // Laravel's `decimal:2` cast serializes to JSON as a STRING (e.g.
        // "1234.00"), not a number — `as num?` throws on it.
        packageAmount: switch (j['package_amount']) { num n => n.toDouble(), String s => double.tryParse(s), _ => null },
        refundableBalance: switch (j['refundable_balance']) { num n => n.toDouble(), String s => double.tryParse(s), _ => null },
        totalRefunded: switch (j['total_refunded']) { num n => n.toDouble(), String s => double.tryParse(s), _ => null },
        totalPaid: switch (j['total_paid']) { num n => n.toDouble(), String s => double.tryParse(s), _ => null },
        isFullyRefunded: j['is_fully_refunded'] as bool?,
        counselling: _asJsonMap(j['counselling']) != null ? OtCounsellingItem.fromJson(_asJsonMap(j['counselling'])!) : null,
        payments: (j['payments'] as List? ?? []).whereType<Map<String, dynamic>>().map(OtPaymentEntry.fromJson).toList(),
        preOp: _asJsonMap(j['pre_op']) != null ? OtVitalsItem.fromJson(_asJsonMap(j['pre_op'])!) : null,
        dilationEntries: (j['dilation_entries'] as List? ?? []).whereType<Map<String, dynamic>>().map(OtEyeDropEntry.fromJson).toList(),
        surgery: _asJsonMap(j['surgery']) != null ? OtSurgeryRecord.fromJson(_asJsonMap(j['surgery'])!) : null,
        lensDetail: _asJsonMap(j['lens_detail']) != null ? OtLensDetailInfo.fromJson(_asJsonMap(j['lens_detail'])!) : null,
        invoice: _asJsonMap(j['invoice']) != null ? OtInvoiceSummary.fromJson(_asJsonMap(j['invoice'])!) : null,
        dischargedAt: j['discharged_at'] != null ? DateTime.tryParse(j['discharged_at'] as String) : null,
        hasMediclaim: j['has_mediclaim'] as bool?,
        hasInvoice: j['has_invoice'] as bool?,
        dischargePrintsDone: (j['discharge_prints_done'] as num?)?.toInt(),
        dischargePrintsTotal: (j['discharge_prints_total'] as num?)?.toInt(),
        summaryBillPrintedAt: j['summary_bill_printed_at'] != null ? DateTime.tryParse(j['summary_bill_printed_at'] as String) : null,
        dischargePrintedAt: j['discharge_printed_at'] != null ? DateTime.tryParse(j['discharge_printed_at'] as String) : null,
        certificatePrintedAt: j['certificate_printed_at'] != null ? DateTime.tryParse(j['certificate_printed_at'] as String) : null,
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
