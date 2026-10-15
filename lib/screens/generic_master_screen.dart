import 'package:flutter/material.dart';
import '../widgets/app_refresh_indicator.dart';
import '../constants/app_colors.dart';
import '../widgets/table_row_action.dart';
import '../utils/app_dialogs.dart';
import '../constants/app_radius.dart';
import '../services/simple_master_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/form_kit.dart';
import '../widgets/skeleton.dart';

/// Tablet generic master editor — Pattern A (list, inline add/edit dialog).
/// Covers every simple {value, is_favourite, is_seeded} master (~26 types:
/// complaints, kcos, hno, diagnoses, advices, vn/pnvn/nrvn, sph_cyl, axis,
/// nct, sac/lid/conj/cornea/ac/iris/pupil/lens/em/covertest, disc/fr,
/// durations, lens-options, ot-types). Embedded as the Masters hub's detail
/// pane (no own Scaffold) — ported from
/// eye_care_app/lib/screens/generic_master_screen.dart.
class GenericMasterScreen extends StatefulWidget {
  final String title;
  final String apiPath;
  final Color accentColor;
  final IconData icon;
  final bool hasFavourite;
  final bool hasSeeded;
  final bool canAdd;
  final bool canEdit;
  final bool canDelete;

  /// Only the Advice master links to diagnoses on web ("Link by Diagnosis" —
  /// see DetailMasterController::isAdviceType()) — every other detail master
  /// has none of this.
  final bool isAdvice;

  const GenericMasterScreen({
    super.key,
    required this.title,
    required this.apiPath,
    required this.accentColor,
    this.icon = Icons.list_rounded,
    this.hasFavourite = false,
    this.hasSeeded = false,
    this.canAdd = true,
    this.canEdit = true,
    this.canDelete = true,
    this.isAdvice = false,
  });

  @override
  State<GenericMasterScreen> createState() => _GenericMasterScreenState();
}

class _GenericMasterScreenState extends State<GenericMasterScreen> {
  List<SimpleMasterItem> _all = [];
  List<SimpleMasterItem> _diagnosisOptions = [];
  bool _loading = false;
  String? _error;
  String _query = '';

  List<SimpleMasterItem> get _filtered => _query.isEmpty
      ? _all
      : _all
            .where((i) => i.value.toLowerCase().contains(_query.toLowerCase()))
            .toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(GenericMasterScreen old) {
    super.didUpdateWidget(old);
    if (old.apiPath != widget.apiPath) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final futures = <Future>[
        SimpleMasterService.instance.fetchAll(widget.apiPath),
        if (widget.isAdvice)
          SimpleMasterService.instance.fetchAll('masters/detail/diagnoses'),
      ];
      final results = await Future.wait(futures);
      if (mounted) {
        setState(() {
          _all = results[0] as List<SimpleMasterItem>;
          if (widget.isAdvice)
            _diagnosisOptions = results[1] as List<SimpleMasterItem>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
    }
  }

  Future<void> _toggleFav(SimpleMasterItem item) async {
    try {
      final newFav = await SimpleMasterService.instance.toggleFavourite(
        widget.apiPath,
        item.id,
      );
      if (!mounted) return;
      setState(() {
        final idx = _all.indexWhere((i) => i.id == item.id);
        if (idx != -1) _all[idx] = item.copyWith(isFavourite: newFav);
        _all.sort(
          (a, b) => a.isFavourite == b.isFavourite
              ? a.value.compareTo(b.value)
              : (a.isFavourite ? -1 : 1),
        );
      });
    } catch (_) {}
  }

  Future<void> _delete(SimpleMasterItem item) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete ${widget.title}',
      message: 'Delete "${item.value}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await SimpleMasterService.instance.delete(widget.apiPath, item.id);
      await _load();
    } catch (e) {
      if (mounted)
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
    }
  }

