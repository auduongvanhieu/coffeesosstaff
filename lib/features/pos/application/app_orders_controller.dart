import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/order_repository.dart';
import '../data/realtime.dart';
import '../domain/order.dart';

/// Today's app orders for the "Đơn từ app" screen. Refreshed on realtime
/// `order.*` events and by an explicit refresh.
class AppOrdersController extends AsyncNotifier<List<Order>> {
  Timer? _debounce;

  @override
  Future<List<Order>> build() async {
    ref.listen(realtimeEventsProvider, (_, next) {
      final ev = next.value;
      if (ev == null) return;
      if (ev.type == 'order.created' || ev.type == 'order.updated') {
        final raw = ev.data['order'];
        if (raw is Map<String, dynamic>) {
          _merge(Order.fromJson(raw));
        } else {
          _scheduleRefresh();
        }
      }
    });
    ref.onDispose(() => _debounce?.cancel());
    return ref.read(orderRepositoryProvider).list(sources: ['app']);
  }

  void _merge(Order order) {
    final current = state.value;
    if (current == null || order.source != 'app') return;
    final idx = current.indexWhere((o) => o.id == order.id);
    final next = [...current];
    if (idx >= 0) {
      next[idx] = order;
    } else {
      next.insert(0, order);
    }
    state = AsyncData(next);
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), refresh);
  }

  Future<void> refresh() async {
    final res = await AsyncValue.guard(
      () => ref.read(orderRepositoryProvider).list(sources: ['app']),
    );
    if (res.hasValue || state.value == null) state = res;
  }

  Future<Order> setStatus(String id, String status) async {
    final order = await ref.read(orderRepositoryProvider).setStatus(id, status);
    _merge(order);
    return order;
  }
}

final appOrdersProvider =
    AsyncNotifierProvider<AppOrdersController, List<Order>>(
      AppOrdersController.new,
    );

/// Badge count for the nav: app orders awaiting confirmation.
final pendingAppCountProvider = Provider<int>(
  (ref) =>
      ref
          .watch(appOrdersProvider)
          .value
          ?.where((o) => o.status == 'pending')
          .length ??
      0,
);
