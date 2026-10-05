import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/order_repository.dart';
import '../domain/cart.dart';
import '../domain/menu.dart';
import '../domain/order.dart';

/// The order being built on this terminal. Pure local state; prices are
/// recomputed by the server when the order is created.
class CartController extends Notifier<CartState> {
  int _seq = 0;

  @override
  CartState build() => const CartState();

  void addLine(
    MenuItem item, {
    List<SelectedChoice> choices = const [],
    int quantity = 1,
    String? note,
  }) {
    final candidate = CartLine(
      uid: '',
      item: item,
      quantity: quantity,
      choices: choices,
      note: note,
    );
    final existing = state.lines.indexWhere(
      (l) => l.signature == candidate.signature,
    );
    if (existing >= 0) {
      final lines = [...state.lines];
      lines[existing] = lines[existing].copyWith(
        quantity: lines[existing].quantity + quantity,
      );
      state = state.copyWith(lines: lines);
      return;
    }
    final line = CartLine(
      uid: 'l${++_seq}',
      item: item,
      quantity: quantity,
      choices: choices,
      note: note,
    );
    state = state.copyWith(lines: [...state.lines, line]);
  }

  void setQuantity(String uid, int quantity) {
    if (quantity <= 0) {
      removeLine(uid);
      return;
    }
    state = state.copyWith(
      lines: [
        for (final l in state.lines)
          l.uid == uid ? l.copyWith(quantity: quantity) : l,
      ],
    );
  }

  void increment(String uid) {
    final l = state.lines.firstWhere((l) => l.uid == uid);
    setQuantity(uid, l.quantity + 1);
  }

  void decrement(String uid) {
    final l = state.lines.firstWhere((l) => l.uid == uid);
    setQuantity(uid, l.quantity - 1);
  }

  void updateLine(
    String uid, {
    List<SelectedChoice>? choices,
    int? quantity,
    String? note,
  }) {
    state = state.copyWith(
      lines: [
        for (final l in state.lines)
          l.uid == uid
              ? l.copyWith(choices: choices, quantity: quantity, note: note)
              : l,
      ],
    );
  }

  void removeLine(String uid) {
    state = state.copyWith(
      lines: state.lines.where((l) => l.uid != uid).toList(),
    );
  }

  void setTable(String label, {String? id}) => state = state.copyWith(
    tableLabel: label,
    tableId: id,
    clearTableId: id == null,
    orderType: 'dine_in',
  );

  void setOrderType(String type) => state = state.copyWith(orderType: type);

  void setCustomer(Customer? c) => state = c == null
      ? state.copyWith(clearCustomer: true)
      : state.copyWith(customer: c);

  void setPromotion(Promotion? p) => state = p == null
      ? state.copyWith(clearPromotion: true)
      : state.copyWith(promotion: p);

  void setNote(String? note) => state = state.copyWith(note: note);

  void clear() =>
      state = CartState(tableLabel: state.tableLabel, tableId: state.tableId);

  /// Reopens an existing order for editing. `adjusting` marks a bill that was
  /// already paid: saving then goes through /adjust instead of creating a new
  /// order. Lines are rebuilt from the live menu so options stay in sync.
  void loadFrom(Order order, StoreMenu menu, {bool adjusting = false}) {
    final byId = {for (final i in menu.items) i.id: i};
    final lines = <CartLine>[];
    for (final l in order.items) {
      final item = byId[l.itemId];
      if (item == null) continue; // item left the menu; drop the line
      lines.add(
        CartLine(
          uid: 'l${++_seq}',
          item: item,
          quantity: l.quantity,
          choices: [
            for (final c in l.choices)
              SelectedChoice(
                group: c.group,
                groupName: c.groupName,
                code: c.code,
                name: c.name,
                priceDelta: c.priceDelta,
                isDefault: false,
              ),
          ],
          note: l.note,
        ),
      );
    }
    state = CartState(
      lines: lines,
      orderType: order.orderType == 'takeaway' ? 'takeaway' : 'dine_in',
      tableLabel: order.tableLabel ?? state.tableLabel,
      tableId: order.tableId,
      customer: order.customer,
      promotion: order.promotionCode == null
          ? null
          : Promotion(
              code: order.promotionCode!,
              name: order.promotionCode!,
              type: 'fixed',
              value: order.discount,
              minSubtotal: 0,
            ),
      note: order.note,
      orderId: order.id,
      adjustingNumber: adjusting ? order.number : null,
    );
  }

  /// Saves a correction to an already-paid bill. Returns the updated order and
  /// the difference to collect (positive) or hand back (negative).
  Future<(Order, int)> saveAdjustment(String reason) async {
    final res = await ref
        .read(orderRepositoryProvider)
        .adjust(state.orderId!, state.toInput(), reason);
    return res;
  }

  /// Sends the cart to the server as an open order (or replaces the lines of
  /// the order already created for this cart). Returns the priced order.
  Future<Order> submit() async {
    final repo = ref.read(orderRepositoryProvider);
    final input = state.toInput();
    final order = state.orderId == null
        ? await repo.create(input)
        : await repo.replace(state.orderId!, input);
    state = state.copyWith(orderId: order.id);
    return order;
  }
}

final cartProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);
