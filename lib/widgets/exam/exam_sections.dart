/// Clinical exam section IDs — order matches web STEP_ORDER
/// (primary.blade.php / secondary.blade.php).

enum ExamSection {
  co,
  kcoHo,
  vision,
  pg,
  st,
  nct,
  oe,
  fundus,
  dilate,
  diagnosis,
  medicine,
  advice,
  surgery,
}

extension ExamSectionX on ExamSection {
  String get id => name;

  String get shortLabel {
    switch (this) {
      case ExamSection.co:
        return 'C/O';
      case ExamSection.kcoHo:
        return 'K/C/O & H/O';
      case ExamSection.vision:
        return 'Vision';
      case ExamSection.pg:
        return 'PG';
      case ExamSection.st:
        return 'ST';
      case ExamSection.nct:
        return 'NCT';
      case ExamSection.oe:
        return 'O/E';
      case ExamSection.fundus:
        return 'Fundus';
      case ExamSection.dilate:
        return 'Dilate';
      case ExamSection.diagnosis:
        return 'Diagnosis';
      case ExamSection.medicine:
        return 'Medicine';
      case ExamSection.advice:
        return 'Advice';
      case ExamSection.surgery:
        return 'Surgery';
    }
  }

}

/// Primary exam steps (ends at Dilate — web parity).
const List<ExamSection> kPrimaryExamSections = [
  ExamSection.co,
  ExamSection.kcoHo,
  ExamSection.vision,
  ExamSection.pg,
  ExamSection.st,
  ExamSection.nct,
  ExamSection.oe,
  ExamSection.fundus,
  ExamSection.dilate,
];

/// Primary page on web also shows Diagnosis, Medicine and Advice.
const List<ExamSection> kPrimaryPageSections = [
  ...kPrimaryExamSections,
  ExamSection.diagnosis,
  ExamSection.medicine,
  ExamSection.advice,
];

/// Secondary = primary clinical steps + Dx / Rx / Advice.
const List<ExamSection> kSecondaryExamSections = [
  ...kPrimaryExamSections,
  ExamSection.diagnosis,
  ExamSection.medicine,
  ExamSection.advice,
];

/// Secondary steps for the current user — the 13th "Recommend Surgery" step
/// only exists for users allowed to recommend surgery (`ot_surgery_recommend`),
/// so it sits in the normal flow instead of only behind a small app-bar icon
/// that was easy to miss.
List<ExamSection> secondaryExamSectionsFor({required bool canRecommendSurgery}) =>
    canRecommendSurgery ? [...kSecondaryExamSections, ExamSection.surgery] : kSecondaryExamSections;

ExamSection? nextExamSection(ExamSection current, List<ExamSection> order) {
  final i = order.indexOf(current);
  if (i < 0 || i + 1 >= order.length) return null;
  return order[i + 1];
}
