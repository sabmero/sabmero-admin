import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/app_config.dart';

// Notification bell for the top bar. Polls /api/notifications/unread-count
// every 30s, shows a red badge, and opens a panel with the latest items.
class NotificationItem {
  final int id;
  final String title;
  final String body;
  final String type;
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.referenceId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        id: (j['id'] ?? j['Id'] ?? 0) as int,
        title: (j['title'] ?? j['Title'] ?? '').toString(),
        body: (j['body'] ?? j['Body'] ?? '').toString(),
        type: (j['type'] ?? j['Type'] ?? '').toString(),
        referenceId: (j['referenceId'] ?? j['ReferenceId'])?.toString(),
        isRead: (j['isRead'] ?? j['IsRead'] ?? false) == true,
        createdAt: DateTime.tryParse(
                    (j['createdAt'] ?? j['CreatedAt'] ?? '').toString())
                ?.toLocal() ??
            DateTime.now(),
      );
}

class NotificationApi {
  final _api = ApiClient.instance;

  Future<int> unreadCount() async {
    final res = await _api.get('/notifications/unread-count');
    if (!res.ok) return 0;
    final d = res.data;
    if (d is Map) return ((d['count'] ?? d['Count'] ?? 0) as num).toInt();
    if (d is num) return d.toInt();
    return 0;
  }

  Future<List<NotificationItem>> list() async {
    final res = await _api.get('/notifications');
    if (!res.ok || res.data is! List) return [];
    return (res.data as List)
        .whereType<Map>()
        .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> markRead(int id) => _api.post('/notifications/$id/read');
  Future<void> markAllRead() => _api.post('/notifications/read-all');
}

class NotificationBell extends StatefulWidget {
  // Optional: called when a notification is tapped (e.g. to switch tab).
  final void Function(NotificationItem item)? onOpen;
  const NotificationBell({super.key, this.onOpen});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _svc = NotificationApi();
  Timer? _timer;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final c = await _svc.unreadCount();
    if (mounted && c != _count) setState(() => _count = c);
  }

  Future<void> _open() async {
    await showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (_) => Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 56, right: 12, left: 12),
          child: _Panel(svc: _svc, onOpen: widget.onOpen),
        ),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: _open,
      icon: Badge(
        isLabelVisible: _count > 0,
        label: Text(_count > 99 ? '99+' : '$_count'),
        backgroundColor: AppColors.danger,
        child: const Icon(Icons.notifications_outlined, color: AppColors.text),
      ),
    );
  }
}

class _Panel extends StatefulWidget {
  final NotificationApi svc;
  final void Function(NotificationItem item)? onOpen;
  const _Panel({required this.svc, this.onOpen});

  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> {
  List<NotificationItem>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await widget.svc.list();
    if (mounted) setState(() => _items = l);
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  IconData _icon(String type) {
    if (type.startsWith('order')) return Icons.receipt_long_outlined;
    if (type.startsWith('booking')) return Icons.build_outlined;
    if (type.startsWith('vendor_request')) return Icons.how_to_reg_outlined;
    if (type.toLowerCase().contains('payment')) return Icons.payments_outlined;
    if (type == 'promo') return Icons.local_offer_outlined;
    return Icons.notifications_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final hasUnread = items?.any((e) => !e.isRead) ?? false;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: AppColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 520),
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Notifications',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    TextButton(
                      onPressed: hasUnread
                          ? () async {
                              await widget.svc.markAllRead();
                              _load();
                            }
                          : null,
                      child: const Text('Mark all read'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Flexible(
                child: items == null
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      )
                    : items.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('No notifications yet',
                                style: TextStyle(color: AppColors.textMuted)),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, color: AppColors.border),
                            itemBuilder: (_, i) {
                              final n = items[i];
                              return ListTile(
                                dense: true,
                                tileColor: n.isRead
                                    ? null
                                    : AppColors.primaryLight.withAlpha(24),
                                leading: Icon(_icon(n.type),
                                    color: AppColors.primaryLight),
                                title: Text(n.title,
                                    style: TextStyle(
                                        fontWeight: n.isRead
                                            ? FontWeight.w400
                                            : FontWeight.w700)),
                                subtitle: Text(n.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                trailing: Text(_ago(n.createdAt),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted)),
                                onTap: () async {
                                  if (!n.isRead) await widget.svc.markRead(n.id);
                                  if (!mounted) return;
                                  Navigator.of(context).pop();
                                  widget.onOpen?.call(n);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
