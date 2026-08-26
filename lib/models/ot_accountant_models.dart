import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'ot_booking_models.dart';
import 'ot_counsellor_models.dart';
import 'ot_inventory_models.dart';
import 'patient_models.dart';

/// Shared payment-status badge styling (OT_WEB_PARITY_FIX_PRD.md §6.1):
/// Payment Completed=green / Partially Paid=info-blue / Package Not
/// Set=grey (unpriced) / Payment Pending=amber.
Color paymentStatusColor(String status) => switch (status) {
      'paid' => AppColors.green,
      'partially_paid' => AppColors.blue,
      'unpriced' => AppColors.textDisabled,
      _ => AppColors.orange,
    };

String paymentStatusLabel(String status) => switch (status) {
      'paid' => 'Payment Completed',
      'partially_paid' => 'Partially Paid',
      'unpriced' => 'Package Not Set',
      _ => 'Payment Pending',
    };

/// A single payment record — exact field set not spelled out in the
/// contract beyond "payments[]"/"payment (with booking.patient,
/// recordedBy)"; modeled from the `POST .../payments` body shape (the
/// natural mirror of what gets stored) plus the obvious display fields.
/// Verify against a live response once the backend is reachable (§1).
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
        packageAmount: numOrStringToDouble(j['package_amount']) ?? 0,
        receiptNumber: j['receipt_number'] as String?,
        paymentMode: j['payment_mode'] as String? ?? 'cash',
        hasMediclaim: j['has_mediclaim'] as bool? ?? false,
        paidAt: j['paid_at'] as String? ?? j['created_at'] as String?,
        recordedBy: j['recorded_by'] != null ? OtNamedRef.fromJson(j['recorded_by'] as Map<String, dynamic>) : null,
      );
}

/// `GET .../payment-status` — always derived live, never a stored/stale
/// column.
class OtPaymentStatus {
  final String paymentStatus; // unpriced | pending | partially_paid | paid
  final double requiredTotal;
  final double totalPaid;
  final double remainingBalance;
  final List<OtPaymentEntry> payments;

  const OtPaymentStatus({
    required this.paymentStatus,
    required this.requiredTotal,
    required this.totalPaid,
    required this.remainingBalance,
    required this.payments,
  });

