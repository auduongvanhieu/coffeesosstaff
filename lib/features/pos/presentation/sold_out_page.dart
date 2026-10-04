import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/breakpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../data/menu_repository.dart';
import '../domain/menu.dart';

/// "Hết món": flip store-level availability per item.
class SoldOutPage extends ConsumerStatefulWidget {
  const SoldOutPage({super.key});

  @override
  ConsumerState<SoldOutPage> createState() => _SoldOutPageState();
}

class _SoldOutPageState extends ConsumerState<SoldOutPage> {
  final _busy = <String>{};

  Future<void> _toggle(MenuItem item, bool available) async {
    setState(() => _busy.add(item.id));
    try {
      final storeId = ref.read(currentStoreIdProvider);
      await ref
          .read(menuRepositoryProvider)
          .setAvailability(item.id, available, storeId: storeId);
      ref.invalidate(storeMenuProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(storeMenuProvider);
    final tablet = Breakpoints.isTablet(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(tablet ? 24 : 16, 16, tablet ? 24 : 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Hết món',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Tải lại',
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => ref.invalidate(storeMenuProvider),
                ),
              ],
            ),
            const Text(
              'Tắt món đang hết tại quán; món sẽ mờ trên màn hình order và app khách.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: menu.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(describeError(e))),
                data: (data) {
                  final soldOut = data.items.where((i) => !i.available).length;
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      if (soldOut > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            '$soldOut món đang hết',
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      for (final c in data.categories) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                          child: Text(
                            c.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              for (final (idx, item)
                                  in data.items
                                      .where((i) => i.categoryId == c.id)
                                      .indexed) ...[
                                if (idx > 0)
                                  const Divider(
                                    height: 1,
                                    indent: 16,
                                    endIndent: 16,
                                  ),
                                _Row(
                                  item: item,
                                  busy: _busy.contains(item.id),
                                  onChanged: (v) => _toggle(item, v),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
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

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.busy, required this.onChanged});

  final MenuItem item;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.beige,
              borderRadius: BorderRadius.circular(8),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: item.available
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                Text(
                  item.available ? formatVnd(item.price) : 'Hết món',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: item.available
                        ? AppColors.primary
                        : AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Switch(value: item.available, onChanged: onChanged),
        ],
      ),
    );
  }
}
