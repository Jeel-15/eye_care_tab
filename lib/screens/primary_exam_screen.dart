import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/auth_models.dart';
import '../models/patient_models.dart';
import '../services/exam_masters_service.dart';
import '../services/exam_service.dart';
import '../services/referrer_service.dart';
import '../services/simple_master_service.dart';
import '../constants/permissions.dart';
import '../models/medicine_models.dart';
import '../services/permission_service.dart';
import '../utils/app_route.dart';
import '../widgets/app_animations.dart';
import '../widgets/exam/advice_picker.dart';
import '../widgets/exam/diagnosis_grouped_chips.dart';
import '../widgets/exam/exam_field_widgets.dart';
import '../widgets/exam/exam_live_slip.dart';
import '../widgets/exam/exam_section_sheet.dart';
import '../widgets/exam/exam_finish_chooser.dart';
import '../widgets/exam/exam_sections.dart';
import '../widgets/exam/exam_stepper.dart';
import '../widgets/ot/recommend_surgery_dialog.dart';
import '../widgets/patient_details_modal.dart';
import '../widgets/skeleton.dart';
import 'secondary_exam_screen.dart';

class _CoRow {
  final TextEditingController complaintCtrl;
  String since, unit, eye, comment;
  // Field-chain auto-advance (complaint → since → unit → eye → comment,
  // matching web's advanceExamRowField) lands here after the eye picker.
  final FocusNode commentFocus = FocusNode();
  _CoRow({
    String complaint = '',
    this.since = '-',
    this.unit = 'Days',
    this.eye = '-',
    this.comment = '',
  }) : complaintCtrl = TextEditingController(text: complaint);
  void dispose() {
    complaintCtrl.dispose();
    commentFocus.dispose();
  }

  Map<String, dynamic> toJson() => {
    'complaint': complaintCtrl.text,
    'since': since == '-' ? '' : since,
    'unit': unit,
    'eye': eye == '-' ? '' : eye,
    'comment': comment,
  };
}

class _KcoRow {
  final TextEditingController conditionCtrl;
  String since, unit, comment;
  // Field-chain auto-advance (condition → since → unit → comment) lands
  // here after the unit picker.
  final FocusNode commentFocus = FocusNode();
  _KcoRow({
    String condition = '',
    this.since = '-',
    this.unit = 'Years',
    this.comment = '',
  }) : conditionCtrl = TextEditingController(text: condition);
  void dispose() {
    conditionCtrl.dispose();
    commentFocus.dispose();
  }

  Map<String, dynamic> toJson() => {
    'condition': conditionCtrl.text,
    'since': since == '-' ? '' : since,
    'unit': unit,
    'comment': comment,
  };
}

/// Tablet Primary Exam — web-parity shell:
/// sticky stepper + live clinical slip; one section sheet at a time with Done
/// → auto-advance. Dilate commits (Yes → exit; No → open Secondary).
class PrimaryExamScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;
  final Patient patient;
  const PrimaryExamScreen({
    super.key,
    required this.user,
    required this.hospital,
    required this.patient,
  });

  @override
  State<PrimaryExamScreen> createState() => _PrimaryExamScreenState();
}

class _PrimaryExamScreenState extends State<PrimaryExamScreen> {
  // Web pull 2026-09-29 (WEB_VIEW_BUTTONS_PARITY_AUDIT.md finding #2) — the
  // "Patient Details" modal can edit name/age/gender/contact/city; this
  // holds the latest saved copy so the header reflects it without needing
  // `widget.patient` (a `final`) to change. Everything else in this screen
  // keeps using `widget.patient.id` for saves, unaffected by this edit.
  late Patient _currentPatient;
  bool _loading = true;
  String? _loadError;
  bool _anySaved = false;
  bool _committing = false;
  int? _selectedDoctorId;
  ExamFormData? _formData;
  ExamSection? _activeSection;
  final Set<ExamSection> _filled = {};
  bool _sheetOpen = false;
  final ValueNotifier<int> _sheetTick = ValueNotifier(0);

  /// Guards the section-open auto-advance below so it fires exactly once
  /// per sheet open, not on every _sheetTick rebuild.
  bool _autoOpenDone = false;

