import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabmero_admin/core/api_client.dart';
import '../../core/app_config.dart';
import '../../models/service_catalog_models.dart';
import '../../models/service_item_model.dart';
import '../../providers/service_catalog_providers.dart';
import '../../services/service_admin_api.dart';
import '../../widgets/common.dart';

// Admin management of the services shown in the app: category, prices,
// gallery, duration, warranty, requirements, featured and display order.
class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  static const _pageSize = 10;

  String _query = '';
  int? _categoryFilter;
  String _status = 'All';
  int _page = 0;

  void _refresh() {
    ref.invalidate(serviceItemsProvider);
    ref.invalidate(serviceCategoriesProvider);
  }

  // A main category filter also matches its sub-categories.
  Set<int>? _filterIds(List<ServiceCategoryNode> roots) {
    final id = _categoryFilter;
    if (id == null) return null;
    for (final r in roots) {
      if (r.id == id) return {r.id, ...r.children.map((c) => c.id)};
    }
    return {id};
  }

  List<ServiceItem> _apply(List<ServiceItem> rows, Set<int>? ids) {
    final q = _query.trim().toLowerCase();
    return rows.where((s) {
      if (q.isNotEmpty && !s.name.toLowerCase().contains(q)) return false;
      if (ids != null && !(s.categoryId != null && ids.contains(s.categoryId))) {
        return false;
      }
      if (_status == 'Active' && !s.isActive) return false;
      if (_status == 'Inactive' && s.isActive) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(serviceItemsProvider);
    final roots =
        ref.watch(serviceCategoriesProvider).asData?.value ??
        const <ServiceCategoryNode>[];
    final options = serviceCategoryOptions(roots);
    final labelOf = {for (final o in options) o.id: o.label};
    final ids = _filterIds(roots);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Services',
          subtitle: 'Services customers can book in the app',
          actions: [
            FilledButton.icon(
              onPressed: () => _openForm(context, options, null),
              icon: const Icon(Icons.add),
              label: const Text('Add Service'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        _filters(options),
        const SizedBox(height: 8),
        Expanded(
          child: AsyncListView<ServiceItem>(
            value: async,
            onRetry: _refresh,
            emptyText: 'No services yet. Add one.',
            builder: (all) {
              final rows = _apply(all, ids);
              final pages = (rows.length / _pageSize).ceil();
              final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);
              final start = page * _pageSize;
              final end = (start + _pageSize).clamp(0, rows.length);
              final shown = rows.sublist(start, end);

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No services match the filters.'),
                      )
                    else
                      TableCard(
                        columns: const [
                          DataColumn(label: Text('Image')),
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Price')),
                          DataColumn(label: Text('Duration')),
                          DataColumn(label: Text('Active')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: shown
                            .map((s) => _row(context, options, labelOf, s))
                            .toList(),
                      ),
                    if (pages > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: page > 0
                                  ? () => setState(() => _page = page - 1)
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text(
                              '${start + 1}-$end of ${rows.length}  (page ${page + 1}/$pages)',
                            ),
                            IconButton(
                              onPressed: page < pages - 1
                                  ? () => setState(() => _page = page + 1)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filters(List<ServiceCategoryOption> options) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: TextField(
            onChanged: (v) => setState(() {
              _query = v;
              _page = 0;
            }),
            decoration: const InputDecoration(
              hintText: 'Search services',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<int?>(
            value: options.any((o) => o.id == _categoryFilter)
                ? _categoryFilter
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('All categories'),
              ),
              for (final o in options)
                DropdownMenuItem<int?>(
                  value: o.id,
                  child: Text(o.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() {
              _categoryFilter = v;
              _page = 0;
            }),
          ),
        ),
        SizedBox(
          width: 140,
          child: DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All')),
              DropdownMenuItem(value: 'Active', child: Text('Active')),
              DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
            ],
            onChanged: (v) => setState(() {
              _status = v ?? 'All';
              _page = 0;
            }),
          ),
        ),
      ],
    );
  }

  DataRow _row(
    BuildContext context,
    List<ServiceCategoryOption> options,
    Map<int, String> labelOf,
    ServiceItem s,
  ) {
    final img = s.gallery.isEmpty ? null : s.gallery.first;
    final cat = s.categoryId == null ? null : labelOf[s.categoryId];

    return DataRow(
      cells: [
        DataCell(
          img != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    serviceImageUrl(img),
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image, size: 24),
                  ),
                )
              : const Icon(Icons.handyman_outlined, color: AppColors.textMuted),
        ),
        DataCell(
          SizedBox(
            width: 200,
            child: Row(
              children: [
                if (s.isFeatured)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.star, size: 16, color: AppColors.warning),
                  ),
                Expanded(child: Text(s.name, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 180,
            child: Text(
              cat ?? 'No category',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cat == null ? AppColors.danger : null),
            ),
          ),
        ),
        DataCell(
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: s.charge > 0 ? 'Rs ${s.charge.toStringAsFixed(0)}' : 'On request'),
                if (s.hasDiscount)
                  TextSpan(
                    text: '  Rs ${s.oldPrice!.toStringAsFixed(0)}',
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                if (s.hasDiscount && s.discountPercent > 0)
                  TextSpan(
                    text: '  -${s.discountPercent}%',
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
        DataCell(Text(s.durationText ?? '-')),
        DataCell(StatusBadge(s.isActive ? 'Active' : 'Inactive')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _btn('Edit', AppColors.info, () => _openForm(context, options, s)),
              const SizedBox(width: 6),
              _btn('Delete', AppColors.danger, () => _delete(context, s)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color.withAlpha(120)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      minimumSize: const Size(0, 32),
    ),
    onPressed: onTap,
    child: Text(label, style: const TextStyle(fontSize: 12)),
  );

  Future<void> _delete(BuildContext context, ServiceItem s) async {
    final ok = await confirm(
      context,
      'Delete service?',
      'Remove "${s.name}" from the app? Existing bookings are not affected.',
    );
    if (!ok) return;
    final res = await ref.read(serviceAdminApiProvider).delete(s.id);
    if (!context.mounted) return;
    toast(context, res.ok ? 'Deleted' : (res.message ?? 'Failed'), error: !res.ok);
    if (res.ok) _refresh();
  }

  Future<void> _openForm(
    BuildContext context,
    List<ServiceCategoryOption> options,
    ServiceItem? existing,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ServiceFormDialog(existing: existing, options: options),
    );
    if (saved == true) _refresh();
  }
}

// One image in the gallery: already on the server (path) or just picked (bytes).
class _Img {
  String? path;
  Uint8List? bytes;
  String? name;
  _Img.fromPath(this.path);
  _Img.fromBytes(this.bytes, this.name);
}

class _ServiceFormDialog extends ConsumerStatefulWidget {
  final ServiceItem? existing;
  final List<ServiceCategoryOption> options;
  const _ServiceFormDialog({required this.existing, required this.options});

  @override
  ConsumerState<_ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends ConsumerState<_ServiceFormDialog> {
  static const _maxImages = 8;

  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _desc = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final TextEditingController _charge = TextEditingController(
    text: _fmt(widget.existing?.charge),
  );
  late final TextEditingController _oldPrice = TextEditingController(
    text: _fmt(widget.existing?.oldPrice),
  );
  late final TextEditingController _duration = TextEditingController(
    text: widget.existing?.durationText ?? '',
  );
  late final TextEditingController _warranty = TextEditingController(
    text: widget.existing?.warranty ?? '',
  );
  late final TextEditingController _requirements = TextEditingController(
    text: widget.existing?.requirements ?? '',
  );
  late final TextEditingController _order = TextEditingController(
    text: (widget.existing?.sortOrder ?? 0).toString(),
  );
  late int? _categoryId = widget.existing?.categoryId;
  late bool _active = widget.existing?.isActive ?? true;
  late bool _home = widget.existing?.homeServiceAvailable ?? true;
  late bool _featured = widget.existing?.isFeatured ?? false;
  late final List<_Img> _images = [
    for (final p in widget.existing?.gallery ?? const <String>[]) _Img.fromPath(p),
  ];
  bool _busy = false;

  static String _fmt(double? v) =>
      (v == null || v <= 0) ? '' : v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _charge.dispose();
    _oldPrice.dispose();
    _duration.dispose();
    _warranty.dispose();
    _requirements.dispose();
    _order.dispose();
    super.dispose();
  }

  double get _chargeValue => double.tryParse(_charge.text.trim()) ?? 0;
  double get _oldValue => double.tryParse(_oldPrice.text.trim()) ?? 0;

  Future<void> _pickImages() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: true,
    );
    if (picked == null) return;
    final room = _maxImages - _images.length;
    setState(() {
      for (final f in picked.files.take(room)) {
        if (f.bytes == null) continue;
        _images.add(_Img.fromBytes(f.bytes!, f.name));
      }
    });
    if (picked.files.length > room) {
      _snack('You can add up to $_maxImages images.', ok: false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Name is required.', ok: false);
      return;
    }
    if (_categoryId == null) {
      _snack('Choose a category (main or sub).', ok: false);
      return;
    }
    final charge = _chargeValue;
    final old = _oldValue;
    if (old > 0 && charge > 0 && old <= charge) {
      _snack('Regular price must be higher than the offer price.', ok: false);
      return;
    }

    setState(() => _busy = true);
    final api = ref.read(serviceAdminApiProvider);

    // upload newly picked images, keep the order
    final paths = <String>[];
    for (final img in _images) {
      if (img.path == null && img.bytes != null) {
        final up = await api.uploadImage(img.bytes!, img.name ?? 'image.jpg');
        if (!up.ok || up.path == null) {
          if (!mounted) return;
          setState(() => _busy = false);
          _snack(up.message, ok: false);
          return;
        }
        img.path = up.path; // do not upload it again if saving is retried
        img.bytes = null;
      }
      if (img.path != null) paths.add(img.path!);
    }

    final body = <String, dynamic>{
      'name': name,
      'description': _desc.text.trim(),
      'charge': charge,
      'oldPrice': old > 0 ? old : 0, // 0 removes the regular price
      'imagePath': paths.isEmpty ? null : paths.first,
      'imagePaths': paths,
      'categoryId': _categoryId,
      'durationText': _duration.text.trim(),
      'warranty': _warranty.text.trim(),
      'requirements': _requirements.text.trim(),
      'homeServiceAvailable': _home,
      'isFeatured': _featured,
      'sortOrder': int.tryParse(_order.text.trim()) ?? 0,
      if (widget.existing != null) 'isActive': _active,
    };

    final ApiResult res = await api.save(id: widget.existing?.id, body: body);
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(res.message ?? (res.ok ? 'Saved.' : 'Failed.'), ok: res.ok);
    if (res.ok) Navigator.pop(context, true);
  }

  void _snack(String msg, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ),
    );
  }

  InputDecoration _dec(String label, {String? prefix, String? helper}) =>
      InputDecoration(
        labelText: label,
        prefixText: prefix,
        helperText: helper,
        counterText: '',
        border: const OutlineInputBorder(),
      );

  Widget _imageTile(int i) {
    final img = _images[i];
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: img.bytes != null
                  ? Image.memory(img.bytes!, fit: BoxFit.cover)
                  : Image.network(
                      serviceImageUrl(img.path ?? ''),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                    ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: InkWell(
              onTap: _busy ? null : () => setState(() => _images.removeAt(i)),
              child: const CircleAvatar(
                radius: 10,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            left: 2,
            bottom: 2,
            child: i == 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Main',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  )
                : InkWell(
                    onTap: _busy
                        ? null
                        : () => setState(() => _images.insert(0, _images.removeAt(i))),
                    child: const CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.star_border, size: 12, color: Colors.white),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final discount = (_oldValue > _chargeValue && _chargeValue > 0)
        ? ((_oldValue - _chargeValue) / _oldValue * 100).round()
        : 0;

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Service' : 'Edit Service'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                maxLength: 100,
                decoration: _dec('Service name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: widget.options.any((o) => o.id == _categoryId)
                    ? _categoryId
                    : null,
                isExpanded: true,
                decoration: _dec('Category (main or sub)'),
                items: [
                  for (final o in widget.options)
                    DropdownMenuItem<int>(
                      value: o.id,
                      child: Text(o.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                maxLines: 3,
                maxLength: 500,
                decoration: _dec('Description'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _charge,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      decoration: _dec('Offer price (NPR)', prefix: 'Rs '),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _oldPrice,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      decoration: _dec(
                        'Regular price (optional)',
                        prefix: 'Rs ',
                        helper: discount > 0 ? 'Discount: $discount% off' : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _duration,
                      maxLength: 60,
                      decoration: _dec('Duration', helper: 'e.g. 2-3 hours'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _warranty,
                      maxLength: 200,
                      decoration: _dec('Warranty / guarantee'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _requirements,
                maxLines: 3,
                maxLength: 1000,
                decoration: _dec('Requirements and notes'),
              ),
              const SizedBox(height: 12),
              Text(
                'Images (${_images.length}/$_maxImages). The first is the main image.',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _images.length; i++) _imageTile(i),
                  if (_images.length < _maxImages)
                    InkWell(
                      onTap: _busy ? null : _pickImages,
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add_photo_alternate_outlined,
                            color: AppColors.textMuted),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _order,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dec('Display order', helper: 'Smaller numbers come first'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Home service available'),
                value: _home,
                onChanged: (v) => setState(() => _home = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Featured'),
                value: _featured,
                onChanged: (v) => setState(() => _featured = v),
              ),
              if (widget.existing != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active (visible in app)'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
