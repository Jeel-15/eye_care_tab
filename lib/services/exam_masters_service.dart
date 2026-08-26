import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'base_service.dart';
import 'cache_service.dart';

// ── ExamMasterItem ─────────────────────────────────────────────────────────────
// Represents one row from GET /masters/detail/{type}
// Response shape: { "id": 1, "value": "6/6", "is_favourite": true }

class ExamMasterItem {
  final int id;
  final String value;
  final bool isFavourite;

  const ExamMasterItem({
    required this.id,
    required this.value,
    required this.isFavourite,
  });

  factory ExamMasterItem.fromJson(Map<String, dynamic> j) => ExamMasterItem(
        id: (j['id'] as num).toInt(),
        value: (j['value'] as String?) ?? '',
        isFavourite: j['is_favourite'] == true,
      );

  Map<String, dynamic> toJson() => {'id': id, 'value': value, 'is_favourite': isFavourite};

  @override
  bool operator ==(Object other) => other is ExamMasterItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ── ExamMastersData ────────────────────────────────────────────────────────────
// Holds all 22 master lists needed by primary + secondary exam screens.

class ExamMastersData {
  // Vision tab
  final List<ExamMasterItem> vn;          // distance VN
  final List<ExamMasterItem> pnvn;        // pinhole VN
  final List<ExamMasterItem> nrvn;        // near VN
  final List<ExamMasterItem> nct;         // NCT / IOP

  // Refraction tab (PG / ST)
  final List<ExamMasterItem> sphCyl;      // SPH and CYL values
  final List<ExamMasterItem> axis;        // AXIS values

  // Findings tab — OE fields
  final List<ExamMasterItem> sac;
  final List<ExamMasterItem> lid;
  final List<ExamMasterItem> conj;
  final List<ExamMasterItem> cornea;
  final List<ExamMasterItem> ac;
  final List<ExamMasterItem> iris;
  final List<ExamMasterItem> pupil;
  final List<ExamMasterItem> lens;
  final List<ExamMasterItem> em;
  final List<ExamMasterItem> covertest;

  // Findings tab — Fundus
  final List<ExamMasterItem> disc;
  final List<ExamMasterItem> fr;

  // H & C/O tab
  final List<ExamMasterItem> chiefComplaints;
  final List<ExamMasterItem> kcos;
  final List<ExamMasterItem> hno;

  // Rx & Plan tab
  final List<ExamMasterItem> diagnoses;
  final List<ExamMasterItem> advices;

  const ExamMastersData({
    required this.vn,
    required this.pnvn,
    required this.nrvn,
    required this.nct,
    required this.sphCyl,
    required this.axis,
    required this.sac,
    required this.lid,
    required this.conj,
    required this.cornea,
    required this.ac,
    required this.iris,
    required this.pupil,
    required this.lens,
    required this.em,
    required this.covertest,
    required this.disc,
    required this.fr,
    required this.chiefComplaints,
    required this.kcos,
    required this.hno,
    required this.diagnoses,
    required this.advices,
  });

  /// Empty instance — used as a safe fallback when prewarm fails.
  factory ExamMastersData.empty() => const ExamMastersData(
    vn: [], pnvn: [], nrvn: [], nct: [], sphCyl: [], axis: [],
    sac: [], lid: [], conj: [], cornea: [], ac: [], iris: [],
    pupil: [], lens: [], em: [], covertest: [], disc: [], fr: [],
    chiefComplaints: [], kcos: [], hno: [], diagnoses: [], advices: [],
  );

  /// Returns the master list for a given OE field key.
  List<ExamMasterItem> oeListFor(String key) {
    switch (key) {
      // Vision acuity
      case 'vn':        return vn;
      case 'pnvn':      return pnvn;
      case 'nrvn':      return nrvn;
      // OE fields
      case 'sac':       return sac;
      case 'lid':       return lid;
      case 'conj':      return conj;
      case 'cornea':    return cornea;
      case 'ac':        return ac;
      case 'iris':      return iris;
      case 'pupil':     return pupil;
      case 'lens':      return lens;
      case 'em':        return em;
      case 'covertest': return covertest;
      // Fundus
      case 'disc':      return disc;
      case 'fr':        return fr;
      default:          return [];
    }
  }

