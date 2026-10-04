import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../core/storage/device_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../auth/application/auth_controller.dart';
import '../application/app_orders_controller.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}

const _destinations = [
  _Destination('Order', Icons.local_cafe_rounded, Routes.order),
  _Destination('Đơn app', Icons.smartphone_rounded, Routes.appOrders),
  _Destination('Hết món', Icons.block_rounded, Routes.soldOut),
  _Destination('Kết ca', Icons.receipt_long_rounded, Routes.shift),
];

/// Tablet: left rail like Figma "02 Order chính". Phone: bottom nav like "M2".
class PosShell extends ConsumerWidget {
  const PosShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  int get _index {
    final i = _destinations.indexWhere((d) => d.route == location);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingAppCountProvider);
    final device = ref.watch(deviceContextProvider);
    return AdaptiveLayout(
      tablet: (_) => Scaffold(
        body: Row(
          children: [
            _Rail(
              index: _index,
              pending: pending,
              logoUrl: device?.brandLogoUrl,
            ),
            Expanded(child: child),
          ],
        ),
      ),
      phone: (_) => Scaffold(
        body: child,
        bottomNavigationBar: _BottomNav(index: _index, pending: pending),
      ),
    );
  }
}

class _Rail extends ConsumerWidget {
  const _Rail({required this.index, required this.pending, this.logoUrl});

  final int index;
  final int pending;
  final String? logoUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    return Container(
      width: 72,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          BrandLogo(size: 36, url: logoUrl),
          const SizedBox(height: 24),
          for (var i = 0; i < _destinations.length; i++) ...[
            _RailItem(
              destination: _destinations[i],
              active: i == index,
              badge: i == 1 ? pending : 0,
            ),
            const SizedBox(height: 14),
          ],
          const Spacer(),
          if (user != null)
            Tooltip(
              message: user.fullName,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.go(Routes.shift),
                child: StaffAvatar(
                  initials: user.initials,
                  url: user.avatarUrl,
                  size: 40,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.destination,
    required this.active,
    required this.badge,
  });

  final _Destination destination;
  final bool active;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.go(destination.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.beige,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    destination.icon,
                    size: 20,
                    color: active ? Colors.white : AppColors.textSecondary,
                  ),
                ),
                if (badge > 0)
                  Positioned(top: -4, right: -4, child: _Badge(count: badge)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              destination.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.pending});

  final int index;
  final int pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.only(
        top: 8,
        bottom: 8 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          for (var i = 0; i < _destinations.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => context.go(_destinations[i].route),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: i == index
                                ? AppColors.primary
                                : AppColors.beigeDark,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(
                            _destinations[i].icon,
                            size: 14,
                            color: i == index
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                        if (i == 1 && pending > 0)
                          Positioned(
                            top: -6,
                            right: -8,
                            child: _Badge(count: pending),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _destinations[i].label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: i == index
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surface, width: 1.5),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
