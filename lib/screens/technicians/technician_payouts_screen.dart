import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/app_config.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

// ── Models ───────────────────────────────────────────────────────────────────
double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String _s(dynamic v) => v?.toString() ?? '';

class TechnicianPayoutSummary {
  final int technicianId, completedJobs;
  final String name, phone, role;
  final double totalServiceCharge, totalPaid, deliveryFees;
  final double cashCollected, remitted, cashHeld;
  final int pendingRemittances;
  final String? paymentQrPath;
  final double commissionPercent, earned, payable;
  TechnicianPayoutSummary.fromJson(Map<String, dynamic> j)
      : commissionPercent = _d(j['commissionPercent']),
        earned = _d(j['earned']),
        payable = _d(j['payable']),
        cashCollected = _d(j['cashCollected']),
        remitted = _d(j['remitted']),
        cashHeld = _d(j['cashHeld']),
        pendingRemittances = _i(j['pendingRemittances']),
        paymentQrPath = (j['paymentQrPath']?.toString().isEmpty ?? true)
            ? null
            : j['paymentQrPath'].toString(),
        technicianId = _i(j['technicianId']),
        completedJobs = _i(j['completedJobs']),
        name = _s(j['name']),
        phone = _s(j['phone']),
        role = _s(j['role']).isEmpty ? 'Technician' : _s(j['role']),
        totalServiceCharge = _d(j['totalServiceCharge']),
        deliveryFees = _d(j['deliveryFees']),
        totalPaid = _d(j['totalPaid']);
  bool get isRider => role == 'Rider';
}

class TechnicianPaymentRow {
  final int id;
  final String technicianName, status, createdAt, method, role;
  final double amount;
  final String? note, screenshotPath, amountInWords;
  TechnicianPaymentRow.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        technicianName = _s(j['technicianName']),
        role = _s(j['role']).isEmpty ? 'Technician' : _s(j['role']),
        status = _s(j['status']),
        createdAt = _s(j['createdAt']),
        method = _s(j['method']).isEmpty ? 'Cash' : _s(j['method']),
        amount = _d(j['amount']),
        note = j['note']?.toString(),
        amountInWords = j['amountInWords']?.toString(),
        screenshotPath = j['screenshotPath']?.toString();
}

// Money a technician / rider handed over to SabMero (needs admin verification).
class RemittanceRow {
  final int id;
  final String staffName, role, method, status, createdAt;
  final double amount;
  final String? amountInWords, screenshotPath, note, rejectReason;
  RemittanceRow.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        staffName = _s(j['staffName']),
        role = _s(j['role']),
        method = _s(j['method']).isEmpty ? 'Cash' : _s(j['method']),
        status = _s(j['status']).isEmpty ? 'Pending' : _s(j['status']),
        createdAt = _s(j['createdAt']),
        amount = _d(j['amount']),
        amountInWords = j['amountInWords']?.toString(),
        screenshotPath = j['screenshotPath']?.toString(),
        note = j['note']?.toString(),
        rejectReason = j['rejectReason']?.toString();
}

// What technicians collected from customers (completed jobs).
class CollectionSummary {
  final int technicianId, jobs;
  final String technicianName, role;
  final double cash, online, total, paidToTechnician, deliveryFees;
  CollectionSummary.fromJson(Map<String, dynamic> j)
      : technicianId = _i(j['technicianId']),
        jobs = _i(j['jobs']),
        technicianName = _s(j['technicianName']),
        role = _s(j['role']).isEmpty ? 'Technician' : _s(j['role']),
        deliveryFees = _d(j['deliveryFees']),
        cash = _d(j['cash']),
        online = _d(j['online']),
        total = _d(j['total']),
        paidToTechnician = _d(j['paidToTechnician']);
}

class CollectionRow {
  final int bookingId;
  final String technicianName, serviceType, customerName, method, kind, role;
  final double amount;
  final String? amountInWords, screenshotPath, completedAt;
  CollectionRow.fromJson(Map<String, dynamic> j)
      : bookingId = _i(j['bookingId']),
        kind = _s(j['kind']).isEmpty ? 'Booking' : _s(j['kind']),
        role = _s(j['role']).isEmpty ? 'Technician' : _s(j['role']),
        technicianName = _s(j['technicianName']),
        serviceType = _s(j['serviceType']),
        customerName = _s(j['customerName']),
        method = _s(j['method']).isEmpty ? 'Cash' : _s(j['method']),
        amount = _d(j['amount']),
        amountInWords = j['amountInWords']?.toString(),
        screenshotPath = j['screenshotPath']?.toString(),
        completedAt = j['completedAt']?.toString();
}

