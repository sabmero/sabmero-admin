import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_config.dart';
import '../../models/models.dart';
import '../../models/service_catalog_models.dart' show serviceImageUrl;
import '../../providers/providers.dart';
import '../../providers/service_catalog_providers.dart';
import '../../widgets/common.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  void _refresh(WidgetRef ref) => ref.invalidate(categoriesProvider);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Categories',
          subtitle: 'Product categories',
          actions: [
            ElevatedButton.icon(
              onPressed: () => _edit(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('New category'),
            ),
          ],
        ),
        Expanded(
          child: AsyncListView<CategoryRow>(
            value: async,
            onRetry: () => _refresh(ref),
            emptyText: 'No categories.',
            builder: (rows) => SingleChildScrollView(
              child: TableCard(
                columns: const [
                  DataColumn(label: Text('Image')),
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Products')),
                  DataColumn(label: Text('Active')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: rows
                    .map((c) => DataRow(cells: [
                          DataCell(_thumb(c.imagePath)),
                          DataCell(Text('${c.id}')),
                          DataCell(Text(c.name)),
                          DataCell(Text('${c.productCount}')),
                          DataCell(StatusBadge(c.isActive ? 'Active' : 'Inactive')),
                          DataCell(Row(children: [
                            IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _edit(context, ref, c)),
                            IconButton(
                                icon: const Icon(Icons.delete, size: 18, color: AppColors.danger),
                                onPressed: () => _delete(context, ref, c)),
                          ])),
                        ]))
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _thumb(String? path) {
    final has = path != null && path.isNotEmpty;
    if (!has) {
      return const Icon(Icons.image_not_supported_outlined,
          color: AppColors.textMuted);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        serviceImageUrl(path),
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 24),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, CategoryRow? existing) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CategoryFormDialog(existing: existing),
    );
    if (saved == true) _refresh(ref);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, CategoryRow c) async {
    final ok = await confirm(context, 'Delete category?', '"${c.name}" will be removed.');
    if (!ok) return;
    final res = await ref.read(adminServiceProvider).deleteCategory(c.id);
    if (!context.mounted) return;
    toast(context, res.ok ? 'Deleted' : (res.message ?? 'Failed'), error: !res.ok);
    if (res.ok) _refresh(ref);
  }
}

// Add / edit one product category, including its photo. The photo is uploaded
// first and the returned path is saved with the category, so the customer app
// shows it on the Home screen and in the category lists.
class _CategoryFormDialog extends ConsumerStatefulWidget {
  const _CategoryFormDialog({required this.existing});
  final CategoryRow? existing;

  @override
  ConsumerState<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<_CategoryFormDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late bool _active = widget.existing?.isActive ?? true;
  late String? _imagePath = widget.existing?.imagePath;
  List<int>? _pickedBytes;
  String? _pickedName;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await FilePicker.pickFiles(type: FileType.image, withData: true);
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
    setState(() => _busy = true);

    var imagePath = _imagePath;
    if (_pickedBytes != null && _pickedName != null) {
      final up = await ref
          .read(serviceCatalogApiProvider)
          .uploadImage(_pickedBytes!, _pickedName!);
      if (!up.ok || up.path == null) {
        if (!mounted) return;
        setState(() => _busy = false);
        _snack(up.message, ok: false);
        return;
      }
      imagePath = up.path;
    }

    final svc = ref.read(adminServiceProvider);
    final existing = widget.existing;
    final res = existing == null
        ? await svc.createCategory(name, imagePath: imagePath)
        : await svc.updateCategory(existing.id, name, _active, imagePath: imagePath);
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(res.ok ? 'Saved' : (res.message ?? 'Failed'), ok: res.ok);
    if (res.ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final hasPicked = _pickedBytes != null;
    final hasExistingImg = _imagePath != null && _imagePath!.isNotEmpty;

    return AlertDialog(
      title: Text(widget.existing == null ? 'New category' : 'Edit category'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: hasPicked
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              Uint8List.fromList(_pickedBytes!),
                              fit: BoxFit.cover,
                            ),
                          )
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
                            ? (_pickedName ?? 'Photo selected')
                            : (hasExistingImg ? 'Replace photo' : 'Upload photo'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
