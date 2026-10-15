import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_radius.dart';

/// Live clinical-slip canvas — mirrors web `#liveReportCanvas` / `updateLivePreview()`.
/// Pass the same `exam_data` map shape the apps already POST to the API.
class ExamLiveSlip extends StatelessWidget {
  final Map<String, dynamic> examData;
  final bool showDiagnosis;
  final bool showMedicine;
  final bool showAdvice;
  final List<Map<String, dynamic>>? prescriptions;
  final Map<int, String>? dosageLabels;
  final Map<int, String>? routeLabels;
  final List<String>? diagnosisLabels;

  const ExamLiveSlip({
    super.key,
    required this.examData,
    this.showDiagnosis = false,
    this.showMedicine = false,
    this.showAdvice = false,
    this.prescriptions,
    this.dosageLabels,
    this.routeLabels,
    this.diagnosisLabels,
  });

  static const _navy = Color(0xFF1B4F72);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primaryA10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: _navy,
            child: const Row(children: [
              Icon(Icons.description_outlined, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Live Clinical Chart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              Spacer(),
              Text('Updates as you fill', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth >= 640;
                final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (showMedicine) _medicineBox(),
                  _pgBox(),
                  _stBox(),
                  _kcoBox(),
                  _fundusBox(),
                ]);
                final right = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _coBox(),
                  _hnoBox(),
                  _visionLineBox(),
                  _oeBox(),
                  if (showDiagnosis) _diagnosisBox(),
                  if (showAdvice) _adviceBox(),
                ]);
                if (!wide) {
                  return Column(children: [
                    _coBox(),
                    _kcoBox(),
                    _hnoBox(),
                    _visionLineBox(),
                    _pgBox(),
                    _stBox(),
                    _oeBox(),
                    _fundusBox(),
                    if (showDiagnosis) _diagnosisBox(),
                    if (showMedicine) _medicineBox(),
                    if (showAdvice) _adviceBox(),
                  ]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 12),
                    Expanded(child: right),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Data helpers ──────────────────────────────────────────────────────

  Map<String, dynamic> _map(String key) {
    final v = examData[key];
    return v is Map<String, dynamic> ? v : {};
  }

  List<Map<String, dynamic>> _rows(String key) {
    final v = examData[key];
    if (v is! List) return [];
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  String _s(dynamic v) {
    final t = (v ?? '').toString().trim();
    return t.isEmpty ? '' : t;
  }

  String _dash(dynamic v) {
    final t = _s(v);
    return t.isEmpty ? '—' : t;
  }

  String _formatKcoSince(String since, String unit) {
    if (unit == 'Longtime') return 'Longtime';
    final parts = [since, unit].where((e) => e.trim().isNotEmpty).toList();
    return parts.join(' ');
  }

  String _axisChip(String ax) {
    final a = ax.trim();
    if (a.isEmpty) return '';
    return a.endsWith('°') ? a : '$a°';
  }

  String _pgFmt(String? sph, String? cyl, String? ax) {
    final s = _s(sph);
    final c = _s(cyl);
    final a = _s(ax);
    if (s.isEmpty && c.isEmpty && a.isEmpty) return '';
    var out = '${s.isEmpty ? '-' : s} / ${c.isEmpty ? '-' : c}';
    if (a.isNotEmpty) out += ' X ${_axisChip(a)}';
    return out;
  }

  String _lensOe(String eye) {
    final oe = _map('oe');
    final base = _s(oe['lens_$eye']);
    if (base.isEmpty) return '—';
    final pseudo = oe['pseudophakia_$eye'];
    if (pseudo is! Map) return base;
    final type = _s(pseudo['operation_type']);
    final exp = _s(pseudo['operation_expense']);
    final hosp = _s(pseudo['hospital_name']);
    final extras = [type, if (exp.isNotEmpty) exp, if (hosp.isNotEmpty) hosp].where((e) => e.isNotEmpty).toList();
    return extras.isEmpty ? base : '$base (${extras.join(', ')})';
  }

  // ── Boxes ─────────────────────────────────────────────────────────────

  Widget _coBox() {
    final rows = _rows('co_rows').where((r) => _s(r['complaint']).isNotEmpty).toList();
    return _tableBox(
      title: 'C/O',
      titleAlign: TextAlign.left,
      cols: const ['Complaint', 'Since', 'Eye', 'Comment'],
      body: rows.isEmpty
          ? [_emptyRow(4)]
          : rows.map((d) {
              final since = _s(d['since']);
              final unit = _s(d['unit']);
              final sinceTxt = since.isEmpty ? '' : '$since $unit'.trim();
              return [_dash(d['complaint']), sinceTxt.isEmpty ? '—' : sinceTxt, _dash(d['eye']), _dash(d['comment'])];
            }).toList(),
    );
  }

  Widget _kcoBox() {
    final rows = _rows('kco_rows').where((r) => _s(r['condition']).isNotEmpty).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return _tableBox(
      title: 'K/C/O',
      titleAlign: TextAlign.left,
      cols: const ['Condition', 'Since/Duration', 'Comment'],
      body: rows
          .map((d) => [
                _dash(d['condition']),
                _formatKcoSince(_s(d['since']), _s(d['unit'])).isEmpty ? '—' : _formatKcoSince(_s(d['since']), _s(d['unit'])),
                _dash(d['comment']),
              ])
          .toList(),
    );
  }

  Widget _hnoBox() {
    final raw = _s(examData['history']);
    final chips = raw.isEmpty ? <String>[] : raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(spacing: 4, runSpacing: 4, children: chips.map(_pill).toList()),
    );
  }

  Widget _visionLineBox() {
    final v = _map('vision');
    final nct = _map('nct');
    final pg = _map('pg');
    final pgRe = pg['re'] is Map ? Map<String, dynamic>.from(pg['re'] as Map) : <String, dynamic>{};
    final pgLe = pg['le'] is Map ? Map<String, dynamic>.from(pg['le'] as Map) : <String, dynamic>{};
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 8, children: [
          _vnBlock('Vn', _s(v['vn_re']), _s(v['vn_le'])),
          _vnBlock('Vn C GL', _s(pgRe['vn']), _s(pgLe['vn'])),
          _vnBlock('Pn/Vn', _s(v['pnvn_re']), _s(v['pnvn_le'])),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 12, runSpacing: 8, children: [
          _vnBlock('Nr/Vn', _s(v['nrvn_re']), _s(v['nrvn_le'])),
          _vnBlock('Nr/Vn C GL', _s(pgRe['near_vn']), _s(pgLe['near_vn'])),
          _vnBlock('NCT', _s(nct['iop_re']), _s(nct['iop_le'])),
        ]),
      ]),
    );
  }

  Widget _pgBox() {
    final pg = _map('pg');
    final re = pg['re'] is Map ? Map<String, dynamic>.from(pg['re'] as Map) : <String, dynamic>{};
    final le = pg['le'] is Map ? Map<String, dynamic>.from(pg['le'] as Map) : <String, dynamic>{};
    final distRe = _pgFmt(_s(re['ds']), _s(re['dc']), _s(re['ax']));
    final distLe = _pgFmt(_s(le['ds']), _s(le['dc']), _s(le['ax']));
    final nearRe = _pgFmt(_s(re['ns']), _s(re['nc']), _s(re['na']));
    final nearLe = _pgFmt(_s(le['ns']), _s(le['nc']), _s(le['na']));
    if (distRe.isEmpty && distLe.isEmpty && nearRe.isEmpty && nearLe.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(spacing: 12, children: [_vnBlock('PG', '', ''), _vnBlock('NrPG', '', '')]),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(spacing: 12, runSpacing: 6, children: [
        _vnBlock('PG', distRe, distLe),
        _vnBlock('NrPG', nearRe, nearLe),
      ]),
    );
  }

  Widget _stBox() {
    final st = _map('st');
    final re = st['re'] is Map ? Map<String, dynamic>.from(st['re'] as Map) : <String, dynamic>{};
    final le = st['le'] is Map ? Map<String, dynamic>.from(st['le'] as Map) : <String, dynamic>{};
    final opts = <String>[
      if (st['bifocal'] == true) 'Bifocal',
      if (st['nd_separate'] == true) 'Near & Distance Separate',
      if (st['progressive'] == true) 'Progressive',
      if (st['computer_uses'] == true) 'Computer Uses',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _stTable(re, le),
        if (opts.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(spacing: 4, runSpacing: 4, children: opts.map(_pill).toList()),
        ],
      ]),
    );
  }

  Widget _stTable(Map<String, dynamic> re, Map<String, dynamic> le) {
    String cell(dynamic v) {
      final t = _s(v);
      return t.isEmpty ? '—' : t;
    }

    String ax(dynamic v) {
      final t = _axisChip(_s(v));
      return t.isEmpty ? '—' : t;
    }

    final vnRe = _s(re['vn']);
    final vnLe = _s(le['vn']);
    return Column(children: [
      Row(children: [
        Expanded(child: Container(color: _navy, padding: const EdgeInsets.symmetric(vertical: 3), child: const Text('RIGHT EYE', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)))),
        Expanded(child: Container(color: _navy, padding: const EdgeInsets.symmetric(vertical: 3), child: const Text('LEFT EYE', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)))),
      ]),
      Table(
        border: TableBorder.all(color: const Color(0xFFCBD5E1), width: 0.8),
        columnWidths: const {
          0: FlexColumnWidth(0.7),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
          4: FlexColumnWidth(0.7),
          5: FlexColumnWidth(1),
          6: FlexColumnWidth(1),
          7: FlexColumnWidth(1),
        },
        children: [
          TableRow(decoration: const BoxDecoration(color: Color(0xFFEEF4F9)), children: [
            _th(vnRe.isEmpty ? 'VN' : vnRe),
            _th('SPH'),
            _th('CYL'),
            _th('AXIS'),
            _th(vnLe.isEmpty ? 'VN' : vnLe),
            _th('SPH'),
            _th('CYL'),
            _th('AXIS'),
          ]),
          TableRow(children: [
            _rowTag('D'),
            _td(cell(re['ds'])),
            _td(cell(re['dc'])),
            _td(ax(re['ax'])),
            _rowTag('D'),
            _td(cell(le['ds'])),
            _td(cell(le['dc'])),
            _td(ax(le['ax'])),
          ]),
          TableRow(children: [
            _rowTag('N'),
            _td(cell(re['ns'])),
            _td(cell(_s(re['nc']).isNotEmpty ? re['nc'] : re['dc'])),
            _td(ax(_s(re['na']).isNotEmpty ? re['na'] : re['ax'])),
            _rowTag('N'),
            _td(cell(le['ns'])),
            _td(cell(_s(le['nc']).isNotEmpty ? le['nc'] : le['dc'])),
            _td(ax(_s(le['na']).isNotEmpty ? le['na'] : le['ax'])),
          ]),
        ],
      ),
    ]);
  }

  Widget _oeBox() {
    const fields = [
      ('SAC', 'sac'),
      ('LID', 'lid'),
      ('CONJ', 'conj'),
      ('CORNEA', 'cornea'),
      ('AC', 'ac'),
      ('IRIS', 'iris'),
      ('PUPIL', 'pupil'),
      ('LENS', 'lens'),
      ('EM', 'em'),
      ('COVERTEST', 'covertest'),
      ('OTHER', 'other'),
    ];
    final oe = _map('oe');
    return _oeFundusTable(
      title: 'O/E',
      rows: fields.map((f) {
        if (f.$2 == 'lens') return [f.$1, _lensOe('re'), _lensOe('le')];
        return [f.$1, _dash(oe['${f.$2}_re']), _dash(oe['${f.$2}_le'])];
      }).toList(),
    );
  }

  Widget _fundusBox() {
    final f = _map('fundus');
    return _oeFundusTable(
      title: 'Fundus',
      rows: [
        ['DISC', _dash(f['disc_re']), _dash(f['disc_le'])],
        ['FR', _dash(f['fr_re']), _dash(f['fr_le'])],
        ['COMMENT', _dash(f['comment_re']), _dash(f['comment_le'])],
      ],
    );
  }

  Widget _diagnosisBox() {
    final dilate = _s(examData['dilate']).isEmpty ? 'No' : _s(examData['dilate']);
    final dx = (diagnosisLabels ?? []).where((e) => e.trim().isNotEmpty).toList();
    final dxText = dx.isEmpty ? '—' : dx.join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(style: const TextStyle(fontSize: 11, color: AppColors.textPrimary), children: [
          const TextSpan(text: 'Dx: ', style: TextStyle(fontWeight: FontWeight.w800)),
          TextSpan(text: dxText),
          const TextSpan(text: '   Dilate: ', style: TextStyle(fontWeight: FontWeight.w800)),
          TextSpan(text: dilate),
        ]),
      ),
    );
  }

  Widget _medicineBox() {
    final rows = (prescriptions ?? []).where((r) => _s(r['name']).isNotEmpty || r['medicine_id'] != null).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return _tableBox(
      title: 'Medicine',
      cols: const ['Medicine Name', 'Dosage', 'Days', 'QTY', 'Mode'],
      body: rows.map((r) {
        final dosageId = r['dosage_id'] as int?;
        final routeId = r['route_id'] as int?;
        final dur = _s(r['duration']);
        return [
          _dash(r['name']),
          dosageId != null ? (dosageLabels?[dosageId] ?? '—') : '—',
          dur.isEmpty ? '—' : '$dur Days',
          _dash(r['quantity']),
          routeId != null ? (routeLabels?[routeId] ?? '—') : '—',
        ];
      }).toList(),
    );
  }

  Widget _adviceBox() {
    final advice = _s(examData['advice']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: advice.isEmpty
          ? Text('No advice entered', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.primaryA45))
          : Text(advice, style: const TextStyle(fontSize: 12, height: 1.35)),
    );
  }

  // ── Shared chrome ─────────────────────────────────────────────────────

  Widget _vnBlock(String label, String re, String le) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(width: 4),
        const Text('⟨', style: TextStyle(fontSize: 22, height: 0.7, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(width: 2),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(re, style: const TextStyle(fontSize: 11, height: 1.25)),
            Text(le, style: const TextStyle(fontSize: 11, height: 1.25)),
          ],
        ),
      ],
    );
  }

  Widget _pill(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFFEEF4F9), borderRadius: BorderRadius.circular(8)),
        child: Text(t, style: const TextStyle(fontSize: 10, color: _navy, fontWeight: FontWeight.w600)),
      );

  Widget _tableBox({
    required String title,
    required List<String> cols,
    required List<List<String>> body,
    TextAlign titleAlign = TextAlign.center,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: _navy,
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          child: Text(title, textAlign: titleAlign, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ),
        Table(
          border: TableBorder.all(color: const Color(0xFFCBD5E1), width: 0.8),
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFEEF4F9)),
              children: cols.map(_th).toList(),
            ),
            ...body.map((r) {
              final cells = List<String>.from(r);
              while (cells.length < cols.length) {
                cells.add('—');
              }
              return TableRow(children: cells.take(cols.length).map(_td).toList());
            }),
          ],
        ),
      ]),
    );
  }

  Widget _oeFundusTable({required String title, required List<List<String>> rows}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Table(
        border: TableBorder.all(color: const Color(0xFF1E293B), width: 0.7),
        columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFF1E293B)),
            children: [
              _thDark(title),
              _thDark('RIGHT'),
              _thDark('LEFT'),
            ],
          ),
          ...rows.map((r) => TableRow(children: [
                Container(
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                  child: Text(r[0], textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                ),
                _td(r[1]),
                _td(r[2]),
              ])),
        ],
      ),
    );
  }

  List<String> _emptyRow(int n) => List.filled(n, '—');

  Widget _th(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
        child: Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _navy)),
      );

  Widget _thDark(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 3),
        child: Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
      );

  Widget _td(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
        child: Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10)),
      );

  Widget _rowTag(String t) => Container(
        color: const Color(0xFFF0F4F8),
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _navy)),
      );
}
