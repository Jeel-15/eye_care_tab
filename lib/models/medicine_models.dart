// ── Generic master item (dosages, types, categories, routes, diagnoses) ──────

import '../utils/json_parse.dart';

class MedMasterItem {
  final int id;
  final String name;

  const MedMasterItem({required this.id, required this.name});

  factory MedMasterItem.fromJson(Map<String, dynamic> j, {String field = 'name'}) =>
      MedMasterItem(id: jsonInt(j['id']), name: (j[field] ?? j['name'] ?? '-') as String);

  @override
  bool operator ==(Object other) => other is MedMasterItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ── Pagination meta (shared) ──────────────────────────────────────────────────

class MedMeta {
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;

  const MedMeta({
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.perPage,
  });

  factory MedMeta.fromJson(Map<String, dynamic> j) => MedMeta(
        currentPage: jsonInt(j['current_page'], fallback: 1),
        lastPage: jsonInt(j['last_page'], fallback: 1),
        total: jsonInt(j['total'], fallback: 0),
        perPage: jsonInt(j['per_page'], fallback: 25),
      );

  bool get hasPrev => currentPage > 1;
  bool get hasNext => currentPage < lastPage;
}

// ── Medicine ──────────────────────────────────────────────────────────────────

class MedItem {
  final int id;
  final String name;
  // Web's exam-page medicine picker matches on brand name too (that's what's
  // printed on the box, and what's often searched by) — see
  // secondary.blade.php's client-side filter over `$medicinesForJs`.
  final String? brandName;
  // opd | ot — new field, web pull 2026-08-07. Distinct from
  // MedicineGroup.usageScope (which has a 3rd 'both' value) — this one is
  // per-Medicine and only ever opd/ot. See
  // WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §10.
  final String usageScope;
  final int? medicineTypeId;
  final String? medicineTypeName;
  final int? dosageId;
  final String? dosageText;
  final String? duration;
  final String? qty;
  final String? company;
  final String? composition;
  final double? price;

  const MedItem({
    required this.id,
    required this.name,
    this.brandName,
    this.usageScope = 'opd',
    this.medicineTypeId,
    this.medicineTypeName,
    this.dosageId,
    this.dosageText,
    this.duration,
    this.qty,
    this.company,
    this.composition,
    this.price,
  });

  factory MedItem.fromJson(Map<String, dynamic> j) => MedItem(
        id: jsonInt(j['id']),
        name: j['name'] as String? ?? '-',
        brandName: j['brand_name'] as String?,
        usageScope: j['usage_scope'] as String? ?? 'opd',
        medicineTypeId: jsonIntOrNull(j['medicine_type_id']),
        medicineTypeName: (j['medicine_type'] as Map<String, dynamic>?)?['name'] as String?,
        dosageId: jsonIntOrNull(j['dosage_id']),
        dosageText: (j['dosage'] as Map<String, dynamic>?)?['dosage'] as String?,
        duration: j['duration'] as String?,
        qty: j['qty'] as String?,
        company: j['company'] as String?,
        composition: j['composition'] as String?,
        price: jsonDoubleOrNull(j['price']),
      );
}

class MedListResult {
  final List<MedItem> items;
  final MedMeta meta;
  final List<MedMasterItem> types;
  final List<MedMasterItem> dosages;

  const MedListResult({
    required this.items,
    required this.meta,
    required this.types,
    required this.dosages,
  });

