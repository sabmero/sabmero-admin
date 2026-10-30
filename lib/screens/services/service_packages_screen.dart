import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_config.dart';
import '../../models/service_catalog_models.dart';
import '../../providers/service_catalog_providers.dart';
import '../../widgets/common.dart';

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

// Admin management of on-site service packages (e.g. "4 camera CCTV package"):
// category, photo, price, old price (discount is worked out by the server) and
// the list of what the package includes.
class ServicePackagesScreen extends ConsumerWidget {
  const ServicePackagesScreen({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(servicePackagesProvider);
    ref.invalidate(serviceCategoriesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(servicePackagesProvider);
    // Keep the categories loaded so the form can offer them.
    ref.watch(serviceCategoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Service Packages',
          subtitle: 'Bundles customers can book (CCTV, door phone, networking...)',
          actions: [
            FilledButton.icon(
              onPressed: () => _openForm(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Add package'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => _refresh(ref),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        Expanded(
          child: AsyncListView<ServicePackageRow>(
            value: async,
            onRetry: () => _refresh(ref),
            emptyText: 'No packages yet. Add one.',
            builder: (rows) => SingleChildScrollView(
              child: TableCard(
                columns: const [
                  DataColumn(label: Text('Image')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Price')),
                  DataColumn(label: Text('Discount')),
                  DataColumn(label: Text('Items')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: rows.map((p) => _row(context, ref, p)).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  DataRow _row(BuildContext context, WidgetRef ref, ServicePackageRow p) {
    final hasImg = p.imagePath != null && p.imagePath!.isNotEmpty;
    final showOld = p.oldPrice != null && p.discountPercent > 0;
    return DataRow(cells: [
      DataCell(hasImg
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                serviceImageUrl(p.imagePath!),
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, size: 24),
              ),
            )
          : const Icon(Icons.inventory_2_outlined,
              color: AppColors.textMuted)),
      DataCell(SizedBox(
          width: 200, child: Text(p.name, overflow: TextOverflow.ellipsis))),
      DataCell(Text(p.categoryName ?? '-')),
      DataCell(Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rs ${_num(p.price)}'),
          if (showOld)
            Text(
              'Rs ${_num(p.oldPrice!)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                decoration: TextDecoration.lineThrough,
              ),
            ),
        ],
      )),
      DataCell(Text(p.discountPercent > 0 ? '-${p.discountPercent}%' : '-')),
      DataCell(Text('${p.items.length}')),
      DataCell(StatusBadge(p.status)),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn('Edit', AppColors.info, () => _openForm(context, ref, p)),
          const SizedBox(width: 6),
          _btn('Delete', AppColors.danger, () => _delete(context, ref, p)),
        ],
      )),
    ]);
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

  Future<void> _delete(
      BuildContext context, WidgetRef ref, ServicePackageRow p) async {
    final ok = await confirm(
        context, 'Delete package?', 'Remove "${p.name}" from the app?');
    if (!ok) return;
    final res = await ref.read(serviceCatalogApiProvider).deletePackage(p.id);
    if (!context.mounted) return;
    toast(context, res.ok ? 'Deleted' : (res.message ?? 'Failed'),
        error: !res.ok);
    if (res.ok) _refresh(ref);
  }

  Future<void> _openForm(
      BuildContext context, WidgetRef ref, ServicePackageRow? existing) async {
    final options = ref.read(serviceCategoriesProvider).maybeWhen(
          data: (d) => serviceCategoryOptions(d),
          orElse: () => const <ServiceCategoryOption>[],
        );
    if (options.isEmpty) {
      toast(context, 'Add a service category first.', error: true);
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PackageFormDialog(existing: existing, options: options),
    );
    if (saved == true) _refresh(ref);
  }
}

// One editable row of "what the package includes".
class _ItemEdit {
  final TextEditingController name;
  final TextEditingController qty;
  _ItemEdit(String n, int q)
      : name = TextEditingController(text: n),
        qty = TextEditingController(text: '$q');
  void dispose() {
    name.dispose();
    qty.dispose();
  }
}

class _PackageFormDialog extends ConsumerStatefulWidget {
  final ServicePackageRow? existing;
  final List<ServiceCategoryOption> options;
  const _PackageFormDialog({required this.existing, required this.options});

  @override
  ConsumerState<_PackageFormDialog> createState() => _PackageFormDialogState();
}

class _PackageFormDialogState extends ConsumerState<_PackageFormDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _desc =
      TextEditingController(text: widget.existing?.description ?? '');
  late final TextEditingController _price = TextEditingController(
      text: widget.existing == null ? '' : _num(widget.existing!.price));
  late final TextEditingController _oldPrice = TextEditingController(
      text: widget.existing?.oldPrice == null
          ? ''
          : _num(widget.existing!.oldPrice!));
  late final TextEditingController _sort =
      TextEditingController(text: '${widget.existing?.sortOrder ?? 0}');
  late int? _categoryId = widget.existing?.categoryId;
  late String _status = widget.existing?.status ?? 'Active';
  late String? _imagePath = widget.existing?.imagePath;
  final List<_ItemEdit> _items = [];
  final List<_ItemEdit> _removed = [];
  List<int>? _pickedBytes;
  String? _pickedName;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final it in widget.existing?.items ?? const <ServicePackageItemRow>[]) {
      _items.add(_ItemEdit(it.name, it.quantity));
    }
    if (_items.isEmpty) _items.add(_ItemEdit('', 1));
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    _oldPrice.dispose();
    _sort.dispose();
    for (final i in _items) {
      i.dispose();
    }
    for (final i in _removed) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked =
        await FilePicker.pickFiles(type: FileType.image, withData: true);
    final f = picked?.files.firstOrNull;
    if (f == null || f.bytes == null) return;
    setState(() {
      _pickedBytes = f.bytes;
      _pickedName = f.name;
    });
  }

  void _snack(String msg, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.success : AppColors.danger,
    ));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Name is required.', ok: false);
      return;
    }
    if (_categoryId == null) {
      _snack('Choose a category.', ok: false);
      return;
    }
    final price = double.tryParse(_price.text.trim());
    if (price == null || price < 0) {
      _snack('Enter a valid price.', ok: false);
      return;
    }
    final oldText = _oldPrice.text.trim();
    final oldPrice = oldText.isEmpty ? null : double.tryParse(oldText);
    if (oldText.isNotEmpty && (oldPrice == null || oldPrice <= price)) {
      _snack('Old price must be higher than the price.', ok: false);
      return;
    }
    final sort = int.tryParse(_sort.text.trim()) ?? 0;

