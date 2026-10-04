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
import '../domain/menu.dart';
import 'widgets/cart_widgets.dart';
import 'widgets/dialogs.dart';
import 'widgets/item_options_sheet.dart';

/// Figma "02 Order chính" (tablet) and "M2 Order" (phone).
class OrderPage extends ConsumerStatefulWidget {
  const OrderPage({super.key});

  @override
  ConsumerState<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends ConsumerState<OrderPage> {
  String _query = '';
  String? _categoryId; // null = Tất cả

  Future<void> _addItem(MenuItem item) async {
    final cart = ref.read(cartProvider.notifier);
    if (!item.hasOptions) {
      cart.addLine(item);
      return;
    }
    final sel = await showItemOptionsSheet(context, item);
    if (sel == null) return;
    cart.addLine(
      item,
      choices: sel.choices,
      quantity: sel.quantity,
      note: sel.note,
    );
  }

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(storeMenuProvider);
    return menu.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(
        message: describeError(e),
        onRetry: () => ref.invalidate(storeMenuProvider),
      ),
      data: (data) {
        final items = data.items.where((i) {
          if (_categoryId != null && i.categoryId != _categoryId) return false;
          if (_query.isNotEmpty &&
              !i.name.toLowerCase().contains(_query.toLowerCase())) {
            return false;
          }
          return true;
        }).toList();
        return AdaptiveLayout(
          tablet: (_) => _TabletLayout(
            menu: data,
            items: items,
            categoryId: _categoryId,
            onCategory: (id) => setState(() => _categoryId = id),
            onQuery: (q) => setState(() => _query = q),
            onTapItem: _addItem,
          ),
          phone: (_) => _PhoneLayout(
            menu: data,
            items: items,
            categoryId: _categoryId,
            onCategory: (id) => setState(() => _categoryId = id),
            onQuery: (q) => setState(() => _query = q),
            onTapItem: _addItem,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tablet
// ---------------------------------------------------------------------------

class _TabletLayout extends ConsumerWidget {
  const _TabletLayout({
    required this.menu,
    required this.items,
    required this.categoryId,
    required this.onCategory,
    required this.onQuery,
    required this.onTapItem,
  });

  final StoreMenu menu;
  final List<MenuItem> items;
  final String? categoryId;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String> onQuery;
  final ValueChanged<MenuItem> onTapItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _SearchField(onChanged: onQuery)),
                    const SizedBox(width: 12),
                    const _TablePill(),
                    const SizedBox(width: 8),
                    const _TakeawayToggle(),
                  ],
                ),
                const SizedBox(height: 12),
                _CategoryChips(
                  categories: menu.categories,
                  selected: categoryId,
                  onSelected: onCategory,
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: MenuGrid(items: items, columns: 4, onTap: onTapItem),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          width: 320,
          color: AppColors.surface,
          child: const _OrderPanel(),
        ),
      ],
    );
  }
}

class _OrderPanel extends ConsumerWidget {
  const _OrderPanel();

  Future<void> _hold(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider.notifier);
    try {
      final order = await cart.submit();
      cart.clear();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Đã lưu đơn ${order.number}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    }
  }

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Đơn hàng',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 16, color: AppColors.border),
              const Spacer(),
              Text(
                cart.headerLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const CustomerChip(),
          const SizedBox(height: 6),
          Expanded(
            child: cart.isEmpty
                ? const Center(
                    child: Text(
                      'Chọn món để bắt đầu đơn',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView(
                    children: [
                      for (final l in cart.lines) CartLineTile(line: l),
                    ],
                  ),
          ),
          const Divider(height: 20),
          const CartTotals(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SoftButton(
                  label: 'Lưu đơn',
                  onPressed: cart.isEmpty ? null : () => _hold(context, ref),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: FilledButton(
                  onPressed: cart.isEmpty
                      ? null
                      : () => _checkout(context, ref),
                  child: const Text('Thanh toán'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phone
// ---------------------------------------------------------------------------

class _PhoneLayout extends ConsumerWidget {
  const _PhoneLayout({
    required this.menu,
    required this.items,
    required this.categoryId,
    required this.onCategory,
    required this.onQuery,
    required this.onTapItem,
  });

  final StoreMenu menu;
  final List<MenuItem> items;
  final String? categoryId;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String> onQuery;
  final ValueChanged<MenuItem> onTapItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                const _TablePill(),
                const SizedBox(width: 8),
                Expanded(
                  child: _SearchField(onChanged: onQuery, compact: true),
                ),
                const SizedBox(width: 8),
                const _TakeawayToggle(compact: true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _CategoryChips(
              categories: menu.categories,
              selected: categoryId,
              onSelected: onCategory,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: MenuGrid(items: items, columns: 2, onTap: onTapItem),
            ),
          ),
          if (!cart.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push(Routes.cart),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${cart.itemCount} món · ${formatVnd(cart.total)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Xem đơn →',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged, this.compact = false});

  final ValueChanged<String> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 40 : 44,
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Tìm món...',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: compact ? 10 : 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _TablePill extends ConsumerWidget {
  const _TablePill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final label = cart.isTakeaway ? 'Mang đi' : cart.tableLabel;
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showTablePicker(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _TakeawayToggle extends ConsumerWidget {
  const _TakeawayToggle({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final takeaway = ref.watch(cartProvider.select((s) => s.isTakeaway));
    return Material(
      color: takeaway ? AppColors.primaryLight : AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => ref
            .read(cartProvider.notifier)
            .setOrderType(takeaway ? 'dine_in' : 'takeaway'),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: 11,
          ),
          child: compact
              ? Icon(
                  Icons.shopping_bag_outlined,
                  size: 18,
                  color: takeaway ? AppColors.primary : AppColors.textSecondary,
                )
              : Text(
                  'Mang đi',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: takeaway ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<MenuCategory> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, String? id) {
      final active = selected == id;
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Material(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => onSelected(id),
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

    return Align(
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
              chip('Tất cả', null),
              for (final c in categories) chip(c.name, c.id),
            ],
          ),
        ),
      ),
    );
  }
}

class MenuGrid extends StatelessWidget {
  const MenuGrid({
    super.key,
    required this.items,
    required this.columns,
    required this.onTap,
  });

  final List<MenuItem> items;
  final int columns;
  final ValueChanged<MenuItem> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Không có món nào',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: columns >= 4 ? 1.15 : 1.0,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) =>
          MenuItemCard(item: items[i], onTap: () => onTap(items[i])),
    );
  }
}

class MenuItemCard extends StatelessWidget {
  const MenuItemCard({super.key, required this.item, required this.onTap});

  final MenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final soldOut = !item.available;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: soldOut ? null : onTap,
      child: Opacity(
        opacity: soldOut ? 0.55 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.beige,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: item.imageUrl == null || item.imageUrl!.isEmpty
                    ? null
                    : Image.network(
                        item.imageUrl!,
                        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: soldOut
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              soldOut ? 'Hết món' : formatVnd(item.price),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: soldOut
                    ? AppColors.danger.withValues(alpha: 0.8)
                    : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 40, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          SizedBox(
            width: 140,
            child: OutlinedButton(
              onPressed: onRetry,
              child: const Text('Thử lại'),
            ),
          ),
        ],
      ),
    );
  }
}