  /// Web parity: modalClinical/modalHko/modalVision's `shown.bs.modal`
  /// handlers open the first field's picker immediately, no manual tap
  /// needed. Called from a field's `exposeOpener` the first time it builds
  /// after a section sheet opens.
  void _autoOpenFirstField(VoidCallback open) {
    if (_autoOpenDone) return;
    _autoOpenDone = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) open();
      });
    });
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (_sheetOpen) _sheetTick.value++;
  }

  final List<String> _historyChips = [];
  final List<_CoRow> _coRows = [];
  final List<_KcoRow> _kcoRows = [];

  final _vnRe = TextEditingController(), _vnLe = TextEditingController();
  final _pnvnRe = TextEditingController(), _pnvnLe = TextEditingController();
  final _nrvnRe = TextEditingController(), _nrvnLe = TextEditingController();
  final _nctIopRe = TextEditingController(),
      _nctIopLe = TextEditingController();

  static const _pgDistKeys = ['ds', 'dc', 'ax', 'vn'];
  static const _pgNearKeys = ['ns', 'nc', 'na', 'near_vn'];
  late final Map<String, Map<String, TextEditingController>> _pg;

  static const _stDistKeys = ['ds', 'dc', 'ax', 'vn'];
  late final Map<String, Map<String, TextEditingController>> _st;
  final _stAddRe = TextEditingController(), _stAddLe = TextEditingController();
  final _stNsRe = TextEditingController(), _stNsLe = TextEditingController();
  bool _bifocal = false,
      _ndSeparate = false,
      _progressive = false,
      _computerUses = false;

  static const _oeFieldNames = [
    'sac',
    'lid',
    'conj',
    'cornea',
    'ac',
    'iris',
    'pupil',
    'lens',
    'em',
    'covertest',
    'other',
  ];
  // Client request (2026-10-07): matches web's actual visible row labels
  // exactly (`$oeFieldMeta[...]['label']` in primary.blade.php — web keeps
  // a separate, unused 'full' name alongside these for every field).
  static const _oeLabels = {
    'sac': 'SAC',
    'lid': 'LID',
    'conj': 'CONJ',
    'cornea': 'CORNEA',
    'ac': 'AC',
    'iris': 'IRIS',
    'pupil': 'PUPIL',
    'lens': 'LENS',
    'em': 'EM',
    'covertest': 'COVERTEST',
    'other': 'Other',
  };
  late final Map<String, TextEditingController> _oeRe, _oeLe;
  Map<String, List<ExamMasterItem>> _oeMasters = {};
  static const _oeMasterApiType = {
    'sac': 'sac',
    'lid': 'lid',
    'conj': 'conj',
    'cornea': 'cornea',
    'ac': 'ac',
    'iris': 'iris',
    'pupil': 'pupil',
    'lens': 'lens_master',
    'em': 'em',
    'covertest': 'covertest',
  };
  String _pseudoOpRe = 'Phaco', _pseudoOpLe = 'Phaco';
  final _pseudoExpRe = TextEditingController(),
      _pseudoExpLe = TextEditingController();
  final _pseudoHospRe = TextEditingController(),
      _pseudoHospLe = TextEditingController();
  List<ExamMasterItem> _referrers = [];

  final _fundusDiscRe = TextEditingController(),
      _fundusDiscLe = TextEditingController();
  final _fundusFrRe = TextEditingController(),
      _fundusFrLe = TextEditingController();
  final _fundusCommentRe = TextEditingController(),
      _fundusCommentLe = TextEditingController();
  final _fundusCommentReFocus = FocusNode(),
      _fundusCommentLeFocus = FocusNode();
  List<ExamMasterItem> _fundusDiscMasters = [], _fundusFrMasters = [];

  String _dilate = 'No';
  final _dilationTimeCtrl = TextEditingController();
  List<ExamMasterItem> _diagnosisMasters = [];
  List<ExamMasterItem> _adviceMasters = [];
  final Set<int> _selectedDiagnosisIds = {};
  String _diagnosisSearch = '';
  final _adviceCtrl = TextEditingController();
  final List<_PrescRow> _medicines = [];

  @override
  void initState() {
    super.initState();
    _currentPatient = widget.patient;
    _pg = {
      're': {
        for (final k in [..._pgDistKeys, ..._pgNearKeys])
          k: TextEditingController(),
      },
      'le': {
        for (final k in [..._pgDistKeys, ..._pgNearKeys])
          k: TextEditingController(),
      },
    };
    _st = {
      're': {for (final k in _stDistKeys) k: TextEditingController()},
      'le': {for (final k in _stDistKeys) k: TextEditingController()},
    };
    _oeRe = {for (final f in _oeFieldNames) f: TextEditingController()};
    _oeLe = {for (final f in _oeFieldNames) f: TextEditingController()};
    _loadAll();
  }

  @override
  void dispose() {
    _vnRe.dispose();
    _vnLe.dispose();
    _pnvnRe.dispose();
    _pnvnLe.dispose();
    _nrvnRe.dispose();
    _nrvnLe.dispose();
    _nctIopRe.dispose();
    _nctIopLe.dispose();
    for (final e in _pg.values) {
      for (final c in e.values) {
        c.dispose();
      }
    }
    for (final e in _st.values) {
      for (final c in e.values) {
        c.dispose();
      }
    }
    _stAddRe.dispose();
    _stAddLe.dispose();
    _stNsRe.dispose();
    _stNsLe.dispose();
    for (final c in _oeRe.values) {
      c.dispose();
    }
    for (final c in _oeLe.values) {
      c.dispose();
    }
    _pseudoExpRe.dispose();
    _pseudoExpLe.dispose();
    _pseudoHospRe.dispose();
    _pseudoHospLe.dispose();
    _fundusDiscRe.dispose();
    _fundusDiscLe.dispose();
    _fundusFrRe.dispose();
    _fundusFrLe.dispose();
    _fundusCommentRe.dispose();
    _fundusCommentLe.dispose();
    _dilationTimeCtrl.dispose();
    _adviceCtrl.dispose();
    _fundusCommentReFocus.dispose();
    _fundusCommentLeFocus.dispose();
    for (final r in _coRows) {
      r.dispose();
    }
    for (final r in _kcoRows) {
      r.dispose();
    }
    _sheetTick.dispose();
    super.dispose();
  }

  // ── Load / prefill ──────────────────────────────────────────────────

  Future<void> _loadAll() async {
    final cacheHit = ExamMastersService.instance.isCacheValid;
    if (!cacheHit)
      setState(() {
        _loading = true;
        _loadError = null;
      });
    try {
      final formData = await ExamService.instance.loadFormData();
      final existing = await ExamService.instance.loadPrimaryExam(
        widget.patient.id,
      );
      final referrers = await ReferrerService.instance.fetchAll();
      if (!mounted) return;
      setState(() {
        _formData = formData;
        _oeMasters = {
          for (final f in _oeMasterApiType.keys)
            f: List<ExamMasterItem>.from(formData.masters.oeListFor(f)),
        };
        _fundusDiscMasters = List<ExamMasterItem>.from(formData.masters.disc);
        _fundusFrMasters = List<ExamMasterItem>.from(formData.masters.fr);
        _diagnosisMasters = List<ExamMasterItem>.from(
          formData.masters.diagnoses,
        );
        _adviceMasters = List<ExamMasterItem>.from(formData.masters.advices);
        // Pseudophakia panel's Hospital field autocompletes from the
        // Referrers master list, matching web (StorePrimaryExamRequest's
        // hospital_name field uses a datalist sourced from $masters['referrers']).
        _referrers = referrers
            .map(
              (r) =>
                  ExamMasterItem(id: r.id, value: r.name, isFavourite: false),
            )
            .toList();
        // Mirrors web's $currentDoctorId fallback exactly
        // (PrimaryExamController::show()) — never leaves this null, since
        // there's no picker UI for it in either app or on web (web sets it
        // via a hidden field). If you're a doctor, the exam is always
        // attributed to you; otherwise fall back to the patient's assigned
        // doctor, then to you as a last resort.
        _selectedDoctorId = widget.user.role?.slug == 'doctor'
            ? widget.user.id
            : (widget.patient.doctor?.id ?? widget.user.id);
        if (existing != null) _prefill(existing);
        _refreshFilledFlags();
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _loadError = e.toString();
          _loading = false;
        });
    }
  }

  void _prefill(Map<String, dynamic> exam) {
    final raw = exam['exam_data'];
    Map<String, dynamic> ed = {};
    if (raw is Map<String, dynamic>) {
      ed = raw;
    } else if (raw is String && raw.isNotEmpty) {
      try {
        ed = jsonDecode(raw) as Map<String, dynamic>? ?? {};
      } catch (_) {}
    }
    _historyChips
      ..clear()
      ..addAll(
        ((ed['history'] as String?) ?? '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty),
      );
    for (final r in (ed['co_rows'] as List? ?? [])) {
      final m = r as Map<String, dynamic>;
      _coRows.add(
        _CoRow(
          complaint: m['complaint'] as String? ?? '',
          since: (m['since'] as String? ?? '').isEmpty
              ? '-'
              : m['since'] as String,
          unit: m['unit'] as String? ?? 'Days',
          eye: (m['eye'] as String? ?? '').isEmpty ? '-' : m['eye'] as String,
          comment: m['comment'] as String? ?? '',
        ),
      );
    }
    for (final r in (ed['kco_rows'] as List? ?? [])) {
      final m = r as Map<String, dynamic>;
      _kcoRows.add(
        _KcoRow(
          condition: m['condition'] as String? ?? '',
          since: (m['since'] as String? ?? '').isEmpty
              ? '-'
              : m['since'] as String,
          unit: m['unit'] as String? ?? 'Years',
          comment: m['comment'] as String? ?? '',
        ),
      );
    }
    final vd = ed['vision'] as Map<String, dynamic>? ?? {};
    _vnRe.text = vd['vn_re'] as String? ?? '';
    _vnLe.text = vd['vn_le'] as String? ?? '';
    _pnvnRe.text = vd['pnvn_re'] as String? ?? '';
    _pnvnLe.text = vd['pnvn_le'] as String? ?? '';
    _nrvnRe.text = vd['nrvn_re'] as String? ?? '';
    _nrvnLe.text = vd['nrvn_le'] as String? ?? '';
    final pgd = ed['pg'] as Map<String, dynamic>? ?? {};
    for (final eye in ['re', 'le']) {
      final ev = pgd[eye] as Map<String, dynamic>? ?? {};
      for (final k in [..._pgDistKeys, ..._pgNearKeys]) {
        _pg[eye]![k]!.text = ev[k] as String? ?? '';
      }
    }
    final std = ed['st'] as Map<String, dynamic>? ?? {};
    for (final eye in ['re', 'le']) {
      final ev = std[eye] as Map<String, dynamic>? ?? {};
      for (final k in _stDistKeys) {
        _st[eye]![k]!.text = ev[k] as String? ?? '';
      }
    }
    _stAddRe.text =
        (std['re'] as Map<String, dynamic>?)?['add'] as String? ?? '';
    _stAddLe.text =
        (std['le'] as Map<String, dynamic>?)?['add'] as String? ?? '';
    _stNsRe.text = (std['re'] as Map<String, dynamic>?)?['ns'] as String? ?? '';
    _stNsLe.text = (std['le'] as Map<String, dynamic>?)?['ns'] as String? ?? '';
    _bifocal = std['bifocal'] == true;
    _ndSeparate = std['nd_separate'] == true;
    _progressive = std['progressive'] == true;
    _computerUses = std['computer_uses'] == true;
    final nct = ed['nct'] as Map<String, dynamic>? ?? {};
    _nctIopRe.text = nct['iop_re'] as String? ?? '';
    _nctIopLe.text = nct['iop_le'] as String? ?? '';
    final oed = ed['oe'] as Map<String, dynamic>? ?? {};
    for (final f in _oeFieldNames) {
      _oeRe[f]!.text = oed['${f}_re'] as String? ?? '';
      _oeLe[f]!.text = oed['${f}_le'] as String? ?? '';
    }
    final pseudoRe = oed['pseudophakia_re'] as Map<String, dynamic>? ?? {};
    _pseudoOpRe = pseudoRe['operation_type'] as String? ?? 'Phaco';
    _pseudoExpRe.text = pseudoRe['operation_expense'] as String? ?? '';
    _pseudoHospRe.text = pseudoRe['hospital_name'] as String? ?? '';
    final pseudoLe = oed['pseudophakia_le'] as Map<String, dynamic>? ?? {};
    _pseudoOpLe = pseudoLe['operation_type'] as String? ?? 'Phaco';
    _pseudoExpLe.text = pseudoLe['operation_expense'] as String? ?? '';
    _pseudoHospLe.text = pseudoLe['hospital_name'] as String? ?? '';
    final fundus = ed['fundus'] as Map<String, dynamic>? ?? {};
    _fundusDiscRe.text = fundus['disc_re'] as String? ?? '';
    _fundusDiscLe.text = fundus['disc_le'] as String? ?? '';
    _fundusFrRe.text = fundus['fr_re'] as String? ?? '';
    _fundusFrLe.text = fundus['fr_le'] as String? ?? '';
    _fundusCommentRe.text = fundus['comment_re'] as String? ?? '';
    _fundusCommentLe.text = fundus['comment_le'] as String? ?? '';
    _dilate = ed['dilate'] as String? ?? 'No';
    _dilationTimeCtrl.text = (exam['dilation_time'] as int?)?.toString() ?? '';
    for (final d in (ed['diagnoses'] as List? ?? [])) {
      final id = d is int ? d : int.tryParse(d.toString());
      if (id != null) _selectedDiagnosisIds.add(id);
    }
    _adviceCtrl.text = ed['advice'] as String? ?? '';
    for (final m in (exam['prescriptions'] as List? ?? [])) {
      final row = m as Map<String, dynamic>;
      _medicines.add(
        _PrescRow(
          medicineId: row['medicine_id'] as int?,
          medicineName:
              (row['medicine'] as Map<String, dynamic>?)?['name'] as String? ??
              '',
          dosageId: row['dosage_id'] as int?,
          routeId: row['route_id'] as int?,
          duration: row['duration'] as String? ?? '',
          quantity: (row['quantity'] as num?)?.toInt() ?? 1,
        ),
      );
    }
    for (final m in (ed['rx'] as List? ?? [])) {
      final row = m as Map<String, dynamic>;
      _medicines.add(
        _PrescRow(
          medicineId: row['medicine_id'] as int?,
          medicineName: row['name'] as String? ?? '',
          dosageId: row['dosage_id'] as int?,
          routeId: row['route_id'] as int?,
          duration: row['duration'] as String? ?? '',
          quantity: (row['quantity'] as num?)?.toInt() ?? 1,
        ),
      );
    }
  }

  // ── Save / commit (web: Dilate submits primary) ───────────────────────

  bool _isPseudo(String eye) => (eye == 're' ? _oeRe['lens'] : _oeLe['lens'])!
      .text
      .toLowerCase()
      .contains('pseudophakia');

  Map<String, dynamic> _buildFullExamData() {
    final examData = <String, dynamic>{};
    examData['history'] = _historyChips.join(', ');
    examData['co_rows'] = _coRows.map((r) => r.toJson()).toList();
    examData['kco_rows'] = _kcoRows.map((r) => r.toJson()).toList();

    final v = <String, dynamic>{};
    void putV(String k, String val) {
      if (val.isNotEmpty) v[k] = val;
    }

    putV('vn_re', _vnRe.text.trim());
    putV('vn_le', _vnLe.text.trim());
    putV('pnvn_re', _pnvnRe.text.trim());
    putV('pnvn_le', _pnvnLe.text.trim());
    putV('nrvn_re', _nrvnRe.text.trim());
    putV('nrvn_le', _nrvnLe.text.trim());
    if (v.isNotEmpty) examData['vision'] = v;

    final pg = <String, dynamic>{};
    for (final eye in ['re', 'le']) {
      final ev = <String, String>{};
      for (final k in [..._pgDistKeys, ..._pgNearKeys]) {
        final val = _pg[eye]![k]!.text.trim();
        if (val.isNotEmpty) ev[k] = val;
      }
      if (ev.isNotEmpty) pg[eye] = ev;
    }
    if (pg.isNotEmpty) examData['pg'] = pg;

    final st = <String, dynamic>{};
    for (final eye in ['re', 'le']) {
      final ev = <String, String>{};
      for (final k in _stDistKeys) {
        final val = _st[eye]![k]!.text.trim();
        if (val.isNotEmpty) ev[k] = val;
      }
      final addVal = eye == 're' ? _stAddRe.text.trim() : _stAddLe.text.trim();
      final nsVal = eye == 're' ? _stNsRe.text.trim() : _stNsLe.text.trim();
      if (addVal.isNotEmpty) ev['add'] = addVal;
      if (nsVal.isNotEmpty) ev['ns'] = nsVal;
      final dcVal = _st[eye]!['dc']!.text.trim();
      final axVal = _st[eye]!['ax']!.text.trim();
      if (dcVal.isNotEmpty) ev['nc'] = dcVal;
      if (axVal.isNotEmpty) ev['na'] = axVal;
      if (ev.isNotEmpty) st[eye] = ev;
    }
    if (_bifocal) st['bifocal'] = true;
    if (_ndSeparate) st['nd_separate'] = true;
    if (_progressive) st['progressive'] = true;
    if (_computerUses) st['computer_uses'] = true;
    if (st.isNotEmpty) examData['st'] = st;

    final nct = <String, dynamic>{};
    if (_nctIopRe.text.trim().isNotEmpty) nct['iop_re'] = _nctIopRe.text.trim();
    if (_nctIopLe.text.trim().isNotEmpty) nct['iop_le'] = _nctIopLe.text.trim();
    if (nct.isNotEmpty) examData['nct'] = nct;

    final oe = <String, dynamic>{};
    for (final f in _oeFieldNames) {
      if (_oeRe[f]!.text.trim().isNotEmpty)
        oe['${f}_re'] = _oeRe[f]!.text.trim();
      if (_oeLe[f]!.text.trim().isNotEmpty)
        oe['${f}_le'] = _oeLe[f]!.text.trim();
    }
    if (_isPseudo('re'))
      oe['pseudophakia_re'] = {
        'operation_type': _pseudoOpRe,
        'operation_expense': _pseudoExpRe.text.trim(),
        'hospital_name': _pseudoHospRe.text.trim(),
      };
    if (_isPseudo('le'))
      oe['pseudophakia_le'] = {
        'operation_type': _pseudoOpLe,
        'operation_expense': _pseudoExpLe.text.trim(),
        'hospital_name': _pseudoHospLe.text.trim(),
      };
    if (oe.isNotEmpty) examData['oe'] = oe;

    final fundus = <String, dynamic>{};
    void putF(String k, String val) {
      if (val.isNotEmpty) fundus[k] = val;
    }

    putF('disc_re', _fundusDiscRe.text.trim());
    putF('disc_le', _fundusDiscLe.text.trim());
    putF('fr_re', _fundusFrRe.text.trim());
    putF('fr_le', _fundusFrLe.text.trim());
    putF('comment_re', _fundusCommentRe.text.trim());
    putF('comment_le', _fundusCommentLe.text.trim());
    if (fundus.isNotEmpty) examData['fundus'] = fundus;

    examData['dilate'] = _dilate;
    examData['diagnoses'] = _selectedDiagnosisIds.toList();
    examData['advice'] = _adviceCtrl.text.trim();
    return examData;
  }

  bool get _secondaryClinicalFilled {
    if (_selectedDiagnosisIds.isNotEmpty) return true;
    if (_adviceCtrl.text.trim().isNotEmpty) return true;
    return _medicines.any((m) => m.medicineName.trim().isNotEmpty);
  }

  Map<String, dynamic> _examPayload({required bool isFinal}) {
    final payload = <String, dynamic>{
      'doctor_id': _selectedDoctorId,
      'exam_data': _buildFullExamData(),
    };
    if (!isFinal) payload['is_final'] = false;
    if (_dilate == 'Yes' && _dilationTimeCtrl.text.trim().isNotEmpty) {
      payload['dilation_time'] = int.tryParse(_dilationTimeCtrl.text.trim());
    }
    final medicines = _medicines
        .where((m) => m.medicineId != null || m.medicineName.isNotEmpty)
        .map((m) => m.toJson())
        .toList();
    if (medicines.isNotEmpty) payload['medicines'] = medicines;
    return payload;
  }

  void _refreshFilledFlags() {
    final ed = _buildFullExamData();
    void mark(ExamSection s, bool ok) {
      if (ok) {
        _filled.add(s);
      } else {
        _filled.remove(s);
      }
    }

    mark(
      ExamSection.co,
      (ed['co_rows'] as List).any(
        (r) => (r as Map)['complaint']?.toString().trim().isNotEmpty == true,
      ),
    );
    mark(
      ExamSection.kcoHo,
      (ed['kco_rows'] as List).any(
            (r) =>
                (r as Map)['condition']?.toString().trim().isNotEmpty == true,
          ) ||
          _historyChips.isNotEmpty,
    );
    mark(
      ExamSection.vision,
      ed['vision'] is Map && (ed['vision'] as Map).isNotEmpty,
    );
    mark(ExamSection.pg, ed['pg'] is Map && (ed['pg'] as Map).isNotEmpty);
    mark(ExamSection.st, ed['st'] is Map && (ed['st'] as Map).isNotEmpty);
    mark(ExamSection.nct, ed['nct'] is Map && (ed['nct'] as Map).isNotEmpty);
    mark(ExamSection.oe, ed['oe'] is Map && (ed['oe'] as Map).isNotEmpty);
    mark(
      ExamSection.fundus,
      ed['fundus'] is Map && (ed['fundus'] as Map).isNotEmpty,
    );
    mark(ExamSection.dilate, true);
    mark(ExamSection.diagnosis, _selectedDiagnosisIds.isNotEmpty);
    mark(
      ExamSection.medicine,
      _medicines.any(
        (m) => m.medicineId != null || m.medicineName.trim().isNotEmpty,
      ),
    );
    mark(ExamSection.advice, _adviceCtrl.text.trim().isNotEmpty);
  }

  Future<void> _persistExam({required bool completeSecondary}) async {
    await ExamService.instance.savePrimaryExam(
      widget.patient.id,
      _examPayload(isFinal: true),
    );
    if (completeSecondary) {
      await ExamService.instance.saveSecondaryExam(
        widget.patient.id,
        _examPayload(isFinal: true),
      );
    }
    _anySaved = true;
  }

  Future<void> _showFinishChooser() async {
    if (!mounted || _committing) return;
    final choice = await showExamFinishChooser(
      context,
      canRecommend: PermissionService.instance.can(Perm.otSurgeryRecommend),
    );
    if (!mounted || choice == null) return;
    if (choice == ExamFinishChoice.recommendOt) {
      final ok = await showRecommendSurgeryDialog(
        context,
        patient: _currentPatient,
        diagnosisHint: _diagnosisHintText(),
        beforeRecommend: () => _persistExam(completeSecondary: true),
      );
      if (ok == true && mounted) {
        showAppSnackBar(
          context,
          'Primary and secondary saved. Patient sent to Counsellor.',
          isSuccess: true,
        );
        Navigator.of(context).pop(true);
      }
      return;
    }
    await _saveFromPrimary();
  }

  String? _diagnosisHintText() {
    if (_selectedDiagnosisIds.isEmpty) return null;
    final names = _diagnosisMasters
        .where((d) => _selectedDiagnosisIds.contains(d.id))
        .map((d) => d.value);
    final text = names.join(', ');
    return text.isEmpty ? null : text;
  }

  Future<void> _saveFromPrimary() async {
    if (_committing) return;
    if (_dilate == 'Yes' && _dilationTimeCtrl.text.trim().isEmpty) {
      showAppSnackBar(context, 'Enter dilation minutes.', isError: true);
      await _openSection(ExamSection.dilate);
      return;
    }
    setState(() => _committing = true);
    try {
      final completeSecondary = _dilate != 'Yes' && _secondaryClinicalFilled;
      await _persistExam(completeSecondary: completeSecondary);
      if (!mounted) return;
      setState(() => _committing = false);
      if (_dilate == 'Yes') {
        showAppSnackBar(
          context,
          'Primary exam saved. Wait for dilation, then continue Secondary.',
          isSuccess: true,
        );
        Navigator.of(context).pop(true);
      } else if (completeSecondary) {
        showAppSnackBar(
          context,
          'Primary and secondary examination saved.',
          isSuccess: true,
        );
        Navigator.of(context).pop(true);
      } else {
        // Pass result: true so the dashboard's `push<bool>` awaiter (which
        // resolves to this replaced route's completion, not the new one's)
        // sees the primary save and refreshes its queues immediately —
        // otherwise it resolves with null and the list never shows this
        // patient as Primary Done until some unrelated refresh happens.
        await Navigator.of(context).pushReplacement(
          appRoute(
            SecondaryExamScreen(
              user: widget.user,
              hospital: widget.hospital,
              patient: widget.patient,
            ),
          ),
          result: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _committing = false);
        showAppSnackBar(
          context,
          e.toString(),
          isError: true,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  /// Auto-save on every section's Done — not just the final commit — so an
  /// accidental back-navigation never loses already-entered data. Sends the
  /// same full accumulated payload the final commit uses (never a
  /// per-section fragment — see _commitPrimary's history: a fragment-only
  /// save was tried before and caused data loss for sections the user
  /// never explicitly re-saved). The backend upserts on patient id, so
  /// repeated calls are safe. Fired in the background (not awaited by the
  /// caller) so it never slows down the section-to-section auto-advance.
  Future<void> _autoSaveProgress() async {
    try {
      // is_final: false — tells the API this isn't the doctor's actual
      // finish, so it must not stamp the patient as "Primary Done" if the
      // doctor backs out before completing every section.
      await ExamService.instance.savePrimaryExam(
        widget.patient.id,
        _examPayload(isFinal: false),
      );
      if (mounted) _anySaved = true;
    } catch (_) {
      if (mounted)
        showAppSnackBar(
          context,
          'Progress not synced — check connection.',
          isError: true,
        );
    }
  }

  /// Web parity for "Start / Continue": resumes at the first section that
  /// isn't filled yet instead of always restarting at C/O, so reopening
  /// this screen after an accidental back-navigation picks up where the
  /// user left off.
  ExamSection _nextIncompleteSection() {
    for (final s in kPrimaryPageSections) {
      if (!_filled.contains(s)) return s;
    }
    return kPrimaryPageSections.last;
  }

  Future<void> _openSection(
    ExamSection section, {
    bool autoOpened = false,
  }) async {
    if (_sheetOpen || _loading || _loadError != null) return;
    _autoOpenDone = false;
    setState(() {
      _activeSection = section;
      _sheetOpen = true;
    });
    final close = await showExamSectionSheet(
      context: context,
      userId: widget.user.id,
      section: section,
      listenable: _sheetTick,
      doneLabel: 'Done',
      builder: (_) => _sectionBody(section),
    );
    if (!mounted) return;
    setState(() {
      _sheetOpen = false;
      _refreshFilledFlags();
      if (close == ExamSectionClose.done) _filled.add(section);
    });

    if (close != ExamSectionClose.done) {
      setState(() => _activeSection = null);
      return;
    }

    if (section == ExamSection.dilate &&
        _dilate == 'Yes' &&
        _dilationTimeCtrl.text.trim().isEmpty) {
      showAppSnackBar(context, 'Enter dilation minutes.', isError: true);
      await _openSection(ExamSection.dilate);
      return;
    }

    // Web: Dilate Yes + Done saves primary and returns to the dashboard.
    if (section == ExamSection.dilate && _dilate == 'Yes') {
      await _saveFromPrimary();
      return;
    }

    unawaited(_autoSaveProgress());

    final next = nextExamSection(section, kPrimaryPageSections);
    if (next != null) {
      await _openSection(next, autoOpened: true);
    } else {
      setState(() => _activeSection = null);
      unawaited(_showFinishChooser());
    }
  }

  Widget _sectionBody(ExamSection section) {
    switch (section) {
      case ExamSection.co:
        return _coBody();
      case ExamSection.kcoHo:
        return _kcoHoBody();
      case ExamSection.vision:
        return _visionBody();
      case ExamSection.pg:
        return _pgBody();
      case ExamSection.st:
        return _stBody();
      case ExamSection.nct:
        return _nctBody();
      case ExamSection.oe:
        return _oeBody();
      case ExamSection.fundus:
        return _fundusBody();
      case ExamSection.dilate:
        return _dilateBody();
      case ExamSection.diagnosis:
        return _diagnosisBody();
      case ExamSection.medicine:
        return _medicineBody();
      case ExamSection.advice:
        return _adviceBody();
      case ExamSection.surgery:
        return const SizedBox.shrink();
    }
  }

  // ── Favourite toggle ──────────────────────────────────────────────────

  Future<void> _refreshMasters() async {
    final masters = await ExamMastersService.instance.fetchAll(
      forceRefresh: true,
    );
    if (!mounted) return;
    setState(() {
      _formData = ExamFormData(
        dosages: _formData?.dosages ?? [],
        routes: _formData?.routes ?? [],
        masters: masters,
        medGroups: _formData?.medGroups ?? [],
        medicines: _formData?.medicines ?? [],
      );
      _oeMasters = {
        for (final f in _oeMasterApiType.keys)
          f: List<ExamMasterItem>.from(masters.oeListFor(f)),
      };
      _fundusDiscMasters = List<ExamMasterItem>.from(masters.disc);
      _fundusFrMasters = List<ExamMasterItem>.from(masters.fr);
      _diagnosisMasters = List<ExamMasterItem>.from(masters.diagnoses);
      _adviceMasters = List<ExamMasterItem>.from(masters.advices);
    });
  }

  Future<bool> _toggleFav(String masterType, ExamMasterItem item) async {
    final newFav = await SimpleMasterService.instance.toggleFavourite(
      'masters/detail/$masterType',
      item.id,
    );
    unawaited(_refreshMasters());
    return newFav;
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_anySaved);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEBF5FB),
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const AppSkeletonList(count: 5, itemHeight: 120)
                  : _loadError != null
                  ? _buildError()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ExamStepper(
                            sections: kPrimaryPageSections,
                            secondaryFrom: ExamSection.diagnosis,
                            active: _activeSection,
                            filled: _filled,
                            onSelect: (s) => _openSection(s),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: ExamLiveSlip(examData: _buildFullExamData()),
                          ),
                        ],
                      ),
                    ),
            ),
            if (_committing) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final p = _currentPatient;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.blueLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 20, 14),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(_anySaved),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.remove_red_eye_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Primary Examination',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${p.fullName}  ·  MRD: ${p.patientCode}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Web pull 2026-09-29 — `exam/_patient_info_modal.blade.php`'s
              // "Patient Details" button (WEB_VIEW_BUTTONS_PARITY_AUDIT.md #2).
              if (widget.user.role?.slug == 'doctor')
                IconButton(
                  icon: const Icon(Icons.badge_outlined, color: Colors.white),
                  tooltip: 'Patient Details',
                  onPressed: () => showPatientDetailsModal(
                    context,
                    p,
                    onSaved: (updated) =>
                        setState(() => _currentPatient = updated),
                  ),
                ),
              TextButton.icon(
                onPressed: _loading || _loadError != null
                    ? null
                    : () => _openSection(_nextIncompleteSection()),
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                label: const Text(
                  'Start / Continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.red),
        const SizedBox(height: 12),
        Text(_loadError ?? 'Failed to load exam.', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _loadAll,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
        ),
      ],
    ),
  );

  // ── C/O ───────────────────────────────────────────────────────────────

  /// Web parity (getCoModalFocusTarget): the section's first-open auto-open
  /// targets the last row with an empty complaint, or — since apps have no
  /// standalone top search bar like web's #coSearch — auto-adds a fresh
  /// blank row when every row is already filled (or none exist), then
  /// targets that one instead.
  _CoRow? _coAutoOpenTarget() {
    if (_autoOpenDone) return null;
    for (final r in _coRows.reversed) {
      if (r.complaintCtrl.text.trim().isEmpty) return r;
    }
    final row = _CoRow();
    _coRows.add(row);
    return row;
  }

  Widget _coBody() {
    final favs = (_formData?.masters.chiefComplaints ?? [])
        .where((c) => c.isFavourite)
        .toList();
    final autoTarget = _coAutoOpenTarget();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FavouriteChipRow(
          favourites: favs,
          onTapAdd: (item) =>
              setState(() => _coRows.add(_CoRow(complaint: item.value))),
          onUnfavourite: (item) => _toggleFav('complaints', item),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                'Complaints',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            _addBtn(() => setState(() => _coRows.add(_CoRow()))),
          ],
        ),
        const SizedBox(height: 8),
        if (_coRows.isEmpty)
          _emptyHint('No complaints added')
        else
          ..._coRows.asMap().entries.map(
            (e) => _coRowWidget(
              e.key,
              e.value,
              autoOpen: identical(e.value, autoTarget),
            ),
          ),
      ],
    );
  }

  // Field-chain auto-advance for C/O and K/C/O rows — matches web's
  // advanceExamRowField: complaint/condition → since → unit → (eye) →
  // comment. Each picker opens the next one on completion, ending on a
  // plain focus request for the comment text field.
  static const _sinceOptions = [
    '-',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
  ];
  static const _unitOptions = ['Days', 'Weeks', 'Months', 'Years', 'Longtime'];
  static const _eyeOptions = ['-', 'RE', 'LE', 'Both', 'OU'];

  Widget _coRowWidget(int idx, _CoRow row, {bool autoOpen = false}) {
    final safeEye = _eyeOptions.contains(row.eye) ? row.eye : '-';
    final safeSince = _sinceOptions.contains(row.since) ? row.since : '-';
    late VoidCallback openSince, openUnit, openEye;

    return Container(
      key: ValueKey('co_$idx'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextPickerField(
              controller: row.complaintCtrl,
              hint: 'Complaint',
              items: _formData?.masters.chiefComplaints ?? [],
              showFavourites: true,
              onToggleFavourite: (item) => _toggleFav('complaints', item),
              onChanged: (_) {},
              exposeOpener: autoOpen ? (fn) => _autoOpenFirstField(fn) : null,
              onFinalPick: () async {
                await Future.delayed(const Duration(milliseconds: 150));
                if (mounted) openSince();
              },
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 62,
            child: MiniListPickerField(
              value: safeSince,
              options: _sinceOptions,
              onChanged: (v) => setState(() => row.since = v),
              exposeOpener: (fn) => openSince = fn,
              onFinalPick: () async {
                await Future.delayed(const Duration(milliseconds: 150));
                if (mounted) openUnit();
              },
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 92,
            child: MiniListPickerField(
              value: row.unit,
              options: _unitOptions,
              onChanged: (v) => setState(() => row.unit = v),
              exposeOpener: (fn) => openUnit = fn,
              onFinalPick: () async {
                await Future.delayed(const Duration(milliseconds: 150));
                if (mounted) openEye();
              },
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 62,
            child: MiniListPickerField(
              value: safeEye,
              options: _eyeOptions,
              onChanged: (v) => setState(() => row.eye = v),
              exposeOpener: (fn) => openEye = fn,
              onFinalPick: () => row.commentFocus.requestFocus(),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: _simpleField(
              initial: row.comment,
              hint: 'Comment',
              onChanged: (v) => row.comment = v,
              focusNode: row.commentFocus,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.remove_circle_rounded,
              color: AppColors.red,
              size: 20,
            ),
            onPressed: () => setState(() {
              row.dispose();
              _coRows.removeAt(idx);
            }),
          ),
        ],
      ),
    );
  }

  // ── K/C/O & H/O ───────────────────────────────────────────────────────

  /// See _coAutoOpenTarget — same fallback (auto-add a blank row when none
  /// is empty) for the K/C/O section's first-open auto-open.
  _KcoRow? _kcoAutoOpenTarget() {
    if (_autoOpenDone) return null;
    for (final r in _kcoRows.reversed) {
      if (r.conditionCtrl.text.trim().isEmpty) return r;
    }
    final row = _KcoRow();
    _kcoRows.add(row);
    return row;
  }

  Widget _kcoHoBody() {
    final kcoFavs = (_formData?.masters.kcos ?? [])
        .where((i) => i.isFavourite)
        .toList();
    final autoTarget = _kcoAutoOpenTarget();
    final kco = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FavouriteChipRow(
          favourites: kcoFavs,
          onTapAdd: (item) =>
              setState(() => _kcoRows.add(_KcoRow(condition: item.value))),
          onUnfavourite: (item) => _toggleFav('kcos', item),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                'Known Conditions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            _addBtn(() => setState(() => _kcoRows.add(_KcoRow()))),
          ],
        ),
        const SizedBox(height: 8),
        if (_kcoRows.isEmpty)
          _emptyHint('No conditions added')
        else
          ..._kcoRows.asMap().entries.map(
            (e) => _kcoRowWidget(
              e.key,
              e.value,
              autoOpen: identical(e.value, autoTarget),
            ),
          ),
      ],
    );
    final ho = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'History (H/O)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        _historyChipsSection(),
      ],
    );
    return Column(children: [kco, const SizedBox(height: 16), ho]);
  }

  Widget _kcoRowWidget(int idx, _KcoRow row, {bool autoOpen = false}) {
    final safeSince = _sinceOptions.contains(row.since) ? row.since : '-';
    late VoidCallback openSince, openUnit;

    return Container(
      key: ValueKey('kco_$idx'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextPickerField(
              controller: row.conditionCtrl,
              hint: 'Condition',
              items: _formData?.masters.kcos ?? [],
              showFavourites: true,
              onToggleFavourite: (item) => _toggleFav('kcos', item),
              onChanged: (_) {},
              exposeOpener: autoOpen ? (fn) => _autoOpenFirstField(fn) : null,
              onFinalPick: () async {
                await Future.delayed(const Duration(milliseconds: 150));
                if (mounted) openSince();
              },
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 62,
            child: MiniListPickerField(
              value: safeSince,
              options: _sinceOptions,
              onChanged: (v) => setState(() => row.since = v),
              exposeOpener: (fn) => openSince = fn,
              onFinalPick: () async {
                await Future.delayed(const Duration(milliseconds: 150));
                if (mounted) openUnit();
              },
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 92,
            child: MiniListPickerField(
              value: row.unit,
              options: _unitOptions,
              onChanged: (v) => setState(() => row.unit = v),
              exposeOpener: (fn) => openUnit = fn,
              onFinalPick: () => row.commentFocus.requestFocus(),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: _simpleField(
              initial: row.comment,
              hint: 'Comment',
              onChanged: (v) => row.comment = v,
              focusNode: row.commentFocus,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.remove_circle_rounded,
              color: AppColors.red,
              size: 20,
            ),
            onPressed: () => setState(() {
              row.dispose();
              _kcoRows.removeAt(idx);
            }),
          ),
        ],
      ),
    );
  }

  Widget _historyChipsSection() {
    final hnoItems = _formData?.masters.hno ?? [];
    final favs = hnoItems.where((i) => i.isFavourite).toList();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_historyChips.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _historyChips
                  .map(
                    (chip) => Chip(
                      label: Text(chip, style: const TextStyle(fontSize: 11)),
                      deleteIcon: const Icon(Icons.close, size: 13),
                      onDeleted: () =>
                          setState(() => _historyChips.remove(chip)),
                      backgroundColor: AppColors.primaryA08,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
          if (favs.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: favs.map((item) {
                final sel = _historyChips.contains(item.value);
                return PressScaleWrapper(
                  onTap: () {
                    if (!sel) setState(() => _historyChips.add(item.value));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? Colors.amber.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Text(
                      item.value,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
          MasterSearchAddField(
            items: hnoItems,
            hint: 'Search or type history item…',
            icon: Icons.history_edu_rounded,
            onToggleFavourite: (item) => _toggleFav('hno', item),
            onSelected: (val) {
              if (!_historyChips.contains(val))
                setState(() => _historyChips.add(val));
            },
          ),
        ],
      ),
    );
  }

  // ── Vision ────────────────────────────────────────────────────────────

  // Vision field-chain auto-advance — matches web's advanceVisionField:
  // VN RE → Pinhole RE → Near VN RE → VN LE → Pinhole LE → Near VN LE.
  // `late` openers resolve fine here since they're only ever *called* after
  // a tap, by which point every field's exposeOpener has already fired
  // during the initial build.
  Widget _visionBody() {
    late VoidCallback openPinRe, openNearRe, openVnLe, openPinLe, openNearLe;
    return Table(
      columnWidths: const {0: FixedColumnWidth(40)},
      children: [
        TableRow(
          children: [
            const SizedBox(),
            examTh('VN (Dist)'),
            examTh('Pinhole'),
            examTh('Near VN'),
          ],
        ),
        _visionRow(
          'RE',
          _vnRe,
          _pnvnRe,
          _nrvnRe,
          true,
          exposeVn: (fn) => _autoOpenFirstField(fn),
          exposePin: (fn) => openPinRe = fn,
          exposeNear: (fn) => openNearRe = fn,
          onVnDone: () => openPinRe(),
          onPinDone: () => openNearRe(),
          onNearDone: () => openVnLe(),
        ),
        _visionRow(
          'LE',
          _vnLe,
          _pnvnLe,
          _nrvnLe,
          false,
          exposeVn: (fn) => openVnLe = fn,
          exposePin: (fn) => openPinLe = fn,
          exposeNear: (fn) => openNearLe = fn,
          onVnDone: () => openPinLe(),
          onPinDone: () => openNearLe(),
          onNearDone: null,
        ),
      ],
    );
  }

  TableRow _visionRow(
    String label,
    TextEditingController vn,
    TextEditingController pnvn,
    TextEditingController nrvn,
    bool isRe, {
    required void Function(VoidCallback) exposeVn,
    required void Function(VoidCallback) exposePin,
    required void Function(VoidCallback) exposeNear,
    required VoidCallback onVnDone,
    required VoidCallback onPinDone,
    VoidCallback? onNearDone,
  }) {
    Future<void> delay() => Future.delayed(const Duration(milliseconds: 150));
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isRe ? Colors.red.shade700 : AppColors.primary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: TextPickerField(
            controller: vn,
            hint: 'VN',
            items: _formData?.masters.vn ?? [],
            onChanged: (_) {},
            exposeOpener: exposeVn,
            onFinalPick: () async {
              await delay();
              if (mounted) onVnDone();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: TextPickerField(
            controller: pnvn,
            hint: 'PnVN',
            items: _formData?.masters.pnvn ?? [],
            onChanged: (_) {},
            exposeOpener: exposePin,
            onFinalPick: () async {
              await delay();
              if (mounted) onPinDone();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: TextPickerField(
            controller: nrvn,
            hint: 'NrVN',
            items: _formData?.masters.nrvn ?? [],
            onChanged: (_) {},
            exposeOpener: exposeNear,
            onFinalPick: onNearDone == null
                ? null
                : () async {
                    await delay();
                    if (mounted) onNearDone();
                  },
          ),
        ),
      ],
    );
  }

  // ── PG / ST (shared refraction table builder) ────────────────────────

  Widget _pgBody() => _refractionTable(_pg, isSt: false);

  Widget _stBody() {
    return Column(
      children: [
        _refractionTable(_st, isSt: true),
        const SizedBox(height: 10),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _checkbox(
              'Bifocal',
              _bifocal,
              (v) => setState(() => _bifocal = v!),
            ),
            _checkbox(
              'N&D Separate',
              _ndSeparate,
              (v) => setState(() => _ndSeparate = v!),
            ),
            _checkbox(
              'Progressive',
              _progressive,
              (v) => setState(() => _progressive = v!),
            ),
            _checkbox(
              'Computer Use',
              _computerUses,
              (v) => setState(() => _computerUses = v!),
            ),
          ],
        ),
      ],
    );
  }

  bool _axisDisabled(String cylText) {
    final t = cylText.trim();
    if (t.isEmpty || t == 'Plano') return true;
    final abs = (t.startsWith('+') || t.startsWith('-')) ? t.substring(1) : t;
    return abs == '0.00' || abs == '0';
  }

  /// Field-chain order per eye: DS→DC→AX→VN (dist) →NS→NC→NA→NearVN (near)
  /// for PG; DS→DC→AX→VN→ADD for ST (NC/NA-near are read-only mirrors, not
  /// pickable, so they're skipped). RE then LE — same technique as
  /// C/O/K-C-O/Vision; web has no reference pattern for PG/ST specifically,
  /// so this follows the natural reading order. `openers` is filled in as
  /// each field's own ChipPickerField builds (via exposeOpener); onFinalPick
  /// closures only ever look it up *after* a tap, by which point the whole
  /// tree has finished its initial build.
  Widget _refractionTable(
    Map<String, Map<String, TextEditingController>> data, {
    required bool isSt,
  }) {
    final sphCyl = _formData?.masters.sphCyl ?? [];
    final axis = _formData?.masters.axis ?? [];
    final vn = _formData?.masters.vn ?? [];
    final nrvn = _formData?.masters.nrvn ?? [];
    final chainKeys = isSt
        ? const ['ds', 'dc', 'ax', 'vn', 'add']
        : const ['ds', 'dc', 'ax', 'vn', 'ns', 'nc', 'na', 'near_vn'];
    final openers = <String, VoidCallback>{};

    VoidCallback? nextOpenFor(String eye, String key) {
      final idx = chainKeys.indexOf(key);
      if (idx < 0) return null;
      if (idx < chainKeys.length - 1) {
        final nextKey = chainKeys[idx + 1];
        return () => openers['${eye}_$nextKey']?.call();
      }
      if (eye == 're') return () => openers['le_${chainKeys.first}']?.call();
      return null;
    }

    void Function()? onFinalPickFor(String eye, String key) {
      final next = nextOpenFor(eye, key);
      if (next == null) return null;
      return () async {
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) next();
      };
    }

    void registerOpener(String eye, String key, VoidCallback fn) {
      openers['${eye}_$key'] = fn;
      if (eye == 're' && key == chainKeys.first) _autoOpenFirstField(fn);
    }

    String pickerTitle(String eye, String key, bool isSt) {
      const names = {'ds': 'SPH', 'dc': 'CYL', 'ax': 'Axis', 'vn': 'VN', 'ns': 'Near SPH', 'nc': 'Near CYL', 'na': 'Near Axis', 'near_vn': 'Near VN'};
      final field = key == 'vn' ? (isSt ? 'VN C ST' : 'VN C GL') : (names[key] ?? key);
      return '$field  ·  ${eye == 're' ? 'Right Eye (RE)' : 'Left Eye (LE)'}  ·  ${isSt ? 'ST' : 'PG'}';
    }


    Widget cellFor(String eye, String key) {
      final isSph = key == 'ds' || key == 'ns';
      final isCyl = key == 'dc' || key == 'nc';
      final isAxis = key == 'ax' || key == 'na';
      final isVn = key == 'vn';
      final isNearVn = key == 'near_vn';
      if (isSt && (key == 'nc' || key == 'na')) {
        return MirrorCell(value: data[eye]![key == 'nc' ? 'dc' : 'ax']!.text);
      }
      if (isSph || isCyl) {
        return ChipPickerField(
          controller: data[eye]![key]!,
          title: pickerTitle(eye, key, isSt),
          items: sphCyl,
          isSignField: true,
          onChanged: () => setState(() {}),
          exposeOpener: (fn) => registerOpener(eye, key, fn),
          onFinalPick: onFinalPickFor(eye, key),
        );
      }
      if (isAxis) {
        return ChipPickerField(
          controller: data[eye]![key]!,
          title: pickerTitle(eye, key, isSt),
          items: axis,
          isSignField: false,
          disabled: _axisDisabled(data[eye]!['dc']!.text),
          exposeOpener: (fn) => registerOpener(eye, key, fn),
          onFinalPick: onFinalPickFor(eye, key),
        );
      }
      if (isVn || isNearVn) {
        return ChipPickerField(
          controller: data[eye]![key]!,
          title: pickerTitle(eye, key, isSt),
          items: isNearVn ? nrvn : vn,
          isSignField: false,
          exposeOpener: (fn) => registerOpener(eye, key, fn),
          onFinalPick: onFinalPickFor(eye, key),
        );
      }
      return const SizedBox();
    }

    return Column(
      children: ['re', 'le'].map((eye) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primaryA12),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.remove_red_eye_rounded,
                      size: 13,
                      color: eye == 're'
                          ? Colors.red.shade700
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      eye == 're' ? 'Right Eye (RE)' : 'Left Eye (LE)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: eye == 're'
                            ? Colors.red.shade700
                            : AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const SizedBox(width: 42),
                    Expanded(child: examTh('SPH')),
                    Expanded(child: examTh('CYL')),
                    Expanded(child: examTh('AXIS')),
                    Expanded(child: examTh(isSt ? 'VN C ST' : 'VN C GL')),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 42,
                      child: Text(
                        'DIST',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.primaryA50,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: cellFor(eye, 'ds'),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: cellFor(eye, 'dc'),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: cellFor(eye, 'ax'),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: cellFor(eye, 'vn'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    SizedBox(
                      width: 42,
                      child: Text(
                        'NEAR',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.primaryA50,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: isSt
                            ? _stNsCell(
                                eye,
                                exposeOpener: (fn) =>
                                    openers['${eye}_add'] = fn,
                                onFinalPick: onFinalPickFor(eye, 'add'),
                              )
                            : cellFor(eye, 'ns'),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: cellFor(eye, 'nc'),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: cellFor(eye, 'na'),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: isSt
                            ? const SizedBox()
                            : cellFor(eye, 'near_vn'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _stNsCell(
    String eye, {
    void Function(VoidCallback open)? exposeOpener,
    VoidCallback? onFinalPick,
  }) {
    final nsCtrl = eye == 're' ? _stNsRe : _stNsLe;
    final addCtrl = eye == 're' ? _stAddRe : _stAddLe;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChipPickerField(
          controller: addCtrl,
          title: 'Add  ·  ${eye == 're' ? 'Right Eye (RE)' : 'Left Eye (LE)'}  ·  ST',
          items: _formData?.masters.sphCyl ?? [],
          isSignField: true,
          exposeOpener: exposeOpener,
          onFinalPick: onFinalPick,
          onChanged: () {
            final ds =
                double.tryParse(_st[eye]!['ds']!.text.replaceAll('+', '')) ??
                0.0;
            final add =
                double.tryParse(addCtrl.text.replaceAll('+', '')) ?? 0.0;
            final ns = ds + add;
            setState(
              () => nsCtrl.text = ns == 0.0
                  ? ''
                  : (ns > 0
                        ? '+${ns.toStringAsFixed(2)}'
                        : ns.toStringAsFixed(2)),
            );
          },
        ),
        const SizedBox(height: 3),
        Text(
          'NS: ${nsCtrl.text.isEmpty ? '—' : nsCtrl.text}',
          style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
        ),
      ],
    );
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

  Widget _nctBody() {
    late VoidCallback openLe;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    'RE (mmHg)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextPickerField(
                    controller: _nctIopRe,
                    hint: 'IOP',
                    items: _formData?.masters.nct ?? [],
                    grid: true,
                    borderColorFor: _iopColor,
                    onChanged: (_) => setState(() {}),
                    exposeOpener: (fn) => _autoOpenFirstField(fn),
                    onFinalPick: () async {
                      await Future.delayed(const Duration(milliseconds: 150));
                      if (mounted) openLe();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'LE (mmHg)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextPickerField(
                    controller: _nctIopLe,
                    hint: 'IOP',
                    items: _formData?.masters.nct ?? [],
                    grid: true,
                    borderColorFor: _iopColor,
                    onChanged: (_) => setState(() {}),
                    exposeOpener: (fn) => openLe = fn,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            _iopBadge('Normal 10–21', const Color(0xFF22C55E)),
            _iopBadge('Borderline 22–24', const Color(0xFFF59E0B)),
            _iopBadge('High ≥25', const Color(0xFFEF4444)),
          ],
        ),
      ],
    );
  }

  Widget _iopBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  // ── O/E ───────────────────────────────────────────────────────────────

  Widget _oeBody() {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 110),
            Expanded(child: examTh('Right Eye (RE)')),
            Expanded(child: examTh('Left Eye (LE)')),
          ],
        ),
        ..._oeFieldNames.map((f) {
          final isOther = f == 'other';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      _oeLabels[f] ?? f,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryA70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: isOther
                          ? _simpleField(
                              initial: _oeRe[f]!.text,
                              hint: '—',
                              onChanged: (v) => _oeRe[f]!.text = v,
                            )
                          : TextPickerField(
                              controller: _oeRe[f]!,
                              hint: _oeLabels[f] ?? f,
                              items: _oeMasters[f] ?? [],
                              showFavourites: true,
                              onToggleFavourite: (item) =>
                                  _toggleFav(_oeMasterApiType[f]!, item),
                              onChanged: (_) => setState(() {}),
                            ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: isOther
                          ? _simpleField(
                              initial: _oeLe[f]!.text,
                              hint: '—',
                              onChanged: (v) => _oeLe[f]!.text = v,
                            )
                          : TextPickerField(
                              controller: _oeLe[f]!,
                              hint: _oeLabels[f] ?? f,
                              items: _oeMasters[f] ?? [],
                              showFavourites: true,
                              onToggleFavourite: (item) =>
                                  _toggleFav(_oeMasterApiType[f]!, item),
                              onChanged: (_) => setState(() {}),
                            ),
                    ),
                  ),
                ],
              ),
              if (f == 'lens' && (_isPseudo('re') || _isPseudo('le')))
                _pseudoPanel(),
            ],
          );
        }),
      ],
    );
  }

  Widget _pseudoPanel() {
    Widget panel(
      String eye,
      String opType,
      void Function(String) onOp,
      TextEditingController exp,
      TextEditingController hosp,
    ) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primaryA15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pseudophakia — $eye',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: ['Block', 'Phaco']
                  .map(
                    (o) => PressScaleWrapper(
                      onTap: () => setState(() => onOp(o)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: opType == o ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(
                            color: opType == o
                                ? AppColors.primary
                                : AppColors.primaryA20,
                          ),
                        ),
                        child: Text(
                          o,
                          style: TextStyle(
                            fontSize: 11,
                            color: opType == o
                                ? Colors.white
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _simpleField(
                    initial: exp.text,
                    hint: 'Expense',
                    onChanged: (v) => exp.text = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextPickerField(
                    controller: hosp,
                    hint: 'Hospital',
                    items: _referrers,
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_isPseudo('re'))
          panel(
            'RE',
            _pseudoOpRe,
            (v) => _pseudoOpRe = v,
            _pseudoExpRe,
            _pseudoHospRe,
          ),
        if (_isPseudo('le'))
          panel(
            'LE',
            _pseudoOpLe,
            (v) => _pseudoOpLe = v,
            _pseudoExpLe,
            _pseudoHospLe,
          ),
      ],
    );
  }

  // ── Fundus ────────────────────────────────────────────────────────────

  Widget _fundusEyeCard(bool isRe) {
    final disc = isRe ? _fundusDiscRe : _fundusDiscLe;
    final fr = isRe ? _fundusFrRe : _fundusFrLe;
    final comment = isRe ? _fundusCommentRe : _fundusCommentLe;
    final commentFocus = isRe ? _fundusCommentReFocus : _fundusCommentLeFocus;
    late VoidCallback openFr;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primaryA12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.remove_red_eye_rounded,
                size: 13,
                color: isRe ? Colors.red.shade700 : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                isRe ? 'Right Eye (RE)' : 'Left Eye (LE)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isRe ? Colors.red.shade700 : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'DISC',
            style: TextStyle(fontSize: 10, color: AppColors.primaryA55),
          ),
          const SizedBox(height: 3),
          TextPickerField(
            controller: disc,
            hint: 'Disc (CDR)',
            items: _fundusDiscMasters,
            showFavourites: true,
            onToggleFavourite: (item) => _toggleFav('disc', item),
            onChanged: (_) {},
            exposeOpener: isRe ? (fn) => _autoOpenFirstField(fn) : null,
            onFinalPick: () async {
              await Future.delayed(const Duration(milliseconds: 150));
              if (mounted) openFr();
            },
          ),
          const SizedBox(height: 8),
          Text(
            'FR',
            style: TextStyle(fontSize: 10, color: AppColors.primaryA55),
          ),
          const SizedBox(height: 3),
          TextPickerField(
            controller: fr,
            hint: 'Foveal Reflex',
            items: _fundusFrMasters,
            showFavourites: true,
            onToggleFavourite: (item) => _toggleFav('fr', item),
            onChanged: (_) {},
            exposeOpener: (fn) => openFr = fn,
            // Client report (2026-10-07): used to auto-focus (and so
            // auto-open the keyboard over) the Comment field right after FR
            // was picked. Comment is free text, not a picker — web's own
            // modal has no such auto-advance into it. Chain just ends here
            // now; the user taps Comment themselves when they want it.
          ),
          const SizedBox(height: 8),
          Text(
            'COMMENT',
            style: TextStyle(fontSize: 10, color: AppColors.primaryA55),
          ),
          const SizedBox(height: 3),
          _simpleField(
            initial: comment.text,
            hint: 'Additional findings',
            onChanged: (v) => comment.text = v,
            lines: 2,
            focusNode: commentFocus,
          ),
        ],
      ),
    );
  }

  // Client report 2026-10-14: the RE/LE cards stacked vertically made this
  // step unnecessarily tall/scrolly on the tablet's wide screen — side by
  // side halves it.
  Widget _fundusBody() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: _fundusEyeCard(true)),
      const SizedBox(width: 12),
      Expanded(child: _fundusEyeCard(false)),
    ],
  );

  // ── Dilate ────────────────────────────────────────────────────────────

  Widget _dilateBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dilate patient?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ChoiceChip(
              label: const Text('Yes'),
              selected: _dilate == 'Yes',
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: _dilate == 'Yes' ? Colors.white : AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
              onSelected: (_) => setState(() {
                _dilate = 'Yes';
                if (_dilationTimeCtrl.text.trim().isEmpty)
                  _dilationTimeCtrl.text = '40';
              }),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('No'),
              selected: _dilate == 'No',
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: _dilate == 'No' ? Colors.white : AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
              onSelected: (_) => setState(() {
                _dilate = 'No';
                _dilationTimeCtrl.clear();
              }),
            ),
          ],
        ),
        if (_dilate == 'Yes') ...[
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: _simpleField(
                  initial: _dilationTimeCtrl.text,
                  hint: 'Mins',
                  onChanged: (v) => _dilationTimeCtrl.text = v,
                  numeric: true,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'minutes lock',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Finish Primary will save and wait for dilation before Secondary.',
            style: TextStyle(fontSize: 11, color: AppColors.primaryA55),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'Finish Primary will save and open Secondary examination.',
            style: TextStyle(fontSize: 11, color: AppColors.primaryA55),
          ),
        ],
      ],
    );
  }

  // ── Small shared helpers ──────────────────────────────────────────────

  Widget _diagnosisBody() {
    final filtered = _diagnosisSearch.isEmpty
        ? _diagnosisMasters
        : _diagnosisMasters
              .where(
                (d) => d.value.toLowerCase().contains(
                  _diagnosisSearch.toLowerCase(),
                ),
              )
              .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_selectedDiagnosisIds.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  '${_selectedDiagnosisIds.length} selected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              PressScaleWrapper(
                onTap: () => setState(() => _selectedDiagnosisIds.clear()),
                child: Text(
                  'Clear all',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        _simpleField(
          initial: _diagnosisSearch,
          hint: 'Search diagnoses…',
          onChanged: (v) => setState(() => _diagnosisSearch = v),
        ),
        const SizedBox(height: 8),
        DiagnosisGroupedChips(
          items: filtered,
          selectedIds: _selectedDiagnosisIds,
          chipBuilder: (d) {
            final sel = _selectedDiagnosisIds.contains(d.id);
            return Container(
              decoration: BoxDecoration(
                color: sel ? AppColors.teal : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: sel ? AppColors.teal : AppColors.primaryA20,
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PressScaleWrapper(
                      onTap: () async {
                        final f = await _toggleFav('diagnoses', d);
                        setState(() {
                          final i = _diagnosisMasters.indexWhere(
                            (e) => e.id == d.id,
                          );
                          if (i >= 0) {
                            _diagnosisMasters[i] = ExamMasterItem(
                              id: d.id,
                              value: d.value,
                              isFavourite: f,
                            );
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 8,
                          top: 6,
                          bottom: 6,
                          right: 4,
                        ),
                        child: Icon(
                          d.isFavourite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 13,
                          color: d.isFavourite
                              ? Colors.amber.shade600
                              : (sel ? Colors.white54 : AppColors.primaryA30),
                        ),
                      ),
                    ),
                    PressScaleWrapper(
                      onTap: () => setState(() {
                        if (sel)
                          _selectedDiagnosisIds.remove(d.id);
                        else
                          _selectedDiagnosisIds.add(d.id);
                      }),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 8,
                          right: 10,
                          top: 6,
                          bottom: 6,
                        ),
                        child: Text(
                          d.value,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: sel ? Colors.white : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _medicineBody() {
    final dosages = _formData?.dosages ?? [];
    final routes = _formData?.routes ?? [];
    final groups = _formData?.medGroups ?? [];
    final medicines = _formData?.medicines ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (groups.isNotEmpty)
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: null,
                  isExpanded: true,
                  hint: const Text(
                    'Load a medicine group…',
                    style: TextStyle(fontSize: 12),
                  ),
                  items: groups
                      .map(
                        (g) => DropdownMenuItem(
                          value: g.id,
                          child: Text(
                            g.name,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  onChanged: (groupId) {
                    if (groupId == null) return;
                    final group = groups.firstWhere((g) => g.id == groupId);
                    setState(() {
                      for (final item in group.items) {
                        if (item.medicineName == null ||
                            item.medicineName!.isEmpty)
                          continue;
                        _medicines.add(
                          _PrescRow(
                            medicineId: item.medicineId,
                            medicineName: item.medicineName ?? '',
                            dosageId: item.dosageId,
                            routeId: item.routeId,
                            duration: item.duration ?? '',
                            quantity: item.quantity,
                          ),
                        );
                      }
                    });
                  },
                ),
              ),
            const SizedBox(width: 10),
            _addBtn(() => setState(() => _medicines.add(_PrescRow()))),
          ],
        ),
        const SizedBox(height: 10),
        if (_medicines.isEmpty)
          _emptyHint('No medicines added')
        else
          ..._medicines.asMap().entries.map(
            (e) => _prescRowWidget(e.key, e.value, dosages, routes, medicines),
          ),
      ],
    );
  }

  Widget _prescRowWidget(
    int idx,
    _PrescRow row,
    List<MedMasterItem> dosages,
    List<MedMasterItem> routes,
    List<MedItem> medicines,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: _MedicineSearchField(
              initialName: row.medicineName,
              items: medicines,
              onTextChanged: (t) {
                row.medicineName = t.trim();
                row.medicineId = null;
              },
              onSelected: (med) => setState(() {
                row.medicineId = med.id;
                row.medicineName = med.name;
                if (med.dosageId != null) row.dosageId = med.dosageId;
                if (med.duration != null) row.duration = med.duration!;
              }),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: _miniDropdownItems<int?>(
              value: row.dosageId,
              items: [
                const DropdownMenuItem(value: null, child: Text('Dosage')),
                ...dosages.map(
                  (d) => DropdownMenuItem(
                    value: d.id,
                    child: Text(d.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => row.dosageId = v),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: _miniDropdownItems<int?>(
              value: row.routeId,
              items: [
                const DropdownMenuItem(value: null, child: Text('Route')),
                ...routes.map(
                  (r) => DropdownMenuItem(
                    value: r.id,
                    child: Text(r.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => row.routeId = v),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 60,
            child: _simpleField(
              initial: row.duration,
              hint: 'Days',
              onChanged: (v) => row.duration = v,
              numeric: true,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 50,
            child: _simpleField(
              initial: row.quantity.toString(),
              hint: 'Qty',
              onChanged: (v) => row.quantity = int.tryParse(v) ?? 1,
              numeric: true,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.remove_circle_rounded,
              color: AppColors.red,
              size: 20,
            ),
            onPressed: () => setState(() => _medicines.removeAt(idx)),
          ),
        ],
      ),
    );
  }

  Widget _adviceBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Web parity: Primary and Secondary share the exact same advice
        // picker markup/behaviour — this used to be a plain pill `Wrap` here
        // while Secondary had the richer AdviceLibraryPicker card; now both
        // use the same shared widget.
        AdviceLibraryPicker(
          adviceCtrl: _adviceCtrl,
          masters: _adviceMasters,
          onMastersChanged: (updated) =>
              setState(() => _adviceMasters = updated),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _adviceCtrl,
          maxLines: 5,
          maxLength: 2000,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Clinical advice...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addBtn(VoidCallback onTap) => PressScaleWrapper(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primaryA12,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Icon(Icons.add_rounded, color: AppColors.primary, size: 16),
    ),
  );

  Widget _emptyHint(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: AppColors.primaryA40,
        fontStyle: FontStyle.italic,
      ),
    ),
  );

  Widget _miniDropdownItems<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      items: items,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 11, color: Colors.black87),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: AppColors.primaryA18),
        ),
      ),
    );
  }

  Widget _simpleField({
    required String initial,
    required String hint,
    required void Function(String) onChanged,
    int lines = 1,
    bool numeric = false,
    FocusNode? focusNode,
  }) {
    return TextFormField(
      initialValue: initial,
      focusNode: focusNode,
      maxLines: lines,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 11, color: AppColors.primaryA35),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: AppColors.primaryA18),
        ),
      ),
    );
  }

  Widget _checkbox(String label, bool val, void Function(bool?) onChanged) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: val,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.primary)),
        ],
      );
}