  /// Favourites-first sort helper — used by bottom-sheet pickers.
  static List<ExamMasterItem> sortedFavFirst(List<ExamMasterItem> list) {
    final favs   = list.where((e) => e.isFavourite).toList();
    final others = list.where((e) => !e.isFavourite).toList();
    return [...favs, ...others];
  }

  bool get hasData => vn.isNotEmpty || pnvn.isNotEmpty || nrvn.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'vn': vn.map((e) => e.toJson()).toList(),
    'pnvn': pnvn.map((e) => e.toJson()).toList(),
    'nrvn': nrvn.map((e) => e.toJson()).toList(),
    'nct': nct.map((e) => e.toJson()).toList(),
    'sphCyl': sphCyl.map((e) => e.toJson()).toList(),
    'axis': axis.map((e) => e.toJson()).toList(),
    'sac': sac.map((e) => e.toJson()).toList(),
    'lid': lid.map((e) => e.toJson()).toList(),
    'conj': conj.map((e) => e.toJson()).toList(),
    'cornea': cornea.map((e) => e.toJson()).toList(),
    'ac': ac.map((e) => e.toJson()).toList(),
    'iris': iris.map((e) => e.toJson()).toList(),
    'pupil': pupil.map((e) => e.toJson()).toList(),
    'lens': lens.map((e) => e.toJson()).toList(),
    'em': em.map((e) => e.toJson()).toList(),
    'covertest': covertest.map((e) => e.toJson()).toList(),
    'disc': disc.map((e) => e.toJson()).toList(),
    'fr': fr.map((e) => e.toJson()).toList(),
    'chiefComplaints': chiefComplaints.map((e) => e.toJson()).toList(),
    'kcos': kcos.map((e) => e.toJson()).toList(),
    'hno': hno.map((e) => e.toJson()).toList(),
    'diagnoses': diagnoses.map((e) => e.toJson()).toList(),
    'advices':   advices.map((e) => e.toJson()).toList(),
  };

  static ExamMastersData fromDisk(Map<String, dynamic> j) {
    List<ExamMasterItem> parse(String key) =>
        ((j[key] as List?) ?? [])
            .map((e) => ExamMasterItem.fromJson(e as Map<String, dynamic>))
            .toList();
    return ExamMastersData(
      vn: parse('vn'), pnvn: parse('pnvn'), nrvn: parse('nrvn'),
      nct: parse('nct'), sphCyl: parse('sphCyl'), axis: parse('axis'),
      sac: parse('sac'), lid: parse('lid'), conj: parse('conj'),
      cornea: parse('cornea'), ac: parse('ac'), iris: parse('iris'),
      pupil: parse('pupil'), lens: parse('lens'), em: parse('em'),
      covertest: parse('covertest'), disc: parse('disc'), fr: parse('fr'),
      chiefComplaints: parse('chiefComplaints'), kcos: parse('kcos'),
      hno: parse('hno'), diagnoses: parse('diagnoses'),
      advices: parse('advices'),
    );
  }
}

// ── ExamMastersService ─────────────────────────────────────────────────────────
// Fetches all 22 master lists in one parallel Future.wait() call.
// Two-level cache: in-memory (30 min TTL) + SharedPreferences disk cache.
// Disk cache means dropdowns work even after cold starts / timeouts.

class ExamMastersService with AuthenticatedService {
  ExamMastersService._();
  static final ExamMastersService instance = ExamMastersService._();

  static const _diskKey = 'cache_exam_masters_v2';

  ExamMastersData? _cache;
  DateTime? _cachedAt;
  static const _cacheTtl = Duration(minutes: 30);

  bool get _isCacheValid =>
      _cache != null &&
      _cachedAt != null &&
      _cache!.hasData &&
      DateTime.now().difference(_cachedAt!) < _cacheTtl;

