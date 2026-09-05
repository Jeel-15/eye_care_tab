import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/auth_models.dart';
import '../models/medicine_models.dart';
import '../models/patient_models.dart';
import '../services/exam_masters_service.dart';
import '../services/exam_service.dart';
import '../services/referrer_service.dart';
import '../services/simple_master_service.dart';
import '../constants/permissions.dart';
import '../services/permission_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/exam/exam_field_widgets.dart';
import '../widgets/ot/recommend_surgery_dialog.dart';
import '../widgets/skeleton.dart';

class _CoRow {
  final TextEditingController complaintCtrl;
  String since, unit, eye, comment;
  _CoRow({String complaint = '', this.since = '-', this.unit = 'Days', this.eye = '-', this.comment = ''}) : complaintCtrl = TextEditingController(text: complaint);
  void dispose() => complaintCtrl.dispose();
  Map<String, dynamic> toJson() => {'complaint': complaintCtrl.text, 'since': since == '-' ? '' : since, 'unit': unit, 'eye': eye == '-' ? '' : eye, 'comment': comment};
}

class _KcoRow {
  final TextEditingController conditionCtrl;
  String since, unit, comment;
  _KcoRow({String condition = '', this.since = '-', this.unit = 'Years', this.comment = ''}) : conditionCtrl = TextEditingController(text: condition);
  void dispose() => conditionCtrl.dispose();
  Map<String, dynamic> toJson() => {'condition': conditionCtrl.text, 'since': since == '-' ? '' : since, 'unit': unit, 'comment': comment};
}

class _PrescRow {
  int? medicineId;
  String medicineName;
  int? dosageId, routeId;
  String duration;
  int quantity;
  _PrescRow({this.medicineId, this.medicineName = '', this.dosageId, this.routeId, this.duration = '', this.quantity = 1});
  Map<String, dynamic> toJson() => {if (medicineId != null) 'medicine_id': medicineId, if (medicineName.isNotEmpty) 'name': medicineName, if (dosageId != null) 'dosage_id': dosageId, if (routeId != null) 'route_id': routeId, 'duration': duration.isEmpty ? null : duration, 'quantity': quantity};
}

/// Tablet Secondary Exam — extends Primary Exam's sections (reusing the
/// same widgets/exam/* pickers) with Diagnosis, Medicine (Rx) and Advice.
/// Business logic ported from
/// eye_care_app/lib/screens/secondary_exam_screen.dart. See
/// EXAMINATIONS_MODULE_PRD.md for the shared data model, the primary-exam
/// prefill-fallback rule (§4), and locked decisions (§8): per-section Save
/// buttons, anchored-popover pickers.
class SecondaryExamScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;
  final Patient patient;
  const SecondaryExamScreen({super.key, required this.user, required this.hospital, required this.patient});

  @override
  State<SecondaryExamScreen> createState() => _SecondaryExamScreenState();
}

class _SecondaryExamScreenState extends State<SecondaryExamScreen> {
  bool _loading = true;
  String? _loadError;
  bool _anySaved = false;
  String _prefillSource = 'none'; // 'none' | 'primary' | 'secondary'
  int? _selectedDoctorId;
  ExamFormData? _formData;

  final Map<String, bool> _saving = {};
  final Map<String, bool> _saved = {};

  final List<String> _historyChips = [];
  final List<_CoRow> _coRows = [];
  final List<_KcoRow> _kcoRows = [];

  final _vnRe = TextEditingController(), _vnLe = TextEditingController();
  final _pnvnRe = TextEditingController(), _pnvnLe = TextEditingController();
  final _nrvnRe = TextEditingController(), _nrvnLe = TextEditingController();
  final _nctIopRe = TextEditingController(), _nctIopLe = TextEditingController();

  static const _pgDistKeys = ['ds', 'dc', 'ax', 'vn'];
  static const _pgNearKeys = ['ns', 'nc', 'na', 'near_vn'];
  late final Map<String, Map<String, TextEditingController>> _pg;

  static const _stDistKeys = ['ds', 'dc', 'ax', 'vn'];
  late final Map<String, Map<String, TextEditingController>> _st;
  final _stAddRe = TextEditingController(), _stAddLe = TextEditingController();
  final _stNsRe = TextEditingController(), _stNsLe = TextEditingController();
  bool _bifocal = false, _ndSeparate = false, _progressive = false, _computerUses = false;

  static const _oeFieldNames = ['sac', 'lid', 'conj', 'cornea', 'ac', 'iris', 'pupil', 'lens', 'em', 'covertest', 'other'];
  static const _oeLabels = {'sac': 'SAC', 'lid': 'Lid', 'conj': 'Conjunctiva', 'cornea': 'Cornea', 'ac': 'Ant. Chamber', 'iris': 'Iris', 'pupil': 'Pupil', 'lens': 'Lens', 'em': 'Ext. Mov.', 'covertest': 'Cover Test', 'other': 'Other'};
  late final Map<String, TextEditingController> _oeRe, _oeLe;
  Map<String, List<ExamMasterItem>> _oeMasters = {};
  static const _oeMasterApiType = {'sac': 'sac', 'lid': 'lid', 'conj': 'conj', 'cornea': 'cornea', 'ac': 'ac', 'iris': 'iris', 'pupil': 'pupil', 'lens': 'lens_master', 'em': 'em', 'covertest': 'covertest'};
  String _pseudoOpRe = 'Phaco', _pseudoOpLe = 'Phaco';
  final _pseudoExpRe = TextEditingController(), _pseudoExpLe = TextEditingController();
  final _pseudoHospRe = TextEditingController(), _pseudoHospLe = TextEditingController();
  List<ExamMasterItem> _referrers = [];

  final _fundusDiscRe = TextEditingController(), _fundusDiscLe = TextEditingController();
  final _fundusFrRe = TextEditingController(), _fundusFrLe = TextEditingController();
  final _fundusCommentRe = TextEditingController(), _fundusCommentLe = TextEditingController();
  List<ExamMasterItem> _fundusDiscMasters = [], _fundusFrMasters = [];

  String _dilate = 'No';
  final _dilationTimeCtrl = TextEditingController();

  // Secondary-only
  List<ExamMasterItem> _diagnosisMasters = [];
  List<ExamMasterItem> _adviceMasters = [];
  final Set<int> _selectedDiagnosisIds = {};
  String _diagnosisSearch = '';
  final _adviceCtrl = TextEditingController();
  final List<_PrescRow> _medicines = [];

  @override
  void initState() {
    super.initState();
    _pg = {'re': {for (final k in [..._pgDistKeys, ..._pgNearKeys]) k: TextEditingController()}, 'le': {for (final k in [..._pgDistKeys, ..._pgNearKeys]) k: TextEditingController()}};
    _st = {'re': {for (final k in _stDistKeys) k: TextEditingController()}, 'le': {for (final k in _stDistKeys) k: TextEditingController()}};
    _oeRe = {for (final f in _oeFieldNames) f: TextEditingController()};
    _oeLe = {for (final f in _oeFieldNames) f: TextEditingController()};
    _loadAll();
  }

  @override
  void dispose() {
    _vnRe.dispose(); _vnLe.dispose(); _pnvnRe.dispose(); _pnvnLe.dispose(); _nrvnRe.dispose(); _nrvnLe.dispose();
    _nctIopRe.dispose(); _nctIopLe.dispose();
    for (final e in _pg.values) { for (final c in e.values) { c.dispose(); } }
    for (final e in _st.values) { for (final c in e.values) { c.dispose(); } }
    _stAddRe.dispose(); _stAddLe.dispose(); _stNsRe.dispose(); _stNsLe.dispose();
    for (final c in _oeRe.values) { c.dispose(); }
    for (final c in _oeLe.values) { c.dispose(); }
    _pseudoExpRe.dispose(); _pseudoExpLe.dispose(); _pseudoHospRe.dispose(); _pseudoHospLe.dispose();
    _fundusDiscRe.dispose(); _fundusDiscLe.dispose(); _fundusFrRe.dispose(); _fundusFrLe.dispose();
    _fundusCommentRe.dispose(); _fundusCommentLe.dispose(); _dilationTimeCtrl.dispose();
    _adviceCtrl.dispose();
    for (final r in _coRows) { r.dispose(); }
    for (final r in _kcoRows) { r.dispose(); }
    super.dispose();
  }

