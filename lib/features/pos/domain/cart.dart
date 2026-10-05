import 'menu.dart';
import 'order.dart';

/// One chosen option on a cart line (mirrors `OrderChoice` once priced by the server).
class SelectedChoice {
  const SelectedChoice({
    required this.group,
    required this.groupName,
    required this.code,
    required this.name,
    required this.priceDelta,
    this.isDefault = false,
  });

  final String group;
  final String groupName;
  final String code;
  final String name;
  final int priceDelta;

  /// First choice of a non-size group with no surcharge (e.g. "Bình thường",
  /// "100%"): left out of the ticket text, same rule as the backend.
  final bool isDefault;

  Map<String, dynamic> toJson() => {'group': group, 'code': code};
}

class CartLine {
  const CartLine({
    required this.uid,
    required this.item,
    required this.quantity,
    required this.choices,
    this.note,
  });

  final String uid;
  final MenuItem item;
  final int quantity;
  final List<SelectedChoice> choices;
  final String? note;

  int get unitPrice => item.price + choices.fold(0, (s, c) => s + c.priceDelta);
  int get lineTotal => unitPrice * quantity;

  /// "Size L · Ít đá" — same rendering the backend uses for `optionsText`.
  String get optionsText => choices
      .where((c) => !c.isDefault)
      .map(
        (c) => c.name.runes.length <= 3 ? '${c.groupName} ${c.name}' : c.name,
      )
      .join(' · ');

  /// Same item + same choices + same note collapses into one line.
  String get signature =>
      '${item.id}|${choices.map((c) => '${c.group}:${c.code}').join(',')}|${note ?? ''}';

  CartLine copyWith({
    int? quantity,
    List<SelectedChoice>? choices,
    String? note,
    bool clearNote = false,
  }) => CartLine(
    uid: uid,
    item: item,
    quantity: quantity ?? this.quantity,
    choices: choices ?? this.choices,
    note: clearNote ? null : (note ?? this.note),
  );

  Map<String, dynamic> toJson() => {
    'itemId': item.id,
    'quantity': quantity,
    'choices': choices.map((c) => c.toJson()).toList(),
    if (note != null && note!.isNotEmpty) 'note': note,
  };
}

class CartState {
  const CartState({
    this.lines = const [],
    this.orderType = 'dine_in',
    this.tableLabel = 'Bàn 05',
    this.tableId,
    this.customer,
    this.promotion,
    this.note,
    this.orderId,
  });

  final List<CartLine> lines;

  /// "dine_in" | "takeaway"
  final String orderType;
  final String tableLabel;

  /// Set when the table came from the floor plan; the server then uses the
  /// table's own name for the ticket.
  final String? tableId;
  final Customer? customer;
  final Promotion? promotion;
  final String? note;

  /// Set once the cart has been sent to the server (open order awaiting payment).
  final String? orderId;

  bool get isEmpty => lines.isEmpty;
  int get itemCount => lines.fold(0, (s, l) => s + l.quantity);
  int get subtotal => lines.fold(0, (s, l) => s + l.lineTotal);
  int get discount => promotion?.discountFor(subtotal) ?? 0;
  int get total => subtotal - discount;
  int get pointsEarned => total ~/ 10000;
  bool get isTakeaway => orderType == 'takeaway';
  String get headerLabel => isTakeaway ? 'Mang đi' : tableLabel;

  CartState copyWith({
    List<CartLine>? lines,
    String? orderType,
    String? tableLabel,
    String? tableId,
    bool clearTableId = false,
    Customer? customer,
    bool clearCustomer = false,
    Promotion? promotion,
    bool clearPromotion = false,
    String? note,
    String? orderId,
    bool clearOrderId = false,
  }) => CartState(
    lines: lines ?? this.lines,
    orderType: orderType ?? this.orderType,
    tableLabel: tableLabel ?? this.tableLabel,
    tableId: clearTableId ? null : (tableId ?? this.tableId),
    customer: clearCustomer ? null : (customer ?? this.customer),
    promotion: clearPromotion ? null : (promotion ?? this.promotion),
    note: note ?? this.note,
    orderId: clearOrderId ? null : (orderId ?? this.orderId),
  );

  /// `CreateOrderInput` from the API contract.
  Map<String, dynamic> toInput() => {
    'orderType': orderType,
    if (!isTakeaway) 'tableLabel': tableLabel,
    if (!isTakeaway && tableId != null) 'tableId': tableId,
    if (customer != null) 'customerId': customer!.id,
    if (promotion != null) 'promotionCode': promotion!.code,
    if (note != null && note!.isNotEmpty) 'note': note,
    'items': lines.map((l) => l.toJson()).toList(),
  };
}
