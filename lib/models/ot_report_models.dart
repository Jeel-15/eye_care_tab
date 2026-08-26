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