  // ── Load / prefill ──────────────────────────────────────────────────

  Future<void> _loadAll() async {
    final cacheHit = ExamMastersService.instance.isCacheValid;
    if (!cacheHit) setState(() { _loading = true; _loadError = null; });
    try {
      final formData = await ExamService.instance.loadFormData();
      final secondary = await ExamService.instance.loadSecondaryExam(widget.patient.id);
      final primary = secondary == null ? await ExamService.instance.loadPrimaryExam(widget.patient.id) : null;
      final referrers = await ReferrerService.instance.fetchAll();
      if (!mounted) return;
      setState(() {
        _formData = formData;
        _oeMasters = {for (final f in _oeMasterApiType.keys) f: List<ExamMasterItem>.from(formData.masters.oeListFor(f))};
        _fundusDiscMasters = List<ExamMasterItem>.from(formData.masters.disc);
        _fundusFrMasters = List<ExamMasterItem>.from(formData.masters.fr);
        _diagnosisMasters = List<ExamMasterItem>.from(formData.masters.diagnoses);
        _adviceMasters = List<ExamMasterItem>.from(formData.masters.advices);
        // Pseudophakia panel's Hospital field autocompletes from the
        // Referrers master list, matching web.
        _referrers = referrers.map((r) => ExamMasterItem(id: r.id, value: r.name, isFavourite: false)).toList();
        _selectedDoctorId = widget.patient.doctor?.id;
        if (secondary != null) {
          _prefill(secondary);
          _prefillSource = 'secondary';
        } else if (primary != null) {
          _prefill(primary);
          _prefillSource = 'primary';
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loadError = e.toString(); _loading = false; });
    }
  }

  void _prefill(Map<String, dynamic> exam) {
    final raw = exam['exam_data'];
    Map<String, dynamic> ed = {};
    if (raw is Map<String, dynamic>) {
      ed = raw;
    } else if (raw is String && raw.isNotEmpty) {
      try { ed = jsonDecode(raw) as Map<String, dynamic>? ?? {}; } catch (_) {}
    }
    _historyChips..clear()..addAll(((ed['history'] as String?) ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty));
    for (final r in (ed['co_rows'] as List? ?? [])) {
      final m = r as Map<String, dynamic>;
      _coRows.add(_CoRow(complaint: m['complaint'] as String? ?? '', since: (m['since'] as String? ?? '').isEmpty ? '-' : m['since'] as String, unit: m['unit'] as String? ?? 'Days', eye: (m['eye'] as String? ?? '').isEmpty ? '-' : m['eye'] as String, comment: m['comment'] as String? ?? ''));
    }
    for (final r in (ed['kco_rows'] as List? ?? [])) {
      final m = r as Map<String, dynamic>;
      _kcoRows.add(_KcoRow(condition: m['condition'] as String? ?? '', since: (m['since'] as String? ?? '').isEmpty ? '-' : m['since'] as String, unit: m['unit'] as String? ?? 'Years', comment: m['comment'] as String? ?? ''));
    }
    final vd = ed['vision'] as Map<String, dynamic>? ?? {};
    _vnRe.text = vd['vn_re'] as String? ?? ''; _vnLe.text = vd['vn_le'] as String? ?? '';
    _pnvnRe.text = vd['pnvn_re'] as String? ?? ''; _pnvnLe.text = vd['pnvn_le'] as String? ?? '';
    _nrvnRe.text = vd['nrvn_re'] as String? ?? ''; _nrvnLe.text = vd['nrvn_le'] as String? ?? '';
    final pgd = ed['pg'] as Map<String, dynamic>? ?? {};
    for (final eye in ['re', 'le']) {
      final ev = pgd[eye] as Map<String, dynamic>? ?? {};
      for (final k in [..._pgDistKeys, ..._pgNearKeys]) { _pg[eye]![k]!.text = ev[k] as String? ?? ''; }
    }
    final std = ed['st'] as Map<String, dynamic>? ?? {};
    for (final eye in ['re', 'le']) {
      final ev = std[eye] as Map<String, dynamic>? ?? {};
      for (final k in _stDistKeys) { _st[eye]![k]!.text = ev[k] as String? ?? ''; }
    }
    _stAddRe.text = (std['re'] as Map<String, dynamic>?)?['add'] as String? ?? '';
    _stAddLe.text = (std['le'] as Map<String, dynamic>?)?['add'] as String? ?? '';
    _stNsRe.text = (std['re'] as Map<String, dynamic>?)?['ns'] as String? ?? '';
    _stNsLe.text = (std['le'] as Map<String, dynamic>?)?['ns'] as String? ?? '';
    _bifocal = std['bifocal'] == true; _ndSeparate = std['nd_separate'] == true;
    _progressive = std['progressive'] == true; _computerUses = std['computer_uses'] == true;
    final nct = ed['nct'] as Map<String, dynamic>? ?? {};
    _nctIopRe.text = nct['iop_re'] as String? ?? ''; _nctIopLe.text = nct['iop_le'] as String? ?? '';
    final oed = ed['oe'] as Map<String, dynamic>? ?? {};
    for (final f in _oeFieldNames) { _oeRe[f]!.text = oed['${f}_re'] as String? ?? ''; _oeLe[f]!.text = oed['${f}_le'] as String? ?? ''; }
    final pseudoRe = oed['pseudophakia_re'] as Map<String, dynamic>? ?? {};
    _pseudoOpRe = pseudoRe['operation_type'] as String? ?? 'Phaco';
    _pseudoExpRe.text = pseudoRe['operation_expense'] as String? ?? ''; _pseudoHospRe.text = pseudoRe['hospital_name'] as String? ?? '';
    final pseudoLe = oed['pseudophakia_le'] as Map<String, dynamic>? ?? {};
    _pseudoOpLe = pseudoLe['operation_type'] as String? ?? 'Phaco';
    _pseudoExpLe.text = pseudoLe['operation_expense'] as String? ?? ''; _pseudoHospLe.text = pseudoLe['hospital_name'] as String? ?? '';
    final fundus = ed['fundus'] as Map<String, dynamic>? ?? {};
    _fundusDiscRe.text = fundus['disc_re'] as String? ?? ''; _fundusDiscLe.text = fundus['disc_le'] as String? ?? '';
    _fundusFrRe.text = fundus['fr_re'] as String? ?? ''; _fundusFrLe.text = fundus['fr_le'] as String? ?? '';
    _fundusCommentRe.text = fundus['comment_re'] as String? ?? ''; _fundusCommentLe.text = fundus['comment_le'] as String? ?? '';
    _dilate = ed['dilate'] as String? ?? 'No';
    _dilationTimeCtrl.text = (exam['dilation_time'] as int?)?.toString() ?? '';

    for (final d in (ed['diagnoses'] as List? ?? [])) {
      final id = d is int ? d : int.tryParse(d.toString());
      if (id != null) _selectedDiagnosisIds.add(id);
    }
    _adviceCtrl.text = ed['advice'] as String? ?? '';
    for (final m in (exam['prescriptions'] as List? ?? [])) {
      final row = m as Map<String, dynamic>;
      _medicines.add(_PrescRow(medicineId: row['medicine_id'] as int?, medicineName: (row['medicine'] as Map<String, dynamic>?)?['name'] as String? ?? '', dosageId: row['dosage_id'] as int?, routeId: row['route_id'] as int?, duration: row['duration'] as String? ?? '', quantity: (row['quantity'] as num?)?.toInt() ?? 1));
    }
    for (final m in (ed['rx'] as List? ?? [])) {
      final row = m as Map<String, dynamic>;
      _medicines.add(_PrescRow(medicineId: row['medicine_id'] as int?, medicineName: row['name'] as String? ?? '', dosageId: row['dosage_id'] as int?, routeId: row['route_id'] as int?, duration: row['duration'] as String? ?? '', quantity: (row['quantity'] as num?)?.toInt() ?? 1));
    }
  }

  // ── Save (per-section — PRD §8.1) ────────────────────────────────────

  Future<void> _save(String key, Map<String, dynamic> examData, {int? dilationTime, List<Map<String, dynamic>>? medicines}) async {
    setState(() => _saving[key] = true);
    try {
      final payload = <String, dynamic>{'doctor_id': _selectedDoctorId, 'exam_data': examData};
      if (dilationTime != null) payload['dilation_time'] = dilationTime;
      if (medicines != null) payload['medicines'] = medicines;
      await ExamService.instance.saveSecondaryExam(widget.patient.id, payload);
      if (!mounted) return;
      _anySaved = true;
      setState(() { _saving[key] = false; _saved[key] = true; });
      showAppSnackBar(context, '$key saved.', isSuccess: true, duration: const Duration(seconds: 2));
      Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _saved[key] = false); });
    } catch (e) {
      if (mounted) {
        setState(() => _saving[key] = false);
        showAppSnackBar(context, e.toString(), isError: true, duration: const Duration(seconds: 4));
      }
    }
  }

  void _saveCo() => _save('C/O', {'history': _historyChips.join(', '), 'co_rows': _coRows.map((r) => r.toJson()).toList()});
  void _saveKcoHo() => _save('K/C/O & H/O', {'kco_rows': _kcoRows.map((r) => r.toJson()).toList(), 'history': _historyChips.join(', ')});

  void _saveVision() {
    final v = <String, dynamic>{};
    void put(String k, String val) { if (val.isNotEmpty) v[k] = val; }
    put('vn_re', _vnRe.text.trim()); put('vn_le', _vnLe.text.trim());
    put('pnvn_re', _pnvnRe.text.trim()); put('pnvn_le', _pnvnLe.text.trim());
    put('nrvn_re', _nrvnRe.text.trim()); put('nrvn_le', _nrvnLe.text.trim());
    _save('Vision', {'vision': v});
  }

  void _savePg() {
    final pg = <String, dynamic>{};
    for (final eye in ['re', 'le']) {
      final ev = <String, String>{};
      for (final k in [..._pgDistKeys, ..._pgNearKeys]) { final v = _pg[eye]![k]!.text.trim(); if (v.isNotEmpty) ev[k] = v; }
      if (ev.isNotEmpty) pg[eye] = ev;
    }
    _save('PG', {'pg': pg});
  }

  void _saveSt() {
    final st = <String, dynamic>{};
    for (final eye in ['re', 'le']) {
      final ev = <String, String>{};
      for (final k in _stDistKeys) { final v = _st[eye]![k]!.text.trim(); if (v.isNotEmpty) ev[k] = v; }
      final addVal = eye == 're' ? _stAddRe.text.trim() : _stAddLe.text.trim();
      final nsVal = eye == 're' ? _stNsRe.text.trim() : _stNsLe.text.trim();
      if (addVal.isNotEmpty) ev['add'] = addVal;
      if (nsVal.isNotEmpty) ev['ns'] = nsVal;
      final dcVal = _st[eye]!['dc']!.text.trim(); final axVal = _st[eye]!['ax']!.text.trim();
      if (dcVal.isNotEmpty) ev['nc'] = dcVal;
      if (axVal.isNotEmpty) ev['na'] = axVal;
      if (ev.isNotEmpty) st[eye] = ev;
    }
    if (_bifocal) st['bifocal'] = true;
    if (_ndSeparate) st['nd_separate'] = true;
    if (_progressive) st['progressive'] = true;
    if (_computerUses) st['computer_uses'] = true;
    _save('ST', {'st': st});
  }

  void _saveNct() {
    final nct = <String, dynamic>{};
    if (_nctIopRe.text.trim().isNotEmpty) nct['iop_re'] = _nctIopRe.text.trim();
    if (_nctIopLe.text.trim().isNotEmpty) nct['iop_le'] = _nctIopLe.text.trim();
    _save('NCT', {'nct': nct});
  }

  bool _isPseudo(String eye) => (eye == 're' ? _oeRe['lens'] : _oeLe['lens'])!.text.toLowerCase().contains('pseudophakia');

  void _saveOe() {
    final oe = <String, dynamic>{};
    for (final f in _oeFieldNames) {
      if (_oeRe[f]!.text.trim().isNotEmpty) oe['${f}_re'] = _oeRe[f]!.text.trim();
      if (_oeLe[f]!.text.trim().isNotEmpty) oe['${f}_le'] = _oeLe[f]!.text.trim();
    }
    if (_isPseudo('re')) oe['pseudophakia_re'] = {'operation_type': _pseudoOpRe, 'operation_expense': _pseudoExpRe.text.trim(), 'hospital_name': _pseudoHospRe.text.trim()};
    if (_isPseudo('le')) oe['pseudophakia_le'] = {'operation_type': _pseudoOpLe, 'operation_expense': _pseudoExpLe.text.trim(), 'hospital_name': _pseudoHospLe.text.trim()};
    _save('O/E', {'oe': oe});
  }

  void _saveFundus() {
    final f = <String, dynamic>{};
    void put(String k, String v) { if (v.isNotEmpty) f[k] = v; }
    put('disc_re', _fundusDiscRe.text.trim()); put('disc_le', _fundusDiscLe.text.trim());
    put('fr_re', _fundusFrRe.text.trim()); put('fr_le', _fundusFrLe.text.trim());
    put('comment_re', _fundusCommentRe.text.trim()); put('comment_le', _fundusCommentLe.text.trim());
    _save('Fundus', {'fundus': f});
  }

  void _saveDilate() => _save('Dilate', {'dilate': _dilate}, dilationTime: (_dilate == 'Yes' && _dilationTimeCtrl.text.trim().isNotEmpty) ? int.tryParse(_dilationTimeCtrl.text.trim()) : null);

  void _saveDiagnosis() => _save('Diagnosis', {'diagnoses': _selectedDiagnosisIds.toList()});

  void _saveMedicine() => _save('Medicine', {}, medicines: _medicines.where((m) => m.medicineId != null || m.medicineName.isNotEmpty).map((m) => m.toJson()).toList());

  void _saveAdvice() => _save('Advice', {'advice': _adviceCtrl.text.trim()});

  // ── Favourite toggle ──────────────────────────────────────────────────

  Future<void> _refreshMasters() async {
    final masters = await ExamMastersService.instance.fetchAll(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _formData = ExamFormData(dosages: _formData?.dosages ?? [], routes: _formData?.routes ?? [], masters: masters, medGroups: _formData?.medGroups ?? []);
      _oeMasters = {for (final f in _oeMasterApiType.keys) f: List<ExamMasterItem>.from(masters.oeListFor(f))};
      _fundusDiscMasters = List<ExamMasterItem>.from(masters.disc);
      _fundusFrMasters = List<ExamMasterItem>.from(masters.fr);
      _diagnosisMasters = List<ExamMasterItem>.from(masters.diagnoses);
      _adviceMasters = List<ExamMasterItem>.from(masters.advices);
    });
  }

  Future<bool> _toggleFav(String masterType, ExamMasterItem item) async {
    final newFav = await SimpleMasterService.instance.toggleFavourite('masters/detail/$masterType', item.id);
    unawaited(_refreshMasters());
    return newFav;
  }

  void _appendAdvice(String text) {
    final existing = _adviceCtrl.text.trimRight();
    setState(() => _adviceCtrl.text = existing.isEmpty ? text : '$existing\n$text');
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) Navigator.of(context).pop(_anySaved); },
      child: Scaffold(
        backgroundColor: const Color(0xFFEBF5FB),
        body: Column(children: [
          _buildHeader(),
          if (_prefillSource == 'primary') _primaryBanner(),
          Expanded(
            child: _loading
                ? const AppSkeletonList(count: 5, itemHeight: 120)
                : _loadError != null
                    ? _buildError()
                    : SingleChildScrollView(padding: const EdgeInsets.all(20), child: _buildGrid()),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    final p = widget.patient;
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.teal, AppColors.tealDark], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 20, 14),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.of(context).pop(_anySaved)),
            Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Secondary Examination', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                Text('${p.fullName}  ·  MRD: ${p.patientCode}', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
              ]),
            ),
            if (PermissionService.instance.can(Perm.otSurgeryRecommend))
              IconButton(
                icon: const Icon(Icons.medical_services_rounded, color: Colors.white),
                tooltip: 'Recommend Surgery',
                onPressed: () => showRecommendSurgeryDialog(context, patient: widget.patient, diagnosisHint: _diagnosisHintText()),
              ),
          ]),
        ),
      ),
    );
  }

  String? _diagnosisHintText() {
    if (_selectedDiagnosisIds.isEmpty) return null;
    return _diagnosisMasters
        .where((d) => _selectedDiagnosisIds.contains(d.id))
        .map((d) => d.value)
        .join(', ');
  }

  Widget _primaryBanner() => Container(
        width: double.infinity,
        color: const Color(0xFFFFF3CD),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF856404)),
          const SizedBox(width: 8),
          Expanded(child: Text('Data pre-filled from Primary Exam — no Secondary record exists yet.', style: TextStyle(fontSize: 11.5, color: const Color(0xFF856404), fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _buildError() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.red),
          const SizedBox(height: 12),
          Text(_loadError ?? 'Failed to load exam.', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _loadAll, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal)),
        ]),
      );

  Widget _buildGrid() {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= AppBreakpoints.medium;
      final full = <Widget>[_coCard(), _kcoHoCard(), _visionCard()];
      final pairedPgSt = wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _pgCard()), const SizedBox(width: 16), Expanded(child: _stCard())])
          : Column(children: [_pgCard(), const SizedBox(height: 16), _stCard()]);
      final rest = <Widget>[_nctCard(), _oeCard()];
      final pairedFundus = wide ? _fundusCardWide() : _fundusCardStacked();
      final tail = <Widget>[_dilateCard(), _diagnosisCard(), _medicineCard(), _adviceCard()];
      final children = <Widget>[...full, pairedPgSt, ...rest, pairedFundus, ...tail];
      return Column(children: [for (final w in children) Padding(padding: const EdgeInsets.only(bottom: 16), child: w)]);
    });
  }

  // ── C/O ───────────────────────────────────────────────────────────────

  Widget _coCard() {
    final favs = (_formData?.masters.chiefComplaints ?? []).where((c) => c.isFavourite).toList();
    return ExamSectionCard(
      title: 'C/O — Chief Complaints',
      saving: _saving['C/O'] ?? false,
      saved: _saved['C/O'] ?? false,
      onSave: _saveCo,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FavouriteChipRow(favourites: favs, onTapAdd: (item) => setState(() => _coRows.add(_CoRow(complaint: item.value))), onUnfavourite: (item) => _toggleFav('complaints', item)),
        Row(children: [Expanded(child: Text('Complaints', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary))), _addBtn(() => setState(() => _coRows.add(_CoRow())))]),
        const SizedBox(height: 8),
        if (_coRows.isEmpty) _emptyHint('No complaints added') else ..._coRows.asMap().entries.map((e) => _coRowWidget(e.key, e.value)),
      ]),
    );
  }

  Widget _coRowWidget(int idx, _CoRow row) {
    const eyeOptions = ['-', 'RE', 'LE', 'Both', 'OU'];
    const sinceOptions = ['-', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10'];
    return Container(
      key: ValueKey('co_$idx'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: TextPickerField(controller: row.complaintCtrl, hint: 'Complaint', items: _formData?.masters.chiefComplaints ?? [], showFavourites: true, onToggleFavourite: (item) => _toggleFav('complaints', item), onChanged: (_) {})),
        const SizedBox(width: 6),
        SizedBox(width: 60, child: _miniDropdown(value: sinceOptions.contains(row.since) ? row.since : '-', items: sinceOptions, onChanged: (v) => setState(() => row.since = v ?? '-'))),
        const SizedBox(width: 6),
        SizedBox(width: 90, child: _miniDropdown(value: row.unit, items: const ['Days', 'Weeks', 'Months', 'Years', 'Longtime'], onChanged: (v) => setState(() => row.unit = v!))),
        const SizedBox(width: 6),
        SizedBox(width: 60, child: _miniDropdown(value: eyeOptions.contains(row.eye) ? row.eye : '-', items: eyeOptions, onChanged: (v) => setState(() => row.eye = v ?? '-'))),
        const SizedBox(width: 6),
        Expanded(flex: 2, child: _simpleField(initial: row.comment, hint: 'Comment', onChanged: (v) => row.comment = v)),
        IconButton(icon: const Icon(Icons.remove_circle_rounded, color: AppColors.red, size: 20), onPressed: () => setState(() { row.dispose(); _coRows.removeAt(idx); })),
      ]),
    );
  }

  // ── K/C/O & H/O ───────────────────────────────────────────────────────

  Widget _kcoHoCard() {
    final kcoFavs = (_formData?.masters.kcos ?? []).where((i) => i.isFavourite).toList();
    return ExamSectionCard(
      title: 'K/C/O & H/O',
      saving: _saving['K/C/O & H/O'] ?? false,
      saved: _saved['K/C/O & H/O'] ?? false,
      onSave: _saveKcoHo,
      child: LayoutBuilder(builder: (context, c) {
        final kco = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FavouriteChipRow(favourites: kcoFavs, onTapAdd: (item) => setState(() => _kcoRows.add(_KcoRow(condition: item.value))), onUnfavourite: (item) => _toggleFav('kcos', item)),
          Row(children: [Expanded(child: Text('Known Conditions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary))), _addBtn(() => setState(() => _kcoRows.add(_KcoRow())))]),
          const SizedBox(height: 8),
          if (_kcoRows.isEmpty) _emptyHint('No conditions added') else ..._kcoRows.asMap().entries.map((e) => _kcoRowWidget(e.key, e.value)),
        ]);
        final ho = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('History (H/O)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
          const SizedBox(height: 8),
          _historyChipsSection(),
        ]);
        if (c.maxWidth < 700) return Column(children: [kco, const SizedBox(height: 16), ho]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: kco), const SizedBox(width: 16), Expanded(child: ho)]);
      }),
    );
  }

  Widget _kcoRowWidget(int idx, _KcoRow row) {
    const sinceOptions = ['-', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10'];
    return Container(
      key: ValueKey('kco_$idx'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: TextPickerField(controller: row.conditionCtrl, hint: 'Condition', items: _formData?.masters.kcos ?? [], showFavourites: true, onToggleFavourite: (item) => _toggleFav('kcos', item), onChanged: (_) {})),
        const SizedBox(width: 6),
        SizedBox(width: 60, child: _miniDropdown(value: sinceOptions.contains(row.since) ? row.since : '-', items: sinceOptions, onChanged: (v) => setState(() => row.since = v ?? '-'))),
        const SizedBox(width: 6),
        SizedBox(width: 90, child: _miniDropdown(value: row.unit, items: const ['Days', 'Weeks', 'Months', 'Years', 'Longtime'], onChanged: (v) => setState(() => row.unit = v!))),
        const SizedBox(width: 6),
        Expanded(flex: 2, child: _simpleField(initial: row.comment, hint: 'Comment', onChanged: (v) => row.comment = v)),
        IconButton(icon: const Icon(Icons.remove_circle_rounded, color: AppColors.red, size: 20), onPressed: () => setState(() { row.dispose(); _kcoRows.removeAt(idx); })),
      ]),
    );
  }

  Widget _historyChipsSection() {
    final hnoItems = _formData?.masters.hno ?? [];
    final favs = hnoItems.where((i) => i.isFavourite).toList();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_historyChips.isNotEmpty) ...[
          Wrap(spacing: 6, runSpacing: 6, children: _historyChips.map((chip) => Chip(label: Text(chip, style: const TextStyle(fontSize: 11)), deleteIcon: const Icon(Icons.close, size: 13), onDeleted: () => setState(() => _historyChips.remove(chip)), backgroundColor: AppColors.primaryA08, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)).toList()),
          const SizedBox(height: 8),
        ],
        if (favs.isNotEmpty) ...[
          Wrap(spacing: 6, runSpacing: 6, children: favs.map((item) {
            final sel = _historyChips.contains(item.value);
            return PressScaleWrapper(onTap: () { if (!sel) setState(() => _historyChips.add(item.value)); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: sel ? Colors.amber.shade50 : Colors.white, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: Colors.amber.shade300)), child: Text(item.value, style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w600))));
          }).toList()),
          const SizedBox(height: 8),
        ],
        MasterSearchAddField(items: hnoItems, hint: 'Search or type history item…', icon: Icons.history_edu_rounded, onToggleFavourite: (item) => _toggleFav('hno', item), onSelected: (val) { if (!_historyChips.contains(val)) setState(() => _historyChips.add(val)); }),
      ]),
    );
  }

  // ── Vision ────────────────────────────────────────────────────────────

  Widget _visionCard() {
    return ExamSectionCard(
      title: 'Vision — Visual Acuity',
      saving: _saving['Vision'] ?? false,
      saved: _saved['Vision'] ?? false,
      onSave: _saveVision,
      child: Table(columnWidths: const {0: FixedColumnWidth(40)}, children: [
        TableRow(children: [const SizedBox(), examTh('VN (Dist)'), examTh('Pinhole'), examTh('Near VN')]),
        _visionRow('RE', _vnRe, _pnvnRe, _nrvnRe, true),
        _visionRow('LE', _vnLe, _pnvnLe, _nrvnLe, false),
      ]),
    );
  }

  TableRow _visionRow(String label, TextEditingController vn, TextEditingController pnvn, TextEditingController nrvn, bool isRe) {
    return TableRow(children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isRe ? Colors.red.shade700 : AppColors.primary))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: TextPickerField(controller: vn, hint: 'VN', items: _formData?.masters.vn ?? [], onChanged: (_) {})),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: TextPickerField(controller: pnvn, hint: 'PnVN', items: _formData?.masters.pnvn ?? [], onChanged: (_) {})),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: TextPickerField(controller: nrvn, hint: 'NrVN', items: _formData?.masters.nrvn ?? [], onChanged: (_) {})),
    ]);
  }

  // ── PG / ST ───────────────────────────────────────────────────────────

  Widget _pgCard() => ExamSectionCard(title: 'PG — Prescription Glasses', saving: _saving['PG'] ?? false, saved: _saved['PG'] ?? false, onSave: _savePg, child: _refractionTable(_pg, isSt: false));

  Widget _stCard() {
    return ExamSectionCard(
      title: 'ST — Subjective Test',
      saving: _saving['ST'] ?? false,
      saved: _saved['ST'] ?? false,
      onSave: _saveSt,
      child: Column(children: [
        _refractionTable(_st, isSt: true),
        const SizedBox(height: 10),
        Wrap(spacing: 4, runSpacing: 4, children: [
          _checkbox('Bifocal', _bifocal, (v) => setState(() => _bifocal = v!)),
          _checkbox('N&D Separate', _ndSeparate, (v) => setState(() => _ndSeparate = v!)),
          _checkbox('Progressive', _progressive, (v) => setState(() => _progressive = v!)),
          _checkbox('Computer Use', _computerUses, (v) => setState(() => _computerUses = v!)),
        ]),
      ]),
    );
  }

  bool _axisDisabled(String cylText) {
    final t = cylText.trim();
    if (t.isEmpty || t == 'Plano') return true;
    final abs = (t.startsWith('+') || t.startsWith('-')) ? t.substring(1) : t;
    return abs == '0.00' || abs == '0';
  }

  Widget _refractionTable(Map<String, Map<String, TextEditingController>> data, {required bool isSt}) {
    final sphCyl = _formData?.masters.sphCyl ?? [];
    final axis = _formData?.masters.axis ?? [];
    final vn = _formData?.masters.vn ?? [];
    final nrvn = _formData?.masters.nrvn ?? [];

    Widget cellFor(String eye, String key) {
      final isSph = key == 'ds' || key == 'ns';
      final isCyl = key == 'dc' || key == 'nc';
      final isAxis = key == 'ax' || key == 'na';
      final isVn = key == 'vn';
      final isNearVn = key == 'near_vn';
      if (isSt && (key == 'nc' || key == 'na')) return MirrorCell(value: data[eye]![key == 'nc' ? 'dc' : 'ax']!.text);
      if (isSph || isCyl) return ChipPickerField(controller: data[eye]![key]!, items: sphCyl, isSignField: true, onChanged: () => setState(() {}));
      if (isAxis) return ChipPickerField(controller: data[eye]![key]!, items: axis, isSignField: false, disabled: _axisDisabled(data[eye]!['dc']!.text));
      if (isVn || isNearVn) return ChipPickerField(controller: data[eye]![key]!, items: isNearVn ? nrvn : vn, isSignField: false);
      return const SizedBox();
    }

    return Column(
      children: ['re', 'le'].map((eye) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA12)),
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              Row(children: [Icon(Icons.remove_red_eye_rounded, size: 13, color: eye == 're' ? Colors.red.shade700 : AppColors.primary), const SizedBox(width: 6), Text(eye == 're' ? 'Right Eye (RE)' : 'Left Eye (LE)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: eye == 're' ? Colors.red.shade700 : AppColors.primary))]),
              const SizedBox(height: 6),
              Row(children: [const SizedBox(width: 42), Expanded(child: examTh('SPH')), Expanded(child: examTh('CYL')), Expanded(child: examTh('AXIS')), Expanded(child: examTh(isSt ? 'VN C ST' : 'VN C GL'))]),
              Row(children: [
                SizedBox(width: 42, child: Text('DIST', style: TextStyle(fontSize: 9, color: AppColors.primaryA50))),
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: cellFor(eye, 'ds'))),
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: cellFor(eye, 'dc'))),
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: cellFor(eye, 'ax'))),
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: cellFor(eye, 'vn'))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                SizedBox(width: 42, child: Text('NEAR', style: TextStyle(fontSize: 9, color: AppColors.primaryA50))),
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: isSt ? _stNsCell(eye) : cellFor(eye, 'ns'))),
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: cellFor(eye, 'nc'))),
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: cellFor(eye, 'na'))),
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: isSt ? const SizedBox() : cellFor(eye, 'near_vn'))),
              ]),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _stNsCell(String eye) {
    final nsCtrl = eye == 're' ? _stNsRe : _stNsLe;
    final addCtrl = eye == 're' ? _stAddRe : _stAddLe;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      ChipPickerField(controller: addCtrl, items: _formData?.masters.sphCyl ?? [], isSignField: true, onChanged: () {
        final ds = double.tryParse(_st[eye]!['ds']!.text.replaceAll('+', '')) ?? 0.0;
        final add = double.tryParse(addCtrl.text.replaceAll('+', '')) ?? 0.0;
        final ns = ds + add;
        setState(() => nsCtrl.text = ns == 0.0 ? '' : (ns > 0 ? '+${ns.toStringAsFixed(2)}' : ns.toStringAsFixed(2)));
      }),
      const SizedBox(height: 3),
      Text('NS: ${nsCtrl.text.isEmpty ? '—' : nsCtrl.text}', style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
    ]);
  }

  // ── NCT ───────────────────────────────────────────────────────────────

  Color _iopColor(String v) {
    final iop = int.tryParse(v.trim());
    if (iop == null) return AppColors.primaryA18;
    if (iop >= 25) return const Color(0xFFEF4444);
    if (iop >= 22) return const Color(0xFFF59E0B);
    if (iop >= 10) return const Color(0xFF22C55E);
    return AppColors.primaryA18;
  }

  Widget _nctCard() {
    return ExamSectionCard(
      title: 'NCT — Non-Contact Tonometry',
      saving: _saving['NCT'] ?? false,
      saved: _saved['NCT'] ?? false,
      onSave: _saveNct,
      child: Column(children: [
        Row(children: [
          Expanded(child: Column(children: [Text('RE (mmHg)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red.shade700)), const SizedBox(height: 6), TextPickerField(controller: _nctIopRe, hint: 'IOP', items: _formData?.masters.nct ?? [], grid: true, borderColorFor: _iopColor, onChanged: (_) {})])),
          const SizedBox(width: 16),
          Expanded(child: Column(children: [Text('LE (mmHg)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)), const SizedBox(height: 6), TextPickerField(controller: _nctIopLe, hint: 'IOP', items: _formData?.masters.nct ?? [], grid: true, borderColorFor: _iopColor, onChanged: (_) {})])),
        ]),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 6, children: [_iopBadge('Normal 10–21', const Color(0xFF22C55E)), _iopBadge('Borderline 22–24', const Color(0xFFF59E0B)), _iopBadge('High ≥25', const Color(0xFFEF4444))]),
      ]),
    );
  }

  Widget _iopBadge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: color.withValues(alpha: 0.4))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600))]),
      );

  // ── O/E ───────────────────────────────────────────────────────────────

  Widget _oeCard() {
    return ExamSectionCard(
      title: 'O/E — On Examination',
      saving: _saving['O/E'] ?? false,
      saved: _saved['O/E'] ?? false,
      onSave: _saveOe,
      child: Column(children: [
        Row(children: [const SizedBox(width: 110), Expanded(child: examTh('Right Eye (RE)')), Expanded(child: examTh('Left Eye (LE)'))]),
        ..._oeFieldNames.map((f) {
          final isOther = f == 'other';
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Divider(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              SizedBox(width: 110, child: Text(_oeLabels[f] ?? f, style: TextStyle(fontSize: 12, color: AppColors.primaryA70, fontWeight: FontWeight.w600))),
              Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: isOther ? _simpleField(initial: _oeRe[f]!.text, hint: '—', onChanged: (v) => _oeRe[f]!.text = v) : TextPickerField(controller: _oeRe[f]!, hint: _oeLabels[f] ?? f, items: _oeMasters[f] ?? [], showFavourites: true, onToggleFavourite: (item) => _toggleFav(_oeMasterApiType[f]!, item), onChanged: (_) => setState(() {})))),
              Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: isOther ? _simpleField(initial: _oeLe[f]!.text, hint: '—', onChanged: (v) => _oeLe[f]!.text = v) : TextPickerField(controller: _oeLe[f]!, hint: _oeLabels[f] ?? f, items: _oeMasters[f] ?? [], showFavourites: true, onToggleFavourite: (item) => _toggleFav(_oeMasterApiType[f]!, item), onChanged: (_) => setState(() {})))),
            ]),
            if (f == 'lens' && (_isPseudo('re') || _isPseudo('le'))) _pseudoPanel(),
          ]);
        }),
      ]),
    );
  }

  Widget _pseudoPanel() {
    Widget panel(String eye, String opType, void Function(String) onOp, TextEditingController exp, TextEditingController hosp) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primaryA15)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pseudophakia — $eye', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: ['Block', 'Phaco'].map((o) => PressScaleWrapper(onTap: () => setState(() => onOp(o)), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: opType == o ? AppColors.primary : Colors.white, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: opType == o ? AppColors.primary : AppColors.primaryA20)), child: Text(o, style: TextStyle(fontSize: 11, color: opType == o ? Colors.white : AppColors.primary))))).toList()),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: _simpleField(initial: exp.text, hint: 'Expense', onChanged: (v) => exp.text = v)), const SizedBox(width: 8), Expanded(child: TextPickerField(controller: hosp, hint: 'Hospital', items: _referrers, onChanged: (_) {}))]),
        ]),
      );
    }
    return Column(children: [
      if (_isPseudo('re')) panel('RE', _pseudoOpRe, (v) => _pseudoOpRe = v, _pseudoExpRe, _pseudoHospRe),
      if (_isPseudo('le')) panel('LE', _pseudoOpLe, (v) => _pseudoOpLe = v, _pseudoExpLe, _pseudoHospLe),
    ]);
  }

  // ── Fundus ────────────────────────────────────────────────────────────

  Widget _fundusEyeCard(bool isRe) {
    final disc = isRe ? _fundusDiscRe : _fundusDiscLe;
    final fr = isRe ? _fundusFrRe : _fundusFrLe;
    final comment = isRe ? _fundusCommentRe : _fundusCommentLe;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.remove_red_eye_rounded, size: 13, color: isRe ? Colors.red.shade700 : AppColors.primary), const SizedBox(width: 6), Text(isRe ? 'Right Eye (RE)' : 'Left Eye (LE)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isRe ? Colors.red.shade700 : AppColors.primary))]),
        const SizedBox(height: 8),
        Text('Disc', style: TextStyle(fontSize: 10, color: AppColors.primaryA55)),
        const SizedBox(height: 3),
        TextPickerField(controller: disc, hint: 'Disc (CDR)', items: _fundusDiscMasters, showFavourites: true, onToggleFavourite: (item) => _toggleFav('disc', item), onChanged: (_) {}),
        const SizedBox(height: 8),
        Text('FR', style: TextStyle(fontSize: 10, color: AppColors.primaryA55)),
        const SizedBox(height: 3),
        TextPickerField(controller: fr, hint: 'Foveal Reflex', items: _fundusFrMasters, showFavourites: true, onToggleFavourite: (item) => _toggleFav('fr', item), onChanged: (_) {}),
        const SizedBox(height: 8),
        Text('Comment', style: TextStyle(fontSize: 10, color: AppColors.primaryA55)),
        const SizedBox(height: 3),
        _simpleField(initial: comment.text, hint: 'Additional findings', onChanged: (v) => comment.text = v, lines: 2),
      ]),
    );
  }

  Widget _fundusCardWide() => ExamSectionCard(title: 'Fundus Examination', saving: _saving['Fundus'] ?? false, saved: _saved['Fundus'] ?? false, onSave: _saveFundus, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _fundusEyeCard(true)), const SizedBox(width: 16), Expanded(child: _fundusEyeCard(false))]));

  Widget _fundusCardStacked() => ExamSectionCard(title: 'Fundus Examination', saving: _saving['Fundus'] ?? false, saved: _saved['Fundus'] ?? false, onSave: _saveFundus, child: Column(children: [_fundusEyeCard(true), const SizedBox(height: 12), _fundusEyeCard(false)]));

  // ── Dilate ────────────────────────────────────────────────────────────

  Widget _dilateCard() {
    return ExamSectionCard(
      title: 'Dilation',
      saving: _saving['Dilate'] ?? false,
      saved: _saved['Dilate'] ?? false,
      onSave: _saveDilate,
      child: Row(children: [
        Text('Dilate patient?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
        const SizedBox(width: 16),
        ChoiceChip(label: const Text('Yes'), selected: _dilate == 'Yes', selectedColor: AppColors.teal, labelStyle: TextStyle(color: _dilate == 'Yes' ? Colors.white : AppColors.primary, fontWeight: FontWeight.w700), onSelected: (_) => setState(() { _dilate = 'Yes'; if (_dilationTimeCtrl.text.trim().isEmpty) _dilationTimeCtrl.text = '40'; })),
        const SizedBox(width: 8),
        ChoiceChip(label: const Text('No'), selected: _dilate == 'No', selectedColor: AppColors.teal, labelStyle: TextStyle(color: _dilate == 'No' ? Colors.white : AppColors.primary, fontWeight: FontWeight.w700), onSelected: (_) => setState(() { _dilate = 'No'; _dilationTimeCtrl.clear(); })),
        if (_dilate == 'Yes') ...[
          const SizedBox(width: 16),
          SizedBox(width: 90, child: _simpleField(initial: _dilationTimeCtrl.text, hint: 'Mins', onChanged: (v) => _dilationTimeCtrl.text = v, numeric: true)),
          const SizedBox(width: 6),
          const Text('minutes', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ]),
    );
  }

  // ── Diagnosis ─────────────────────────────────────────────────────────

  Widget _diagnosisCard() {
    final filtered = _diagnosisSearch.isEmpty ? _diagnosisMasters : _diagnosisMasters.where((d) => d.value.toLowerCase().contains(_diagnosisSearch.toLowerCase())).toList();
    final sorted = [...filtered.where((d) => d.isFavourite), ...filtered.where((d) => !d.isFavourite)];
    return ExamSectionCard(
      title: 'Diagnosis',
      saving: _saving['Diagnosis'] ?? false,
      saved: _saved['Diagnosis'] ?? false,
      onSave: _saveDiagnosis,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (_selectedDiagnosisIds.isNotEmpty) ...[
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(AppRadius.md)), child: Text('${_selectedDiagnosisIds.length} selected', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
            const Spacer(),
            PressScaleWrapper(onTap: () => setState(() => _selectedDiagnosisIds.clear()), child: Text('Clear all', style: TextStyle(fontSize: 11, color: Colors.red.shade600, fontWeight: FontWeight.w600))),
          ],
        ]),
        const SizedBox(height: 8),
        _simpleField(initial: _diagnosisSearch, hint: 'Search diagnoses…', onChanged: (v) => setState(() => _diagnosisSearch = v)),
        const SizedBox(height: 8),
        if (sorted.isEmpty)
          Text(_diagnosisSearch.isEmpty ? 'No diagnoses available' : 'No results for "$_diagnosisSearch"', style: TextStyle(fontSize: 12, color: AppColors.primaryA40, fontStyle: FontStyle.italic))
        else
          Wrap(spacing: 6, runSpacing: 6, children: sorted.map((d) {
            final sel = _selectedDiagnosisIds.contains(d.id);
            return Container(
              decoration: BoxDecoration(color: sel ? AppColors.teal : Colors.white, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: sel ? AppColors.teal : AppColors.primaryA20)),
              child: IntrinsicHeight(child: Row(mainAxisSize: MainAxisSize.min, children: [
                PressScaleWrapper(onTap: () async { final f = await _toggleFav('diagnoses', d); setState(() { final i = _diagnosisMasters.indexWhere((e) => e.id == d.id); if (i >= 0) _diagnosisMasters[i] = ExamMasterItem(id: d.id, value: d.value, isFavourite: f); }); }, child: Padding(padding: const EdgeInsets.only(left: 8, top: 6, bottom: 6, right: 4), child: Icon(d.isFavourite ? Icons.star_rounded : Icons.star_border_rounded, size: 13, color: d.isFavourite ? Colors.amber.shade600 : (sel ? Colors.white54 : AppColors.primaryA30)))),
                Container(width: 0.5, color: sel ? Colors.white24 : AppColors.primaryA10),
                PressScaleWrapper(onTap: () => setState(() { if (sel) _selectedDiagnosisIds.remove(d.id); else _selectedDiagnosisIds.add(d.id); }), child: Padding(padding: const EdgeInsets.only(left: 8, right: 10, top: 6, bottom: 6), child: Row(mainAxisSize: MainAxisSize.min, children: [if (sel) const Icon(Icons.check_rounded, size: 13, color: Colors.white), if (sel) const SizedBox(width: 3), Text(d.value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: sel ? Colors.white : AppColors.primary))]))),
              ])),
            );
          }).toList()),
      ]),
    );
  }

  // ── Medicine / Rx ─────────────────────────────────────────────────────

  Widget _medicineCard() {
    final dosages = _formData?.dosages ?? [];
    final routes = _formData?.routes ?? [];
    final groups = _formData?.medGroups ?? [];
    return ExamSectionCard(
      title: 'Medicine (Rx)',
      saving: _saving['Medicine'] ?? false,
      saved: _saved['Medicine'] ?? false,
      onSave: _saveMedicine,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (groups.isNotEmpty)
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: null,
                isExpanded: true,
                hint: const Text('Load a medicine group…', style: TextStyle(fontSize: 12)),
                items: groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: AppColors.primaryA18))),
                onChanged: (groupId) {
                  if (groupId == null) return;
                  final group = groups.firstWhere((g) => g.id == groupId);
                  setState(() {
                    for (final item in group.items) {
                      if (item.medicineName == null || item.medicineName!.isEmpty) continue;
                      _medicines.add(_PrescRow(medicineId: item.medicineId, medicineName: item.medicineName ?? '', dosageId: item.dosageId, routeId: item.routeId, duration: item.duration ?? '', quantity: item.quantity));
                    }
                  });
                },
              ),
            ),
          const SizedBox(width: 10),
          _addBtn(() => setState(() => _medicines.add(_PrescRow()))),
        ]),
        const SizedBox(height: 10),
        if (_medicines.isEmpty) _emptyHint('No medicines added') else ..._medicines.asMap().entries.map((e) => _prescRowWidget(e.key, e.value, dosages, routes)),
      ]),
    );
  }

  Widget _prescRowWidget(int idx, _PrescRow row, List<MedMasterItem> dosages, List<MedMasterItem> routes) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: _MedicineSearchField(initialName: row.medicineName, onSelected: (med) => setState(() {
          row.medicineId = med.id; row.medicineName = med.name;
          if (med.dosageId != null) row.dosageId = med.dosageId;
          if (med.duration != null) row.duration = med.duration!;
        }))),
        const SizedBox(width: 6),
        Expanded(flex: 2, child: _miniDropdownItems<int?>(value: row.dosageId, items: [const DropdownMenuItem(value: null, child: Text('Dosage')), ...dosages.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis)))], onChanged: (v) => setState(() => row.dosageId = v))),
        const SizedBox(width: 6),
        Expanded(flex: 2, child: _miniDropdownItems<int?>(value: row.routeId, items: [const DropdownMenuItem(value: null, child: Text('Route')), ...routes.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name, overflow: TextOverflow.ellipsis)))], onChanged: (v) => setState(() => row.routeId = v))),
        const SizedBox(width: 6),
        SizedBox(width: 60, child: _simpleField(initial: row.duration, hint: 'Days', onChanged: (v) => row.duration = v, numeric: true)),
        const SizedBox(width: 6),
        SizedBox(width: 50, child: _simpleField(initial: row.quantity.toString(), hint: 'Qty', onChanged: (v) => row.quantity = int.tryParse(v) ?? 1, numeric: true)),
        IconButton(icon: const Icon(Icons.remove_circle_rounded, color: AppColors.red, size: 20), onPressed: () => setState(() => _medicines.removeAt(idx))),
      ]),
    );
  }

  // ── Advice ────────────────────────────────────────────────────────────

  Widget _adviceCard() {
    final favAdvices = _adviceMasters.where((a) => a.isFavourite).toList();
    return ExamSectionCard(
      title: 'Advice / Follow-up',
      saving: _saving['Advice'] ?? false,
      saved: _saved['Advice'] ?? false,
      onSave: _saveAdvice,
      child: LayoutBuilder(builder: (context, c) {
        final quickAdd = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.bolt_rounded, size: 13, color: Colors.amber.shade700),
            const SizedBox(width: 5),
            Expanded(child: Text('QUICK ADD', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.primaryA55, letterSpacing: 0.5))),
            PressScaleWrapper(onTap: _showAdviceMore, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.primaryA15)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.grid_view_rounded, size: 11, color: AppColors.primaryA60), const SizedBox(width: 4), Text('More', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryA70))]))),
          ]),
          const SizedBox(height: 8),
          if (favAdvices.isNotEmpty)
            Wrap(spacing: 6, runSpacing: 6, children: favAdvices.map((a) => PressScaleWrapper(onTap: () => _appendAdvice(a.value), child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFFFFBEB), border: Border.all(color: Colors.amber.shade300), borderRadius: BorderRadius.circular(AppRadius.xl)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.star_rounded, size: 11, color: Colors.amber.shade600), const SizedBox(width: 4), Text(a.value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF92400E)))])))).toList())
          else
            Text('No favourites yet — tap More → ★ to mark', style: TextStyle(fontSize: 11, color: AppColors.primaryA40, fontStyle: FontStyle.italic)),
        ]);
        final adviceBox = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _adviceCtrl,
            builder: (_, val, __) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              TextFormField(controller: _adviceCtrl, maxLines: 5, maxLength: 2000, style: const TextStyle(fontSize: 12), decoration: InputDecoration(hintText: 'Clinical advice, post-operative care, follow-up instructions...', hintStyle: TextStyle(fontSize: 11, color: AppColors.primaryA35), filled: true, fillColor: Colors.white, counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: AppColors.primaryA18)))),
              Text('${val.text.length} / 2000', style: TextStyle(fontSize: 9, color: val.text.length > 1800 ? Colors.red : AppColors.primaryA40)),
            ]),
          ),
        ]);
        if (c.maxWidth < 700) return Column(children: [quickAdd, const SizedBox(height: 12), adviceBox]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: quickAdd), const SizedBox(width: 16), Expanded(flex: 3, child: adviceBox)]);
      }),
    );
  }

  void _showAdviceMore() {
    String query = '';
    final masterList = List<ExamMasterItem>.from(_adviceMasters);
    final addCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dCtx) => StatefulBuilder(builder: (_, ss) {
        final filtered = masterList.where((i) => query.isEmpty || i.value.toLowerCase().contains(query.toLowerCase())).toList();
        final favs = filtered.where((i) => i.isFavourite).toList();
        final others = filtered.where((i) => !i.isFavourite).toList();

        Future<void> toggle(ExamMasterItem item) async {
          final newFav = await _toggleFav('advices', item);
          ss(() { final i = masterList.indexWhere((e) => e.id == item.id); if (i >= 0) masterList[i] = ExamMasterItem(id: item.id, value: item.value, isFavourite: newFav); });
        }

        Widget tile(ExamMasterItem item) => ListTile(
              dense: true,
              title: Text(item.value, style: const TextStyle(fontSize: 13)),
              trailing: IconButton(icon: Icon(item.isFavourite ? Icons.star_rounded : Icons.star_outline_rounded, size: 17, color: item.isFavourite ? Colors.amber : AppColors.primaryA30), onPressed: () => toggle(item)),
              onTap: () { _appendAdvice(item.value); },
            );

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 14, 8, 8), child: Row(children: [Expanded(child: Text('All Advice', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary))), IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => Navigator.pop(dCtx))])),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(children: [
                  Expanded(child: TextField(onChanged: (v) => ss(() => query = v), decoration: InputDecoration(hintText: 'Search…', isDense: true, prefixIcon: const Icon(Icons.search_rounded, size: 16), contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm))))),
                  const SizedBox(width: 8),
                  PressScaleWrapper(
                    onTap: () async {
                      final text = addCtrl.text.trim();
                      if (text.isEmpty) return;
                      final created = await SimpleMasterService.instance.create('masters/detail/advices', text);
                      ss(() => masterList.add(ExamMasterItem(id: created.id, value: created.value, isFavourite: created.isFavourite)));
                      _appendAdvice(created.value);
                      setState(() => _adviceMasters = List<ExamMasterItem>.from(masterList));
                      addCtrl.clear();
                    },
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.sm)), child: const Icon(Icons.add_rounded, size: 16, color: Colors.white)),
                  ),
                ]),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: TextField(controller: addCtrl, decoration: const InputDecoration(hintText: 'New advice text (tap + to save)', isDense: true), style: const TextStyle(fontSize: 12))),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  if (favs.isNotEmpty) ...[Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 2), child: Text('★ Favourites', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.amber.shade700))), ...favs.map(tile)],
                  if (others.isNotEmpty) ...[Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 2), child: Text('All', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryA50))), ...others.map(tile)],
                ]),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        );
      }),
    ).whenComplete(() => addCtrl.dispose());
  }

  // ── Small shared helpers ──────────────────────────────────────────────

  Widget _addBtn(VoidCallback onTap) => PressScaleWrapper(onTap: onTap, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: AppColors.tealA12, borderRadius: BorderRadius.circular(AppRadius.xl)), child: Icon(Icons.add_rounded, color: AppColors.teal, size: 16)));

  Widget _emptyHint(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: TextStyle(fontSize: 12, color: AppColors.primaryA40, fontStyle: FontStyle.italic)));

  Widget _simpleField({required String initial, required String hint, required void Function(String) onChanged, int lines = 1, bool numeric = false}) {
    return TextFormField(
      initialValue: initial,
      maxLines: lines,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(fontSize: 11, color: AppColors.primaryA35), isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: AppColors.primaryA18))),
    );
  }

  Widget _miniDropdown({required String value, required List<String> items, required void Function(String?) onChanged}) {
    return DropdownButtonFormField<String>(initialValue: value, isExpanded: true, items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))).toList(), onChanged: onChanged, decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: AppColors.primaryA18))));
  }

  Widget _miniDropdownItems<T>({required T value, required List<DropdownMenuItem<T>> items, required void Function(T?) onChanged}) {
    return DropdownButtonFormField<T>(initialValue: value, isExpanded: true, items: items, onChanged: onChanged, style: const TextStyle(fontSize: 11, color: Colors.black87), decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: AppColors.primaryA18))));
  }

  Widget _checkbox(String label, bool val, void Function(bool?) onChanged) => Row(mainAxisSize: MainAxisSize.min, children: [Checkbox(value: val, onChanged: onChanged, activeColor: AppColors.primary, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap), Text(label, style: TextStyle(fontSize: 12, color: AppColors.primary))]);

}