    final items = <({String name, int quantity})>[];
    for (final it in _items) {
      final n = it.name.text.trim();
      if (n.isEmpty) continue;
      final q = int.tryParse(it.qty.text.trim()) ?? 1;
      items.add((name: n, quantity: q < 1 ? 1 : q));
    }

    setState(() => _busy = true);
    final api = ref.read(serviceCatalogApiProvider);

    var imagePath = _imagePath;
    if (_pickedBytes != null && _pickedName != null) {
      final up = await api.uploadImage(_pickedBytes!, _pickedName!);
      if (!up.ok || up.path == null) {
        if (!mounted) return;
        setState(() => _busy = false);
        _snack(up.message, ok: false);
        return;
      }
      imagePath = up.path;
    }

    final desc = _desc.text.trim();
    final res = await api.savePackage(
      id: widget.existing?.id,
      name: name,
      description: desc.isEmpty ? null : desc,
      categoryId: _categoryId!,
      imagePath: imagePath,
      price: price,
      oldPrice: oldPrice,
      status: _status,
      sortOrder: sort,
      items: items,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(res.message ?? (res.ok ? 'Saved.' : 'Failed.'), ok: res.ok);
    if (res.ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final hasPicked = _pickedBytes != null;
    final hasExistingImg = _imagePath != null && _imagePath!.isNotEmpty;
    final statuses = <String>{'Active', 'Inactive', _status}.toList();
    final money = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add package' : 'Edit package'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: 'Package name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Category', border: OutlineInputBorder()),
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
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Description', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: money,
                      decoration: const InputDecoration(
                          labelText: 'Price',
                          prefixText: 'Rs ',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _oldPrice,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: money,
                      decoration: const InputDecoration(
                          labelText: 'Old price (optional)',
                          prefixText: 'Rs ',
                          border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'The discount % is worked out automatically from the two prices.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(
                          labelText: 'Status', border: OutlineInputBorder()),
                      items: [
                        for (final s in statuses)
                          DropdownMenuItem<String>(value: s, child: Text(s)),
                      ],
                      onChanged: (v) =>
                          setState(() => _status = v ?? _status),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _sort,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                          labelText: 'Display order',
                          border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: hasPicked
                        ? const Icon(Icons.check_circle,
                            color: AppColors.success)
                        : hasExistingImg
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  serviceImageUrl(_imagePath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image),
                                ),
                              )
                            : const Icon(Icons.image_outlined,
                                color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _pickImage,
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        hasPicked
                            ? (_pickedName ?? 'Image selected')
                            : (hasExistingImg ? 'Replace photo' : 'Upload photo'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('What the package includes',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              for (var i = 0; i < _items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _items[i].name,
                          decoration: const InputDecoration(
                              labelText: 'Item',
                              border: OutlineInputBorder(),
                              isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        child: TextField(
                          controller: _items[i].qty,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: const InputDecoration(
                              labelText: 'Qty',
                              border: OutlineInputBorder(),
                              isDense: true),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: AppColors.danger),
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _removed.add(_items.removeAt(i));
                                }),
                      ),
                    ],
                  ),
                ),
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => setState(() => _items.add(_ItemEdit('', 1))),
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
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
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}
