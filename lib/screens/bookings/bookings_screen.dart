import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/app_config.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  String? _status;

  void _refresh() => ref.invalidate(bookingsProvider(_status));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bookingsProvider(_status));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Bookings',
          subtitle: 'Repair & installation jobs',
          actions: [
            DropdownButton<String?>(
              value: _status,
              hint: const Text('All statuses'),
              items: const [
                DropdownMenuItem(value: null, child: Text('All statuses')),
                DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                DropdownMenuItem(value: 'Processing', child: Text('Processing')),
                DropdownMenuItem(value: 'Completed', child: Text('Completed')),
              ],
              onChanged: (v) => setState(() => _status = v),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
                onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
          ],
        ),
        Expanded(
          child: AsyncListView<BookingRow>(
            value: async,
            onRetry: _refresh,
            emptyText: 'No bookings.',
            builder: (rows) => SingleChildScrollView(
              child: TableCard(
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Service')),
                  DataColumn(label: Text('Time slot')),
                  DataColumn(label: Text('Address')),
                  DataColumn(label: Text('Payment')),
                  DataColumn(label: Text('To collect')),
                  DataColumn(label: Text('From order')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: rows.map(_row).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  DataRow _row(BookingRow b) {
    return DataRow(cells: [
      DataCell(Text('${b.id}')),
      DataCell(Text(b.serviceType)),
      DataCell(Text(b.timeSlot)),
      DataCell(SizedBox(width: 180, child: Text(b.serviceAddress, overflow: TextOverflow.ellipsis))),
      DataCell(Text(b.paymentMethod)),
      DataCell(Text(b.serviceCharge == null
          ? '—'
          : 'Rs ${b.serviceCharge!.toStringAsFixed(0)}')),
      DataCell(b.relatedOrderId != null
          ? Tooltip(
              message: 'Order #${b.relatedOrderId}',
              child: const Icon(Icons.link, size: 18, color: AppColors.info))
          : const Text('—')),
      DataCell(StatusBadge(b.status)),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 32),
            ),
            onPressed: () => _details(b),
            child: const Text('View', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          if (b.status != 'Completed') ...[
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: const Size(0, 32),
              ),
              onPressed: () => _setAmount(b),
              child: const Text('Set amount', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 6),
          ],
          if (b.status != 'Completed')
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: const Size(0, 32),
              ),
              onPressed: () => _assignTech(b),
              child: const Text('Assign tech', style: TextStyle(fontSize: 12)),
            ),
        ],
      )),
    ]);
  }

  static String _fullUrl(String path) =>
      path.startsWith('http') ? path : '${AppConfig.baseUrl}$path';

  void _viewImage(String path, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(title),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(_fullUrl(path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(32), child: Text('Could not load image.'))),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _details(BookingRow b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Booking #${b.id} • ${b.serviceType}'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _kv('Customer', '${b.customerName}${b.customerPhone.isNotEmpty ? ' • ${b.customerPhone}' : ''}'),
                _kv('Time slot', b.timeSlot),
                _kv('Address', b.serviceAddress),
                _kv('Payment', b.paymentMethod),
                _kv(b.status == 'Completed' ? 'Collected' : 'To collect',
                    b.serviceCharge == null ? 'not set' : 'Rs ${b.serviceCharge!.toStringAsFixed(0)}'),
                const SizedBox(height: 12),
                const Text('Problem Description',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  (b.description == null || b.description!.trim().isEmpty)
                      ? 'No description provided.'
                      : b.description!,
                  style: TextStyle(
                      color: (b.description == null || b.description!.trim().isEmpty)
                          ? AppColors.textMuted
                          : AppColors.text),
                ),
                const SizedBox(height: 16),
                const Text('Damage Photos',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (b.damageImagePaths.isEmpty)
                  const Text('No photos uploaded.',
                      style: TextStyle(color: AppColors.textMuted))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: b.damageImagePaths
                        .map((path) => InkWell(
                              onTap: () => _viewImage(path, 'Damage photo'),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  _fullUrl(path),
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image, size: 36),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                if (b.paymentScreenshotPath != null && b.paymentScreenshotPath!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Payment Screenshot',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _viewImage(b.paymentScreenshotPath!, 'Payment screenshot'),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        _fullUrl(b.paymentScreenshotPath!),
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image, size: 36),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(color: AppColors.text, fontSize: 14),
            children: [
              TextSpan(text: '$k: ', style: const TextStyle(color: AppColors.textMuted)),
              TextSpan(text: v),
            ],
          ),
        ),
      );

  Future<void> _setAmount(BookingRow b) async {
    final v = await showDialog<double>(
      context: context,
      builder: (_) => _AmountDialog(initial: b.serviceCharge),
    );
    if (v == null) return;
    final res = await ApiClient.instance
        .put('/technician-payments/bookings/${b.id}/amount', body: {'amount': v});
    if (!mounted) return;
    toast(context, res.message ?? (res.ok ? 'Saved' : 'Failed'), error: !res.ok);
    if (res.ok) _refresh();
  }

  Future<void> _assignTech(BookingRow b) async {
    final techs = await ref.read(techniciansProvider.future);
    if (!mounted) return;
    if (techs.isEmpty) {
      toast(context, 'No technicians available. Add one first.', error: true);
      return;
    }

    int? selected = techs.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Assign technician to booking #${b.id}'),
          content: DropdownButtonFormField<int>(
            value: selected,
            decoration: const InputDecoration(labelText: 'Technician'),
            items: techs
                .map((t) => DropdownMenuItem(value: t.id, child: Text('${t.fullName} (${t.phone})')))
                .toList(),
            onChanged: (v) => setLocal(() => selected = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Assign')),
          ],
        ),
      ),
    );
    if (ok != true || selected == null) return;
    final res = await ref.read(adminServiceProvider).assignTechnician(b.id, selected!);
    if (!mounted) return;
    toast(context, res.ok ? (res.message ?? 'Assigned') : (res.message ?? 'Failed'), error: !res.ok);
    if (res.ok) _refresh();
  }
}


// Amount the customer must pay (State owns the controller).
class _AmountDialog extends StatefulWidget {
  const _AmountDialog({this.initial});
  final double? initial;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final _ctrl = TextEditingController(
      text: widget.initial == null ? '' : widget.initial!.toStringAsFixed(0));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Amount to collect from customer'),
      content: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(prefixText: 'Rs ', labelText: 'Amount'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final v = double.tryParse(_ctrl.text.trim());
            if (v == null || v < 0) return;
            Navigator.pop(context, v);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
