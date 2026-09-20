import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/breakpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../data/menu_repository.dart';
import '../domain/menu.dart';

final _vnd = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

/// POS home. Tablet: menu grid + order panel side by side.
/// Phone: menu grid only, order panel will open as a sheet (next step).
class PosHomePage extends ConsumerWidget {
  const PosHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final menu = ref.watch(storeMenuProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.fullName.isNotEmpty == true ? 'Xin chào, ${user!.fullName}' : 'POS'),
        actions: [
          IconButton(
            tooltip: 'Tải lại menu',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(storeMenuProvider),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: menu.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: describeError(e),
          onRetry: () => ref.invalidate(storeMenuProvider),
        ),
        data: (data) => AdaptiveLayout(
          phone: (_) => _MenuGrid(menu: data),
          tablet: (_) => Row(
            children: [
              Expanded(flex: 3, child: _MenuGrid(menu: data)),
              const VerticalDivider(width: 1, color: AppColors.border),
              const Expanded(flex: 2, child: _OrderPanelPlaceholder()),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.menu});

  final StoreMenu menu;

  @override
  Widget build(BuildContext context) {
    if (menu.items.isEmpty) {
      return const Center(child: Text('Cửa hàng chưa có món nào trong menu.'));
    }
    final width = MediaQuery.sizeOf(context).width;
    final columns = (width / 180).floor().clamp(2, 6);

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: menu.items.length,
      itemBuilder: (context, i) => _MenuItemCard(item: menu.items[i]),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.available ? () {} : null,
        child: Opacity(
          opacity: item.available ? 1 : 0.45,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: item.imageUrl != null
                    ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                    : const ColoredBox(
                        color: AppColors.primaryLight,
                        child: Icon(Icons.local_cafe_outlined, color: AppColors.primary, size: 36),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(_vnd.format(item.price),
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderPanelPlaceholder extends StatelessWidget {
  const _OrderPanelPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Text('Đơn hàng hiện tại\n(chưa có món)',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
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
          OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