  Future<void> _openDialog({SimpleMasterItem? item}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _GenericMasterDialog(
        item: item,
        title: widget.title,
        apiPath: widget.apiPath,
        accentColor: widget.accentColor,
        hasFavourite: widget.hasFavourite,
        showDiagnosisPicker: widget.isAdvice,
        diagnosisOptions: _diagnosisOptions,
      ),
    );
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(widget.icon, color: widget.accentColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              color: widget.accentColor,
              onPressed: _loading ? null : _load,
            ),
            if (widget.canAdd) ...[
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: () => _openDialog(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() => _query = v.trim()),
          decoration: InputDecoration(
            hintText: 'Search ${widget.title.toLowerCase()}...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: AppColors.background,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 10,
              horizontal: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading)
      return const AppSkeletonList(
        count: 6,
        itemHeight: 60,
        padding: EdgeInsets.zero,
      );
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: AppColors.red.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accentColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Text(
          _query.isNotEmpty
              ? 'No results for "$_query"'
              : (widget.canAdd
                    ? 'No ${widget.title.toLowerCase()} yet. Tap Add to create one.'
                    : 'No ${widget.title.toLowerCase()} yet.'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textDisabled),
        ),
      );
    }
    return AppRefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final item = items[i];
          return AnimatedListItem(
            index: i,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primaryA08),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.value,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (widget.isAdvice && item.diagnoses.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: item.diagnoses
                                .map(
                                  (d) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.green.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: AppColors.green.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      d.value,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.green.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.hasFavourite)
                    IconButton(
                      icon: Icon(
                        item.isFavourite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 20,
                        color: item.isFavourite
                            ? AppColors.orange
                            : const Color(0xFFCBD5E1),
                      ),
                      onPressed: widget.canEdit ? () => _toggleFav(item) : null,
                    ),
                  if (item.isSeeded)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: AppColors.textDisabled,
                      ),
                    )
                  else ...[
                    if (widget.canEdit)
                      TableIconAction(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit',
                        kind: TableActionKind.edit,
                        onTap: () => _openDialog(item: item),
                      ),
                    if (widget.canDelete)
                      TableIconAction(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Delete',
                        kind: TableActionKind.delete,
                        onTap: () => _delete(item),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GenericMasterDialog extends StatefulWidget {
  final SimpleMasterItem? item;
  final String title;
  final String apiPath;
  final Color accentColor;
  final bool hasFavourite;

  /// Advice master only — see GenericMasterScreen.isAdvice.
  final bool showDiagnosisPicker;
  final List<SimpleMasterItem> diagnosisOptions;

  const _GenericMasterDialog({
    required this.item,
    required this.title,
    required this.apiPath,
    required this.accentColor,
    required this.hasFavourite,
    this.showDiagnosisPicker = false,
    this.diagnosisOptions = const [],
  });

  @override
  State<_GenericMasterDialog> createState() => _GenericMasterDialogState();
}

class _GenericMasterDialogState extends State<_GenericMasterDialog> {
  late final TextEditingController _ctrl;
  late bool _fav;
  late Set<int> _diagnosisIds;
  bool _saving = false;
  String? _fieldError;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.item?.value ?? '');
    _fav = widget.item?.isFavourite ?? false;
    _diagnosisIds = widget.item?.diagnoses.map((d) => d.id).toSet() ?? {};
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = _ctrl.text.trim();
    if (v.isEmpty) {
      setState(() => _fieldError = 'Value is required');
      return;
    }
    setState(() {
      _saving = true;
      _fieldError = null;
    });
    try {
      final item = widget.item;
      final diagIds = widget.showDiagnosisPicker
          ? _diagnosisIds.toList()
          : null;
      if (item == null) {
        await SimpleMasterService.instance.create(
          widget.apiPath,
          v,
          isFavourite: _fav,
          diagnosisIds: diagIds,
        );
      } else {
        await SimpleMasterService.instance.update(
          widget.apiPath,
          item.id,
          v,
          isFavourite: _fav,
          diagnosisIds: diagIds,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    return AppDialog(
      size: AppDialogSize.small,
      header: AppDialogHeader(
        icon: isEdit ? Icons.edit_outlined : Icons.add_rounded,
        title: isEdit ? 'Edit ${widget.title}' : 'Add ${widget.title}',
        colors: [widget.accentColor, widget.accentColor],
        onClose: _saving ? null : () => Navigator.pop(context, false),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _ctrl,
            autofocus: !isEdit,
            decoration: appFieldDecoration(
              'Value',
            ).copyWith(errorText: _fieldError),
          ),
          if (widget.showDiagnosisPicker) ...[
            const SizedBox(height: 14),
            Text(
              'Diagnosis',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.diagnosisOptions.isEmpty)
              const Text(
                'No diagnoses in Master Data yet.',
                style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: widget.diagnosisOptions.map((d) {
                      final selected = _diagnosisIds.contains(d.id);
                      return FilterChip(
                        label: Text(
                          d.value,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: selected,
                        selectedColor: widget.accentColor.withValues(
                          alpha: 0.18,
                        ),
                        checkmarkColor: widget.accentColor,
                        onSelected: (v) => setState(() {
                          if (v) {
                            _diagnosisIds.add(d.id);
                          } else {
                            _diagnosisIds.remove(d.id);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
          if (widget.hasFavourite) ...[
            const SizedBox(height: 14),
            AppSwitchTile(
              label: 'Mark as Favourite',
              value: _fav,
              color: widget.accentColor,
              onChanged: (v) => setState(() => _fav = v),
            ),
          ],
        ],
      ),
      actions: [
        AppSecondaryButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
        ),
        AppPrimaryButton(
          label: 'Save',
          color: widget.accentColor,
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
