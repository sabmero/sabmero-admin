import '../core/api_client.dart';
import '../models/service_catalog_models.dart';

// API calls for on-site service categories (main / sub) and service packages.
// Kept apart from AdminService so the existing admin code stays untouched.
class ServiceCatalogService {
  final _api = ApiClient.instance;

  List<Map<String, dynamic>> _list(dynamic data) =>
      ((data as List?) ?? []).whereType<Map<String, dynamic>>().toList();

  // ── Service categories ──
  Future<List<ServiceCategoryNode>> categories() async {
    final res = await _api.get(
      '/ServiceCategories',
      query: {'includeInactive': true},
    );
    return _list(res.data).map(ServiceCategoryNode.fromJson).toList();
  }

  Future<ApiResult> saveCategory({
    int? id,
    required String name,
    String? imagePath,
    int? parentId,
    required int sortOrder,
    required bool isActive,
  }) {
    final Map<String, dynamic> body = {
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

  // ── Service packages ──
  // As an admin this returns packages of every status.
  Future<List<ServicePackageRow>> packages() async {
    final res = await _api.get('/ServicePackages');
    return _list(res.data).map(ServicePackageRow.fromJson).toList();
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
    final Map<String, dynamic> body = {
      'name': name,
      'description': description,
      'categoryId': categoryId,
      'imagePath': imagePath,
      'price': price,
      'oldPrice': oldPrice,
      'status': status,
      'sortOrder': sortOrder,
      'items': [
        for (final it in items) {'name': it.name, 'quantity': it.quantity},
      ],
    };
    return id == null
        ? _api.post('/ServicePackages', body: body)
        : _api.put('/ServicePackages/$id', body: body);
  }

  Future<ApiResult> deletePackage(int id) =>
      _api.delete('/ServicePackages/$id');

  // Upload an image → server path (same upload folder the services use).
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
        ? (
            ok: false,
            message: 'Upload succeeded but no path returned.',
            path: null,
          )
        : (ok: true, message: 'Uploaded.', path: path);
  }
}
