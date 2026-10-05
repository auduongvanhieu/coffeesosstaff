import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../data/order_repository.dart';
import '../domain/order.dart';

final _time = DateFormat('HH:mm');
final _day = DateFormat('EEEE, d/M/yyyy', 'vi_VN');

/// Bills of one day: every order the store rang up, so staff can look one up
/// and correct it when it was charged wrong.
class BillsPage extends ConsumerStatefulWidget {
  const BillsPage({super.key});

  @override
  ConsumerState<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends ConsumerState<BillsPage> {
  final _search = TextEditingController();
  DateTime _date = DateTime.now();
  String _filter = 'all';
  String _query = '';

  static const _filters = {
    'all': 'Tất cả',
    'paid': 'Đã thanh toán',
    'open': 'Chưa thanh toán',
    'cancelled': 'Đã huỷ',
  };

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> get _statuses => switch (_filter) {
    'open' => ['open'],
    'cancelled' => ['cancelled', 'rejected'],
    _ => const <String>[],
  };

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      locale: const Locale('vi'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final q = HistoryQuery(
      date: DateFormat('yyyy-MM-dd').format(_date),
      statuses: _statuses,
      query: _query,
    );
    final bills = ref.watch(orderHistoryProvider(q));
    final tablet = Breakpoints.isTablet(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(tablet ? 20 : 16, 16, tablet ? 20 : 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Hoá đơn',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text(_day.format(_date)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Tải lại',
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => ref.invalidate(orderHistoryProvider(q)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Tìm số đơn hoặc số điện thoại khách',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  onSubmitted: (v) => setState(() => _query = v.trim()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final e in _filters.entries) ...[
                  _Chip(
                    label: e.value,
                    selected: _filter == e.key,
                    onTap: () => setState(() => _filter = e.key),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: bills.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(describeError(e))),
              data: (items) {
                final shown = _filter == 'paid'
                    ? items.where((o) => o.isPaid).toList()
                    : items;
                if (shown.isEmpty) {
                  return const Center(
                    child: Text(
                      'Không có hoá đơn nào.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(orderHistoryProvider(q)),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _BillTile(
                      order: shown[i],
                      onTap: () => context.push(Routes.bill(shown[i].id)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
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
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cancelled = order.status == 'cancelled' || order.status == 'rejected';
    final summary = order.items
        .map(
          (l) =>
              '${l.quantity}x ${l.name}'
              '${l.optionsText.isEmpty ? '' : ' (${l.optionsText})'}',
        )
        .join(' · ');

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    order.number,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      decoration: cancelled ? TextDecoration.lineThrough : null,
                      color: cancelled
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_time.format(order.createdAt.toLocal())} · ${order.orderTypeLabel}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatVnd(order.total),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cancelled
                          ? AppColors.textSecondary
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  _StatusText(order: order),
                  if (order.adjustmentCount > 0) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.edit_note_rounded,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    const Text(
                      ' đã sửa',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (order.status) {
      'cancelled' || 'rejected' => (order.statusLabel, AppColors.danger),
      _ when order.isPaid => (
        'Đã thanh toán${order.paymentMethod == null ? '' : ' · ${paymentMethodLabelOf(order.paymentMethod!)}'}',
        AppColors.success,
      ),
      _ => ('Chưa thanh toán', AppColors.primary),
    };
    return Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
    );
  }
}
