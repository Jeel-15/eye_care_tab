import '../services/auth_service.dart';

// Shared currency formatters — screens that already receive `HospitalInfo`
// via constructor should pass `widget.hospital.currencySymbol` explicitly.
// `currentCurrencySymbol()` below is a fallback for screens buried several
// navigation levels deep that were never threaded a `hospital` param at
// all (e.g. most of the OT module) — reads AuthService's existing
// in-memory session cache rather than inventing a new global. See
// LOCATION_CURRENCY_PARITY_PRD.md Phase 3/4. Only the symbol is dynamic;
// digit-grouping style (Indian lakh/crore) stays as-is, since web itself
// doesn't vary number-grouping by country either.

/// Fallback for screens with no `hospital` constructor param to thread
/// through — reads the session's cached hospital info directly.
String currentCurrencySymbol() => AuthService.instance.cachedHospital?.currencySymbol ?? '₹';

/// Direct replacement for inline `'₹${amount.toStringAsFixed(2)}'` literals.
String formatMoneySimple(double amount, String symbol, {int decimals = 2}) =>
    '$symbol${amount.toStringAsFixed(decimals)}';

/// Indian-style comma grouping (1,23,456), full precision — replaces the
/// old hardcoded `_fmtRupeeFull`.
String formatMoney(double amount, String symbol) {
  final n = amount.toInt();
  if (n == 0) return '${symbol}0';
  final s = n.toString();
  if (s.length <= 3) return '$symbol$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final chunks = <String>[last3];
  while (rest.length > 2) {
    chunks.add(rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) chunks.add(rest);
  return '$symbol${chunks.reversed.join(',')}';
}

/// Compact lakh/crore form (₹1.2Cr, ₹85k) — replaces the old hardcoded
/// `_fmtRupee`.
String formatMoneyCompact(double amount, String symbol) {
  if (amount >= 10000000) return '$symbol${(amount / 10000000).toStringAsFixed(1)}Cr';
  if (amount >= 100000) return '$symbol${(amount / 100000).toStringAsFixed(1)}L';
  if (amount >= 1000) return '$symbol${(amount / 1000).toStringAsFixed(0)}k';
  return '$symbol${amount.toInt()}';
}
