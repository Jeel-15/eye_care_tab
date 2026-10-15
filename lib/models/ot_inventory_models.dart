import '../utils/json_parse.dart';

/// Laravel's `decimal:N` model casts serialize to JSON as a STRING (e.g.
/// "1234.00"), not a number — every money/measurement field read from a raw
/// (un-mapped) Eloquent model response needs this instead of a bare
/// `as num?` cast. See OT_WEB_PARITY_FIX_PRD.md (decimal-cast gotcha).
/// Kept as a named alias so existing OT model imports keep working.
double? numOrStringToDouble(dynamic v) => jsonDoubleOrNull(v);

/// Fixed lens-type enum used across the OT module (lens inventory + the
/// Phase 4 lens-detail form) — replaces the old placeholder A/B enum.
/// See OT_WORKFLOW_UPGRADE_PRD.md §4 (`ot_lens_details`).
const kOtLensTypes = [
  'Accommodating',
  'Aspheric',
  'EDOF',
  'Monofocal',
  'Multifocal',
  'Spherical',
  'Toric',
  'Trifocal',
];

/// `lens_inventory` table (Round 3 Phase 7) — stock-tracked lens master.
class LensInventoryItem {
  final int id;
  final String lensCode;
  final String? manufacturer;
  final String lensName;
  final String type;
  final String? power;
  final String? batchNumber;
  final String? serialNumber;
  final double mrp;
  final double? purchaseCost;
  final String? supplier;
  final String? expiryDate;
  final int availableStock;

  const LensInventoryItem({
    required this.id,
    required this.lensCode,
    this.manufacturer,
    required this.lensName,
    required this.type,
    this.power,
    this.batchNumber,
    this.serialNumber,
    required this.mrp,
    this.purchaseCost,
    this.supplier,
    this.expiryDate,
    required this.availableStock,
  });

  factory LensInventoryItem.fromJson(Map<String, dynamic> j) => LensInventoryItem(
        id: jsonInt(j['id']),
        lensCode: j['lens_code'] as String? ?? '',
        manufacturer: j['manufacturer'] as String?,
        lensName: j['lens_name'] as String? ?? '',
        type: j['type'] as String? ?? '',
        power: j['power']?.toString(),
        batchNumber: j['batch_number'] as String?,
        serialNumber: j['serial_number'] as String?,
        mrp: jsonDoubleOrNull(j['mrp']) ?? 0,
        purchaseCost: jsonDoubleOrNull(j['purchase_cost']),
        supplier: j['supplier'] as String?,
        expiryDate: j['expiry_date'] as String?,
        availableStock: jsonInt(j['available_stock']),
      );

  Map<String, dynamic> toJson() => {
        'lens_code': lensCode,
        'manufacturer': manufacturer,
        'lens_name': lensName,
        'type': type,
        'power': power,
        'batch_number': batchNumber,
        'serial_number': serialNumber,
        'mrp': mrp,
        'purchase_cost': purchaseCost,
        'supplier': supplier,
        'expiry_date': expiryDate,
        'available_stock': availableStock,
      };
}

/// `ot_lens_powers` table — web field is `power` (numeric), not `value`.
/// List display on web: `+{power} D` (e.g. +10.50 D).
class LensPowerItem {
  final int id;
  final double power;
  final bool isFavourite;
  final bool isActive;

  const LensPowerItem({
    required this.id,
    required this.power,
    this.isFavourite = false,
    this.isActive = true,
  });

  /// Web list cell: `+10.50 D`
  String get displayLabel => '+${power.toStringAsFixed(2)} D';

  /// Prefill edit field with bare number (web modal uses raw `power`).
  String get editText =>
      power == power.roundToDouble() ? '${power.toInt()}' : power.toStringAsFixed(2);

  factory LensPowerItem.fromJson(Map<String, dynamic> j) {
    final raw = j['power'] ?? j['value'];
    final parsed = switch (raw) {
      num n => n.toDouble(),
      String s => double.tryParse(s.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0,
      _ => 0.0,
    };
    return LensPowerItem(
      id: jsonInt(j['id']),
      power: parsed,
      isFavourite: jsonBool(j['is_favourite']),
      isActive: jsonBool(j['is_active'], fallback: true),
    );
  }
}

/// `ot_package_masters` table (Round 3 Phase 7) — feeds Phase 1's
/// counselling package-lookup/package_cost_options.
class OtPackageMasterItem {
  final int id;
  final String packageName;
  final double? lensCost;
  final String roomCategory; // general | private
  final double otCharges;
  final double surgeonCharges;
  final double nursingCharges;
  final double consumablesCharges;
  // The Counselling form's package dropdown (`package_cost_options`) only
  // ever returns `is_active = true` rows (API: OtCounsellorApiController::
  // fetchCounsellingDetail()) — a package created without this field set
  // silently defaults to inactive server-side and never appears there.
  // Web's own Add-Package form has an "Active" checkbox that's checked by
  // default; this app's form never had one at all, so this field was
  // missing from the model too (unlike the sibling Lens Power/Lens Option
  // masters, which already track it the same way LensPowerItem does).
  final bool isActive;

  const OtPackageMasterItem({
    required this.id,
    required this.packageName,
    this.lensCost,
    required this.roomCategory,
    required this.otCharges,
    required this.surgeonCharges,
    required this.nursingCharges,
    required this.consumablesCharges,
    this.isActive = true,
  });

  double get totalPreview => (lensCost ?? 0) + otCharges + surgeonCharges + nursingCharges + consumablesCharges;

  factory OtPackageMasterItem.fromJson(Map<String, dynamic> j) => OtPackageMasterItem(
        id: jsonInt(j['id']),
        packageName: j['package_name'] as String? ?? '',
        lensCost: jsonDoubleOrNull(j['lens_cost']),
        roomCategory: j['room_category'] as String? ?? 'general',
        otCharges: jsonDoubleOrNull(j['ot_charges']) ?? 0,
        surgeonCharges: jsonDoubleOrNull(j['surgeon_charges']) ?? 0,
        nursingCharges: jsonDoubleOrNull(j['nursing_charges']) ?? 0,
        consumablesCharges: jsonDoubleOrNull(j['consumables_charges']) ?? 0,
        isActive: jsonBool(j['is_active'], fallback: true),
      );
}

/// `ot_lens_options` table — corrected-permission master (Round 3.5, was
/// reachable via the wrong `master.eye_exam`-gated generic route before).
class OtLensOptionItem {
  final int id;
  final String name;
  final bool isActive;

  const OtLensOptionItem({required this.id, required this.name, this.isActive = true});

  factory OtLensOptionItem.fromJson(Map<String, dynamic> j) => OtLensOptionItem(
        id: jsonInt(j['id']),
        name: j['name'] as String? ?? '',
        isActive: jsonBool(j['is_active'], fallback: true),
      );
}

/// `ot_types` table via the dedicated `/masters/ot-type` route (Round 3.5
/// correction — same table `OtSurgeryTypeService.fetchOtTypes()` already
/// reads read-only; this is the actual CRUD-management screen for it).
class OtTypeMasterItem {
  final int id;
  final String name;

  const OtTypeMasterItem({required this.id, required this.name});

  factory OtTypeMasterItem.fromJson(Map<String, dynamic> j) => OtTypeMasterItem(
        id: jsonInt(j['id']),
        name: j['name'] as String? ?? '',
      );
}
