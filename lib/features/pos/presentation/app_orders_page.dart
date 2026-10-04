import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/breakpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../application/app_orders_controller.dart';
import '../domain/order.dart';
import 'widgets/cart_widgets.dart';

enum _Tab { pending, preparing, ready, today }

/// Figma "04 Đơn từ app" (tablet) and "M5 Đơn từ app" (phone).
class AppOrdersPage extends ConsumerStatefulWidget {
  const AppOrdersPage({super.key});

  @override
  ConsumerState<AppOrdersPage> createState() => _AppOrdersPageState();
}

class _AppOrdersPageState extends ConsumerState<AppOrdersPage> {
  _Tab _tab = _Tab.pending;

  List<Order> _filter(List<Order> all) {
    final list = switch (_tab) {
      _Tab.pending => all.where((o) => o.status == 'pending'),
      _Tab.preparing => all.where((o) => o.status == 'preparing'),
      _Tab.ready => all.where((o) => o.status == 'ready'),
      _Tab.today => all,
    }.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> _setStatus(Order o, String status) async {
    try {
      await ref.read(appOrdersProvider.notifier).setStatus(o.id, status);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(appOrdersProvider);
    final tablet = Breakpoints.isTablet(context);
    final all = orders.value ?? const <Order>[];
    int count(_Tab t) => switch (t) {
      _Tab.pending => all.where((o) => o.status == 'pending').length,
      _Tab.preparing => all.where((o) => o.status == 'preparing').length,
      _Tab.ready => all.where((o) => o.status == 'ready').length,
      _Tab.today => all.length,
    };
    final labels = {
      _Tab.pending: tablet ? 'Chờ xác nhận' : 'Chờ',
      _Tab.preparing: 'Đang pha',
      _Tab.ready: 'Sẵn sàng',
      _Tab.today: 'Hôm nay',
    };

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(tablet ? 24 : 16, 16, tablet ? 24 : 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Đơn từ app',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Tải lại',
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () =>
                      ref.read(appOrdersProvider.notifier).refresh(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final t in _Tab.values)
                        _TabChip(
                          label: '${labels[t]} · ${count(t)}',
                          active: _tab == t,
                          onTap: () => setState(() => _tab = t),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: orders.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(describeError(e))),
                data: (data) {
                  final list = _filter(data);
                  if (list.isEmpty) {
                    return const Center(
                      child: Text(
                        'Không có đơn nào',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.read(appOrdersProvider.notifier).refresh(),
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _OrderCard(
                        order: list[i],
                        tablet: tablet,
                        onStatus: (s) => _setStatus(list[i], s),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: active ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.tablet,
    required this.onStatus,
  });

  final Order order;
  final bool tablet;
  final ValueChanged<String> onStatus;

  ({String text, Color color}) get _statusText {
    if (order.status == 'ready') {
      return (text: 'Sẵn sàng — khách đang tới', color: AppColors.primary);
    }
    if (order.status == 'completed') {
      return (text: 'Đã giao', color: AppColors.textSecondary);
    }
    if (order.status == 'rejected') {
      return (text: 'Đã từ chối', color: AppColors.danger);
    }
    if (order.isPaid) {
      return (
        text: 'Đã thanh toán ${order.paymentMethodLabel}',
        color: AppColors.success,
      );
    }
    return (text: 'Chưa thanh toán', color: AppColors.textSecondary);
  }

  List<Widget> get _actions => switch (order.status) {
    'pending' => [
      SoftButton(
        label: 'Từ chối',
        height: 40,
        expand: false,
        color: AppColors.dangerSoft,
        textColor: AppColors.danger,
        onPressed: () => onStatus('rejected'),
      ),
      const SizedBox(width: 8),
      _Primary(label: 'Xác nhận', onPressed: () => onStatus('preparing')),
    ],
    'preparing' => [
      _Primary(label: 'Sẵn sàng', onPressed: () => onStatus('ready')),
    ],
    'ready' => [
      _Primary(
        label: 'Đã giao cho khách',
        onPressed: () => onStatus('completed'),
      ),
    ],
    _ => const [],
  };

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(order.createdAt.toLocal());
    final who = order.customer?.name ?? 'Khách';
    final st = _statusText;
    final meta = '$who · $time · ${order.orderTypeLabel}';
    final actions = _actions;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '#${order.number}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  meta,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                st.text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: st.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(order.itemsSummary, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                formatVnd(order.total),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              ...actions,
            ],
          ),
        ],
      ),
    );
  }
}

class _Primary extends StatelessWidget {
  const _Primary({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
