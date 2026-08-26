/// Shared date-formatting helpers — consolidates the month-name array and
/// ISO/display-date builders that were previously reimplemented privately in
/// several screen files with minor format drift between copies.
const kMonthNamesShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// `2026-08-25` — for API query params / form fields.
String toIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// `25 Aug 2026` — for on-screen display. Day is zero-padded, matching
/// web's PHP `d M Y` format (the convention this codebase's web-parity work
/// deliberately mirrors) — do not "simplify" away the padding.
String toDisplayDate(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${kMonthNamesShort[d.month - 1]} ${d.year}';

/// `25 Aug 2026, 02:30 PM` — for on-screen display with time, matching
/// web's `d M Y, h:i A` receipt timestamp format.
String toDisplayDateTime(DateTime d) {
  final local = d.toLocal();
  final h12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${toDisplayDate(local)}, ${h12.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} $period';
}

/// Parses an ISO datetime string and formats it, with a fallback for
/// null/unparseable input — the common shape every ad hoc `_fmtXxx(String?)`
/// helper reimplemented.
String formatDateTimeString(String? raw, {String fallback = '—'}) {
  if (raw == null) return fallback;
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return toDisplayDateTime(d);
}