class CollectionsReport {
  final double totalCash, totalOnline, totalPaid;
  final List<CollectionSummary> summary;
  final List<CollectionRow> rows;
  CollectionsReport(this.totalCash, this.totalOnline, this.totalPaid,
      this.summary, this.rows);
  factory CollectionsReport.fromJson(Map<String, dynamic> j) =>
      CollectionsReport(
        _d(j['totalCash']),
        _d(j['totalOnline']),
        _d(j['totalPaidToTechnicians']),
        _list(j['summary']).map(CollectionSummary.fromJson).toList(),
        _list(j['rows']).map(CollectionRow.fromJson).toList(),
      );
}

List<Map<String, dynamic>> _list(dynamic data) => data is List
    ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

// ── Providers ────────────────────────────────────────────────────────────────
final technicianPayoutsProvider =
    FutureProvider.autoDispose<List<TechnicianPayoutSummary>>((ref) async {
  final res = await ApiClient.instance.get('/technician-payments/technicians');
  return _list(res.data).map(TechnicianPayoutSummary.fromJson).toList();
});

final remittancesProvider =
    FutureProvider.autoDispose<List<RemittanceRow>>((ref) async {
  final res = await ApiClient.instance.get('/staff-remittances');
  return _list(res.data).map(RemittanceRow.fromJson).toList();
});

// (rider %, technician %)
final commissionProvider =
    FutureProvider.autoDispose<(double, double)>((ref) async {
  final res = await ApiClient.instance.get('/technician-payments/commission');
  final m = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
  return (_d(m['riderPercent']), _d(m['technicianPercent']));
});

final technicianHistoryProvider =
    FutureProvider.autoDispose<List<TechnicianPaymentRow>>((ref) async {
  final res = await ApiClient.instance.get('/technician-payments/history');
  return _list(res.data).map(TechnicianPaymentRow.fromJson).toList();
});

// '' = all dates, otherwise yyyy-MM-dd (Nepal local date).
final collectionsProvider = FutureProvider.autoDispose
    .family<CollectionsReport, String>((ref, date) async {
  final res = await ApiClient.instance.get('/technician-payments/collections',
      query: {if (date.isNotEmpty) 'date': date, 'tzOffsetMinutes': 345});
  final data = res.data;
  return CollectionsReport.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
});

// ── Screen ───────────────────────────────────────────────────────────────────
// Admin pays technicians, records it here, and the technician is notified.
class TechnicianPayoutsScreen extends ConsumerStatefulWidget {
  const TechnicianPayoutsScreen({super.key});

  @override
  ConsumerState<TechnicianPayoutsScreen> createState() =>
      _TechnicianPayoutsScreenState();
}

