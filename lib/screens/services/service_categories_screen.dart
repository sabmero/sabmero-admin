import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_config.dart';
import '../../models/service_catalog_models.dart';
import '../../providers/service_catalog_providers.dart';
import '../../widgets/common.dart';

class _FlatRow {
  final ServiceCategoryNode node;
  final int level; // 0 = main category, 1 = sub-category
  const _FlatRow(this.node, this.level);
}

// Admin management of the on-site service categories (main and sub), which
// group the services and packages shown in the customer app.
class ServiceCategoriesScreen extends ConsumerWidget {
  const ServiceCategoriesScreen({super.key});

  void _refresh(WidgetRef ref) => ref.invalidate(serviceCategoriesProvider);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(serviceCategoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Service Categories',
          subtitle: 'Main and sub categories for on-site services',
          actions: [
            FilledButton.icon(
              onPressed: () => _openForm(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Add category'),
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
          child: AsyncListView<ServiceCategoryNode>(
            value: async,
            onRetry: () => _refresh(ref),
            emptyText: 'No service categories yet. Add one.',
            builder: (roots) {
              final flat = <_FlatRow>[];
              for (final m in roots) {
                flat.add(_FlatRow(m, 0));
                for (final s in m.children) {
                  flat.add(_FlatRow(s, 1));
                }
              }
              return SingleChildScrollView(
                child: TableCard(
                  columns: const [
                    DataColumn(label: Text('Image')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Order')),
                    DataColumn(label: Text('Active')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: flat.map((f) => _row(context, ref, f)).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  DataRow _row(BuildContext context, WidgetRef ref, _FlatRow f) {
    final c = f.node;
    final isMain = f.level == 0;
    final hasImg = c.imagePath != null && c.imagePath!.isNotEmpty;
    return DataRow(cells: [
      DataCell(hasImg
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                serviceImageUrl(c.imagePath!),
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, size: 24),
              ),
            )
          : const Icon(Icons.category_outlined, color: AppColors.textMuted)),
      DataCell(Padding(
        padding: EdgeInsets.only(left: f.level * 24.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMain)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.subdirectory_arrow_right,
                    size: 16, color: AppColors.textMuted),
              ),
            Text(
              c.name,
              style: TextStyle(
                  fontWeight: isMain ? FontWeight.w600 : FontWeight.w400),
            ),
          ],
        ),
      )),
      DataCell(Text(isMain ? 'Main' : 'Sub')),
      DataCell(Text('${c.sortOrder}')),
      DataCell(StatusBadge(c.isActive ? 'Active' : 'Inactive')),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMain) ...[
            _btn('Add sub', AppColors.success,
                () => _openForm(context, ref, null, presetParentId: c.id)),
            const SizedBox(width: 6),
          ],
          _btn('Edit', AppColors.info, () => _openForm(context, ref, c)),
          const SizedBox(width: 6),
          _btn('Delete', AppColors.danger, () => _delete(context, ref, c)),
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
      BuildContext context, WidgetRef ref, ServiceCategoryNode c) async {
    final ok = await confirm(
        context, 'Delete category?', 'Remove "${c.name}" from the app?');
    if (!ok) return;
    final res = await ref.read(serviceCatalogApiProvider).deleteCategory(c.id);
    if (!context.mounted) return;
    toast(context, res.ok ? 'Deleted' : (res.message ?? 'Failed'),
        error: !res.ok);
    if (res.ok) _refresh(ref);
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref,
    ServiceCategoryNode? existing, {
    int? presetParentId,
  }) async {
    final mains = ref.read(serviceCategoriesProvider).maybeWhen(
          data: (d) => d,
          orElse: () => const <ServiceCategoryNode>[],
        );
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CategoryFormDialog(
        existing: existing,
        mains: mains,
        presetParentId: presetParentId,
      ),
    );
    if (saved == true) _refresh(ref);
  }
}

class _CategoryFormDialog extends ConsumerStatefulWidget {
  final ServiceCategoryNode? existing;
  final List<ServiceCategoryNode> mains;
  final int? presetParentId;
  const _CategoryFormDialog({
    required this.existing,
    required this.mains,
    this.presetParentId,
  });

  @override
  ConsumerState<_CategoryFormDialog> createState() =>
      _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<_CategoryFormDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _sort =
      TextEditingController(text: '${widget.existing?.sortOrder ?? 0}');
  late int? _parentId = widget.existing?.parentId ?? widget.presetParentId;
  late bool _active = widget.existing?.isActive ?? true;
  late String? _imagePath = widget.existing?.imagePath;
  List<int>? _pickedBytes;
  String? _pickedName;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _sort.dispose();
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

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Name is required.', ok: false);
      return;
    }
    final sort = int.tryParse(_sort.text.trim()) ?? 0;
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

    final res = await api.saveCategory(
      id: widget.existing?.id,
      name: name,
      imagePath: imagePath,
      parentId: _parentId,
      sortOrder: sort,
      isActive: _active,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(res.message ?? (res.ok ? 'Saved.' : 'Failed.'), ok: res.ok);
    if (res.ok) Navigator.pop(context, true);
  }

  void _snack(String msg, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.success : AppColors.danger,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasPicked = _pickedBytes != null;
    final hasExistingImg = _imagePath != null && _imagePath!.isNotEmpty;
    final hasChildren = widget.existing?.children.isNotEmpty ?? false;
    final parentChoices =
        widget.mains.where((m) => m.id != widget.existing?.id).toList();

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add category' : 'Edit category'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: 'Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _parentId,
                decoration: const InputDecoration(
                    labelText: 'Belongs to', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<int?>(
                      value: null, child: Text('None (main category)')),
                  ...parentChoices.map((m) =>
                      DropdownMenuItem<int?>(value: m.id, child: Text(m.name))),
                ],
                onChanged: hasChildren
                    ? null
                    : (v) => setState(() => _parentId = v),
              ),
              if (hasChildren)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'It has sub-categories, so it stays a main category.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _sort,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: 'Display order (0 = first)',
                    border: OutlineInputBorder()),
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
                            : (hasExistingImg ? 'Replace image' : 'Upload image'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}
