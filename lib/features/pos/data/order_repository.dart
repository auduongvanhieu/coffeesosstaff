import 'package:dio/dio.dart' show DioException, Options;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/order.dart';
import '../domain/table.dart';
import 'menu_repository.dart';
import 'realtime.dart';

class OrderRepository {
  OrderRepository(this._api, this._storeId);

  final ApiClient _api;
  final String? _storeId;

  Options? get _opts =>
      _storeId == null ? null : Options(headers: {'X-Store-ID': _storeId});

  Future<Order> create(Map<String, dynamic> input) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/pos/orders',
      data: input,
      options: _opts,
    );
    return Order.fromJson(res.data!);
  }

  Future<Order> replace(String id, Map<String, dynamic> input) async {
    final res = await _api.dio.put<Map<String, dynamic>>(
      '/pos/orders/$id',
      data: input,
      options: _opts,
    );
    return Order.fromJson(res.data!);
  }

  Future<Order> pay(
    String id, {
    required String method,
    int? cashReceived,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/pos/orders/$id/pay',
      data: {'method': method, 'cashReceived': ?cashReceived},
      options: _opts,
    );
    return Order.fromJson(res.data!);
  }

  Future<Order> get(String id) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/pos/orders/$id',
      options: _opts,
    );
    return Order.fromJson(res.data!);
  }

  Future<List<Order>> list({
    List<String>? statuses,
    List<String>? sources,
    String? date,
  }) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/pos/orders',
      queryParameters: {
        if (statuses != null && statuses.isNotEmpty)
          'status': statuses.join(','),
        if (sources != null && sources.isNotEmpty) 'source': sources.join(','),
        'date': ?date,
      },
      options: _opts,
    );
    return (res.data?['items'] as List<dynamic>? ?? [])
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Order> setStatus(String id, String status) async {
    final res = await _api.dio.patch<Map<String, dynamic>>(
      '/pos/orders/$id/status',
      data: {'status': status},
      options: _opts,
    );
    return Order.fromJson(res.data!);
  }

  /// GET /pos/tables — the floor plan with the order on each table.
  Future<FloorPlan> tables() async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/pos/tables',
      options: _opts,
    );
    return FloorPlan.fromJson(res.data!);
  }

  Future<ShiftSummary> summary({String? date}) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/pos/orders/summary',
      queryParameters: {'date': ?date},
      options: _opts,
    );
    return ShiftSummary.fromJson(res.data!);
  }

  /// Returns null when the phone is unknown (404).
  Future<Customer?> lookupCustomer(String phone) async {
    try {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/pos/customers/lookup',
        queryParameters: {'phone': phone},
        options: _opts,
      );
      return Customer.fromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Customer> createCustomer({
    required String phone,
    required String name,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/pos/customers',
      data: {'phone': phone, 'name': name},
      options: _opts,
    );
    return Customer.fromJson(res.data!);
  }

  /// Returns null when the code does not exist (404).
  Future<Promotion?> promotion(String code) async {
    try {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/pos/promotions/${Uri.encodeComponent(code)}',
        options: _opts,
      );
      return Promotion.fromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(
    ref.watch(apiClientProvider),
    ref.watch(currentStoreIdProvider),
  ),
);

final orderByIdProvider = FutureProvider.family<Order, String>(
  (ref, id) => ref.watch(orderRepositoryProvider).get(id),
);

final shiftSummaryProvider = FutureProvider<ShiftSummary>(
  (ref) => ref.watch(orderRepositoryProvider).summary(),
);

/// The floor plan, refetched whenever the hub says a table changed.
final floorPlanProvider = FutureProvider<FloorPlan>((ref) {
  ref.listen(realtimeEventsProvider, (_, next) {
    final type = next.value?.type;
    if (type == 'tables.changed' ||
        type == 'order.created' ||
        type == 'order.updated') {
      ref.invalidateSelf();
    }
  });
  return ref.watch(orderRepositoryProvider).tables();
});