class _TechnicianPayoutsScreenState
    extends ConsumerState<TechnicianPayoutsScreen> {
  // Collections filter: '' = all dates.
  String _day = _today();

  static String _today() {
    // Nepal time (UTC+5:45) regardless of the browser's time zone.
    final n = DateTime.now().toUtc().add(const Duration(minutes: 345));
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(technicianPayoutsProvider);
    ref.invalidate(remittancesProvider);
    ref.invalidate(commissionProvider);
    ref.invalidate(technicianHistoryProvider);
    ref.invalidate(collectionsProvider);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_day) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2025),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() => _day =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
  }

  static String _fullUrl(String path) =>
      path.startsWith('http') ? path : '${AppConfig.baseUrl}$path';

  static String _date(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            'Staff Payouts',
            subtitle: 'Technicians & riders — what they collected, and payments you made to them',
            actions: [
              OutlinedButton.icon(
                onPressed: () => _refresh(ref),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          _commissionCard(context, ref),
          const SizedBox(height: 24),
          _remittancesCard(context, ref),
          const SizedBox(height: 24),
          _collectionsCard(context, ref),
          const SizedBox(height: 24),
          _techniciansCard(context, ref),
          const SizedBox(height: 24),
          _historyCard(context, ref),
        ],
      ),
    );
  }

  Widget _card(String title, Widget child) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );

  Widget _empty(String msg) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
            child: Text(msg,
                style: const TextStyle(color: AppColors.textMuted))),
      );

  void _viewProof(BuildContext context, String path) => showDialog(
        context: context,
        builder: (ctx) => Dialog(
          child: InteractiveViewer(child: Image.network(_fullUrl(path))),
        ),
      );

  Widget _collectionsCard(BuildContext context, WidgetRef ref) {
    final async = ref.watch(collectionsProvider(_day));
    final label = _day.isEmpty ? 'All dates' : _day;
    return _card(
      'Cash & Online collected (technicians & riders)',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(label),
              ),
              TextButton(
                onPressed: () => setState(() => _day = _today()),
                child: const Text('Today'),
              ),
              TextButton(
                onPressed: () => setState(() => _day = ''),
                child: const Text('All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Failed to load: $e'),
            data: (r) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 12, runSpacing: 8, children: [
                  _chip('Cash collected', r.totalCash, AppColors.success),
                  _chip('Online collected', r.totalOnline, AppColors.info),
                  _chip('Paid to technicians', r.totalPaid, AppColors.warning),
                ]),
                const SizedBox(height: 16),
                if (r.summary.isEmpty)
                  _empty('Nothing collected for this period.')
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: AdaptiveTable(
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Role')),
                        DataColumn(label: Text('Jobs / Deliveries')),
                        DataColumn(label: Text('Delivery fees')),
                        DataColumn(label: Text('Cash')),
                        DataColumn(label: Text('Online')),
                        DataColumn(label: Text('Total')),
                        DataColumn(label: Text('Paid to technician')),
                      ],
                      rows: r.summary
                          .map((s) => DataRow(cells: [
                                DataCell(Text(s.technicianName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                                DataCell(Text(s.role)),
                                DataCell(Text('${s.jobs}')),
                                DataCell(Text(s.role == 'Rider'
                                    ? 'Rs ${s.deliveryFees.toStringAsFixed(0)}'
                                    : '—')),
                                DataCell(Text('Rs ${s.cash.toStringAsFixed(0)}')),
                                DataCell(
                                    Text('Rs ${s.online.toStringAsFixed(0)}')),
                                DataCell(
                                    Text('Rs ${s.total.toStringAsFixed(0)}')),
                                DataCell(Text(
                                    'Rs ${s.paidToTechnician.toStringAsFixed(0)}')),
                              ]))
                          .toList(),
                    ),
                  ),
                if (r.rows.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Jobs',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: AdaptiveTable(
                      columns: const [
                        DataColumn(label: Text('Time')),
                        DataColumn(label: Text('Job')),
                        DataColumn(label: Text('Staff')),
                        DataColumn(label: Text('Customer')),
                        DataColumn(label: Text('Amount')),
                        DataColumn(label: Text('Method')),
                        DataColumn(label: Text('In words / proof')),
                      ],
                      rows: r.rows
                          .map((x) => DataRow(cells: [
                                DataCell(Text(_dateTime(x.completedAt))),
                                DataCell(Text('${x.kind} #${x.bookingId} • ${x.serviceType}')),
                                DataCell(Text('${x.technicianName} (${x.role})')),
                                DataCell(Text(x.customerName)),
                                DataCell(
                                    Text('Rs ${x.amount.toStringAsFixed(0)}')),
                                DataCell(StatusBadge(x.method)),
                                DataCell(
                                  (x.screenshotPath != null &&
                                          x.screenshotPath!.isNotEmpty)
                                      ? TextButton.icon(
                                          icon: const Icon(Icons.image,
                                              size: 16),
                                          label: const Text('Screenshot'),
                                          onPressed: () => _viewProof(
                                              context, x.screenshotPath!),
                                        )
                                      : SizedBox(
                                          width: 200,
                                          child: Text(x.amountInWords ?? '—',
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                ),
                              ]))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hand-overs staff sent to SabMero: verify / reject ──
  Future<void> _verify(RemittanceRow r) async {
    final res = await ApiClient.instance.post('/staff-remittances/${r.id}/verify');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.message ?? (res.ok ? 'Verified.' : 'Failed.')),
      backgroundColor: res.ok ? AppColors.success : AppColors.danger,
    ));
    _refresh(ref);
  }

  Future<void> _reject(RemittanceRow r) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReasonDialog(),
    );
    if (reason == null) return;
    final res = await ApiClient.instance
        .post('/staff-remittances/${r.id}/reject', body: {'reason': reason});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.message ?? (res.ok ? 'Rejected.' : 'Failed.')),
      backgroundColor: res.ok ? AppColors.success : AppColors.danger,
    ));
    _refresh(ref);
  }

  Widget _remittancesCard(BuildContext context, WidgetRef ref) {
    final async = ref.watch(remittancesProvider);
    return _card(
      'Money handed over to SabMero (verify)',
      async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Failed to load: $e'),
        data: (rows) => rows.isEmpty
            ? _empty('No hand-overs yet.')
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: AdaptiveTable(
                  columns: const [
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Staff')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Method')),
                    DataColumn(label: Text('In words / proof')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: rows
                      .map((r) => DataRow(cells: [
                            DataCell(Text(_dateTime(r.createdAt))),
                            DataCell(Text('${r.staffName} (${r.role})')),
                            DataCell(Text('Rs ${r.amount.toStringAsFixed(0)}')),
                            DataCell(Text(r.method)),
                            DataCell((r.screenshotPath != null &&
                                    r.screenshotPath!.isNotEmpty)
                                ? TextButton.icon(
                                    icon: const Icon(Icons.image, size: 16),
                                    label: const Text('Screenshot'),
                                    onPressed: () =>
                                        _viewProof(context, r.screenshotPath!),
                                  )
                                : SizedBox(
                                    width: 200,
                                    child: Text(r.amountInWords ?? '—',
                                        overflow: TextOverflow.ellipsis))),
                            DataCell(Tooltip(
                                message: r.rejectReason ?? '',
                                child: StatusBadge(r.status))),
                            DataCell(r.status == 'Pending'
                                ? Row(children: [
                                    FilledButton(
                                      onPressed: () => _verify(r),
                                      child: const Text('Verify'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: () => _reject(r),
                                      child: const Text('Reject'),
                                    ),
                                  ])
                                : const Text('—')),
                          ]))
                      .toList(),
                ),
              ),
      ),
    );
  }

  // Set / replace a staff member's own payout QR.
  Future<void> _setQr(TechnicianPayoutSummary t) async {
    final picked =
        await FilePicker.pickFiles(type: FileType.image, withData: true);
    final file = picked?.files.firstOrNull;
    if (file == null || file.bytes == null) return;
    final up = await ref
        .read(adminServiceProvider)
        .uploadPaymentScreenshot(file.bytes!, file.name);
    if (!mounted) return;
    if (!up.ok || up.path == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(up.message), backgroundColor: AppColors.danger));
      return;
    }
    final res = await ApiClient.instance.put(
        '/staff-remittances/staff/${t.technicianId}/qr',
        body: {'qrImagePath': up.path});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.message ?? (res.ok ? 'QR saved.' : 'Failed.')),
      backgroundColor: res.ok ? AppColors.success : AppColors.danger,
    ));
    _refresh(ref);
  }

  Widget _commissionCard(BuildContext context, WidgetRef ref) {
    final async = ref.watch(commissionProvider);
    return _card(
      'Commission (what staff earn)',
      async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Failed to load: $e'),
        data: (c) => Row(
          children: [
            Expanded(
              child: Text(
                'Rider: ${c.$1.toStringAsFixed(0)}% of delivery fee   •   '
                'Technician: ${c.$2.toStringAsFixed(0)}% of service charge',
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Change'),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => _CommissionDialog(rider: c.$1, tech: c.$2),
                );
                if (ok == true) _refresh(ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, double value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(24),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted)),
            Text('Rs ${value.toStringAsFixed(0)}',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16, color: color)),
          ],
        ),
      );

  static String _dateTime(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _techniciansCard(BuildContext context, WidgetRef ref) {
    final async = ref.watch(technicianPayoutsProvider);
    return _card(
      'Pay Your Technicians & Riders',
      async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Failed to load technicians: $e'),
        data: (rows) => rows.isEmpty
            ? _empty('No technicians yet.')
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: AdaptiveTable(
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Phone')),
                    DataColumn(label: Text('Jobs / Deliveries')),
                    DataColumn(label: Text('Charges / COD')),
                    DataColumn(label: Text('Delivery fees')),
                    DataColumn(label: Text('Earned')),
                    DataColumn(label: Text('Total paid')),
                    DataColumn(label: Text('To pay')),
                    DataColumn(label: Text('Cash held')),
                    DataColumn(label: Text('Payout QR')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: rows
                      .map((t) => DataRow(cells: [
                            DataCell(Text(t.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600))),
                            DataCell(Text(t.role)),
                            DataCell(Text(t.phone)),
                            DataCell(Text('${t.completedJobs}')),
                            DataCell(Text(
                                'Rs ${t.totalServiceCharge.toStringAsFixed(0)}')),
                            DataCell(Text(t.isRider
                                ? 'Rs ${t.deliveryFees.toStringAsFixed(0)}'
                                : '—')),
                            DataCell(Text(
                                'Rs ${t.earned.toStringAsFixed(0)} (${t.commissionPercent.toStringAsFixed(0)}%)')),
                            DataCell(
                                Text('Rs ${t.totalPaid.toStringAsFixed(0)}')),
                            DataCell(Text('Rs ${t.payable.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                            DataCell(Text(
                                'Rs ${t.cashHeld.toStringAsFixed(0)}'
                                '${t.pendingRemittances > 0 ? '  (${t.pendingRemittances} pending)' : ''}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: t.cashHeld > 0
                                        ? AppColors.warning
                                        : null))),
                            DataCell(Row(children: [
                              if (t.paymentQrPath != null)
                                TextButton(
                                  onPressed: () =>
                                      _viewProof(context, t.paymentQrPath!),
                                  child: const Text('View'),
                                ),
                              TextButton(
                                onPressed: () => _setQr(t),
                                child: Text(t.paymentQrPath == null
                                    ? 'Add QR'
                                    : 'Change'),
                              ),
                            ])),
                            DataCell(FilledButton.icon(
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => _PayDialog(tech: t),
                                );
                                if (ok == true) _refresh(ref);
                              },
                              icon: const Icon(Icons.payments_outlined,
                                  size: 16),
                              label: const Text('Pay'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                              ),
                            )),
                          ]))
                      .toList(),
                ),
              ),
      ),
    );
  }

  Widget _historyCard(BuildContext context, WidgetRef ref) {
    final async = ref.watch(technicianHistoryProvider);
    return _card(
      'Payment History',
      async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Failed to load history: $e'),
        data: (rows) => rows.isEmpty
            ? _empty('No payments recorded yet.')
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: AdaptiveTable(
                  columns: const [
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Method')),
                    DataColumn(label: Text('In words')),
                    DataColumn(label: Text('Note')),
                    DataColumn(label: Text('Proof')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: rows
                      .map((p) => DataRow(cells: [
                            DataCell(Text(_date(p.createdAt))),
                            DataCell(Text('${p.technicianName} (${p.role})')),
                            DataCell(
                                Text('Rs ${p.amount.toStringAsFixed(0)}')),
                            DataCell(Text(p.method)),
                            DataCell(SizedBox(
                                width: 160,
                                child: Text(p.amountInWords ?? '—',
                                    overflow: TextOverflow.ellipsis))),
                            DataCell(SizedBox(
                                width: 160,
                                child: Text(p.note ?? '—',
                                    overflow: TextOverflow.ellipsis))),
                            DataCell((p.screenshotPath == null ||
                                    p.screenshotPath!.isEmpty)
                                ? const Text('—')
                                : TextButton.icon(
                                    icon: const Icon(Icons.image, size: 16),
                                    label: const Text('View'),
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (ctx) => Dialog(
                                        child: InteractiveViewer(
                                          child: Image.network(
                                              _fullUrl(p.screenshotPath!)),
                                        ),
                                      ),
                                    ),
                                  )),
                            DataCell(StatusBadge(p.status)),
                          ]))
                      .toList(),
                ),
              ),
      ),
    );
  }
}

