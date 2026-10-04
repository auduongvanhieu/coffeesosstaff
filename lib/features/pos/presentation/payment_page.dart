import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../application/cart_controller.dart';
import '../data/menu_repository.dart';
import '../data/order_repository.dart';
import '../domain/order.dart';

const _methods = [
  ('cash', 'Tiền mặt'),
  ('vietqr', 'VietQR'),
  ('momo', 'MoMo'),
  ('zalopay', 'ZaloPay'),
];

/// Figma "03 Thanh toán" (tablet) and "M4 Thanh toán" (phone).
class PaymentPage extends ConsumerStatefulWidget {
  const PaymentPage({super.key, required this.orderId, this.initial});

  final String orderId;
  final Order? initial;

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  String _method = 'cash';
  late final TextEditingController _cash;
  int _received = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cash = TextEditingController();
    if (widget.initial != null) _seed(widget.initial!.total);
  }

  void _seed(int total) {
    if (_cash.text.isNotEmpty) return;
    _received = total;
    _cash.text = formatVnd(total, symbol: false);
  }

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  void _setReceived(int v) {
    setState(() {
      _received = v;
      _cash.value = TextEditingValue(
        text: formatVnd(v, symbol: false),
        selection: TextSelection.collapsed(
          offset: formatVnd(v, symbol: false).length,
        ),
      );
    });
  }

  List<int> _quickAmounts(int total) {
    final out = <int>{total};
    for (final step in [50000, 100000, 200000, 500000]) {
      final candidate = ((total + step - 1) ~/ step) * step;
      if (candidate > total) out.add(candidate);
      if (out.length >= 4) break;
    }
    for (final fixed in [150000, 200000, 500000]) {
      if (fixed > total) out.add(fixed);
    }
    final list = out.toList()..sort();
    return list.take(4).toList();
  }

  Future<void> _confirm(Order order) async {
    if (_method == 'cash' && _received < order.total) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Khách đưa chưa đủ tiền')));
      return;
    }
    setState(() => _busy = true);
    try {
      final paid = await ref
          .read(orderRepositoryProvider)
          .pay(
            order.id,
            method: _method,
            cashReceived: _method == 'cash' ? _received : null,
          );
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(shiftSummaryProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 44,
          ),
          title: const Text('Đã thanh toán'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${paid.number} · ${paid.paymentMethodLabel} · ${formatVnd(paid.total)}',
              ),
              if (paid.changeDue != null && paid.changeDue! > 0) ...[
                const SizedBox(height: 6),
                Text(
                  'Tiền thừa trả khách: ${formatVnd(paid.changeDue!)}',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (paid.pointsEarned > 0 && paid.customer != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${paid.customer!.name} +${paid.pointsEarned} điểm',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đơn mới'),
            ),
          ],
        ),
      );
      if (mounted) context.go(Routes.order);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _printReceipt(Order order) {
    final store = ref.read(storeInfoProvider).value;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(store?.name ?? 'Hoá đơn'),
        content: SizedBox(
          width: 320,
          child: DefaultTextStyle(
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (store?.address != null)
                  Text(
                    store!.address!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  '${order.number} · ${order.orderTypeLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Divider(),
                for (final l in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${l.quantity}x ${l.name}${l.optionsText.isEmpty ? '' : ' (${l.optionsText})'}',
                          ),
                        ),
                        Text(formatVnd(l.lineTotal)),
                      ],
                    ),
                  ),
                const Divider(),
                _line('Tạm tính', formatVnd(order.subtotal)),
                if (order.discount > 0)
                  _line(
                    'Giảm giá (${order.promotionCode ?? ''})',
                    '-${formatVnd(order.discount)}',
                  ),
                _line('Tổng cộng', formatVnd(order.total), bold: true),
                const SizedBox(height: 8),
                const Text(
                  'Cảm ơn quý khách!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _line(String a, String b, {bool bold = false}) => Row(
    children: [
      Expanded(
        child: Text(
          a,
          style: TextStyle(fontWeight: bold ? FontWeight.w700 : null),
        ),
      ),
      Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w700 : null)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final orderAsync = widget.initial != null
        ? AsyncData<Order>(widget.initial!)
        : ref.watch(orderByIdProvider(widget.orderId));
    return orderAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(describeError(e)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go(Routes.order),
                child: const Text('Về màn hình order'),
              ),
            ],
          ),
        ),
      ),
      data: (order) {
        _seed(order.total);
        final tablet = Breakpoints.isTablet(context);
        final header = Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go(Routes.order),
            ),
            Text(
              'Thanh toán · ${order.orderTypeLabel}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        );
        final totalBar = _TotalBar(order: order, compact: !tablet);
        final tabs = _MethodTabs(
          selected: _method,
          grid: !tablet,
          onSelect: (m) => setState(() => _method = m),
        );
        final left = _method == 'cash'
            ? _CashPanel(
                controller: _cash,
                total: order.total,
                received: _received,
                quick: _quickAmounts(order.total),
                onChanged: (v) => setState(() => _received = v),
                onQuick: _setReceived,
              )
            : _MethodInfoPanel(method: _method, total: order.total);
        final qr = _QrPanel(order: order);
        final confirm = FilledButton(
          onPressed: _busy ? null : () => _confirm(order),
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Xác nhận đã thanh toán'),
        );
        final print = OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.surface,
            side: BorderSide.none,
          ),
          onPressed: () => _printReceipt(order),
          child: const Text('In hoá đơn'),
        );

        if (tablet) {
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [totalBar, const SizedBox(height: 12), tabs],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: left),
                            const SizedBox(width: 16),
                            Expanded(child: qr),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Row(
                        children: [
                          Expanded(child: print),
                          const SizedBox(width: 12),
                          Expanded(flex: 3, child: confirm),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: header,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      totalBar,
                      const SizedBox(height: 12),
                      tabs,
                      const SizedBox(height: 12),
                      left,
                      const SizedBox(height: 12),
                      qr,
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () => _printReceipt(order),
                          child: const Text('In hoá đơn'),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: confirm,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.order, required this.compact});

  final Order order;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = order.discount > 0
        ? 'Tổng thanh toán (đã giảm ${order.promotionCode ?? ''})'
        : 'Tổng thanh toán · ${order.orderTypeLabel}';
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatVnd(order.total),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            formatVnd(order.total),
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodTabs extends StatelessWidget {
  const _MethodTabs({
    required this.selected,
    required this.grid,
    required this.onSelect,
  });

  final String selected;
  final bool grid;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget seg(String code, String label) {
      final active = code == selected;
      return Material(
        color: active ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onSelect(code),
          child: Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(
              horizontal: grid ? 0 : 22,
              vertical: grid ? 14 : 10,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      );
    }

    final container = BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
    );
    if (grid) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: container,
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 3.4,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [for (final m in _methods) seg(m.$1, m.$2)],
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: container,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (final m in _methods) seg(m.$1, m.$2)],
        ),
      ),
    );
  }
}

