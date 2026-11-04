import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_config.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

// ── Providers ────────────────────────────────────────────────────────────────
final vendorPayoutsProvider =
    FutureProvider.autoDispose<List<VendorPayoutSummary>>(
  (ref) => ref.read(adminServiceProvider).vendorsForPayout(),
);

final vendorPaymentHistoryProvider =
    FutureProvider.autoDispose<List<VendorPaymentRow>>(
  (ref) => ref.read(adminServiceProvider).vendorPaymentHistory(),
);

// ── Screen ───────────────────────────────────────────────────────────────────
// Admin pays vendors their commission/settlement against each vendor's own QR.
//  1. Vendors — scan the vendor's QR, pay externally, then record the payment
//     here with the amount + a screenshot of the transfer.
//  2. History — every payment made, with the vendor's confirmation status.
class VendorPayoutsScreen extends ConsumerWidget {
  const VendorPayoutsScreen({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(vendorPayoutsProvider);
    ref.invalidate(vendorPaymentHistoryProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            'Vendor Payouts',
            subtitle: 'Pay vendors their commission and keep a shared record',
            actions: [
              OutlinedButton.icon(
                onPressed: () => _refresh(ref),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          _vendorsCard(context, ref),
          const SizedBox(height: 24),
          _historyCard(context, ref),
        ],
      ),
    );
  }

  // ── 1. Vendors to pay ──────────────────────────────────────────────────────
  Widget _vendorsCard(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vendorPayoutsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pay Your Vendors',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Failed to load vendors: $e'),
              data: (rows) => rows.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('No approved vendors yet.',
                            style: TextStyle(color: AppColors.textMuted)),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: AdaptiveTable(
                        columns: const [
                          DataColumn(label: Text('Vendor')),
                          DataColumn(label: Text('Phone')),
                          DataColumn(label: Text('Commission')),
                          DataColumn(label: Text('QR')),
                          DataColumn(label: Text('Total Paid')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: rows.map((v) => _vendorRow(context, ref, v)).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _vendorRow(BuildContext context, WidgetRef ref, VendorPayoutSummary v) {
    return DataRow(cells: [
      DataCell(Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v.businessName,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(v.ownerName,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      )),
      DataCell(Text(v.phone)),
      DataCell(Text('${v.commissionRate.toStringAsFixed(1)}%')),
      DataCell(
        v.hasQr
            ? InkWell(
                onTap: () => _viewImage(context, v.paymentQrPath!, 'Vendor QR'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        _fullUrl(v.paymentQrPath!),
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image, size: 20),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.zoom_in, size: 16, color: AppColors.textMuted),
                  ],
                ),
              )
            : const Text('No QR',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ),
      DataCell(Text('Rs ${v.totalPaid.toStringAsFixed(0)}')),
      DataCell(
        FilledButton.icon(
          onPressed: v.hasQr ? () => _openPayDialog(context, ref, v) : null,
          icon: const Icon(Icons.payments_outlined, size: 16),
          label: const Text('Pay'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: const Size(0, 36),
          ),
        ),
      ),
    ]);
  }

  Future<void> _openPayDialog(
      BuildContext context, WidgetRef ref, VendorPayoutSummary v) async {
    final paid = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PayVendorDialog(vendor: v),
    );
    if (paid == true) _refresh(ref);
  }

  // ── 2. History ─────────────────────────────────────────────────────────────
  Widget _historyCard(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vendorPaymentHistoryProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment History',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Failed to load history: $e'),
              data: (rows) => rows.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('No payments recorded yet.',
                            style: TextStyle(color: AppColors.textMuted)),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: AdaptiveTable(
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Vendor')),
                          DataColumn(label: Text('Amount')),
                          DataColumn(label: Text('Note')),
                          DataColumn(label: Text('Proof')),
                          DataColumn(label: Text('Status')),
                        ],
                        rows: rows.map((p) => _historyRow(context, p)).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _historyRow(BuildContext context, VendorPaymentRow p) {
    return DataRow(cells: [
      DataCell(Text(_date(p.createdAt))),
      DataCell(SizedBox(
        width: 150,
        child: Text(p.vendorName, overflow: TextOverflow.ellipsis),
      )),
      DataCell(Text('Rs ${p.amount.toStringAsFixed(0)}')),
      DataCell(SizedBox(
        width: 160,
        child: Text(p.note ?? '—', overflow: TextOverflow.ellipsis),
      )),
      DataCell(
        (p.screenshotPath == null || p.screenshotPath!.isEmpty)
            ? const Text('—')
            : TextButton.icon(
                icon: const Icon(Icons.image, size: 16),
                label: const Text('View'),
                onPressed: () =>
                    _viewImage(context, p.screenshotPath!, 'Payment proof'),
              ),
      ),
      DataCell(StatusBadge(p.isAcknowledged ? 'Acknowledged' : 'Paid')),
    ]);
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  static String _fullUrl(String path) =>
      path.startsWith('http') ? path : '${AppConfig.baseUrl}$path';

  static String _date(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final l = d.toLocal();
    final mm = l.month.toString().padLeft(2, '0');
    final dd = l.day.toString().padLeft(2, '0');
    return '${l.year}-$mm-$dd';
  }

  void _viewImage(BuildContext context, String path, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(title),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    _fullUrl(path),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Could not load image.'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pay dialog ───────────────────────────────────────────────────────────────
class _PayVendorDialog extends ConsumerStatefulWidget {
  final VendorPayoutSummary vendor;
  const _PayVendorDialog({required this.vendor});

  @override
  ConsumerState<_PayVendorDialog> createState() => _PayVendorDialogState();
}

class _PayVendorDialogState extends ConsumerState<_PayVendorDialog> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  List<int>? _shotBytes;
  String? _shotName;
  bool _busy = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickShot() async {
    final picked =
        await FilePicker.pickFiles(type: FileType.image, withData: true);
    final file = picked?.files.firstOrNull;
    if (file == null || file.bytes == null) return;
    setState(() {
      _shotBytes = file.bytes;
      _shotName = file.name;
    });
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      _snack('Enter a valid amount.', ok: false);
      return;
    }
    if (_shotBytes == null || _shotName == null) {
      _snack('Attach a payment screenshot.', ok: false);
      return;
    }

    setState(() => _busy = true);
    final svc = ref.read(adminServiceProvider);

    final up = await svc.uploadPaymentScreenshot(_shotBytes!, _shotName!);
    if (!up.ok || up.path == null) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(up.message, ok: false);
      return;
    }

    final res = await svc.recordVendorPayment(
      vendorId: widget.vendor.vendorId,
      amount: amount,
      note: _noteCtrl.text.trim(),
      screenshotPath: up.path!,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(res.message ?? (res.ok ? 'Payment recorded.' : 'Failed.'), ok: res.ok);
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

  @override
  Widget build(BuildContext context) {
    final v = widget.vendor;
    final hasShot = _shotBytes != null;

    return AlertDialog(
      title: Text('Pay ${v.businessName}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${v.ownerName} • ${v.phone}',
                  style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (v.hasQr)
                    Container(
                      width: 140,
                      height: 140,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          VendorPayoutsScreen._fullUrl(v.paymentQrPath!),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    ),
                  const Expanded(
                    child: Text(
                      'Scan this QR in your payment app, pay the vendor, then enter the amount and attach a screenshot of the transfer.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount paid (Rs)',
                  prefixText: 'Rs ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Commission settlement — Sept 2026',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickShot,
                icon: Icon(hasShot ? Icons.check_circle : Icons.upload_file,
                    color: hasShot ? AppColors.success : null),
                label: Text(hasShot ? (_shotName ?? 'Screenshot attached') : 'Attach payment screenshot'),
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
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Record Payment'),
        ),
      ],
    );
  }
}
