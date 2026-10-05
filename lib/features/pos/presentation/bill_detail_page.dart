import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../application/cart_controller.dart';
import '../data/menu_repository.dart';
import '../data/order_repository.dart';
import '../domain/order.dart';

final _stamp = DateFormat('HH:mm · d/M/yyyy');

/// One bill in full, with its correction history and a way to fix it when the
/// guest was charged wrong.
class BillDetailPage extends ConsumerWidget {
  const BillDetailPage({super.key, required this.orderId});

  final String orderId;

  Future<void> _edit(BuildContext context, WidgetRef ref, Order order) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final menu = await ref.read(storeMenuProvider.future);
      ref.read(cartProvider.notifier).loadFrom(order, menu, adjusting: true);
      if (context.mounted) context.go(Routes.order);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderByIdProvider(orderId));

    return Scaffold(
      body: SafeArea(
        child: order.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(describeError(e))),
          data: (o) => Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go(Routes.bills),
                  ),
                  Text(
                    o.number,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    o.statusLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: o.isPaid ? AppColors.success : AppColors.primary,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Line(
                            'Thời gian',
                            _stamp.format(o.createdAt.toLocal()),
                          ),
                          _Line('Hình thức', o.orderTypeLabel),
                          if (o.createdBy != null)
                            _Line('Nhân viên', o.createdBy!.fullName),
                          if (o.customer != null)
                            _Line(
                              'Khách',
                              '${o.customer!.name.isEmpty ? o.customer!.phone : o.customer!.name} · ${o.customer!.phone}',
                            ),
                          if (o.isPaid && o.paymentMethod != null)
                            _Line('Thanh toán', o.paymentMethodLabel),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Card(
                      child: Column(
                        children: [
                          for (final l in o.items) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${l.quantity}x',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (l.optionsText.isNotEmpty ||
                                          (l.note ?? '').isNotEmpty)
                                        Text(
                                          [
                                            if (l.optionsText.isNotEmpty)
                                              l.optionsText,
                                            if ((l.note ?? '').isNotEmpty)
                                              'Ghi chú: ${l.note}',
                                          ].join(' · '),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formatVnd(l.lineTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                          const Divider(height: 8),
                          _Line('Tạm tính', formatVnd(o.subtotal)),
                          if (o.discount > 0)
                            _Line(
                              'Giảm giá${o.promotionCode == null ? '' : ' (${o.promotionCode})'}',
                              '-${formatVnd(o.discount)}',
                              color: AppColors.success,
                            ),
                          _Line(
                            'Tổng cộng',
                            formatVnd(o.total),
                            bold: true,
                            color: AppColors.primary,
                          ),
                          if (o.changeDue != null)
                            _Line(
                              'Tiền thừa trả khách',
                              formatVnd(o.changeDue!),
                            ),
                        ],
                      ),
                    ),
                    if (o.adjustments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lịch sử sửa đơn',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            for (final a in o.adjustments) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(a.reason),
                                        Text(
                                          '${_stamp.format(a.at.toLocal())}${a.byName == null ? '' : ' · ${a.byName}'}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${a.difference > 0 ? '+' : ''}${formatVnd(a.difference)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: a.difference > 0
                                          ? AppColors.primary
                                          : AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (o.status != 'cancelled' && o.status != 'rejected')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () => _edit(context, ref, o),
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    label: const Text('Sửa đơn này'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false, this.color});

  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: bold ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                fontSize: bold ? 15 : 13,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 16 : 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
