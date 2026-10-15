import '../utils/json_parse.dart';

class MasterDosage {
  final int id;
  final String dosage;
  final bool isActive;

  const MasterDosage({required this.id, required this.dosage, required this.isActive});

  factory MasterDosage.fromJson(Map<String, dynamic> json) => MasterDosage(
        id: jsonInt(json['id']),
        dosage: json['dosage'] as String,
        isActive: jsonBool(json['is_active']),
      );
}

class MasterMedicineType {
  final int id;
  final String name;
  final bool isActive;

  const MasterMedicineType({required this.id, required this.name, required this.isActive});

  factory MasterMedicineType.fromJson(Map<String, dynamic> json) => MasterMedicineType(
        id: jsonInt(json['id']),
        name: json['name'] as String,
        isActive: jsonBool(json['is_active']),
      );
}

class MasterMedicineCategory {
  final int id;
  final String name;
  final bool isActive;

  const MasterMedicineCategory({required this.id, required this.name, required this.isActive});

  factory MasterMedicineCategory.fromJson(Map<String, dynamic> json) => MasterMedicineCategory(
        id: jsonInt(json['id']),
        name: json['name'] as String,
        isActive: jsonBool(json['is_active']),
      );
}

class MasterMedicineRoute {
  final int id;
  final String name;
  final bool isActive;

  const MasterMedicineRoute({required this.id, required this.name, required this.isActive});

  factory MasterMedicineRoute.fromJson(Map<String, dynamic> json) => MasterMedicineRoute(
        id: jsonInt(json['id']),
        name: json['name'] as String,
        isActive: jsonBool(json['is_active']),
      );
}

class MasterMedicine {
  final int id;
  final String name;
  final int typeId;
  final String? typeName;
  final int dosageId;
  final String? dosageName;
  final String? duration;
  final String? qty;
  final String? composition;
  final String? company;
  final double? price;
  final bool isActive;

  const MasterMedicine({
    required this.id,
    required this.name,
    required this.typeId,
    this.typeName,
    required this.dosageId,
    this.dosageName,
    this.duration,
    this.qty,
    this.composition,
    this.company,
    this.price,
    required this.isActive,
  });

  factory MasterMedicine.fromJson(Map<String, dynamic> json) => MasterMedicine(
        id: jsonInt(json['id']),
        name: json['name'] as String,
        typeId: jsonInt(json['type_id']),
        typeName: json['type_name'] as String?,
        dosageId: jsonInt(json['dosage_id']),
        dosageName: json['dosage_name'] as String?,
        duration: json['duration'] as String?,
        qty: json['qty'] as String?,
        composition: json['composition'] as String?,
        company: json['company'] as String?,
        price: jsonDoubleOrNull(json['price']),
        isActive: jsonBool(json['is_active']),
      );
}

class MedicineFormData {
  final List<MasterMedicineType> types;
  final List<MasterDosage> dosages;

  const MedicineFormData({required this.types, required this.dosages});
}
