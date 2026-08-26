import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/auth_models.dart';
import '../services/permission_service.dart';
import '../services/settings_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_error_state.dart';

/// Tablet Hospital Settings — single scrollable form (Pattern C, 2-column
/// field pairs within each section card) replacing mobile's AppBar+footer
/// sandwich with a persistent header row (matches Users/Roles panes).
/// Location cascade and timezone use a search dialog instead of mobile's
/// bottom sheet; wait thresholds render as 3 side-by-side groups on wide
/// layouts instead of stacked — the whole R/D/ND picture visible at once.
/// Business logic ported unchanged from eye_care_app/lib/screens/settings_screen.dart.
class SettingsScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;

  const SettingsScreen({super.key, required this.user, required this.hospital});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;

  String _selCountry = '';
  int? _selCountryId;
  String _selState = '';
  int? _selStateId;
  String _selDistrict = '';
  int? _selDistrictId;
  String _selCity = '';
  String _selTimezone = '';

  late final TextEditingController _prefixCtrl;
  late final TextEditingController _taxCtrl;
  late final TextEditingController _headerNoteCtrl;
  late final TextEditingController _footerNoteCtrl;
  late final TextEditingController _dilationCtrl;
  late final Map<String, TextEditingController> _waitCtrl;

  String? _logoUrl;
  bool _uploadingLogo = false;

  bool _letterPadAvailable = false;
  String _paginationLimit = '25';
  bool _isDirty = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  HospitalSettingsData? _settings;

  Timer? _debounce;

  List<LocationCountry>? _cachedCountries;
  final Map<int, List<LocationItem>> _cachedStates = {};
  final Map<int, List<LocationItem>> _cachedDistricts = {};
  final Map<int, List<LocationItem>> _cachedCities = {};
  List<LocationTimezone>? _cachedTimezones;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.hospital.name);
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _prefixCtrl = TextEditingController();
    _taxCtrl = TextEditingController();
    _headerNoteCtrl = TextEditingController();
    _footerNoteCtrl = TextEditingController();
    _dilationCtrl = TextEditingController();
    _waitCtrl = {
      'wait_green_max': TextEditingController(),
      'wait_orange_max': TextEditingController(),
      'wait_red_max': TextEditingController(),
      'wait_d_green_max': TextEditingController(),
      'wait_d_orange_max': TextEditingController(),
      'wait_d_red_max': TextEditingController(),
      'wait_nd_green_max': TextEditingController(),
      'wait_nd_orange_max': TextEditingController(),
      'wait_nd_red_max': TextEditingController(),
    };
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _prefixCtrl.dispose();
    _taxCtrl.dispose();
    _headerNoteCtrl.dispose();
    _footerNoteCtrl.dispose();
    _dilationCtrl.dispose();
    for (final c in _waitCtrl.values) {
      c.dispose();
    }
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final s = await SettingsService.instance.fetchSettings();
      if (!mounted) return;
      _fillSettings(s);
      setState(() { _settings = s; _loading = false; _isDirty = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  void _fillSettings(HospitalSettingsData s) {
    _nameCtrl.text = s.hospitalName;
    _emailCtrl.text = s.hospitalEmail;
    _phoneCtrl.text = s.hospitalPhone;
    _addressCtrl.text = s.hospitalAddress;
    _logoUrl = s.hospitalLogoUrl.isNotEmpty ? s.hospitalLogoUrl : null;
    _selCountry = s.hospitalCountry;
    _selCountryId = s.hospitalCountryId;
    _selState = s.hospitalState;
    _selStateId = s.hospitalStateId;
    _selDistrict = s.hospitalDistrict;
    _selDistrictId = s.hospitalDistrictId;
    _selCity = s.hospitalCity;
    _selTimezone = s.hospitalTimezone;
    _prefixCtrl.text = s.invoicePrefix;
    _taxCtrl.text = s.taxPercentage == s.taxPercentage.roundToDouble() ? s.taxPercentage.toInt().toString() : s.taxPercentage.toString();
    _headerNoteCtrl.text = s.printHeaderNote;
    _footerNoteCtrl.text = s.printFooterNote;
    _dilationCtrl.text = s.defaultDilationTime.toString();
    _waitCtrl['wait_green_max']!.text = s.waitGreenMax.toString();
    _waitCtrl['wait_orange_max']!.text = s.waitOrangeMax.toString();
    _waitCtrl['wait_red_max']!.text = s.waitRedMax.toString();
    _waitCtrl['wait_d_green_max']!.text = s.waitDGreenMax.toString();
    _waitCtrl['wait_d_orange_max']!.text = s.waitDOrangeMax.toString();
    _waitCtrl['wait_d_red_max']!.text = s.waitDRedMax.toString();
    _waitCtrl['wait_nd_green_max']!.text = s.waitNdGreenMax.toString();
    _waitCtrl['wait_nd_orange_max']!.text = s.waitNdOrangeMax.toString();
    _waitCtrl['wait_nd_red_max']!.text = s.waitNdRedMax.toString();
    _letterPadAvailable = s.letterPadAvailable;
    _paginationLimit = s.paginationLimit.toString();
  }

  void _markDirty() {
    if (_isDirty) return;
    setState(() => _isDirty = true);
  }

  void _markDirtyDebounced() {
    if (!_isDirty) _isDirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final thresholds = <String, int>{};
      for (final e in _waitCtrl.entries) {
        final v = int.tryParse(e.value.text.trim());
        if (v != null && v > 0) thresholds[e.key] = v;
      }
      await SettingsService.instance.updateSettings(
        hospitalName: _nameCtrl.text.trim(),
        hospitalEmail: _emailCtrl.text.trim(),
        hospitalPhone: _phoneCtrl.text.trim(),
        hospitalAddress: _addressCtrl.text.trim(),
        hospitalCountry: _selCountry,
        hospitalState: _selState,
        hospitalDistrict: _selDistrict,
        hospitalCity: _selCity,
        hospitalTimezone: _selTimezone,
        invoicePrefix: _prefixCtrl.text.trim(),
        taxPercentage: double.tryParse(_taxCtrl.text.trim()) ?? 0.0,
        letterPadAvailable: _letterPadAvailable,
        printHeaderNote: _headerNoteCtrl.text.trim(),
        printFooterNote: _footerNoteCtrl.text.trim(),
        paginationLimit: int.tryParse(_paginationLimit) ?? 25,
        defaultDilationTime: int.tryParse(_dilationCtrl.text.trim()) ?? 40,
        waitThresholds: thresholds,
      );
      if (!mounted) return;
      setState(() { _isDirty = false; _saving = false; });
      showAppSnackBar(context, 'Settings saved successfully.', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true, duration: const Duration(seconds: 4));
    }
  }

  Future<void> _pickAndUploadLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1024);
    if (picked == null || !mounted) return;
    setState(() => _uploadingLogo = true);
    try {
      final url = await SettingsService.instance.uploadLogo(File(picked.path));
      if (!mounted) return;
      setState(() { _logoUrl = url; _uploadingLogo = false; });
      showAppSnackBar(context, 'Logo updated successfully.', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingLogo = false);
      showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true, duration: const Duration(seconds: 4));
    }
  }

  // ── Location cascade pickers (dialog, not bottom sheet) ───────────────────

  Future<void> _pickCountry() async {
    final picked = await _showPicker<LocationCountry>(title: 'Select Country', loader: () async => _cachedCountries ??= await SettingsService.instance.fetchCountries(), label: (c) => c.name);
    if (picked == null) return;
    setState(() {
      _selCountry = picked.name;
      _selCountryId = picked.id;
      if (picked.defaultTimezone != null && picked.defaultTimezone!.isNotEmpty) _selTimezone = picked.defaultTimezone!;
      _selState = '';
      _selStateId = null;
      _selDistrict = '';
      _selDistrictId = null;
      _selCity = '';
    });
    _markDirty();
  }

  Future<void> _pickState() async {
    if (_selCountry.isEmpty) {
      showAppSnackBar(context, 'Please select a country first.', isError: true);
      return;
    }
    int? cid = _selCountryId;
    if (cid == null) {
      try {
        _cachedCountries ??= await SettingsService.instance.fetchCountries();
        final match = _cachedCountries!.where((c) => c.name.trim().toLowerCase() == _selCountry.trim().toLowerCase()).firstOrNull;
        if (match != null) {
          _selCountryId = match.id;
          cid = match.id;
        }
      } catch (_) {}
      if (cid == null) {
        if (mounted) showAppSnackBar(context, 'Country not found — re-select it from the list.', isError: true);
        return;
      }
    }
    final int stateCid = cid;
    final picked = await _showPicker<LocationItem>(title: 'Select State', loader: () async => _cachedStates[stateCid] ??= await SettingsService.instance.fetchStates(stateCid), label: (s) => s.name);
    if (picked == null) return;
    setState(() {
      _selState = picked.name;
      _selStateId = picked.id;
      _selDistrict = '';
      _selDistrictId = null;
      _selCity = '';
    });
    _markDirty();
  }

  Future<void> _pickDistrict() async {
    if (_selState.isEmpty) {
      showAppSnackBar(context, 'Please select a state first.', isError: true);
      return;
    }
    final sid = _selStateId;
    if (sid == null) {
      showAppSnackBar(context, 'Re-select the state to load districts.', isError: true);
      return;
    }
    final picked = await _showPicker<LocationItem>(title: 'Select District', loader: () async => _cachedDistricts[sid] ??= await SettingsService.instance.fetchDistricts(sid), label: (d) => d.name);
    if (picked == null) return;
    setState(() {
      _selDistrict = picked.name;
      _selDistrictId = picked.id;
      _selCity = '';
    });
    _markDirty();
  }

  Future<void> _pickCity() async {
    if (_selDistrict.isEmpty) {
      showAppSnackBar(context, 'Please select a district first.', isError: true);
      return;
    }
    final did = _selDistrictId;
    if (did == null) {
      showAppSnackBar(context, 'Re-select the district to load cities.', isError: true);
      return;
    }
    final picked = await _showPicker<LocationItem>(title: 'Select City', loader: () async => _cachedCities[did] ??= await SettingsService.instance.fetchCities(did), label: (c) => c.name);
    if (picked == null) return;
    setState(() => _selCity = picked.name);
    _markDirty();
  }

  Future<void> _pickTimezone() async {
    final picked = await _showPicker<LocationTimezone>(title: 'Select Timezone', loader: () async => _cachedTimezones ??= await SettingsService.instance.fetchTimezones(), label: (t) => '${t.offset}  ${t.label}');
    if (picked == null) return;
    setState(() => _selTimezone = picked.value);
    _markDirty();
  }

  Future<T?> _showPicker<T>({required String title, required Future<List<T>> Function() loader, required String Function(T) label}) {
    return showDialog<T>(context: context, builder: (_) => _PickerDialog<T>(title: title, loader: loader, label: label));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!PermissionService.instance.can(Perm.settingsHospital)) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline_rounded, size: 56, color: AppColors.primaryA25),
          const SizedBox(height: 16),
          Text('No Access', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primaryA50)),
          const SizedBox(height: 6),
          Text('You do not have permission to view hospital settings.', style: TextStyle(fontSize: 13, color: AppColors.primaryA35)),
        ]),
      );
    }
    if (_loading) return Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) return _buildError();
    return Form(key: _formKey, child: _buildBody());
  }

  Widget _buildError() {
    return AppErrorState(message: _error!, onRetry: _load);
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderRow(),
          const SizedBox(height: 20),
          _buildGeneralSection(),
          const SizedBox(height: 16),
          _buildLocationSection(),
          const SizedBox(height: 16),
          _buildBillingSection(),
          const SizedBox(height: 16),
          _buildPrintSection(),
          const SizedBox(height: 16),
          _buildQueueSection(),
          const SizedBox(height: 16),
          _buildSecuritySection(),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.primaryA08), boxShadow: [BoxShadow(color: AppColors.primaryA05, blurRadius: 8, offset: const Offset(0, 2))]),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _logoUrl != null && _logoUrl!.isNotEmpty
              ? Image.network(_logoUrl!, width: 56, height: 56, fit: BoxFit.contain, errorBuilder: (ctx, e, s) => _headerIconCircle())
              : _headerIconCircle(),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hospital Settings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
            Text(_settings?.hospitalName.isNotEmpty == true ? _settings!.hospitalName : widget.hospital.name, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
        OutlinedButton.icon(
          onPressed: _uploadingLogo ? null : _pickAndUploadLogo,
          icon: _uploadingLogo ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)) : const Icon(Icons.upload_rounded, size: 16),
          label: Text(_uploadingLogo ? 'Uploading...' : 'Change Logo'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: BorderSide(color: AppColors.primaryA30), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: (_isDirty && !_saving) ? _save : null,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, disabledBackgroundColor: AppColors.primaryA22, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  Widget _headerIconCircle() {
    return Container(width: 56, height: 56, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryA10), child: Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 28));
  }

  // ── Component helpers ──────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.primaryA50),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryA50, letterSpacing: 1.2)),
    ]);
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primaryA08), boxShadow: [BoxShadow(color: AppColors.primaryA05, blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _row2(Widget a, Widget b) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 480) return Column(children: [a, const SizedBox(height: 16), b]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 20), Expanded(child: b)]);
    });
  }

  Widget _fieldRow({required String label, required TextEditingController ctrl, IconData? suffix, TextInputType? keyboardType, TextCapitalization textCapitalization = TextCapitalization.none, List<TextInputFormatter>? inputFormatters, String? Function(String?)? validator, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryA40, letterSpacing: 1.0)),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: ctrl,
              keyboardType: keyboardType,
              textCapitalization: textCapitalization,
              inputFormatters: inputFormatters,
              maxLines: maxLines,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
              onChanged: (_) => _markDirty(),
              validator: validator,
            ),
          ),
          if (suffix != null) Icon(suffix, size: 20, color: AppColors.primaryA30),
        ]),
        Divider(height: 1, color: AppColors.primaryA18),
      ],
    );
  }

  Widget _pickerRow({required String label, required String value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryA40, letterSpacing: 1.0)),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: Text(value.isEmpty ? '— Select' : value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: value.isEmpty ? AppColors.primaryA30 : AppColors.textPrimary))),
          Icon(Icons.expand_more_rounded, size: 22, color: AppColors.primaryA40),
        ]),
        Divider(height: 1, color: AppColors.primaryA18),
      ]),
    );
  }

  // ── Sections ───────────────────────────────────────────────────────────────

  Widget _buildGeneralSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('GENERAL INFORMATION', Icons.business_rounded),
      const SizedBox(height: 10),
      _card([
        _row2(
          _fieldRow(label: 'HOSPITAL NAME', ctrl: _nameCtrl, suffix: Icons.edit_outlined, textCapitalization: TextCapitalization.words, validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          _fieldRow(label: 'EMAIL', ctrl: _emailCtrl, suffix: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            if (!RegExp(r'^[\w\.\+\-]+@[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}$').hasMatch(v.trim())) return 'Enter a valid email';
            return null;
          }),
        ),
        const SizedBox(height: 16),
        _row2(
          _fieldRow(label: 'PHONE', ctrl: _phoneCtrl, suffix: Icons.phone_outlined, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\+\-\s\(\)]'))], validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          _fieldRow(label: 'ADDRESS', ctrl: _addressCtrl, suffix: Icons.location_on_outlined, maxLines: 3, textCapitalization: TextCapitalization.sentences, validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
        ),
      ]),
    ]);
  }

  Widget _buildLocationSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('LOCATION', Icons.location_city_rounded),
      const SizedBox(height: 10),
      _card([
        _row2(_pickerRow(label: 'COUNTRY', value: _selCountry, onTap: _pickCountry), _pickerRow(label: 'STATE', value: _selState, onTap: _pickState)),
        const SizedBox(height: 16),
        _row2(_pickerRow(label: 'DISTRICT', value: _selDistrict, onTap: _pickDistrict), _pickerRow(label: 'CITY', value: _selCity, onTap: _pickCity)),
        const SizedBox(height: 16),
        _pickerRow(label: 'TIMEZONE', value: _selTimezone, onTap: _pickTimezone),
      ]),
      const SizedBox(height: 6),
      Padding(padding: const EdgeInsets.only(left: 2), child: Text('Selecting a country auto-fills the timezone. Each field filters the next.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.primaryA40))),
    ]);
  }

  Widget _buildBillingSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('BILLING', Icons.receipt_long_outlined),
      const SizedBox(height: 10),
      _card([
        _row2(
          _fieldRow(label: 'INVOICE PREFIX', ctrl: _prefixCtrl, suffix: Icons.tag_rounded, textCapitalization: TextCapitalization.characters, validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          _fieldRow(label: 'TAX PERCENTAGE (%)', ctrl: _taxCtrl, suffix: Icons.percent_rounded, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\.]'))], validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            final n = double.tryParse(v.trim());
            if (n == null || n < 0 || n > 100) return 'Enter 0–100';
            return null;
          }),
        ),
      ]),
    ]);
  }

  Widget _buildPrintSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('PRINT SETTINGS', Icons.print_outlined),
      const SizedBox(height: 10),
      _card([
        Text('LETTER PAD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryA40, letterSpacing: 1.0)),
        const SizedBox(height: 12),
        Row(children: [
          _letterPadOption(selected: !_letterPadAvailable, label: 'Unavailable', desc: 'Header prints hospital info & logo automatically', onTap: () { setState(() => _letterPadAvailable = false); _markDirty(); }),
          const SizedBox(width: 10),
          _letterPadOption(selected: _letterPadAvailable, label: 'Available', desc: 'Physical letterhead — header appears in black', onTap: () { setState(() => _letterPadAvailable = true); _markDirty(); }),
        ]),
        const SizedBox(height: 16),
        Divider(height: 1, color: AppColors.primaryA08),
        const SizedBox(height: 12),
        _row2(_fieldRow(label: 'PRINT HEADER NOTE', ctrl: _headerNoteCtrl, suffix: Icons.notes_rounded), _fieldRow(label: 'PRINT FOOTER NOTE', ctrl: _footerNoteCtrl, suffix: Icons.notes_rounded)),
      ]),
    ]);
  }

  Widget _letterPadOption({required bool selected, required String label, required String desc, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(border: Border.all(color: selected ? AppColors.primary : AppColors.primaryA15, width: selected ? 2 : 1), borderRadius: BorderRadius.circular(10), color: selected ? AppColors.primaryA05 : Colors.transparent),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? AppColors.primary : AppColors.primaryA30, width: 2)), child: selected ? Center(child: Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle))) : null),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? AppColors.primary : AppColors.primaryA55)),
            ]),
            const SizedBox(height: 5),
            Text(desc, style: TextStyle(fontSize: 10, color: AppColors.primaryA45, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }

  Widget _buildQueueSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('QUEUE & WAIT THRESHOLDS', Icons.timer_outlined),
      const SizedBox(height: 10),
      _card([
        _fieldRow(label: 'DEFAULT DILATION TIME (MINUTES)', ctrl: _dilationCtrl, suffix: Icons.av_timer_rounded, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: (v) {
          if (v != null && v.trim().isNotEmpty) {
            final n = int.tryParse(v.trim());
            if (n == null || n < 1 || n > 180) return '1–180 minutes';
          }
          return null;
        }),
        const SizedBox(height: 6),
        Text('Auto-filled in primary exam when doctor selects "Yes, Dilated". Doctor can still edit per patient.', style: TextStyle(fontSize: 11, color: AppColors.primaryA45, height: 1.4)),
      ]),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= AppBreakpoints.medium;
        final groups = [
          _waitGroup(badge: 'R', label: 'Reception Entry', desc: 'Time since patient check-in', greenKey: 'wait_green_max', orangeKey: 'wait_orange_max', redKey: 'wait_red_max'),
          _waitGroup(badge: 'D', label: 'Dilated', desc: 'Post-primary exam — dilation = yes', greenKey: 'wait_d_green_max', orangeKey: 'wait_d_orange_max', redKey: 'wait_d_red_max'),
          _waitGroup(badge: 'ND', label: 'Not Dilated', desc: 'Post-primary exam — dilation = no', greenKey: 'wait_nd_green_max', orangeKey: 'wait_nd_orange_max', redKey: 'wait_nd_red_max'),
        ];
        if (!wide) {
          return Column(children: [for (final g in groups) Padding(padding: const EdgeInsets.only(bottom: 10), child: g)]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: groups[0]),
          const SizedBox(width: 12),
          Expanded(child: groups[1]),
          const SizedBox(width: 12),
          Expanded(child: groups[2]),
        ]);
      }),
    ]);
  }

  Widget _waitGroup({required String badge, required String label, required String desc, required String greenKey, required String orangeKey, required String redKey}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primaryA08), boxShadow: [BoxShadow(color: AppColors.primaryA05, blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(6)), child: Text(badge, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(desc, style: TextStyle(fontSize: 10, color: AppColors.primaryA45)),
          ])),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _waitField('Green', _waitCtrl[greenKey]!, AppColors.waitGreen),
          const SizedBox(width: 6),
          _waitField('Orange', _waitCtrl[orangeKey]!, AppColors.waitOrange),
          const SizedBox(width: 6),
          _waitField('Red', _waitCtrl[redKey]!, AppColors.waitRed),
        ]),
        const SizedBox(height: 12),
        _buildWaitPreview(greenKey, orangeKey, redKey, badge),
      ]),
    );
  }

  Widget _waitField(String label, TextEditingController ctrl, Color color) {
    return Expanded(
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryA55)),
        ]),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: color.withValues(alpha: 0.25))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: color.withValues(alpha: 0.25))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: color, width: 2)),
            filled: true,
            fillColor: color.withValues(alpha: 0.04),
            suffixText: 'm',
            suffixStyle: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w700),
            errorStyle: const TextStyle(fontSize: 9, height: 1.2),
          ),
          onChanged: (_) => _markDirtyDebounced(),
          validator: (v) {
            if (v != null && v.trim().isNotEmpty) {
              final n = int.tryParse(v.trim());
              if (n == null || n < 1) return '≥1';
            }
            return null;
          },
        ),
      ]),
    );
  }

  Widget _buildWaitPreview(String greenKey, String orangeKey, String redKey, String badge) {
    final g = int.tryParse(_waitCtrl[greenKey]!.text.trim()) ?? 0;
    final o = int.tryParse(_waitCtrl[orangeKey]!.text.trim()) ?? 0;
    final r = int.tryParse(_waitCtrl[redKey]!.text.trim()) ?? 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      decoration: BoxDecoration(color: AppColors.primaryA03, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primaryA07)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PREVIEW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.primaryA35, letterSpacing: 1.0)),
        const SizedBox(height: 6),
        Row(children: [
          _previewPill(badge, '0–${g}m', AppColors.waitGreen),
          const SizedBox(width: 4),
          _previewPill(badge, '$g–${o}m', AppColors.waitOrange),
          const SizedBox(width: 4),
          _previewPill(badge, '$o–${r}m', AppColors.waitRed),
          const SizedBox(width: 4),
          _previewPill(badge, '${r}m+', const Color(0xFF7C0000), isFire: true),
        ]),
      ]),
    );
  }

  Widget _previewPill(String badge, String time, Color color, {bool isFire = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: color.withValues(alpha: 0.20))),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 16, height: 16, alignment: Alignment.center, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Text(isFire ? '🔥' : badge, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white))),
          const SizedBox(width: 3),
          Flexible(child: Text(time, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }

  // ── Security section ───────────────────────────────────────────────────────

  Widget _buildSecuritySection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('SECURITY', Icons.lock_outline_rounded),
      const SizedBox(height: 10),
      _card([
        InkWell(
          onTap: _showChangePasswordDialog,
          borderRadius: BorderRadius.circular(10),
          child: Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.password_rounded, size: 20, color: AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Change Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text('Update your account login password', style: TextStyle(fontSize: 11, color: AppColors.primaryA45)),
            ])),
            Icon(Icons.chevron_right_rounded, color: AppColors.primaryA35),
          ]),
        ),
      ]),
    ]);
  }

  void _showChangePasswordDialog() {
    showDialog(context: context, builder: (_) => _ChangePasswordDialog(onSuccess: () => showAppSnackBar(context, 'Password changed successfully.', isSuccess: true)));
  }
}

