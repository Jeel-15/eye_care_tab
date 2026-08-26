import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../services/location_service.dart';

/// Tablet Locations master — read-only (managed by platform), search only.
/// Ported from eye_care_app/lib/screens/location_master_screen.dart.
class LocationMasterScreen extends StatefulWidget {
  final Color accentColor;
  const LocationMasterScreen({super.key, required this.accentColor});

  @override
  State<LocationMasterScreen> createState() => _LocationMasterScreenState();
}

class _LocationMasterScreenState extends State<LocationMasterScreen> {
  List<LocationItem> _all = [];
  bool _loading = false;
  String? _error;
  String _query = '';

  List<LocationItem> get _filtered {
    if (_query.isEmpty) return _all;
    final q = _query.toLowerCase();
    return _all.where((i) => i.city.toLowerCase().contains(q) || (i.district ?? '').toLowerCase().contains(q) || (i.state ?? '').toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await LocationService.instance.fetchAll();
      if (mounted) setState(() { _all = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.location_on_rounded, color: widget.accentColor, size: 20),
        const SizedBox(width: 10),
        const Expanded(child: Text('Locations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
        Tooltip(message: 'Read-only — managed by platform', child: Icon(Icons.lock_outline_rounded, color: AppColors.textDisabled, size: 18)),
      ]),
      const SizedBox(height: 14),
      TextField(onChanged: (v) => setState(() => _query = v.trim()), decoration: InputDecoration(hintText: 'Search city, district, or state...', prefixIcon: const Icon(Icons.search_rounded, size: 20), filled: true, fillColor: AppColors.background, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none))),
      const SizedBox(height: 8),
      Align(alignment: Alignment.centerLeft, child: Text(_query.isNotEmpty ? '${_filtered.length} of ${_all.length} locations' : '${_all.length} locations', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary))),
      const SizedBox(height: 8),
      Expanded(child: _buildBody()),
    ]);
  }

  Widget _buildBody() {
    if (_loading) return Center(child: CircularProgressIndicator(color: widget.accentColor));
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 10), ElevatedButton(onPressed: _load, child: const Text('Retry'))]));
    final items = _filtered;
    if (items.isEmpty) return Center(child: Text(_query.isNotEmpty ? 'No results for "$_query"' : 'No locations found.', style: const TextStyle(color: AppColors.textDisabled)));
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA08)),
          child: Row(children: [
            Container(width: 32, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: widget.accentColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.location_on_rounded, size: 16, color: widget.accentColor)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.city, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              if (item.subtitle.isNotEmpty) Text(item.subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            ])),
          ]),
        );
      },
    );
  }
}