// ── Pay dialog ───────────────────────────────────────────────────────────────
class _PayDialog extends ConsumerStatefulWidget {
  final TechnicianPayoutSummary tech;
  const _PayDialog({required this.tech});

  @override
  ConsumerState<_PayDialog> createState() => _PayDialogState();
}

class _PayDialogState extends ConsumerState<_PayDialog> {
  late final _amountCtrl = TextEditingController(
      text: widget.tech.payable > 0
          ? widget.tech.payable.toStringAsFixed(0)
          : '');
  final _noteCtrl = TextEditingController();
  final _wordsCtrl = TextEditingController();
  String _method = 'Cash';
  List<int>? _shotBytes;
  String? _shotName;
  bool _busy = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _wordsCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.success : AppColors.danger,
    ));
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
    if (_method == 'Cash' && _wordsCtrl.text.trim().isEmpty) {
      _snack('Write the amount in words.', ok: false);
      return;
    }
    if (_method == 'Online' && _shotBytes == null) {
      _snack('Attach the online payment screenshot.', ok: false);
      return;
    }
    setState(() => _busy = true);

    String? shotPath;
    if (_method == 'Online' && _shotBytes != null && _shotName != null) {
      final up = await ref
          .read(adminServiceProvider)
          .uploadPaymentScreenshot(_shotBytes!, _shotName!);
      if (!up.ok || up.path == null) {
        if (!mounted) return;
        setState(() => _busy = false);
        _snack(up.message, ok: false);
        return;
      }
      shotPath = up.path;
    }

    final res = await ApiClient.instance.post('/technician-payments', body: {
      'technicianId': widget.tech.technicianId,
      'amount': amount,
      'method': _method,
      'amountInWords':
          _method == 'Cash' ? _wordsCtrl.text.trim() : null,
      'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      'screenshotPath': shotPath,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(res.message ?? (res.ok ? 'Payment recorded.' : 'Failed.'),
        ok: res.ok);
    if (res.ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tech;
    final hasShot = _shotBytes != null;
    return AlertDialog(
      title: Text('Pay ${t.name}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${t.role} • ${t.phone} • ${t.completedJobs} ${t.isRider ? 'deliveries' : 'jobs'} • ${t.isRider ? 'COD collected' : 'charges'} Rs ${t.totalServiceCharge.toStringAsFixed(0)}',
                  style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 16),
              TextField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'Cash',
                      label: Text('Cash'),
                      icon: Icon(Icons.payments_outlined)),
                  ButtonSegment(
                      value: 'Online',
                      label: Text('Online'),
                      icon: Icon(Icons.qr_code_2)),
                ],
                selected: {_method},
                onSelectionChanged: (v) => setState(() => _method = v.first),
              ),
              const SizedBox(height: 12),
              if (_method == 'Cash')
                TextField(
                  controller: _wordsCtrl,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Amount in words',
                    hintText: 'e.g. Five thousand rupees only',
                    border: OutlineInputBorder(),
                  ),
                ),
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Share for completed jobs — Nov 2026',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_method == 'Online' && t.paymentQrPath != null) ...[
                const Text('Scan this QR to pay:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Center(
                  child: Image.network(
                    t.paymentQrPath!.startsWith('http')
                        ? t.paymentQrPath!
                        : '${AppConfig.baseUrl}${t.paymentQrPath!}',
                    height: 200,
                    errorBuilder: (_, __, ___) =>
                        const Text('QR image could not be loaded.'),
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (_method == 'Online')
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                      'No QR set for this person — add it with "Add QR" in the table.',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              if (_method == 'Online')
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickShot,
                  icon: Icon(hasShot ? Icons.check_circle : Icons.upload_file,
                      color: hasShot ? AppColors.success : null),
                  label: Text(hasShot
                      ? (_shotName ?? 'Screenshot attached')
                      : 'Attach payment screenshot'),
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
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Record Payment'),
        ),
      ],
    );
  }
}


