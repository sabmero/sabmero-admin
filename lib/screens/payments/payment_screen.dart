import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_config.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

// ── Providers ────────────────────────────────────────────────────────────────
final qrPathProvider = FutureProvider.autoDispose<String>(
  (ref) => ref.read(adminServiceProvider).getQrPath(),
);

final pendingPaymentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.read(adminServiceProvider).pendingPayments(),
    );

// ── Screen ───────────────────────────────────────────────────────────────────
// Two sections:
//  1. Payment QR — the QR image customers see in the app at checkout.
//     Admin uploads/replaces it here (PUT /api/Payments/qr).
//  2. Pending payments — QR-paid orders/bookings whose screenshot is awaiting
//     verification. Screenshot previews inline; Approve/Reject notifies the
//     customer by push automatically.
class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            'Payments',
            subtitle: 'Payment QR & screenshot verification',
            actions: [
              OutlinedButton.icon(
                onPressed: () {
                  ref.invalidate(qrPathProvider);
                  ref.invalidate(pendingPaymentsProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          _qrSection(context, ref),
          const SizedBox(height: 24),
          _pendingSection(context, ref),
        ],
      ),
    );
  }

  // ── 1. QR management ───────────────────────────────────────────────────────
  Widget _qrSection(BuildContext context, WidgetRef ref) {
    final qrAsync = ref.watch(qrPathProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment QR Code',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'This QR is shown to customers in the app when they choose "QR Pay" at checkout. Upload your bank / FonePay / eSewa QR here.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            qrAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Failed to load QR: $e'),
              data: (path) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: path.isEmpty
                        ? const Center(
                            child: Text(
                              'No QR set yet',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _fullUrl(path),
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Center(child: Icon(Icons.broken_image)),
                            ),
                          ),
                  ),
                  const SizedBox(width: 20),
                  FilledButton.icon(
                    onPressed: () => _pickAndUploadQr(context, ref),
                    icon: const Icon(Icons.qr_code_2),
                    label: Text(path.isEmpty ? 'Upload QR' : 'Replace QR'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadQr(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = picked?.files.firstOrNull;
    if (file == null || file.bytes == null) return;

    final svc = ref.read(adminServiceProvider);
    final up = await svc.uploadQrImage(file.bytes!, file.name);
    if (!context.mounted) return;
    if (!up.ok || up.path == null) {
      _snack(context, up.message, ok: false);
      return;
    }

    final set = await svc.setQr(up.path!);
    if (!context.mounted) return;
    _snack(context, set.message, ok: set.ok);
    if (set.ok) ref.invalidate(qrPathProvider);
  }

  // ── 2. Pending payment screenshots ────────────────────────────────────────
  Widget _pendingSection(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingPaymentsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payments Awaiting Verification',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Failed to load: $e'),
              data: (rows) => rows.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No payments awaiting verification.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: AdaptiveTable(
                        columns: const [
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Ref')),
                          DataColumn(label: Text('Customer')),
                          DataColumn(label: Text('Amount')),
                          DataColumn(label: Text('Screenshot')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: rows.map((p) => _row(context, ref, p)).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, WidgetRef ref, Map<String, dynamic> p) {
    final type = (p['type'] ?? 'Order').toString();
    final id = int.tryParse('${p['id']}') ?? 0;
    final shot = p['screenshotPath']?.toString();

    return DataRow(
      cells: [
        DataCell(Text(type)),
        DataCell(Text('#$id')),
        DataCell(Text('${p['customerName'] ?? ''}')),
        DataCell(Text('Rs ${p['amount'] ?? ''}')),
        DataCell(
          (shot == null || shot.isEmpty)
              ? const Text('—')
              : InkWell(
                  onTap: () => _viewScreenshot(context, shot),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          _fullUrl(shot),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image, size: 20),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.zoom_in,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
        ),
        DataCell(
          Row(
            children: [
              _btn(
                'Approve',
                AppColors.success,
                () => _verify(context, ref, type, id, true),
              ),
              const SizedBox(width: 6),
              _btn(
                'Reject',
                AppColors.danger,
                () => _verify(context, ref, type, id, false),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      minimumSize: const Size(0, 32),
    ),
    onPressed: onTap,
    child: Text(label, style: const TextStyle(fontSize: 12)),
  );

  Future<void> _verify(
    BuildContext context,
    WidgetRef ref,
    String type,
    int id,
    bool approve,
  ) async {
    final res = await ref
        .read(adminServiceProvider)
        .verifyPayment(type, id, approve);
    if (!context.mounted) return;
    _snack(
      context,
      res.message ?? (approve ? 'Verified.' : 'Rejected.'),
      ok: res.ok,
    );
    if (res.ok) ref.invalidate(pendingPaymentsProvider);
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  static String _fullUrl(String path) =>
      path.startsWith('http') ? path : '${AppConfig.baseUrl}$path';

  void _viewScreenshot(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Payment Screenshot'),
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

  void _snack(BuildContext context, String msg, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ),
    );
  }
}