class _CashPanel extends StatelessWidget {
  const _CashPanel({
    required this.controller,
    required this.total,
    required this.received,
    required this.quick,
    required this.onChanged,
    required this.onQuick,
  });

  final TextEditingController controller;
  final int total;
  final int received;
  final List<int> quick;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onQuick;

  @override
  Widget build(BuildContext context) {
    final change = received - total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Khách đưa',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            onChanged: (v) => onChanged(parseVnd(v)),
            decoration: InputDecoration(
              fillColor: AppColors.beige,
              suffixText: 'đ',
              suffixStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in quick)
                Material(
                  color: q == received
                      ? AppColors.primaryLight
                      : AppColors.beige,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onQuick(q),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Text(
                        formatVnd(q, symbol: false),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tiền thừa trả khách',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              Text(
                change >= 0 ? formatVnd(change) : 'Thiếu ${formatVnd(-change)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: change >= 0 ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MethodInfoPanel extends StatelessWidget {
  const _MethodInfoPanel({required this.method, required this.total});

  final String method;
  final int total;

  @override
  Widget build(BuildContext context) {
    final label = paymentMethodLabelOf(method);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Thanh toán qua $label',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            formatVnd(total),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            method == 'vietqr'
                ? 'Khách quét mã VietQR bên cạnh. Bấm xác nhận khi ngân hàng báo có.'
                : 'Khách thanh toán bằng ví $label. Bấm xác nhận khi đã nhận được tiền.',
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _QrPanel extends ConsumerWidget {
  const _QrPanel({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeInfoProvider).value;
    String? url;
    if (store != null && store.hasBank) {
      final qs = Uri(
        queryParameters: {
          'amount': '${order.total}',
          'addInfo': order.number,
          if ((store.bankHolder ?? '').isNotEmpty)
            'accountName': store.bankHolder!,
        },
      ).query;
      url =
          'https://img.vietqr.io/image/${store.bankCode}-${store.bankAccount}-compact2.png?$qs';
    }
    final caption = store == null || !store.hasBank
        ? 'Chưa cấu hình tài khoản ngân hàng'
        : '${store.bankCode} · ${store.bankAccount} · ${store.bankHolder ?? ''}';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 180,
            height: 180,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.beige,
              borderRadius: BorderRadius.circular(10),
            ),
            child: url == null
                ? const Icon(
                    Icons.qr_code_2_rounded,
                    size: 64,
                    color: AppColors.textSecondary,
                  )
                : Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, p) => p == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.qr_code_2_rounded,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Quét VietQR — tự động điền số tiền',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