void unawaited(Future<void> f) {}

// ── Medicine search autocomplete ────────────────────────────────────────

class _MedicineSearchField extends StatefulWidget {
  final String initialName;
  final void Function(MedItem) onSelected;
  const _MedicineSearchField({required this.initialName, required this.onSelected});

  @override
  State<_MedicineSearchField> createState() => _MedicineSearchFieldState();
}

class _MedicineSearchFieldState extends State<_MedicineSearchField> {
  late TextEditingController _ctrl;
  Timer? _debounce;
  List<MedItem> _results = [];
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.length < 2) {
      setState(() { _results = []; _show = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final r = await ExamService.instance.searchMedicines(v);
        if (mounted) setState(() { _results = r; _show = r.isNotEmpty; });
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextFormField(
        controller: _ctrl,
        onChanged: _onChanged,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(hintText: 'Search medicine...', hintStyle: TextStyle(fontSize: 11, color: AppColors.primaryA35), prefixIcon: Icon(Icons.medication_rounded, size: 16, color: AppColors.primary), contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: AppColors.primaryA15))),
      ),
      if (_show)
        Container(
          margin: const EdgeInsets.only(top: 2),
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: AppColors.primaryA15), boxShadow: [BoxShadow(color: AppColors.primaryA10, blurRadius: 8, offset: const Offset(0, 3))]),
          child: ListView(
            shrinkWrap: true,
            children: _results.take(6).map((m) {
              final meta = [if (m.medicineTypeName != null) m.medicineTypeName!, if (m.duration != null) '${m.duration} days'].join(' · ');
              return InkWell(
                onTap: () { _ctrl.text = m.name; setState(() => _show = false); widget.onSelected(m); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)), if (meta.isNotEmpty) Text(meta, style: TextStyle(fontSize: 10, color: AppColors.primaryA55))])),
                    if (m.dosageText != null) Container(margin: const EdgeInsets.only(left: 6, top: 1), padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(AppRadius.xs)), child: Text(m.dosageText!, style: const TextStyle(fontSize: 10, color: Color(0xFF0369A1), fontWeight: FontWeight.w500))),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
    ]);
  }
}
