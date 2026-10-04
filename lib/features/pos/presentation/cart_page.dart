import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../application/cart_controller.dart';
import 'widgets/cart_widgets.dart';
import 'widgets/dialogs.dart';

/// Figma "M3 Giỏ hàng" (phone only).
class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  Future<void> _checkout(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider.notifier);
    try {
      final order = await cart.submit();
      if (context.mounted) context.push(Routes.payment(order.id), extra: order);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final c = cart.customer;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go(Routes.order),
                  ),
                  Text(
                    'Đơn hàng · ${cart.headerLabel}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => showCustomerDialog(context, ref),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                c == null
                                    ? 'Thêm khách hàng tích điểm'
                                    : 'KH: ${c.prettyPhone} · ${c.points} điểm',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              c == null ? 'Thêm' : 'Đổi',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (cart.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'Chưa có món nào',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  for (final l in cart.lines) ...[
                    CartLineCard(line: l),
                    const SizedBox(height: 10),
                  ],
                  Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => showPromoDialog(context, ref),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                cart.promotion == null
                                    ? 'Mã giảm giá'
                                    : 'Mã giảm giá: ${cart.promotion!.code}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: cart.promotion == null
                                      ? AppColors.textSecondary
                                      : AppColors.success,
                                ),
                              ),
                            ),
                            Text(
                              cart.promotion == null ? 'Thêm' : 'Sửa',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: const BoxDecoration(color: AppColors.background),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const CartTotals(large: true, showPromoRow: false),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: cart.isEmpty
                        ? null
                        : () => _checkout(context, ref),
                    child: Text('Thanh toán · ${formatVnd(cart.total)}'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