// ── Reject reason dialog (State owns the controller) ─────────────────────────
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject hand-over'),
      content: TextField(
        controller: _ctrl,
        maxLength: 200,
        decoration: const InputDecoration(
          labelText: 'Reason (optional)',
          hintText: 'e.g. Amount did not arrive',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
            child: const Text('Reject')),
      ],
    );
  }
}


// ── Commission dialog (State owns the controllers) ───────────────────────────
class _CommissionDialog extends StatefulWidget {
  const _CommissionDialog({required this.rider, required this.tech});
  final double rider, tech;

  @override
  State<_CommissionDialog> createState() => _CommissionDialogState();
}

class _CommissionDialogState extends State<_CommissionDialog> {
  late final _riderCtrl =
      TextEditingController(text: widget.rider.toStringAsFixed(0));
  late final _techCtrl =
      TextEditingController(text: widget.tech.toStringAsFixed(0));
  bool _busy = false;

  @override
  void dispose() {
    _riderCtrl.dispose();
    _techCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final r = double.tryParse(_riderCtrl.text.trim());
    final t = double.tryParse(_techCtrl.text.trim());
    if (r == null || t == null || r < 0 || r > 100 || t < 0 || t > 100) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter percentages between 0 and 100.')));
      return;
    }
    setState(() => _busy = true);
    final res = await ApiClient.instance.put('/technician-payments/commission',
        body: {'riderPercent': r, 'technicianPercent': t});
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.message ?? (res.ok ? 'Saved.' : 'Failed.')),
      backgroundColor: res.ok ? AppColors.success : AppColors.danger,
    ));
    if (res.ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Commission %'),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _riderCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Rider — % of delivery fee',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _techCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Technician — % of service charge',
                border: OutlineInputBorder()),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _busy ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