// ── Location Picker Dialog ────────────────────────────────────────────────

class _PickerDialog<T> extends StatefulWidget {
  final String title;
  final Future<List<T>> Function() loader;
  final String Function(T) label;

  const _PickerDialog({required this.title, required this.loader, required this.label});

  @override
  State<_PickerDialog<T>> createState() => _PickerDialogState<T>();
}

class _PickerDialogState<T> extends State<_PickerDialog<T>> {
  List<T>? _items;
  List<T> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_filter);
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final items = await widget.loader();
      if (!mounted) return;
      setState(() { _items = items; _filtered = items; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() => _filtered = (_items ?? []).where((i) => widget.label(i).toLowerCase().contains(q)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: SizedBox(
        width: 420,
        height: 520,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
            child: Row(children: [
              Text(widget.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
              const Spacer(),
              IconButton(icon: Icon(Icons.close_rounded, color: AppColors.textSecondary), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: AppColors.primaryA35),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.primaryA40, size: 20),
                filled: true,
                fillColor: AppColors.backgroundAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: AppColors.primaryA08),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? Padding(padding: const EdgeInsets.all(32), child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)))
                    : _filtered.isEmpty
                        ? Padding(padding: const EdgeInsets.all(32), child: Text('No results found.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.primaryA45)))
                        : ListView.builder(
                            itemCount: _filtered.length,
                            itemBuilder: (ctx, i) {
                              final item = _filtered[i];
                              return ListTile(dense: true, title: Text(widget.label(item), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)), onTap: () => Navigator.pop(ctx, item));
                            },
                          ),
          ),
        ]),
      ),
    );
  }
}

