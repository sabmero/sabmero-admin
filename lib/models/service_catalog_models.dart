import '../core/app_config.dart';

// Models for on-site service categories (main / sub) and service packages.

double _toDouble(dynamic v) =>
    v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);

int _toInt(dynamic v) =>
    v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? 0);

// Full URL for an uploaded image path returned by the API.
String serviceImageUrl(String path) =>
    path.startsWith('http') ? path : '${AppConfig.baseUrl}$path';

// A main category (parentId == null) or a sub-category. Main categories carry
// their sub-categories in [children].
class ServiceCategoryNode {
  final int id;
  final String name;
  final String? imagePath;
  final int? parentId;
  final int sortOrder;
  final bool isActive;
  final List<ServiceCategoryNode> children;

  const ServiceCategoryNode({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.parentId,
    required this.sortOrder,
    required this.isActive,
    required this.children,
  });

  factory ServiceCategoryNode.fromJson(Map<String, dynamic> j) =>
      ServiceCategoryNode(
        id: _toInt(j['id']),
        name: (j['name'] ?? '').toString(),
        imagePath: j['imagePath']?.toString(),
        parentId: j['parentId'] == null ? null : _toInt(j['parentId']),
        sortOrder: _toInt(j['sortOrder']),
        isActive: j['isActive'] == true,
        children: ((j['children'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ServiceCategoryNode.fromJson)
            .toList(),
      );
}

// One choice in a category dropdown.
class ServiceCategoryOption {
  final int id;
  final String label;
  const ServiceCategoryOption(this.id, this.label);
}

// Flat list for dropdowns: "CCTV", "CCTV › Cameras", ...
List<ServiceCategoryOption> serviceCategoryOptions(
  List<ServiceCategoryNode> roots,
) {
  final out = <ServiceCategoryOption>[];
  for (final r in roots) {
    out.add(ServiceCategoryOption(r.id, r.name));
    for (final c in r.children) {
      out.add(ServiceCategoryOption(c.id, '${r.name} › ${c.name}'));
    }
  }
  return out;
}

class ServicePackageItemRow {
  final int id;
  final String name;
  final int quantity;

  const ServicePackageItemRow({
    required this.id,
    required this.name,
    required this.quantity,
  });

  factory ServicePackageItemRow.fromJson(Map<String, dynamic> j) =>
      ServicePackageItemRow(
        id: _toInt(j['id']),
        name: (j['name'] ?? '').toString(),
        quantity: _toInt(j['quantity']),
      );
}

class ServicePackageRow {
  final int id;
  final String name;
  final String? description;
  final int categoryId;
  final String? categoryName;
  final String? imagePath;
  final double price;
  final double? oldPrice;
  final int discountPercent;
  final String status;
  final int sortOrder;
  final List<ServicePackageItemRow> items;

  const ServicePackageRow({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.categoryName,
    required this.imagePath,
    required this.price,
    required this.oldPrice,
    required this.discountPercent,
    required this.status,
    required this.sortOrder,
    required this.items,
  });

  factory ServicePackageRow.fromJson(Map<String, dynamic> j) =>
      ServicePackageRow(
        id: _toInt(j['id']),
        name: (j['name'] ?? '').toString(),
        description: j['description']?.toString(),
        categoryId: _toInt(j['categoryId']),
        categoryName: j['categoryName']?.toString(),
        imagePath: j['imagePath']?.toString(),
        price: _toDouble(j['price']),
        oldPrice: j['oldPrice'] == null ? null : _toDouble(j['oldPrice']),
        discountPercent: _toInt(j['discountPercent']),
        status: (j['status'] ?? 'Active').toString(),
        sortOrder: _toInt(j['sortOrder']),
        items: ((j['items'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ServicePackageItemRow.fromJson)
            .toList(),
      );
}