  factory OtPaymentStatus.fromJson(Map<String, dynamic> j) => OtPaymentStatus(
        paymentStatus: j['payment_status'] as String? ?? 'unpriced',
        requiredTotal: numOrStringToDouble(j['required_total']) ?? 0,
        totalPaid: numOrStringToDouble(j['total_paid']) ?? 0,
        remainingBalance: numOrStringToDouble(j['remaining_balance']) ?? 0,
        payments: (j['payments'] as List? ?? []).map((e) => OtPaymentEntry.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// `GET .../payment-form-data` — lazily auto-creates the OT invoice on
/// first visit (matches web).
class OtPaymentFormData {
  final OtBookingSummary booking;
  final OtCounsellingItem? counselling;
  final double defaultPackageAmount;
  final double totalPaidSoFar;
  final double requiredTotal;
  final String autoReceiptNumber;
  final String defaultPaymentMode;
  // Web shows this as a readonly "Invoice Number (Auto)" field — the backend
  // lazily auto-creates a real `ot_invoices` row the first time this data is
  // fetched, so a real number is always present by the time the client sees
  // it (see OT_WEB_PARITY_FIX_PRD.md).
  final String? invoiceNumber;

  const OtPaymentFormData({
    required this.booking,
    this.counselling,
    required this.defaultPackageAmount,
    required this.totalPaidSoFar,
    required this.requiredTotal,
    required this.autoReceiptNumber,
    required this.defaultPaymentMode,
    this.invoiceNumber,
  });

  double get remainingBalance => (requiredTotal - totalPaidSoFar).clamp(0, double.infinity);

  factory OtPaymentFormData.fromJson(Map<String, dynamic> j) => OtPaymentFormData(
        booking: OtBookingSummary.fromJson(j['booking'] as Map<String, dynamic>),
        counselling: j['counselling'] != null ? OtCounsellingItem.fromJson(j['counselling'] as Map<String, dynamic>) : null,
        defaultPackageAmount: numOrStringToDouble(j['default_package_amount']) ?? 0,
        totalPaidSoFar: numOrStringToDouble(j['total_paid_so_far']) ?? 0,
        requiredTotal: numOrStringToDouble(j['required_total']) ?? 0,
        autoReceiptNumber: j['auto_receipt_number'] as String? ?? '',
        defaultPaymentMode: j['default_payment_mode'] as String? ?? 'cash',
        invoiceNumber: (j['invoice'] as Map<String, dynamic>?)?['invoice_number'] as String?,
      );
}

/// Result of `POST .../payments` — `ot_status` auto-flips to
/// `payment_verified` in this same call when `is_fully_paid` is true, no
/// second "verify" call exists (see build PRD §9 gotcha).
class OtPaymentResult {
  final int paymentId;
  final String otStatus;
  final bool isFullyPaid;
  final double remainingBalance;

  const OtPaymentResult({required this.paymentId, required this.otStatus, required this.isFullyPaid, required this.remainingBalance});

  factory OtPaymentResult.fromJson(Map<String, dynamic> j) => OtPaymentResult(
        paymentId: j['payment_id'] as int,
        otStatus: j['ot_status'] as String? ?? '',
        isFullyPaid: j['is_fully_paid'] as bool? ?? false,
        remainingBalance: numOrStringToDouble(j['remaining_balance']) ?? 0,
      );
}

/// Per-tenant money-summary card shown on the Accountant dashboard (web:
/// collected/refunded/net + a count of refunds still pending). Sits under
/// the `bookings()` response's `meta.money_summary`, not `data`. See
/// WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §4.
class OtMoneySummary {
  final double collected;
  final double refunded;
  final int refundsPending;
  final double net;

  const OtMoneySummary({required this.collected, required this.refunded, required this.refundsPending, required this.net});

  factory OtMoneySummary.fromJson(Map<String, dynamic> j) => OtMoneySummary(
        collected: numOrStringToDouble(j['collected']) ?? 0,
        refunded: numOrStringToDouble(j['refunded']) ?? 0,
        refundsPending: j['refunds_pending'] as int? ?? 0,
        net: numOrStringToDouble(j['net']) ?? 0,
      );
}

/// `GET .../refund-form-data` — only reachable for `surgery_refused`
/// bookings with a refundable balance; `refund_amount` is always the FULL
/// balance (no partial-refund UI exists, matches web exactly). See
/// WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §4.
class OtRefundFormData {
  final OtBookingSummary booking;
  final double totalPaid;
  final double totalRefunded;
  final double refundAmount;
  final String autoReceiptNumber;

  const OtRefundFormData({
    required this.booking,
    required this.totalPaid,
    required this.totalRefunded,
    required this.refundAmount,
    required this.autoReceiptNumber,
  });

  factory OtRefundFormData.fromJson(Map<String, dynamic> j) => OtRefundFormData(
        booking: OtBookingSummary.fromJson(j['booking'] as Map<String, dynamic>),
        totalPaid: numOrStringToDouble(j['total_paid']) ?? 0,
        totalRefunded: numOrStringToDouble(j['total_refunded']) ?? 0,
        refundAmount: numOrStringToDouble(j['refund_amount']) ?? 0,
        autoReceiptNumber: j['auto_receipt_number'] as String? ?? '',
      );
}

/// Result of `POST .../refunds` — a raw `OtRefund` row.
class OtRefundResult {
  final double amount;
  final String? receiptNumber;

  const OtRefundResult({required this.amount, this.receiptNumber});

  factory OtRefundResult.fromJson(Map<String, dynamic> j) => OtRefundResult(
        amount: numOrStringToDouble(j['amount']) ?? 0,
        receiptNumber: j['receipt_number'] as String?,
      );
}

class OtPaymentReceipt {
  final OtPaymentEntry payment;
  final double totalPaid;
  final double requiredTotal;
  // Matches web's receipt_print.blade.php — the Patient box (Name/UHID/
  // Mobile) and the Package Balance box's Status row both read from the
  // booking nested under `payment`, not top-level.
  final Patient? patient;
  final String? bookingPaymentStatus;

  const OtPaymentReceipt({required this.payment, required this.totalPaid, required this.requiredTotal, this.patient, this.bookingPaymentStatus});

  factory OtPaymentReceipt.fromJson(Map<String, dynamic> j) {
    final paymentJson = j['payment'] as Map<String, dynamic>;
    final bookingJson = paymentJson['booking'] as Map<String, dynamic>?;
    return OtPaymentReceipt(
      payment: OtPaymentEntry.fromJson(paymentJson),
      totalPaid: numOrStringToDouble(j['total_paid']) ?? 0,
      requiredTotal: numOrStringToDouble(j['required_total']) ?? 0,
      patient: bookingJson?['patient'] != null ? Patient.fromJson(bookingJson!['patient'] as Map<String, dynamic>) : null,
      bookingPaymentStatus: bookingJson?['payment_status'] as String?,
    );
  }
}
