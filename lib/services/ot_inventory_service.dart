import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/ot_inventory_models.dart';
import 'base_service.dart';

/// Round 3 Phase 7 — `OtInventoryApiController`: Lens Inventory / Lens
/// Power / Package masters (all gated by `master.ot_inventory`), plus the
/// lens-inventory typeahead search used by Phase 1/4 pickers.
class OtInventoryService with AuthenticatedService {
  OtInventoryService._();
  static final OtInventoryService instance = OtInventoryService._();

  String get _base => AppConfig.hospitalApiUrl;

  Map<String, dynamic> _parse(http.Response res) => parseApiResponse(res);

  // ── Lens Inventory ────────────────────────────────────────────────────

  Future<List<LensInventoryItem>> fetchLensInventory() async {
    final res = await http.get(Uri.parse('$_base/masters/ot/lens-inventory'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as List? ?? []).map((e) => LensInventoryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<LensInventoryItem> createLensInventory(LensInventoryItem item) async {
    final res = await http
        .post(Uri.parse('$_base/masters/ot/lens-inventory'), headers: await headers, body: jsonEncode(item.toJson()))
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return LensInventoryItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<LensInventoryItem> updateLensInventory(int id, LensInventoryItem item) async {
    final res = await http
        .put(Uri.parse('$_base/masters/ot/lens-inventory/$id'), headers: await headers, body: jsonEncode(item.toJson()))
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return LensInventoryItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> deleteLensInventory(int id) async {
    final res = await http.delete(Uri.parse('$_base/masters/ot/lens-inventory/$id'), headers: await headers).timeout(AppConfig.requestTimeout);
    _parse(res);
  }

  /// Typeahead used by Phase 1 (counselling) & Phase 4 (lens form) pickers.
  Future<List<LensInventoryItem>> searchLensInventory({String? q, String? type, String? power, bool includeOutOfStock = false}) async {
    final qp = <String, String>{
      if (q != null && q.isNotEmpty) 'q': q,
      if (type != null && type.isNotEmpty) 'type': type,
      if (power != null && power.isNotEmpty) 'power': power,
      if (includeOutOfStock) 'include_out_of_stock': '1',
    };
    final uri = Uri.parse('$_base/ot/lens-inventory/search').replace(queryParameters: qp.isEmpty ? null : qp);
    final res = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as List? ?? []).map((e) => LensInventoryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Lens Powers ───────────────────────────────────────────────────────

  Future<List<LensPowerItem>> fetchLensPowers() async {
    final res = await http.get(Uri.parse('$_base/masters/ot/lens-powers'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as List? ?? []).map((e) => LensPowerItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<LensPowerItem> createLensPower(String value, bool isFavourite) async {
    final res = await http
        .post(Uri.parse('$_base/masters/ot/lens-powers'), headers: await headers, body: jsonEncode({'value': value, 'is_favourite': isFavourite}))
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return LensPowerItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<LensPowerItem> updateLensPower(int id, String value, bool isFavourite) async {
    final res = await http
        .put(Uri.parse('$_base/masters/ot/lens-powers/$id'), headers: await headers, body: jsonEncode({'value': value, 'is_favourite': isFavourite}))
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return LensPowerItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> deleteLensPower(int id) async {
    final res = await http.delete(Uri.parse('$_base/masters/ot/lens-powers/$id'), headers: await headers).timeout(AppConfig.requestTimeout);
    _parse(res);
  }

  // ── Packages ──────────────────────────────────────────────────────────

  Future<List<OtPackageMasterItem>> fetchPackages() async {
    final res = await http.get(Uri.parse('$_base/masters/ot/packages'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as List? ?? []).map((e) => OtPackageMasterItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  // `lens_cost` is deliberately NOT sent — web pull 2026-08-07 dropped it as
  // a real package field entirely (always 0 server-side now; lens cost is
  // typed manually on the Counsellor form instead). See
  // WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §3.
  Map<String, dynamic> _packageBody({
    required String packageName,
    required String roomCategory,
    required double otCharges,
    required double surgeonCharges,
    required double nursingCharges,
    required double consumablesCharges,
  }) => {
        'package_name': packageName,
        'room_category': roomCategory,
        'ot_charges': otCharges,
        'surgeon_charges': surgeonCharges,
        'nursing_charges': nursingCharges,
        'consumables_charges': consumablesCharges,
      };

  Future<OtPackageMasterItem> createPackage({
    required String packageName,
    required String roomCategory,
    required double otCharges,
    required double surgeonCharges,
    required double nursingCharges,
    required double consumablesCharges,
  }) async {
    final res = await http
        .post(Uri.parse('$_base/masters/ot/packages'),
            headers: await headers,
            body: jsonEncode(_packageBody(
                packageName: packageName, roomCategory: roomCategory,
                otCharges: otCharges, surgeonCharges: surgeonCharges, nursingCharges: nursingCharges, consumablesCharges: consumablesCharges)))
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtPackageMasterItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<OtPackageMasterItem> updatePackage(int id, {
    required String packageName,
    required String roomCategory,
    required double otCharges,
    required double surgeonCharges,
    required double nursingCharges,
    required double consumablesCharges,
  }) async {
    final res = await http
        .put(Uri.parse('$_base/masters/ot/packages/$id'),
            headers: await headers,
            body: jsonEncode(_packageBody(
                packageName: packageName, roomCategory: roomCategory,
                otCharges: otCharges, surgeonCharges: surgeonCharges, nursingCharges: nursingCharges, consumablesCharges: consumablesCharges)))
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtPackageMasterItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> deletePackage(int id) async {
    final res = await http.delete(Uri.parse('$_base/masters/ot/packages/$id'), headers: await headers).timeout(AppConfig.requestTimeout);
    _parse(res);
  }
}
