import 'package:flutter/material.dart';
import '../models/ot_counsellor_models.dart';
import '../models/patient_models.dart';
import '../utils/currency_format.dart';
import '../utils/date_format.dart';
import '../widgets/detail_card_kit.dart';
import '../constants/app_colors.dart';

/// Shared labels for the locked record-view dialogs. Blank values stay
/// null so [FactSheet] omits the tile.
String? doctorDisplayName(String? name) {
  final n = name?.trim();
  if (n == null || n.isEmpty) return null;
  return RegExp(r'^dr\b\.?', caseSensitive: false).hasMatch(n) ? n : 'Dr. $n';
}

String? otherNumber(String? phone, String? other) {
  final p = phone?.trim() ?? '';
  final o = other?.trim() ?? '';
  if (o.isEmpty || o == p) return null;
  return o;
}

String? ageGenderLabel(int? age, String? gender) {
  final parts = <String>[
    if (age != null) '${age}y',
    if (gender != null && gender.trim().isNotEmpty) gender.trim(),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

String? yesNo(bool? value) => value == null ? null : (value ? 'Yes' : 'No');

String money(num? value) => '${currentCurrencySymbol()}${(value ?? 0).toStringAsFixed(2)}';

String? titleWords(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return null;
  return raw.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}

String formatClock12(DateTime d) {
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final period = d.hour >= 12 ? 'PM' : 'AM';
  return '$h12:${d.minute.toString().padLeft(2, '0')} $period';
}

String? counsellingLensLine(OtCounsellingItem? counselling) {
  if (counselling == null) return null;
  final category = counselling.lensCategory?.trim() ?? '';
  final titled = category.isEmpty ? '' : '${category[0].toUpperCase()}${category.substring(1)}';
  final spec = [counselling.lensCompany, counselling.lensModel].where((s) => (s ?? '').trim().isNotEmpty).join(' ');
  final line = [titled, spec].where((s) => s.isNotEmpty).join(' · ');
  return line.isEmpty ? null : line;
}

String? counsellingPackageLine(OtCounsellingItem? counselling) {
  if (counselling == null) return null;
  final room = counselling.roomCategory.trim();
  final roomLabel = room.isEmpty ? null : '${room[0].toUpperCase()}${room.substring(1)} room';
  final line = [counselling.packageName, roomLabel].where((s) => (s ?? '').trim().isNotEmpty).join(' · ');
  return line.isEmpty ? null : line;
}

List<Widget> patientIdentityPills(Patient? patient) {
  if (patient == null) return const [];
  final age = ageGenderLabel(patient.age, patient.genderDisplay);
  return [
    if (patient.patientCode.isNotEmpty) Pill(patient.patientCode, bg: AppColors.primaryA10, fg: AppColors.primary),
    if (age != null) Pill(age, bg: AppColors.primaryA07, fg: AppColors.primary),
  ];
}

List<Fact> patientRecordFacts(
  Patient? patient, {
  bool consultingDoctor = true,
  bool occupation = false,
  bool visitDate = false,
  bool caseType = false,
  bool fee = false,
  bool referrer = false,
  bool registeredAt = false,
  bool markReturning = false,
}) {
  final type = switch (patient?.type) {
    'phone' => 'Phone Booking',
    'walkin' => 'Walk-in',
    null || '' => null,
    final raw => '${raw[0].toUpperCase()}${raw.substring(1)}',
  };
  final visit = type == null
      ? null
      : (markReturning && (patient?.isOldPatient ?? false) ? '$type · Old patient' : type);
  return [
    Fact('Phone', patient?.contactNo),
    Fact('WhatsApp', otherNumber(patient?.contactNo, patient?.whatsappNo)),
    Fact('City', patient?.location?.city),
    if (occupation) Fact('Occupation', patient?.occupation),
    Fact('Visit Type', visit),
    if (visitDate) Fact('Visit Date', formatDateString(patient?.appointmentDate, fallback: '')),
    if (consultingDoctor) Fact('Consulting Doctor', doctorDisplayName(patient?.doctor?.name)),
    if (caseType) Fact('Case', patient?.caseType?.caseType),
    if (fee) Fact('Fee', patient?.caseFee == null ? null : money(patient!.caseFee)),
    if (referrer) Fact('Referred By', patient?.referrer?.name),
    Fact('Registered By', patient?.receptionistName),
    if (registeredAt) Fact('Registered', patient?.createdAt == null ? null : toDisplayDateTime(patient!.createdAt!)),
  ];
}