  Future<ExamMastersData?> _loadFromDisk() async {
    try {
      final raw = await CacheService.instance.getJson(_diskKey);
      if (raw == null) return null;
      return ExamMastersData.fromDisk(raw as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToDisk(ExamMastersData data) async {
    try {
      await CacheService.instance.setJson(_diskKey, data.toJson());
    } catch (_) {}
  }

  // ── Fetch a single master list ─────────────────────────────────────────────

  // Masters need a longer timeout — 22 calls fire in parallel on first open.
  static const _masterTimeout = Duration(seconds: 18);

  Future<List<ExamMasterItem>> _fetchMaster(String type) async {
    try {
      final uri = Uri.parse(
          '${AppConfig.hospitalApiUrl}/masters/detail/$type');
      final resp = await http
          .get(uri, headers: await headers)
          .timeout(_masterTimeout);

      if (resp.statusCode != 200) {
        debugPrint('[ExamMastersService] $type → HTTP ${resp.statusCode}');
        return [];
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = body['data'] as List? ?? [];
      return list
          .map((e) => ExamMasterItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ExamMastersService] $type ERROR: $e');
      return []; // graceful degradation — one failure doesn't break the screen
    }
  }

  // ── Fetch all 22 masters in parallel ──────────────────────────────────────

  Future<ExamMastersData> fetchAll({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid) {
      debugPrint('[ExamMastersService] Returning in-memory masters');
      return _cache!;
    }

    // Serve disk cache instantly while network fetch happens in background
    if (!forceRefresh) {
      final disk = await _loadFromDisk();
      if (disk != null && disk.hasData) {
        debugPrint('[ExamMastersService] Returning disk-cached masters, refreshing in background');
        _cache = disk;
        _cachedAt = DateTime.now();
        // Background refresh — don't await
        _refreshFromNetwork();
        return _cache!;
      }
    }

    debugPrint('[ExamMastersService] Fetching all 22 masters from network...');

    // All 22 type keys — order matches the list below
    const types = [
      'vn',              // 0
      'pnvn',            // 1
      'nrvn',            // 2
      'nct',             // 3
      'sph_cyl',         // 4
      'axis',            // 5
      'sac',             // 6
      'lid',             // 7
      'conj',            // 8
      'cornea',          // 9
      'ac',              // 10
      'iris',            // 11
      'pupil',           // 12
      'lens',            // 13
      'em',              // 14
      'covertest',       // 15
      'disc',            // 16
      'fr',              // 17
      'chief-complaints',// 18
      'kcos',            // 19
      'hno',             // 20
      'diagnoses',       // 21
      'advices',         // 22
    ];

    final results = await Future.wait(
      types.map((t) => _fetchMaster(t)),
    );

    // Sort purely numeric masters so display order matches clinical expectation
    // regardless of what string order the DB returns them in.
    List<ExamMasterItem> sortNum(List<ExamMasterItem> list) => [...list]
      ..sort((a, b) {
        final na = double.tryParse(a.value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        final nb = double.tryParse(b.value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        return na.compareTo(nb);
      });

    _cache = ExamMastersData(
      vn:              results[0],
      pnvn:            results[1],
      nrvn:            results[2],
      nct:             results[3],
      sphCyl:          sortNum(results[4]), // "10.00" must come after "9.75"
      axis:            sortNum(results[5]), // "100°" must come after "95°"
      sac:             results[6],
      lid:             results[7],
      conj:            results[8],
      cornea:          results[9],
      ac:              results[10],
      iris:            results[11],
      pupil:           results[12],
      lens:            results[13],
      em:              results[14],
      covertest:       results[15],
      disc:            results[16],
      fr:              results[17],
      chiefComplaints: results[18],
      kcos:            results[19],
      hno:             results[20],
      diagnoses:       results[21],
      advices:         results[22],
    );
    _cachedAt = DateTime.now();

    // Only persist to disk when we actually got real data (guards against cold-start timeouts)
    if (_cache!.hasData) {
      unawaited(_saveToDisk(_cache!));
    }

    debugPrint('[ExamMastersService] All masters loaded and cached.');
    return _cache!;
  }

  /// Background network refresh — updates in-memory + disk cache silently.
  Future<void> _refreshFromNetwork() async {
    try {
      await fetchAll(forceRefresh: true);
    } catch (e) {
      debugPrint('[ExamMastersService] background refresh error: $e');
    }
  }

  /// Whether the cache is currently valid (no network call needed).
  bool get isCacheValid => _isCacheValid;

  /// Fire-and-forget cache pre-warm. Call after login so the first exam
  /// screen opens instantly from cache.
  void prewarm() {
    if (_isCacheValid) return;
    fetchAll().catchError((Object e) {
      debugPrint('[ExamMastersService] prewarm error: $e');
      return ExamMastersData.empty();
    });
  }

  /// Clears both in-memory and disk cache (call after hospital settings change).
  void clearCache() {
    _cache = null;
    _cachedAt = null;
    CacheService.instance.remove(_diskKey);
  }
}