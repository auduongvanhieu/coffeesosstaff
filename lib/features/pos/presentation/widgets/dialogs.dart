import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../application/cart_controller.dart';
import '../../data/order_repository.dart';
import '../../domain/order.dart';

/// Pick a table label for the current order (Bàn 01 … Bàn 20 or free text).
Future<void> showTablePicker(BuildContext context, WidgetRef ref) async {
  final current = ref.read(cartProvider).tableLabel;
  final result = await showModalBottomSheet<String>(
    context: context,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (ctx) {
      final custom = TextEditingController();
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chọn bàn',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 1; i <= 20; i++)
                  _Pill(
                    label: 'Bàn ${i.toString().padLeft(2, '0')}',
                    selected: current == 'Bàn ${i.toString().padLeft(2, '0')}',
                    onTap: () =>
                        Navigator.of(ctx)
                            .pop('Bàn ${i.toString().padLeft(2, '0')}'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: custom,
                    decoration: const InputDecoration(
                      hintText: 'Tên bàn khác (VD: Sân vườn 2)',
                    ),
                    onSubmitted: (v) => v.trim().isEmpty
                        ? null
                        : Navigator.of(ctx).pop(v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: FilledButton(
                    onPressed: () => custom.text.trim().isEmpty
                        ? null
                        : Navigator.of(ctx).pop(custom.text.trim()),
                    child: const Text('Chọn'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  if (result != null) ref.read(cartProvider.notifier).setTable(result);
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.beige,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Attach a loyalty customer by phone (lookup, else create).
Future<void> showCustomerDialog(BuildContext context, WidgetRef ref) async {
  final picked = await showDialog<_CustomerResult>(
    context: context,
    builder: (_) => _CustomerDialog(current: ref.read(cartProvider).customer),
  );
  if (picked == null) return;
  ref.read(cartProvider.notifier).setCustomer(picked.customer);
}

class _CustomerResult {
  const _CustomerResult(this.customer);

  final Customer? customer;
}

class _CustomerDialog extends ConsumerStatefulWidget {
  const _CustomerDialog({this.current});

  final Customer? current;

  @override
  ConsumerState<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends ConsumerState<_CustomerDialog> {
  final _phone = TextEditingController();
  final _name = TextEditingController();
  Customer? _found;
  bool _notFound = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.current != null) _phone.text = widget.current!.phone;
  }

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    super.dispose();
  }

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');

  Future<void> _lookup() async {
    if (_digits.length < 9) {
      setState(() => _error = 'Số điện thoại không hợp lệ');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _found = null;
      _notFound = false;
    });
    try {
      final c = await ref.read(orderRepositoryProvider).lookupCustomer(_digits);
      setState(() {
        _found = c;
        _notFound = c == null;
      });
    } catch (e) {
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Nhập tên khách');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final c = await ref
          .read(orderRepositoryProvider)
          .createCustomer(phone: _digits, name: _name.text.trim());
      if (mounted) Navigator.of(context).pop(_CustomerResult(c));
    } catch (e) {
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Khách hàng'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phone,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: 'Số điện thoại',
                    ),
                    onSubmitted: (_) => _lookup(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: FilledButton(
                    onPressed: _busy ? null : _lookup,
                    child: const Text('Tìm'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_found != null) _CustomerCard(customer: _found!),
            if (_notFound) ...[
              const Text(
                'Chưa có khách này. Tạo mới:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                decoration: const InputDecoration(hintText: 'Tên khách'),
                onSubmitted: (_) => _create(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const _CustomerResult(null)),
            child: const Text(
              'Bỏ chọn khách',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
        if (_found != null)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_CustomerResult(_found)),
            child: const Text('Chọn'),
          ),
        if (_notFound)
          FilledButton(
            onPressed: _busy ? null : _create,
            child: const Text('Tạo khách hàng'),
          ),
      ],
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${customer.prettyPhone} · ${customer.tierLabel} · ${customer.points} điểm',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Validate and apply a promotion code.
Future<void> showPromoDialog(BuildContext context, WidgetRef ref) async {
  final result = await showDialog<_PromoResult>(
    context: context,
    builder: (_) => _PromoDialog(
      current: ref.read(cartProvider).promotion,
      subtotal: ref.read(cartProvider).subtotal,
    ),
  );
  if (result == null) return;
  ref.read(cartProvider.notifier).setPromotion(result.promotion);
}

class _PromoResult {
  const _PromoResult(this.promotion);

  final Promotion? promotion;
}

class _PromoDialog extends ConsumerStatefulWidget {
  const _PromoDialog({this.current, required this.subtotal});

  final Promotion? current;
  final int subtotal;

  @override
  ConsumerState<_PromoDialog> createState() => _PromoDialogState();
}

class _PromoDialogState extends ConsumerState<_PromoDialog> {
  final _code = TextEditingController();
  Promotion? _found;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.current != null) {
      _code.text = widget.current!.code;
      _found = widget.current;
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _found = null;
    });
    try {
      final p = await ref.read(orderRepositoryProvider).promotion(code);
      if (p == null) {
        setState(() => _error = 'Mã không tồn tại hoặc đã hết hạn');
      } else if (widget.subtotal < p.minSubtotal) {
        setState(
          () => _error =
              'Đơn tối thiểu ${formatVnd(p.minSubtotal)} mới áp dụng được',
        );
      } else {
        setState(() => _found = p);
      }
    } catch (e) {
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _found;
    return AlertDialog(
      title: const Text('Mã giảm giá'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(hintText: 'VD: SALE10'),
                    onSubmitted: (_) => _check(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: _busy ? null : _check,
                  child: const Text('Kiểm tra'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (p != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.beige,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_offer_rounded,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name.isEmpty ? p.code : p.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            p.type == 'percent'
                                ? 'Giảm ${p.value}% · tiết kiệm ${formatVnd(p.discountFor(widget.subtotal))}'
                                : 'Giảm ${formatVnd(p.value)}',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const _PromoResult(null)),
            child: const Text(
              'Xoá mã',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
        FilledButton(
          onPressed: p == null
              ? null
              : () => Navigator.of(context).pop(_PromoResult(p)),
          child: const Text('Áp dụng'),
        ),
      ],
    );
  }
}
