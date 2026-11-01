import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/service_item_model.dart';

// Admin API for the services list (Phase 2C): the full service form fields,
// image upload and the dashboard counts.
class ServiceAdminApi {
  final _api = ApiClient.instance;

  Future<List<ServiceItem>> services() async {
    final res = await _api.get('/services', query: {'includeInactive': true});
    final data = res.data;
    if (!res.ok || data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ServiceItem.fromJson)
        .toList();
  }

  // id == null creates a service, otherwise updates it.
  Future<ApiResult> save({int? id, required Map<String, dynamic> body}) =>
      id == null
      ? _api.post('/services', body: body)
      : _api.put('/services/$id', body: body);

  Future<ApiResult> delete(int id) => _api.delete('/services/$id');

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

  // null when the server does not have the endpoint (yet).
  Future<ServiceStats?> stats() async {
    final res = await _api.get('/ServiceStats');
    final data = res.data;
    if (!res.ok || data is! Map<String, dynamic>) return null;
    return ServiceStats.fromJson(data);
  }
}

final serviceAdminApiProvider = Provider<ServiceAdminApi>(
  (ref) => ServiceAdminApi(),
);

final serviceItemsProvider = FutureProvider.autoDispose<List<ServiceItem>>(
  (ref) => ref.read(serviceAdminApiProvider).services(),
);

final serviceStatsProvider = FutureProvider.autoDispose<ServiceStats?>(
  (ref) => ref.read(serviceAdminApiProvider).stats(),
);
