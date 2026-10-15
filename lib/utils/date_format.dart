import 'package:timezone/timezone.dart' as tz;

import '../services/auth_service.dart';

/// Shared date-formatting helpers — consolidates the month-name array and
/// ISO/display-date builders that were previously reimplemented privately in
/// several screen files with minor format drift between copies.
const kMonthNamesShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `2026-08-25` — for API query params / form fields.
String toIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// `25 Aug 2026` — for on-screen display. Day is zero-padded, matching
/// web's PHP `d M Y` format (the convention this codebase's web-parity work
/// deliberately mirrors) — do not "simplify" away the padding.
String toDisplayDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${kMonthNamesShort[d.month - 1]} ${d.year}';

/// Converts an absolute instant (as returned by the API, always UTC) into
/// the current hospital's own timezone — matching web, which renders every
/// date/time from PHP already tagged with the tenant's real timezone (see
/// PATIENT_DATE_TIME_DISPLAY_AUDIT.md). Deliberately does NOT use
/// `DateTime.toLocal()`, which would convert to the testing device's own
/// OS timezone instead — unrelated to the hospital's actual location.
/// Falls back to UTC if the hospital's timezone is missing or unrecognized
/// (e.g. before the first successful login response is cached).
DateTime toHospitalTime(DateTime d) {
  final tzName = AuthService.instance.cachedHospital?.timezone;
  if (tzName == null || tzName.isEmpty) return d.toUtc();
  try {
    return tz.TZDateTime.from(d, tz.getLocation(tzName));
  } catch (_) {
    return d.toUtc();
  }
}

/// `25 Aug 2026, 02:30 PM` — for on-screen display with time, matching
/// web's `d M Y, h:i A` receipt timestamp format, in the hospital's own
/// timezone.
String toDisplayDateTime(DateTime d) {
  final local = toHospitalTime(d);
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

/// Date-only variant of [formatDateTimeString] — for fields web shows
/// without a time component (e.g. `appointment_date`).
String formatDateString(String? raw, {String fallback = '—'}) {
  if (raw == null) return fallback;
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return toDisplayDate(toHospitalTime(d));
}

/// Parses a calendar-date API value (`surgery_date`, `follow_up_date`,
/// `expiry_date`, `appointment_date` — every backend field cast as Eloquent
/// `'date'`) into the hospital's correct local calendar date.
///
/// Laravel always serializes a `'date'`-cast attribute to JSON as a full
/// UTC instant (`...Z`), even though it is conceptually a bare calendar
/// date with no time component — e.g. a hospital in Asia/Kolkata (+5:30)
/// with `surgery_date` "2026-10-03" sends `"2026-10-02T18:30:00.000000Z"`.
/// Reading that string's day/month/year directly (a naive
/// `DateTime.parse`) shows the wrong day — one calendar day behind — for
/// any hospital timezone ahead of UTC. Always convert through
/// [toHospitalTime] before reading date components, exactly like
/// [formatDateString] already does for `appointment_date`. Null for
/// null/blank/unparseable input.
DateTime? parseApiPlainDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final d = DateTime.tryParse(raw);
  if (d == null) return null;
  return toHospitalTime(d);
}

/// `25 Aug 2026` display form of [parseApiPlainDate] — falls back to the
/// raw string if it doesn't parse, null for null/blank input so callers can
/// supply their own placeholder.
String? formatPlainDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final d = parseApiPlainDate(raw);
  return d == null ? raw : toDisplayDate(d);
}

/// `2026-09-21T14:30` — wall-clock value for API fields web submits from an
/// `<input type="datetime-local">`. The caller passes a hospital-local
/// wall-clock DateTime (e.g. from [toHospitalTime] or a picker), not an instant.
String toApiDateTimeLocal(DateTime d) =>
    '${toIsoDate(d)}T${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
