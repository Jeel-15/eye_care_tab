import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../utils/json_parse.dart';
import 'base_service.dart';
import 'exam_masters_service.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

/// A diagnosis linked to an Advice master item — web's Advice master (only)
/// links to one or more diagnoses ("Link by Diagnosis"); see
/// DetailMasterController::isAdviceType() + masters/dynamic_index.blade.php's
/// "Diagnosis" multi-select.
class SimpleMasterDiagnosisRef {
  final int id;
  final String value;
  const SimpleMasterDiagnosisRef({required this.id, required this.value});

  factory SimpleMasterDiagnosisRef.fromJson(Map<String, dynamic> j) =>
      SimpleMasterDiagnosisRef(id: jsonInt(j['id']), value: j['value'] as String? ?? '');
}

class SimpleMasterItem {
  final int id;
  final String value;
  final bool isFavourite;
  final bool isSeeded;
  final List<SimpleMasterDiagnosisRef> diagnoses;

  const SimpleMasterItem({
    required this.id,
    required this.value,
    this.isFavourite = false,
    this.isSeeded = false,
    this.diagnoses = const [],
  });

  factory SimpleMasterItem.fromJson(Map<String, dynamic> j) => SimpleMasterItem(
        id: jsonInt(j['id']),
        value: j['value'] as String? ?? '',
        isFavourite: jsonBool(j['is_favourite']),
        isSeeded: jsonBool(j['is_seeded']),
        diagnoses: (j['diagnoses'] as List? ?? [])
            .map((e) => SimpleMasterDiagnosisRef.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  SimpleMasterItem copyWith({String? value, bool? isFavourite}) => SimpleMasterItem(
        id: id,
        value: value ?? this.value,
        isFavourite: isFavourite ?? this.isFavourite,
        isSeeded: isSeeded,
        diagnoses: diagnoses,
      );
}

// ── Service ───────────────────────────────────────────────────────────────────

class SimpleMasterService with AuthenticatedService {
  SimpleMasterService._();
  static final SimpleMasterService instance = SimpleMasterService._();

  String get _base => AppConfig.hospitalApiUrl;


  Map<String, dynamic> _parse(http.Response res) => parseApiResponse(res);

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// [apiPath] — e.g. 'masters/detail/complaints'
  Future<List<SimpleMasterItem>> fetchAll(String apiPath) async {
    final res = await http
        .get(Uri.parse('$_base/$apiPath'), headers: await headers)
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as List? ?? [])
        .map((e) => SimpleMasterItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SimpleMasterItem> create(
    String apiPath,
    String value, {
    bool isFavourite = false,
    List<int>? diagnosisIds,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_base/$apiPath'),
          headers: await headers,
          body: jsonEncode({
            'value': value,
            'is_favourite': isFavourite,
            'diagnosis_ids': ?diagnosisIds,
          }),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    // Every exam-facing "simple master" screen (Diagnosis/Advice/Complaints/
    // K-C-O/History/Fundus Disc-FR/O.E. options...) shares this one service
    // — none of them invalidated ExamMastersService's cache after their own
    // CRUD, so a newly added/edited item kept missing from Primary/Secondary
    // Exam's dropdowns for the rest of the app session (that cache only
    // refetches on its own 30-min TTL or when fully empty), fixed only by a
    // full app restart. Clearing here covers every one of those screens at
    // once instead of patching each individually.
    ExamMastersService.instance.clearCache();
    return SimpleMasterItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<SimpleMasterItem> update(
    String apiPath,
    int id,
    String value, {
    bool isFavourite = false,
    List<int>? diagnosisIds,
  }) async {
    final res = await http
        .put(
          Uri.parse('$_base/$apiPath/$id'),
          headers: await headers,
          body: jsonEncode({
            'value': value,
            'is_favourite': isFavourite,
            'diagnosis_ids': ?diagnosisIds,
          }),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    ExamMastersService.instance.clearCache();
    return SimpleMasterItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String apiPath, int id) async {
    final res = await http
        .delete(Uri.parse('$_base/$apiPath/$id'), headers: await headers)
        .timeout(AppConfig.requestTimeout);
    _parse(res);
    ExamMastersService.instance.clearCache();
  }

  Future<bool> toggleFavourite(String apiPath, int id) async {
    final res = await http
        .post(
          Uri.parse('$_base/$apiPath/$id/toggle-favourite'),
          headers: await headers,
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    ExamMastersService.instance.clearCache();
    return jsonBool((body['data'] as Map<String, dynamic>?)?['is_favourite']);
  }
}
