/// `GET /reports/ot` — report catalogue grouped by category.
class OtReportTypeGroup {
  final String group;
  final List<OtReportType> types;
  const OtReportTypeGroup({required this.group, required this.types});
}

class OtReportType {
  final String label;
  final String key;
  const OtReportType({required this.label, required this.key});

  factory OtReportType.fromJson(Map<String, dynamic> j) => OtReportType(
        label: j['label'] as String? ?? '',
        key: j['key'] as String? ?? '',
      );
}

List<OtReportTypeGroup> parseOtReportGroups(Map<String, dynamic> data) => data.entries
    .map((e) => OtReportTypeGroup(
          group: e.key,
          types: (e.value as List? ?? []).map((t) => OtReportType.fromJson(t as Map<String, dynamic>)).toList(),
        ))
    .toList();

/// `GET /reports/ot/lens-report` — dedicated page (summary cards +
/// lens-power breakdown), not the generic headings/rows `OtReportResult`.
/// Mirrors web's `OtReportController::buildLensReportData()`.
class OtLensReportSummary {
  final int totalLensesUsed;
  final int totalSurgeries;
  final int uniquePowers;

  const OtLensReportSummary({
    required this.totalLensesUsed,
    required this.totalSurgeries,
    required this.uniquePowers,
  });

  factory OtLensReportSummary.fromJson(Map<String, dynamic> j) => OtLensReportSummary(
        totalLensesUsed: (j['totalLensesUsed'] as num?)?.toInt() ?? 0,
        totalSurgeries: (j['totalSurgeries'] as num?)?.toInt() ?? 0,
        uniquePowers: (j['uniquePowers'] as num?)?.toInt() ?? 0,
      );
}

class OtLensPowerBreakdownRow {
  final String power;
  final int quantity;

  const OtLensPowerBreakdownRow({required this.power, required this.quantity});

  factory OtLensPowerBreakdownRow.fromJson(Map<String, dynamic> j) => OtLensPowerBreakdownRow(
        power: j['power'] as String? ?? '-',
        quantity: (j['quantity'] as num?)?.toInt() ?? 0,
      );
}

class OtLensReportData {
  final String from;
  final String to;
  final OtLensReportSummary summary;
  final List<OtLensPowerBreakdownRow> powerSummary;
  final List<String> detailHeadings;
  final List<List<dynamic>> detailRows;

  const OtLensReportData({
    required this.from,
    required this.to,
    required this.summary,
    required this.powerSummary,
    required this.detailHeadings,
    required this.detailRows,
  });

  factory OtLensReportData.fromJson(Map<String, dynamic> j) => OtLensReportData(
        from: j['from'] as String? ?? '',
        to: j['to'] as String? ?? '',
        summary: OtLensReportSummary.fromJson(j['summary'] as Map<String, dynamic>? ?? const {}),
        powerSummary: (j['power_summary'] as List? ?? [])
            .map((e) => OtLensPowerBreakdownRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        detailHeadings: (j['detail_headings'] as List? ?? []).map((e) => e.toString()).toList(),
        detailRows: (j['detail_rows'] as List? ?? []).map((r) => r as List<dynamic>).toList(),
      );
}

/// `GET /reports/ot/{type}` result — a plain heading/rows table.
class OtReportResult {
  final String type;
  final String label;
  final List<String> headings;
  final List<List<dynamic>> rows;
  final String from;
  final String to;

  const OtReportResult({required this.type, required this.label, required this.headings, required this.rows, required this.from, required this.to});

  factory OtReportResult.fromJson(Map<String, dynamic> j) => OtReportResult(
        type: j['type'] as String? ?? '',
        label: j['label'] as String? ?? '',
        headings: (j['headings'] as List? ?? []).map((e) => e.toString()).toList(),
        rows: (j['rows'] as List? ?? []).map((r) => r as List<dynamic>).toList(),
        from: j['from'] as String? ?? '',
        to: j['to'] as String? ?? '',
      );
}
