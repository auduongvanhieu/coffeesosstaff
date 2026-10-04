import 'package:dio/dio.dart' show Options;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/menu.dart';
import '../domain/order.dart';

class MenuRepository {
  MenuRepository(this._api);

  final ApiClient _api;

  Options? _storeOptions(String? storeId) =>
      storeId == null ? null : Options(headers: {'X-Store-ID': storeId});

  /// GET /pos/menu — store resolved from the JWT, or from X-Store-ID for
  /// managers/owners who cover several stores.
  Future<StoreMenu> storeMenu({String? storeId}) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/pos/menu',
      options: _storeOptions(storeId),
    );
    return StoreMenu.fromJson(res.data!);
  }

  /// PATCH /pos/menu/items/:id/availability — store-level sold-out override.
  Future<bool> setAvailability(
    String itemId,
    bool available, {
    String? storeId,
  }) async {
    final res = await _api.dio.patch<Map<String, dynamic>>(
      '/pos/menu/items/$itemId/availability',
      data: {'available': available},
      options: _storeOptions(storeId),
    );
    return res.data?['available'] as bool? ?? available;
  }

  /// GET /pos/store — name, address and VietQR bank details.
  Future<StoreInfo> store({String? storeId}) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/pos/store',
      options: _storeOptions(storeId),
    );
    return StoreInfo.fromJson(res.data!);
  }
}

final menuRepositoryProvider = Provider<MenuRepository>(
  (ref) => MenuRepository(ref.watch(apiClientProvider)),
);

/// Store id for X-Store-ID when the signed-in user is not pinned to a store.
final currentStoreIdProvider = Provider<String?>(
  (ref) => ref.watch(authControllerProvider).value?.storeId,
);

final storeMenuProvider = FutureProvider<StoreMenu>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  return ref.watch(menuRepositoryProvider).storeMenu(storeId: storeId);
});

final storeInfoProvider = FutureProvider<StoreInfo>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  return ref.watch(menuRepositoryProvider).store(storeId: storeId);
});
