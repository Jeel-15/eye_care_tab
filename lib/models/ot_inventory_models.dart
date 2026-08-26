/// Laravel's `decimal:N` model casts serialize to JSON as a STRING (e.g.
/// "1234.00"), not a number — every money/measurement field read from a raw
/// (un-mapped) Eloquent model response needs this instead of a bare
/// `as num?` cast. See OT_WEB_PARITY_FIX_PRD.md (decimal-cast gotcha).
double? numOrStringToDouble(dynamic v) => switch (v) { num n => n.toDouble(), String s => double.tryParse(s), _ => null };

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
        id: j['id'] as int,
        lensCode: j['lens_code'] as String? ?? '',
        manufacturer: j['manufacturer'] as String?,
        lensName: j['lens_name'] as String? ?? '',
        type: j['type'] as String? ?? '',
        power: j['power']?.toString(),
        batchNumber: j['batch_number'] as String?,
        serialNumber: j['serial_number'] as String?,
        mrp: numOrStringToDouble(j['mrp']) ?? 0,
        purchaseCost: numOrStringToDouble(j['purchase_cost']),
        supplier: j['supplier'] as String?,
        expiryDate: j['expiry_date'] as String?,
        availableStock: j['available_stock'] as int? ?? 0,
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

/// `ot_lens_powers` table (Round 3 Phase 7) — "master + favourite" pattern,
/// same shape as the existing eye-exam masters (`ExamMasterItem`).
class LensPowerItem {
  final int id;
  final String value;
  final bool isFavourite;

  const LensPowerItem({required this.id, required this.value, this.isFavourite = false});

  factory LensPowerItem.fromJson(Map<String, dynamic> j) => LensPowerItem(
        id: j['id'] as int,
        value: j['value'] as String? ?? '',
        isFavourite: j['is_favourite'] as bool? ?? false,
      );
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

  const OtPackageMasterItem({
    required this.id,
    required this.packageName,
    this.lensCost,
    required this.roomCategory,
    required this.otCharges,
    required this.surgeonCharges,
    required this.nursingCharges,
    required this.consumablesCharges,
  });

  double get totalPreview => (lensCost ?? 0) + otCharges + surgeonCharges + nursingCharges + consumablesCharges;

  factory OtPackageMasterItem.fromJson(Map<String, dynamic> j) => OtPackageMasterItem(
        id: j['id'] as int,
        packageName: j['package_name'] as String? ?? '',
        lensCost: numOrStringToDouble(j['lens_cost']),
        roomCategory: j['room_category'] as String? ?? 'general',
        otCharges: numOrStringToDouble(j['ot_charges']) ?? 0,
        surgeonCharges: numOrStringToDouble(j['surgeon_charges']) ?? 0,
        nursingCharges: numOrStringToDouble(j['nursing_charges']) ?? 0,
        consumablesCharges: numOrStringToDouble(j['consumables_charges']) ?? 0,
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
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        isActive: j['is_active'] as bool? ?? true,
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
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
      );
}
