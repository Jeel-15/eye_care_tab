/// Laravel's `decimal:N` model casts serialize to JSON as a STRING (e.g.
/// "1234.00"), not a number — every money/measurement field read from a raw
/// (un-mapped) Eloquent model response needs this instead of a bare
/// `as num?` cast. See OT_WEB_PARITY_FIX_PRD.md (decimal-cast gotcha).
double? numOrStringToDouble(dynamic v) => switch (v) { num n => n.toDouble(), String s => double.tryParse(s), _ => null };

/// Result of `POST .../invoice/generate` — flips the booking to
/// `discharged` in the same call.
class OtInvoiceGenerateResult {
  final String invoiceNumber;
  final double totalAmount;
  final double netAmount;

  const OtInvoiceGenerateResult({required this.invoiceNumber, required this.totalAmount, required this.netAmount});

  factory OtInvoiceGenerateResult.fromJson(Map<String, dynamic> j) => OtInvoiceGenerateResult(
        invoiceNumber: j['invoice_number'] as String? ?? '',
        totalAmount: numOrStringToDouble(j['total_amount']) ?? 0,
        netAmount: numOrStringToDouble(j['net_amount']) ?? 0,
      );
}

/// One `line_items[]` entry on an invoice — `Lens Charges`/`OT Charges`/etc
/// when the counselling breakdown is present, or a charge-head percentage
/// split otherwise. See OT_DISCHARGE_INVOICES_WEB_PARITY_FIX_PLAN.md TASK 2.2.
class OtInvoiceLineItem {
  final String head;
  final double? percentage;
  final double amount;

  const OtInvoiceLineItem({required this.head, this.percentage, required this.amount});

  factory OtInvoiceLineItem.fromJson(Map<String, dynamic> j) => OtInvoiceLineItem(
        head: j['head'] as String? ?? '',
        percentage: numOrStringToDouble(j['percentage']),
        amount: numOrStringToDouble(j['amount']) ?? 0,
      );
}

/// `GET .../invoice` — the persisted invoice record, if one has been
/// generated for this booking. Drives the detail screen's invoice-summary
/// card + gates the print grid (only shown once this is non-null).
class OtInvoiceSummary {
  final String invoiceNumber;
  final List<OtInvoiceLineItem> lineItems;
  final double totalAmount;
  final double taxAmount;
  final double discount;
  final double netAmount;
  final String? followUpDate;
  final bool isFinalized;
  final String? createdAt;

  const OtInvoiceSummary({
    required this.invoiceNumber,
    required this.lineItems,
    required this.totalAmount,
    required this.taxAmount,
    required this.discount,
    required this.netAmount,
    this.followUpDate,
    this.isFinalized = false,
    this.createdAt,
  });

  factory OtInvoiceSummary.fromJson(Map<String, dynamic> j) => OtInvoiceSummary(
        invoiceNumber: j['invoice_number'] as String? ?? '',
        lineItems: (j['line_items'] as List? ?? []).map((e) => OtInvoiceLineItem.fromJson(e as Map<String, dynamic>)).toList(),
        totalAmount: numOrStringToDouble(j['total_amount']) ?? 0,
        taxAmount: numOrStringToDouble(j['tax_amount']) ?? 0,
        discount: numOrStringToDouble(j['discount']) ?? 0,
        netAmount: numOrStringToDouble(j['net_amount']) ?? 0,
        followUpDate: j['follow_up_date'] as String?,
        isFinalized: j['is_finalized'] as bool? ?? false,
        createdAt: j['created_at'] as String?,
      );
}

/// One entry from the `discharge-bundle` manifest — a URL list, **not** a
/// merged PDF (see build PRD §10 gotcha, no server-side PDF merge exists).
class OtDischargeDocument {
  final String label;
  final String downloadUrl;

  const OtDischargeDocument({required this.label, required this.downloadUrl});

  factory OtDischargeDocument.fromJson(Map<String, dynamic> j) => OtDischargeDocument(
        label: j['label'] as String? ?? '',
        downloadUrl: j['download_url'] as String? ?? '',
      );
}

/// The 8 individual print document types — matches the 8
/// `GET .../print/{type}` routes exactly (`discharge-bundle` is handled
/// separately, it's a manifest not a print type).
enum OtDischargeDocType {
  invoice('invoice', 'Invoice'),
  summaryBill('summary-bill', 'Bill Summary'),
  discharge('discharge', 'Discharge Summary'),
  certificate('certificate', 'Surgery Certificate'),
  medicineSlip('medicine-slip', 'Take-Home Medicine Slip'),
  prescription('prescription', 'Prescription'),
  lensSlip('lens-slip', 'Lens Implant Details'),
  followupSlip('followup-slip', 'Follow-up Appointment Slip');

  final String path;
  final String label;
  const OtDischargeDocType(this.path, this.label);
}
