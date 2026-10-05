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
import '../domain/table.dart';

/// Floor plan: which tables have guests, which are free. Tapping a free table
/// starts an order on it; tapping a busy one reopens that order.
class TablesPage extends ConsumerWidget {
  const TablesPage({super.key});

  Future<void> _openTable(
    BuildContext context,
    WidgetRef ref,
    StoreTable table,
  ) async {
    final cart = ref.read(cartProvider.notifier);
    if (table.isFree) {
      cart.clear();
      cart.setTable(table.name, id: table.id);
      context.go(Routes.order);
      return;
    }
    // Busy: pull the order back into the cart so staff can add more items.
    final messenger = ScaffoldMessenger.of(context);
    try {
      final order = await ref.read(orderRepositoryProvider).get(table.orderId!);
      final menu = await ref.read(storeMenuProvider.future);
      if (order.status != 'open') {
        // Already paid: nothing to edit, show the order instead.
        if (context.mounted) {
          context.push(Routes.payment(order.id), extra: order);
        }
        return;
      }
      cart.loadFrom(order, menu);
      if (context.mounted) context.go(Routes.order);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(floorPlanProvider);
    final tablet = Breakpoints.isTablet(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(tablet ? 20 : 16, 16, tablet ? 20 : 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Sơ đồ bàn',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Tải lại',
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => ref.invalidate(floorPlanProvider),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: plan.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _Error(
                message: describeError(e),
                onRetry: () => ref.invalidate(floorPlanProvider),
              ),
              data: (p) => p.tables.isEmpty
                  ? const _Empty()
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(floorPlanProvider),
                      child: ListView(
                        children: [
                          _Summary(plan: p, tablet: tablet),
                          const SizedBox(height: 16),
                          for (final zone in _zonesOf(p)) ...[
                            if (p.zones.length > 1 || zone.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 8,
                                  top: 4,
                                ),
                                child: Text(
                                  zone.isEmpty ? 'Khác' : zone,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            _TableGrid(
                              tables: zone.isEmpty && p.zones.isEmpty
                                  ? p.tables
                                  : p.inZone(zone),
                              maxWidth: tablet ? 230 : 190,
                              aspect: tablet ? 1.45 : 1.1,
                              onTap: (t) => _openTable(context, ref, t),
                            ),
                            const SizedBox(height: 18),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _zonesOf(FloorPlan p) => p.zones.isEmpty ? [''] : p.zones;
}

/// "4/10 bàn đang có khách · 136.000đ chưa thu".
class _Summary extends StatelessWidget {
  const _Summary({required this.plan, required this.tablet});

  final FloorPlan plan;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _Stat(
        label: 'Đang có khách',
        value: '${plan.busy}/${plan.total}',
        accent: true,
      ),
      _Stat(label: 'Bàn trống', value: '${plan.free}'),
      _Stat(label: 'Chưa thu', value: formatVnd(plan.openRevenue)),
      if (plan.takeawayOpen > 0)
        _Stat(label: 'Mang đi chờ thu', value: formatVnd(plan.takeawayOpen)),
    ];
    return Wrap(spacing: 12, runSpacing: 12, children: cards);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.accent = false});

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: accent ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableGrid extends StatelessWidget {
  const _TableGrid({
    required this.tables,
    required this.maxWidth,
    required this.aspect,
    required this.onTap,
  });

  final List<StoreTable> tables;

  /// Cards keep a comfortable size instead of stretching on wide screens.
  final double maxWidth;

  /// Phone cards are narrower, so they need more height for the order line.
  final double aspect;
  final void Function(StoreTable) onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxWidth,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: aspect,
      ),
      itemCount: tables.length,
      itemBuilder: (_, i) => _TableCard(table: tables[i], onTap: onTap),
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.table, required this.onTap});

  final StoreTable table;
  final void Function(StoreTable) onTap;

  @override
  Widget build(BuildContext context) {
    // Free = plain white card; serving = terracotta; paid = teal.
    final accent = table.isServing
        ? AppColors.primary
        : table.isPaid
        ? AppColors.success
        : AppColors.border;
    final bg = table.isFree
        ? AppColors.surface
        : table.isServing
        ? AppColors.beige
        : AppColors.success.withValues(alpha: 0.10);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onTap(table),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: table.isFree ? AppColors.border : accent,
              width: table.isFree ? 1 : 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      table.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: table.isFree ? AppColors.border : accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                table.isFree ? '${table.seats} chỗ' : table.statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: table.isFree ? FontWeight.w400 : FontWeight.w600,
                  color: table.isFree ? AppColors.textSecondary : accent,
                ),
              ),
              const Spacer(),
              if (table.isFree)
                const Text(
                  'Trống',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                )
              else ...[
                Text(
                  formatVnd(table.total ?? 0),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${table.itemCount ?? 0} món · ${table.elapsedLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Cửa hàng chưa khai báo bàn nào.\nQuản lý có thể thêm bàn trong trang Admin.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
