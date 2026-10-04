import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/breakpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/device_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user.dart';
import '../data/order_repository.dart';
import '../domain/order.dart';

/// "Kết ca": today's totals for this store plus sign-out.
class ShiftPage extends ConsumerWidget {
  const ShiftPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(shiftSummaryProvider);
    final user = ref.watch(authControllerProvider).value;
    final device = ref.watch(deviceContextProvider);
    final tablet = Breakpoints.isTablet(context);
    final today = DateFormat('EEEE, d/M/yyyy', 'vi_VN').format(DateTime.now());

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(tablet ? 24 : 16, 16, tablet ? 24 : 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (user != null) ...[
                  _AvatarButton(user: user),
                  const SizedBox(width: 12),
                ],
                const Text(
                  'Kết ca',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Tải lại',
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => ref.invalidate(shiftSummaryProvider),
                ),
              ],
            ),
            Text(
              '${device?.displayName ?? ''} · $today${user == null ? '' : ' · ${user.fullName}'}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: summary.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(describeError(e))),
                data: (s) => ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _Stat(
                          label: 'Doanh thu',
                          value: formatVnd(s.revenue),
                          accent: true,
                          wide: tablet,
                        ),
                        _Stat(
                          label: 'Số đơn',
                          value: '${s.orders}',
                          wide: tablet,
                        ),
                        _Stat(
                          label: 'Đơn app chờ xác nhận',
                          value: '${s.pendingApp}',
                          wide: tablet,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _Section(
                      title: 'Theo phương thức',
                      rows: [
                        for (final m in const [
                          'cash',
                          'vietqr',
                          'momo',
                          'zalopay',
                        ])
                          (
                            paymentMethodLabelOf(m),
                            formatVnd(s.byMethod[m] ?? 0),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _Section(
                      title: 'Theo nguồn',
                      rows: [
                        ('Tại quầy (POS)', '${s.bySource['pos'] ?? 0} đơn'),
                        ('Đơn từ app', '${s.bySource['app'] ?? 0} đơn'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: tablet ? 260 : double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          backgroundColor: AppColors.surface,
                          side: BorderSide.none,
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Kết ca & đăng xuất'),
                        onPressed: () =>
                            ref.read(authControllerProvider.notifier).logout(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.accent = false,
    required this.wide,
  });

  final String label;
  final String value;
  final bool accent;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? 220 : (MediaQuery.sizeOf(context).width - 44) / 2,
      padding: const EdgeInsets.all(16),
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
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r.$1,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    r.$2,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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

/// Staff photo on the shift screen; tap to pick a new one from the device.
class _AvatarButton extends ConsumerStatefulWidget {
  const _AvatarButton({required this.user});

  final StaffUser user;

  @override
  ConsumerState<_AvatarButton> createState() => _AvatarButtonState();
}

class _AvatarButtonState extends ConsumerState<_AvatarButton> {
  bool _busy = false;

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();
      await ref
          .read(authControllerProvider.notifier)
          .uploadAvatar(bytes, picked.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật ảnh đại diện')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Đổi ảnh đại diện',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _busy ? null : _pick,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            StaffAvatar(
              initials: widget.user.initials,
              url: widget.user.avatarUrl,
              size: 44,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: _busy
                    ? const Padding(
                        padding: EdgeInsets.all(4),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.photo_camera_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
