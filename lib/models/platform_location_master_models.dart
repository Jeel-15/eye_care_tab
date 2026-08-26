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
        id: json['id'] as int,
        name: json['name'] as String,
        defaultTimezone: (json['default_timezone'] ?? '') as String,
        isActive: json['is_active'] == true || json['is_active'] == 1,
        statesCount: (json['states_count'] as num?)?.toInt() ?? 0,
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
        id: json['id'] as int,
        countryId: (json['country_id'] as num).toInt(),
        name: json['name'] as String,
        countryName: json['country_name'] as String?,
        isActive: json['is_active'] == true || json['is_active'] == 1,
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
        id: json['id'] as int,
        stateId: (json['state_id'] as num).toInt(),
        name: json['name'] as String,
        stateName: json['state_name'] as String?,
        isActive: json['is_active'] == true || json['is_active'] == 1,
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
        id: json['id'] as int,
        stateId: (json['state_id'] as num).toInt(),
        districtId: json['district_id'] != null ? (json['district_id'] as num).toInt() : null,
        name: json['name'] as String,
        stateName: json['state_name'] as String?,
        districtName: json['district_name'] as String?,
        isActive: json['is_active'] == true || json['is_active'] == 1,
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
