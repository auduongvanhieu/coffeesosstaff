import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../../core/utils/money.dart';
import '../../domain/cart.dart';
import '../../domain/menu.dart';

/// What the cashier picked for one line.
class ItemSelection {
  const ItemSelection({
    required this.choices,
    required this.quantity,
    this.note,
  });

  final List<SelectedChoice> choices;
  final int quantity;
  final String? note;
}

/// Option picker (size / đá / đường / topping), note and quantity.
/// Returns null when dismissed.
Future<ItemSelection?> showItemOptionsSheet(
  BuildContext context,
  MenuItem item, {
  ItemSelection? initial,
  String confirmLabel = 'Thêm vào đơn',
}) {
  return showModalBottomSheet<ItemSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) =>
        _OptionsSheet(item: item, initial: initial, confirmLabel: confirmLabel),
  );
}

class _OptionsSheet extends StatefulWidget {
  const _OptionsSheet({
    required this.item,
    this.initial,
    required this.confirmLabel,
  });

  final MenuItem item;
  final ItemSelection? initial;
  final String confirmLabel;

  @override
  State<_OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends State<_OptionsSheet> {
  /// group code -> chosen choice codes
  late final Map<String, Set<String>> _picked;
  late int _qty;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _qty = widget.initial?.quantity ?? 1;
    _note = TextEditingController(text: widget.initial?.note ?? '');
    _picked = {for (final g in widget.item.options) g.code: <String>{}};
    if (widget.initial != null) {
      for (final c in widget.initial!.choices) {
        _picked[c.group]?.add(c.code);
      }
    } else {
      // Pre-select the first choice of required single groups (Size M, đá bình thường...).
      for (final g in widget.item.options) {
        if (g.required && g.isSingle && g.choices.isNotEmpty) {
          _picked[g.code]!.add(g.choices.first.code);
        }
      }
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  List<SelectedChoice> get _choices => [
    for (final g in widget.item.options)
      for (final c in g.choices)
        if (_picked[g.code]!.contains(c.code))
          SelectedChoice(
            group: g.code,
            groupName: g.name,
            code: c.code,
            name: c.name,
            priceDelta: c.priceDelta,
            isDefault:
                g.code != 'size' && c.priceDelta == 0 && g.choices.first == c,
          ),
  ];

  int get _unitPrice =>
      widget.item.price + _choices.fold(0, (s, c) => s + c.priceDelta);

  String? get _missing {
    for (final g in widget.item.options) {
      if (g.required && _picked[g.code]!.isEmpty) {
        return 'Chọn ${g.name.toLowerCase()}';
      }
    }
    return null;
  }

  void _toggle(OptionGroup g, OptionChoice c) {
    setState(() {
      final set = _picked[g.code]!;
      if (g.isSingle) {
        set
          ..clear()
          ..add(c.code);
      } else if (!set.remove(c.code)) {
        set.add(c.code);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final missing = _missing;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ItemThumb(url: widget.item.imageUrl, size: 56, radius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.item.name,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  formatVnd(widget.item.price),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (widget.item.description != null &&
                widget.item.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.item.description!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 16),
            for (final g in widget.item.options) ...[
              Row(
                children: [
                  Text(
                    g.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    g.required
                        ? 'bắt buộc'
                        : (g.isSingle ? 'chọn 1' : 'chọn nhiều'),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in g.choices)
                    _ChoiceChip(
                      label: c.priceDelta > 0
                          ? '${c.name} +${formatVnd(c.priceDelta)}'
                          : c.name,
                      selected: _picked[g.code]!.contains(c.code),
                      onTap: () => _toggle(g, c),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                hintText: 'Ghi chú (ít ngọt, hâm nóng...)',
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Stepper(
                  value: _qty,
                  onChanged: (v) => setState(() => _qty = v),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: missing != null
                        ? null
                        : () => Navigator.of(context).pop(
                            ItemSelection(
                              choices: _choices,
                              quantity: _qty,
                              note: _note.text.trim().isEmpty
                                  ? null
                                  : _note.text.trim(),
                            ),
                          ),
                    child: Text(
                      missing ??
                          '${widget.confirmLabel} · ${formatVnd(_unitPrice * _qty)}',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
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
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// − 1 + stepper used in the sheet and the cart.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return QuantityStepper(value: value, onChanged: onChanged, min: 1);
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.compact = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 28.0 : 36.0;
    Widget btn(IconData icon, VoidCallback? onTap) => Material(
      color: AppColors.beige,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: compact ? 14 : 18),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(
          Icons.remove,
          value > min
              ? () => onChanged(value - 1)
              : (min == 0 ? () => onChanged(0) : null),
        ),
        SizedBox(
          width: compact ? 28 : 36,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: compact ? 13 : 15,
            ),
          ),
        ),
        btn(Icons.add, () => onChanged(value + 1)),
      ],
    );
  }
}