  factory MedListResult.fromJson(Map<String, dynamic> j) {
    final fd = j['form_data'] as Map<String, dynamic>? ?? {};
    return MedListResult(
      items: (j['data'] as List? ?? [])
          .map((e) => MedItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: MedMeta.fromJson(j['meta'] as Map<String, dynamic>? ?? {}),
      types: (fd['types'] as List? ?? [])
          .map((e) => MedMasterItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      dosages: (fd['dosages'] as List? ?? [])
          .map((e) => MedMasterItem.fromJson(e as Map<String, dynamic>, field: 'dosage'))
          .toList(),
    );
  }
}

// ── Medicine Group ────────────────────────────────────────────────────────────

/// Result of a CSV/Excel bulk medicine import — mirrors web's plain-language
/// summary + per-row error list (see CSV_MEDICINE_IMPORT_PARITY_PLAN.md).
class MedicineImportResult {
  final int imported;
  final int skipped;
  final List<String> errors;

  const MedicineImportResult({
    required this.imported,
    required this.skipped,
    required this.errors,
  });

  factory MedicineImportResult.fromJson(Map<String, dynamic> j) => MedicineImportResult(
        imported: jsonInt(j['imported']),
        skipped: jsonInt(j['skipped']),
        errors: (j['errors'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

class MedGroupItem {
  final int? medicineId;
  final String? medicineName;
  final int? dosageId;
  final String? dosageText;
  final int? routeId;
  final String? routeName;
  final String? frequency;
  final String? duration;
  final int quantity;

  const MedGroupItem({
    this.medicineId,
    this.medicineName,
    this.dosageId,
    this.dosageText,
    this.routeId,
    this.routeName,
    this.frequency,
    this.duration,
    required this.quantity,
  });

  factory MedGroupItem.fromJson(Map<String, dynamic> j) => MedGroupItem(
        medicineId: jsonIntOrNull(j['medicine_id']),
        medicineName: (j['medicine'] as Map<String, dynamic>?)?['name'] as String?,
        dosageId: jsonIntOrNull(j['dosage_id']),
        dosageText: (j['dosage'] as Map<String, dynamic>?)?['dosage'] as String?,
        routeId: jsonIntOrNull(j['route_id']),
        routeName: (j['route'] as Map<String, dynamic>?)?['name'] as String?,
        frequency: j['frequency'] as String?,
        duration: j['duration'] as String?,
        quantity: jsonInt(j['quantity'], fallback: 1),
      );

  /// OT ward-medicine quick-fill dose text — mirrors web's
  /// `trim($item->frequency . ' ' . $item->duration)` exactly (was previously
  /// just `dosageText`, which drops both fields). See
  /// OT_SURGERY_RECORD_WEB_PARITY_FIX_PLAN.md TASK 2.1.
  String get quickFillDose => [frequency, duration].where((s) => s != null && s.isNotEmpty).join(' ').trim();
}

class MedGroup {
  final int id;
  final String name;
  final String? groupCode;
  final int? diagnosisId;
  final String? diagnosisValue;
  final String? usageScope;
  final int itemsCount;
  final List<MedGroupItem> items;

  const MedGroup({
    required this.id,
    required this.name,
    this.groupCode,
    this.diagnosisId,
    this.diagnosisValue,
    this.usageScope,
    required this.itemsCount,
    required this.items,
  });

  factory MedGroup.fromJson(Map<String, dynamic> j) => MedGroup(
        id: jsonInt(j['id']),
        name: j['name'] as String? ?? '-',
        groupCode: j['group_code'] as String?,
        diagnosisId: jsonIntOrNull(j['diagnosis_id']),
        diagnosisValue: (j['diagnosis'] as Map<String, dynamic>?)?['value'] as String?,
        usageScope: j['usage_scope'] as String?,
        itemsCount: jsonInt(j['items_count']),
        items: (j['items'] as List? ?? [])
            .map((e) => MedGroupItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class MedGroupListResult {
  final List<MedGroup> groups;
  final MedMeta meta;

  const MedGroupListResult({required this.groups, required this.meta});

  factory MedGroupListResult.fromJson(Map<String, dynamic> j) => MedGroupListResult(
        groups: (j['data'] as List? ?? [])
            .map((e) => MedGroup.fromJson(e as Map<String, dynamic>))
            .toList(),
        meta: MedMeta.fromJson(j['meta'] as Map<String, dynamic>? ?? {}),
      );
}

// ── Group form data ───────────────────────────────────────────────────────────

class MedGroupFormData {
  final List<MedMasterItem> medicines;
  final List<MedMasterItem> dosages;
  final List<MedMasterItem> routes;
  final List<MedMasterItem> diagnoses;

  // Quick lookup for auto-fill when a medicine is selected in the repeater
  final Map<int, MedAutoFill> autoFillMap;

  const MedGroupFormData({
    required this.medicines,
    required this.dosages,
    required this.routes,
    required this.diagnoses,
    required this.autoFillMap,
  });

  factory MedGroupFormData.fromJson(Map<String, dynamic> j) {
    final rawMeds = j['medicines'] as List? ?? [];
    final autoFillMap = <int, MedAutoFill>{};
    final medicines = <MedMasterItem>[];
    for (final e in rawMeds) {
      final m = e as Map<String, dynamic>;
      final id = jsonInt(m['id']);
      medicines.add(MedMasterItem(id: id, name: m['name'] as String? ?? '-'));
      autoFillMap[id] = MedAutoFill(
        dosageId: jsonIntOrNull(m['dosage_id']),
        duration: m['duration'] as String?,
        qty: m['qty'] as String?,
      );
    }
    return MedGroupFormData(
      medicines: medicines,
      dosages: (j['dosages'] as List? ?? [])
          .map((e) => MedMasterItem.fromJson(e as Map<String, dynamic>, field: 'dosage'))
          .toList(),
      routes: (j['routes'] as List? ?? [])
          .map((e) => MedMasterItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      diagnoses: (j['diagnoses'] as List? ?? [])
          .map((e) => MedMasterItem.fromJson(e as Map<String, dynamic>, field: 'value'))
          .toList(),
      autoFillMap: autoFillMap,
    );
  }

  MedAutoFill? autoFillFor(int medicineId) => autoFillMap[medicineId];
}

class MedAutoFill {
  final int? dosageId;
  final String? duration;
  final String? qty;
  const MedAutoFill({this.dosageId, this.duration, this.qty});
}

// ── Group repeater row (form state) ──────────────────────────────────────────

class GroupItemRow {
  final int? medicineId;
  final int? dosageId;
  final int? routeId;
  final String duration;
  final int quantity;

  const GroupItemRow({
    this.medicineId,
    this.dosageId,
    this.routeId,
    this.duration = '',
    this.quantity = 1,
  });

  GroupItemRow copyWith({
    Object? medicineId = _s,
    Object? dosageId = _s,
    Object? routeId = _s,
    String? duration,
    int? quantity,
  }) =>
      GroupItemRow(
        medicineId: medicineId == _s ? this.medicineId : medicineId as int?,
        dosageId: dosageId == _s ? this.dosageId : dosageId as int?,
        routeId: routeId == _s ? this.routeId : routeId as int?,
        duration: duration ?? this.duration,
        quantity: quantity ?? this.quantity,
      );

  Map<String, dynamic> toJson() => {
        'medicine_id': medicineId,
        'dosage_id': dosageId,
        'route_id': routeId,
        'duration': duration.isEmpty ? null : duration,
        'quantity': quantity,
      };

  static const _s = Object();
}