void unawaited(Future<void> f) {}

class _PrescRow {
  int? medicineId;
  String medicineName;
  int? dosageId;
  int? routeId;
  String duration;
  int quantity;
  _PrescRow({
    this.medicineId,
    this.medicineName = '',
    this.dosageId,
    this.routeId,
    this.duration = '',
    this.quantity = 1,
  });
  Map<String, dynamic> toJson() => {
    if (medicineId != null) 'medicine_id': medicineId,
    if (medicineName.isNotEmpty) 'name': medicineName,
    if (dosageId != null) 'dosage_id': dosageId,
    if (routeId != null) 'route_id': routeId,
    'duration': duration.isEmpty ? null : duration,
    'quantity': quantity,
  };
}

class _MedicineSearchField extends StatefulWidget {
  final String initialName;
  final List<MedItem> items;
  final void Function(MedItem) onSelected;
  final void Function(String) onTextChanged;
  const _MedicineSearchField({
    required this.initialName,
    required this.items,
    required this.onSelected,
    required this.onTextChanged,
  });
  @override
  State<_MedicineSearchField> createState() => _MedicineSearchFieldState();
}

class _MedicineSearchFieldState extends State<_MedicineSearchField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;
  List<MedItem> _results = [];
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
    _focusNode = FocusNode()
      ..addListener(() {
        if (_focusNode.hasFocus && widget.items.isNotEmpty)
          setState(() {
            _results = widget.items;
            _show = true;
          });
        if (!_focusNode.hasFocus) setState(() => _show = false);
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _ctrl,
          focusNode: _focusNode,
          style: const TextStyle(fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'Search medicine...',
            isDense: true,
          ),
          onChanged: (v) {
            widget.onTextChanged(v);
            final q = v.toLowerCase();
            setState(() {
              _results = q.isEmpty
                  ? widget.items
                  : widget.items
                        .where((m) => m.name.toLowerCase().contains(q))
                        .toList();
              _show = _results.isNotEmpty;
            });
          },
        ),
        if (_show)
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            child: ListView(
              shrinkWrap: true,
              children: _results
                  .take(20)
                  .map(
                    (m) => ListTile(
                      dense: true,
                      title: Text(m.name, style: const TextStyle(fontSize: 12)),
                      onTap: () {
                        _ctrl.text = m.name;
                        setState(() => _show = false);
                        widget.onSelected(m);
                        _focusNode.unfocus();
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
