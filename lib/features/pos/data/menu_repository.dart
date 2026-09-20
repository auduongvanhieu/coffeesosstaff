import 'package:dio/dio.dart' show Options;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/menu.dart';

class MenuRepository {
  MenuRepository(this._api);

  final ApiClient _api;

  /// GET /pos/menu — store resolved from the JWT, or from X-Store-ID for
  /// managers/owners who cover several stores.
  Future<StoreMenu> storeMenu({String? storeId}) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/pos/menu',
      options: storeId == null ? null : Options(headers: {'X-Store-ID': storeId}),
    );
    return StoreMenu.fromJson(res.data!);
  }
}

final menuRepositoryProvider = Provider<MenuRepository>(
  (ref) => MenuRepository(ref.watch(apiClientProvider)),
);

final storeMenuProvider = FutureProvider<StoreMenu>((ref) {
  final user = ref.watch(authControllerProvider).value;
  return ref.watch(menuRepositoryProvider).storeMenu(storeId: user?.storeId);
});
