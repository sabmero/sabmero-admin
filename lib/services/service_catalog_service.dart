import '../core/api_client.dart';
import '../models/service_catalog_models.dart';

// Admin API for the on-site service catalog: categories (main + sub) and
// service packages. Rebuilt from how the Service Categories and Service
// Packages screens call it and from the backend controllers:
//   /api/ServiceCategories   GET (includeInactive) / POST / PUT {id} / DELETE {id}
//   /api/ServicePackages     GET / POST / PUT {id} / DELETE {id}
//   /api/Uploads/product     multipart upload, field "file", returns { path }
class ServiceCatalogService {
  final _api = ApiClient.instance;

  // ── Categories ──
  Future<List<ServiceCategoryNode>> categories() async {
    final res = await _api.get(
      '/ServiceCategories',
      query: {'includeInactive': true},
    );
    final data = res.data;
    if (!res.ok || data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ServiceCategoryNode.fromJson)
        .toList();
  }

  Future<ApiResult> saveCategory({
    int? id,
    required String name,
    String? imagePath,
    int? parentId,
    required int sortOrder,
    required bool isActive,
  }) {
    final body = {
      'name': name,
      'imagePath': imagePath,
      'parentId': parentId,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
    return id == null
        ? _api.post('/ServiceCategories', body: body)
        : _api.put('/ServiceCategories/$id', body: body);
  }

  Future<ApiResult> deleteCategory(int id) =>
      _api.delete('/ServiceCategories/$id');

  // ── Packages ──
  Future<List<ServicePackageRow>> packages() async {
    final res = await _api.get('/ServicePackages');
    final data = res.data;
    if (!res.ok || data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ServicePackageRow.fromJson)
        .toList();
  }

  Future<ApiResult> savePackage({
    int? id,
    required String name,
    String? description,
    required int categoryId,
    String? imagePath,
    required double price,
    double? oldPrice,
    required String status,
    required int sortOrder,
    required List<({String name, int quantity})> items,
  }) {
    final body = {
      'name': name,
      'description': description,
      'categoryId': categoryId,
      'imagePath': imagePath,
      'price': price,
      'oldPrice': oldPrice,
      'status': status,
      'sortOrder': sortOrder,
      'items': [
        for (var i = 0; i < items.length; i++)
          {
            'name': items[i].name,
            'quantity': items[i].quantity,
            'sortOrder': i,
          },
      ],
    };
    return id == null
        ? _api.post('/ServicePackages', body: body)
        : _api.put('/ServicePackages/$id', body: body);
  }

  Future<ApiResult> deletePackage(int id) => _api.delete('/ServicePackages/$id');

  // ── Image upload (same endpoint the Services screen uses) ──
  Future<({bool ok, String message, String? path})> uploadImage(
    List<int> bytes,
    String filename,
  ) async {
    final res = await _api.uploadBytes('/Uploads/product', bytes, filename);
    if (!res.ok) {
      return (ok: false, message: res.message ?? 'Upload failed.', path: null);
    }
    final data = res.data;
    final path = (data is Map) ? data['path']?.toString() : null;
    return path == null || path.isEmpty
        ? (ok: false, message: 'Upload succeeded but no path returned.', path: null)
        : (ok: true, message: 'Uploaded.', path: path);
  }
}
