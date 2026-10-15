import '../utils/json_parse.dart';

class MasterCountry {
  final int id;
  final String name;
  final String defaultTimezone;
  final bool isActive;
  final int statesCount;

  const MasterCountry({
    required this.id,
    required this.name,
    required this.defaultTimezone,
    required this.isActive,
    required this.statesCount,
  });

  factory MasterCountry.fromJson(Map<String, dynamic> json) => MasterCountry(
        id: jsonInt(json['id']),
        name: json['name'] as String,
        defaultTimezone: (json['default_timezone'] ?? '') as String,
        isActive: jsonBool(json['is_active']),
        statesCount: jsonInt(json['states_count']),
      );
}

class MasterState {
  final int id;
  final int countryId;
  final String name;
  final String? countryName;
  final bool isActive;

  const MasterState({
    required this.id,
    required this.countryId,
    required this.name,
    this.countryName,
    required this.isActive,
  });

  factory MasterState.fromJson(Map<String, dynamic> json) => MasterState(
        id: jsonInt(json['id']),
        countryId: jsonInt(json['country_id']),
        name: json['name'] as String,
        countryName: json['country_name'] as String?,
        isActive: jsonBool(json['is_active']),
      );
}

class MasterDistrict {
  final int id;
  final int stateId;
  final String name;
  final String? stateName;
  final bool isActive;

  const MasterDistrict({
    required this.id,
    required this.stateId,
    required this.name,
    this.stateName,
    required this.isActive,
  });

  factory MasterDistrict.fromJson(Map<String, dynamic> json) => MasterDistrict(
        id: jsonInt(json['id']),
        stateId: jsonInt(json['state_id']),
        name: json['name'] as String,
        stateName: json['state_name'] as String?,
        isActive: jsonBool(json['is_active']),
      );
}

class MasterCity {
  final int id;
  final int stateId;
  final int? districtId;
  final String name;
  final String? stateName;
  final String? districtName;
  final bool isActive;

  const MasterCity({
    required this.id,
    required this.stateId,
    this.districtId,
    required this.name,
    this.stateName,
    this.districtName,
    required this.isActive,
  });

  factory MasterCity.fromJson(Map<String, dynamic> json) => MasterCity(
        id: jsonInt(json['id']),
        stateId: jsonInt(json['state_id']),
        districtId: jsonIntOrNull(json['district_id']),
        name: json['name'] as String,
        stateName: json['state_name'] as String?,
        districtName: json['district_name'] as String?,
        isActive: jsonBool(json['is_active']),
      );
}

class LocationDropdownData {
  final List<MasterCountry> countries;
  final List<MasterState> states;
  final List<MasterDistrict> districts;

  const LocationDropdownData({
    required this.countries,
    required this.states,
    required this.districts,
  });
}
