import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_config.dart';
import '../../models/models.dart';
import '../../models/service_item_model.dart';
import '../../providers/providers.dart';
import '../../services/service_admin_api.dart';
import '../../widgets/common.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            'Overview',
            subtitle: 'Platform at a glance',
            actions: [
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(dashboardProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          async.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Could not load dashboard. $e',
                style: const TextStyle(color: AppColors.danger)),
            data: (s) => s == null
                ? const Text('No data.')
                : _grid(context, s),
          ),
          const SizedBox(height: 28),
          _serviceSection(ref),
        ],
      ),
    );
  }

  // Service management counts and the latest service bookings.
  Widget _serviceSection(WidgetRef ref) {
    final async = ref.watch(serviceStatsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Service Management',
          subtitle: 'Categories, services and recent bookings',
          actions: [
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(serviceStatsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        async.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => const Text('Service statistics are unavailable.',
              style: TextStyle(color: AppColors.textMuted)),
          data: (s) {
            if (s == null) {
              return const Text('Service statistics are unavailable.',
                  style: TextStyle(color: AppColors.textMuted));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _gridOf([
                  _Stat('Main Categories', s.mainCategories.toString(), Icons.account_tree, AppColors.primary),
                  _Stat('Sub Categories', s.subCategories.toString(), Icons.subdirectory_arrow_right, AppColors.primaryLight),
                  _Stat('Total Services', s.services.toString(), Icons.handyman, AppColors.primary),
                  _Stat('Active Services', s.activeServices.toString(), Icons.check_circle, AppColors.success),
                  _Stat('Inactive Services', s.inactiveServices.toString(), Icons.pause_circle, AppColors.warning),
                  _Stat('Featured Services', s.featuredServices.toString(), Icons.star, AppColors.warning),
                  _Stat('Service Packages', s.packages.toString(), Icons.inventory_2, AppColors.primaryLight),
                  _Stat('Service Bookings', s.bookings.toString(), Icons.build, AppColors.info),
                ]),
                const SizedBox(height: 16),
                _recentBookings(s.recent),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _recentBookings(List<RecentServiceBooking> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent service bookings',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Text('No bookings yet.',
                  style: TextStyle(color: AppColors.textMuted))
            else
              for (final b in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 48, child: Text('#${b.id}')),
                      Expanded(
                        child: Text(
                          '${b.serviceType}  -  ${b.customerName}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(b.status),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _gridOf(List<_Stat> cards) {
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / 260).floor().clamp(1, 4);
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.2,
        children: cards.map((s) => _card(s)).toList(),
      );
    });
  }

  Widget _grid(BuildContext context, DashboardStats s) {
    final cards = <_Stat>[
      _Stat('Total Users', s.totalUsers.toString(), Icons.people, AppColors.info),
      _Stat('Customers', s.totalCustomers.toString(), Icons.person, AppColors.primaryLight),
      _Stat('Vendors', s.totalVendors.toString(), Icons.store, AppColors.primary),
      _Stat('Pending Vendor Requests', s.pendingVendors.toString(), Icons.how_to_reg, AppColors.warning),
      _Stat('Technicians', s.totalTechnicians.toString(), Icons.engineering, AppColors.info),
      _Stat('Riders', s.totalRiders.toString(), Icons.delivery_dining, AppColors.info),
      _Stat('Products', s.totalProducts.toString(), Icons.inventory_2, AppColors.primaryLight),
      _Stat('Categories', s.totalCategories.toString(), Icons.category, AppColors.primaryLight),
      _Stat('Total Orders', s.totalOrders.toString(), Icons.receipt_long, AppColors.primary),
      _Stat('Pending Orders', s.pendingOrders.toString(), Icons.hourglass_bottom, AppColors.warning),
      _Stat('Delivered Orders', s.deliveredOrders.toString(), Icons.check_circle, AppColors.success),
      _Stat('Total Bookings', s.totalBookings.toString(), Icons.build, AppColors.primary),
      _Stat('Pending Bookings', s.pendingBookings.toString(), Icons.pending_actions, AppColors.warning),
      _Stat('Pending Returns', s.pendingReturns.toString(), Icons.assignment_return, AppColors.danger),
      _Stat('Total Sales', 'Rs ${s.totalSales.toStringAsFixed(0)}', Icons.payments, AppColors.success),
      _Stat('Commission', 'Rs ${s.totalCommission.toStringAsFixed(0)}', Icons.account_balance, AppColors.primary),
    ];

    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / 260).floor().clamp(1, 4);
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.2,
        children: cards.map((s) => _card(s)).toList(),
      );
    });
  }

  Widget _card(_Stat s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: s.color.withAlpha(28),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(s.icon, color: s.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(s.value,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text)),
                  const SizedBox(height: 2),
                  Text(s.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat {
  final String label, value;
  final IconData icon;
  final Color color;
  _Stat(this.label, this.value, this.icon, this.color);
}
