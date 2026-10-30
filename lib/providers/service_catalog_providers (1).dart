import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_catalog_models.dart';
import '../services/service_catalog_service.dart';

// Providers for the on-site service catalog (categories and packages).
final serviceCatalogApiProvider = Provider<ServiceCatalogService>(
  (ref) => ServiceCatalogService(),
);

final serviceCategoriesProvider =
    FutureProvider.autoDispose<List<ServiceCategoryNode>>(
  (ref) => ref.read(serviceCatalogApiProvider).categories(),
);

final servicePackagesProvider =
    FutureProvider.autoDispose<List<ServicePackageRow>>(
  (ref) => ref.read(serviceCatalogApiProvider).packages(),
);