// ── Change Password Dialog ──────────────────────────────────────────────

class _ChangePasswordDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  const _ChangePasswordDialog({required this.onSuccess});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _savingPw = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _savingPw = true);
    try {
      await SettingsService.instance.changePassword(currentPassword: _currentCtrl.text, newPassword: _newCtrl.text, newPasswordConfirmation: _confirmCtrl.text);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingPw = false);
      showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true, duration: const Duration(seconds: 4));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.password_rounded, size: 20, color: AppColors.primary)),
                const SizedBox(width: 12),
                Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
                const Spacer(),
                IconButton(icon: Icon(Icons.close_rounded, color: AppColors.textSecondary), onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 16),
              _pwField('Current Password', _currentCtrl, _showCurrent, () => setState(() => _showCurrent = !_showCurrent), validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
              const SizedBox(height: 14),
              _pwField('New Password (min 8 chars)', _newCtrl, _showNew, () => setState(() => _showNew = !_showNew), validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 8) return 'Minimum 8 characters';
                return null;
              }),
              const SizedBox(height: 14),
              _pwField('Confirm New Password', _confirmCtrl, _showConfirm, () => setState(() => _showConfirm = !_showConfirm), validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v != _newCtrl.text) return 'Passwords do not match';
                return null;
              }),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _savingPw ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, disabledBackgroundColor: AppColors.primaryA35, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)), elevation: 0),
                  child: _savingPw ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Update Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _pwField(String label, TextEditingController ctrl, bool show, VoidCallback toggleShow, {String? Function(String?)? validator}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryA40, letterSpacing: 1.0)),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(
          child: TextFormField(
            controller: ctrl,
            obscureText: !show,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
            validator: validator,
          ),
        ),
        GestureDetector(onTap: toggleShow, child: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.primaryA35)),
      ]),
      Divider(height: 1, color: AppColors.primaryA18),
    ]);
  }
}
