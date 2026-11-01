// A catalog service (GET /api/services) with the Phase 2B fields.

double _toDouble(dynamic v) =>
    v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);

int _toInt(dynamic v) =>
    v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? 0);

String? _toStr(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

class ServiceItem {
  final int id;
  final String name;
  final String? description;
  final double charge; // offer / selling price
  final double? oldPrice; // regular price
  final int discountPercent;
  final String? imagePath;
  final List<String> imagePaths;
  final bool isActive;
  final int? categoryId;
  final String? durationText;
  final String? warranty;
  final bool homeServiceAvailable;
  final String? requirements;
  final bool isFeatured;
  final int sortOrder;

  const ServiceItem({
    required this.id,
    required this.name,
    required this.description,
    required this.charge,
    required this.oldPrice,
    required this.discountPercent,
    required this.imagePath,
    required this.imagePaths,
    required this.isActive,
    required this.categoryId,
    required this.durationText,
    required this.warranty,
    required this.homeServiceAvailable,
    required this.requirements,
    required this.isFeatured,
    required this.sortOrder,
  });

  bool get hasDiscount => oldPrice != null && oldPrice! > charge && charge > 0;

  /// Gallery to show: the API gallery, or the single main image.
  List<String> get gallery => imagePaths.isNotEmpty
      ? imagePaths
      : (imagePath != null ? [imagePath!] : const []);

  factory ServiceItem.fromJson(Map<String, dynamic> j) => ServiceItem(
    id: _toInt(j['id']),
    name: (j['name'] ?? '').toString(),
    description: _toStr(j['description']),
    charge: _toDouble(j['charge']),
    oldPrice: j['oldPrice'] == null ? null : _toDouble(j['oldPrice']),
    discountPercent: _toInt(j['discountPercent']),
    imagePath: _toStr(j['imagePath']),
    imagePaths: ((j['imagePaths'] as List?) ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList(),
    isActive: j['isActive'] != false,
    categoryId: j['categoryId'] == null ? null : _toInt(j['categoryId']),
    durationText: _toStr(j['durationText']),
    warranty: _toStr(j['warranty']),
    homeServiceAvailable: j['homeServiceAvailable'] != false,
    requirements: _toStr(j['requirements']),
    isFeatured: j['isFeatured'] == true,
    sortOrder: _toInt(j['sortOrder']),
  );
}

// Counts for the dashboard (GET /api/ServiceStats).
class RecentServiceBooking {
  final int id;
  final String serviceType;
  final String status;
  final String customerName;

  const RecentServiceBooking({
    required this.id,
    required this.serviceType,
    required this.status,
    required this.customerName,
  });

  factory RecentServiceBooking.fromJson(Map<String, dynamic> j) =>
      RecentServiceBooking(
        id: _toInt(j['id']),
        serviceType: (j['serviceType'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        customerName: (j['customerName'] ?? '').toString(),
      );
}

class ServiceStats {
  final int mainCategories;
  final int subCategories;
  final int services;
  final int activeServices;
  final int inactiveServices;
  final int featuredServices;
  final int packages;
  final int bookings;
  final List<RecentServiceBooking> recent;

  const ServiceStats({
    required this.mainCategories,
    required this.subCategories,
    required this.services,
    required this.activeServices,
    required this.inactiveServices,
    required this.featuredServices,
    required this.packages,
    required this.bookings,
    required this.recent,
  });

  factory ServiceStats.fromJson(Map<String, dynamic> j) => ServiceStats(
    mainCategories: _toInt(j['mainCategories']),
    subCategories: _toInt(j['subCategories']),
    services: _toInt(j['services']),
    activeServices: _toInt(j['activeServices']),
    inactiveServices: _toInt(j['inactiveServices']),
    featuredServices: _toInt(j['featuredServices']),
    packages: _toInt(j['packages']),
    bookings: _toInt(j['bookings']),
    recent: ((j['recentBookings'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(RecentServiceBooking.fromJson)
        .toList(),
  );
}
