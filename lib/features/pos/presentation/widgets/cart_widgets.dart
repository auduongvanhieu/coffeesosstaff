import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../application/cart_controller.dart';
import '../../domain/cart.dart';
import 'dialogs.dart';
import 'item_options_sheet.dart';

/// Opens the option sheet pre-filled with the line, then applies the edit.
Future<void> editCartLine(
  BuildContext context,
  WidgetRef ref,
  CartLine line,
) async {
  final cart = ref.read(cartProvider.notifier);
  if (!line.item.hasOptions) {
    final qty = await showDialog<int>(
      context: context,
      builder: (ctx) => _QuantityDialog(line: line),
    );
    if (qty != null) cart.setQuantity(line.uid, qty);
    return;
  }
  final sel = await showItemOptionsSheet(
    context,
    line.item,
    initial: ItemSelection(
      choices: line.choices,
      quantity: line.quantity,
      note: line.note,
    ),
    confirmLabel: 'Cập nhật',
  );
  if (sel == null) return;
  cart.updateLine(
    line.uid,
    choices: sel.choices,
    quantity: sel.quantity,
    note: sel.note ?? '',
  );
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.line});

  final CartLine line;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late int _qty = widget.line.quantity;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.line.item.name),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Số lượng'),
          const SizedBox(width: 16),
          QuantityStepper(
            value: _qty,
            onChanged: (v) => setState(() => _qty = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(0),
          child: const Text(
            'Xoá món',
            style: TextStyle(color: AppColors.danger),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_qty),
          child: const Text('Xong'),
        ),
      ],
    );
  }
}

/// Compact line used in the tablet order panel: `1x  Cà phê sữa đá   34.000đ`.
class CartLineTile extends ConsumerWidget {
  const CartLineTile({super.key, required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = [
      if (line.optionsText.isNotEmpty) line.optionsText,
      if (line.note != null && line.note!.isNotEmpty) 'Ghi chú: ${line.note}',
    ].join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => editCartLine(context, ref, line),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.beige,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${line.quantity}x',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.item.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatVnd(line.lineTotal),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card with − qty + used on the phone cart screen (Figma M3).
class CartLineCard extends ConsumerWidget {
  const CartLineCard({super.key, required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartProvider.notifier);
    final sub = [
      if (line.optionsText.isNotEmpty) line.optionsText,
      if (line.note != null && line.note!.isNotEmpty) line.note!,
    ].join(' · ');
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => editCartLine(context, ref, line),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      formatVnd(line.lineTotal),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              QuantityStepper(
                value: line.quantity,
                compact: true,
                onChanged: (v) => cart.setQuantity(line.uid, v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "KH: 0901 234 567 · Vàng · 120 điểm" chip, or the add-customer prompt.
class CustomerChip extends ConsumerWidget {
  const CustomerChip({super.key, this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(cartProvider.select((s) => s.customer));
    return Material(
      color: AppColors.beige,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showCustomerDialog(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  c == null
                      ? '+ Thêm khách hàng'
                      : 'KH: ${c.prettyPhone} · ${c.tierLabel} · ${c.points} điểm',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c == null
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Tạm tính / Giảm giá / Tích điểm / Tổng cộng.
class CartTotals extends ConsumerWidget {
  const CartTotals({super.key, this.large = false, this.showPromoRow = true});

  final bool large;
  final bool showPromoRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(cartProvider);
    final muted = TextStyle(
      fontSize: large ? 13 : 12,
      color: AppColors.textSecondary,
    );
    final value = TextStyle(
      fontSize: large ? 13 : 12,
      fontWeight: FontWeight.w500,
    );

    Widget row(String label, Widget right, {Widget? labelWidget}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: labelWidget ?? Text(label, style: muted)),
          right,
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row('Tạm tính', Text(formatVnd(s.subtotal), style: value)),
        if (s.promotion != null)
          row(
            '',
            Text(
              '-${formatVnd(s.discount)}',
              style: value.copyWith(color: AppColors.success),
            ),
            labelWidget: InkWell(
              onTap: () => showPromoDialog(context, ref),
              child: Text('Giảm giá (${s.promotion!.code})', style: muted),
            ),
          )
        else if (showPromoRow)
          row(
            '',
            InkWell(
              onTap: () => showPromoDialog(context, ref),
              child: const Text(
                '+ Thêm mã',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            labelWidget: Text('Mã giảm giá', style: muted),
          ),
        if (s.customer != null)
          row('Tích điểm', Text('+${s.pointsEarned} điểm', style: muted)),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tổng cộng',
                  style: TextStyle(
                    fontSize: large ? 15 : 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                formatVnd(s.total),
                style: TextStyle(
                  fontSize: large ? 22 : 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Beige secondary button ("Lưu đơn", "Từ chối").
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.beige,
    this.textColor = AppColors.textPrimary,
    this.height = 48,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final double height;

  /// false = size to content (inline in a Row), true = fill the width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        disabledBackgroundColor: color.withValues(alpha: 0.6),
        minimumSize: expand ? Size.fromHeight(height) : Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: TextStyle(
          fontSize: expand ? 15 : 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
