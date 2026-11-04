import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_config.dart';

// Coloured status pill used throughout the tables.
class StatusBadge extends StatelessWidget {
  final String? status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withAlpha(90)),
      ),
      child: Text(
        (status == null || status!.isEmpty) ? '—' : status!,
        style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// Standard loading / error / empty handling for a FutureProvider list.
class AsyncListView<T> extends StatelessWidget {
  final AsyncValue<List<T>> value;
  final Widget Function(List<T> items) builder;
  final VoidCallback onRetry;
  final String emptyText;

  const AsyncListView({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
    this.emptyText = 'Nothing here yet.',
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(
        child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
            const SizedBox(height: 12),
            Text('Could not load. $e', style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Text(emptyText, style: const TextStyle(color: AppColors.textMuted)),
            ),
          );
        }
        return builder(items);
      },
    );
  }
}

// Page header with a title and optional trailing actions.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const SectionHeader(this.title, {super.key, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, c) {
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: const TextStyle(color: AppColors.textMuted)),
              ],
            ],
          );

          // On narrow screens, stack the actions below the title so nothing
          // overflows. On wide screens keep them on the same row.
          if (c.maxWidth < 600 && actions.isNotEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleBlock),
              ...actions,
            ],
          );
        },
      ),
    );
  }
}

// A card wrapper around a horizontally-scrollable DataTable.
class TableCard extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  const TableCard({super.key, required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: (MediaQuery.of(context).size.width - 320).clamp(0.0, 4000.0).toDouble()),
            child: AdaptiveTable(columns: columns, rows: rows),
          ),
        ),
      ),
    );
  }
}

// Asks for a required reason (rejection). Returns the text or null if cancelled.
Future<String?> askReason(BuildContext context, String title, String hint) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        maxLines: 3,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (ctrl.text.trim().isEmpty) return;
            Navigator.pop(ctx, ctrl.text.trim());
          },
          child: const Text('Submit'),
        ),
      ],
    ),
  );
}

// Generic yes/no confirm. Returns true if confirmed.
Future<bool> confirm(BuildContext context, String title, String message) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? AppColors.danger : AppColors.primary,
    behavior: SnackBarBehavior.floating,
  ));
}

// On wide screens a normal DataTable; on a phone each row becomes a small card
// (label: value) so nothing is cut off or needs sideways scrolling.
class AdaptiveTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  const AdaptiveTable({super.key, required this.columns, required this.rows});

  static String _label(DataColumn c) {
    final w = c.label;
    return w is Text ? (w.data ?? '') : '';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 760) return DataTable(columns: columns, rows: rows);

    final cardWidth = (width - 120).clamp(240.0, 600.0).toDouble();
    return SizedBox(
      width: cardWidth,
      child: Column(
        children: [
          for (final r in rows)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < r.cells.length && i < columns.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 92,
                            child: Text(_label(columns[i]),
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textMuted)),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: r.cells[i].child,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
