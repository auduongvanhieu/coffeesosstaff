/// Models for /pos/orders, /pos/customers, /pos/promotions, /pos/store and
/// the shift summary. Shapes follow CoffeeSOSBE/docs/pos-api.md.
library;

class Customer {
  const Customer({
    required this.id,
    required this.phone,
    required this.name,
    required this.points,
    required this.tier,
  });

  final String id;
  final String phone;
  final String name;
  final int points;

  /// "member" | "silver" | "gold"
  final String tier;

  String get tierLabel => switch (tier) {
    'gold' => 'Vàng',
    'silver' => 'Bạc',
    _ => 'Thành viên',
  };

  /// "0901 234 567"
  String get prettyPhone {
    final d = phone.replaceAll(RegExp(r'\D'), '');
    if (d.length == 10) {
      return '${d.substring(0, 4)} ${d.substring(4, 7)} ${d.substring(7)}';
    }
    return phone;
  }

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'] as String,
    phone: json['phone'] as String? ?? '',
    name: json['name'] as String? ?? '',
    points: (json['points'] as num?)?.toInt() ?? 0,
    tier: json['tier'] as String? ?? 'member',
  );
}

class Promotion {
  const Promotion({
    required this.code,
    required this.name,
    required this.type,
    required this.value,
    required this.minSubtotal,
  });

  final String code;
  final String name;

  /// "percent" | "fixed"
  final String type;
  final int value;
  final int minSubtotal;

  int discountFor(int subtotal) {
    if (subtotal < minSubtotal) return 0;
    final d = type == 'percent' ? (subtotal * value ~/ 100) : value;
    return d.clamp(0, subtotal);
  }

  factory Promotion.fromJson(Map<String, dynamic> json) => Promotion(
    code: json['code'] as String,
    name: json['name'] as String? ?? '',
    type: json['type'] as String? ?? 'percent',
    value: (json['value'] as num?)?.toInt() ?? 0,
    minSubtotal: (json['minSubtotal'] as num?)?.toInt() ?? 0,
  );
}

class StoreInfo {
  const StoreInfo({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.bankBin,
    this.bankCode,
    this.bankAccount,
    this.bankHolder,
  });

  final String id;
  final String name;
  final String? address;
  final String? phone;
  final String? bankBin;
  final String? bankCode;
  final String? bankAccount;
  final String? bankHolder;

  bool get hasBank =>
      (bankCode ?? '').isNotEmpty && (bankAccount ?? '').isNotEmpty;

  factory StoreInfo.fromJson(Map<String, dynamic> json) => StoreInfo(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    address: json['address'] as String?,
    phone: json['phone'] as String?,
    bankBin: json['bankBin'] as String?,
    bankCode: json['bankCode'] as String?,
    bankAccount: json['bankAccount'] as String?,
    bankHolder: json['bankHolder'] as String?,
  );
}

class OrderChoice {
  const OrderChoice({
    required this.group,
    required this.groupName,
    required this.code,
    required this.name,
    required this.priceDelta,
  });

  final String group;
  final String groupName;
  final String code;
  final String name;
  final int priceDelta;

  factory OrderChoice.fromJson(Map<String, dynamic> json) => OrderChoice(
    group: json['group'] as String? ?? '',
    groupName: json['groupName'] as String? ?? '',
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    priceDelta: (json['priceDelta'] as num?)?.toInt() ?? 0,
  );
}

class OrderLine {
  const OrderLine({
    required this.id,
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.optionsText,
    required this.choices,
    this.note,
  });

  final String id;
  final String itemId;
  final String name;
  final int quantity;
  final int unitPrice;
  final int lineTotal;
  final String optionsText;
  final List<OrderChoice> choices;
  final String? note;

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
    id: json['id'] as String? ?? '',
    itemId: json['itemId'] as String? ?? '',
    name: json['name'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    unitPrice: (json['unitPrice'] as num?)?.toInt() ?? 0,
    lineTotal: (json['lineTotal'] as num?)?.toInt() ?? 0,
    optionsText: json['optionsText'] as String? ?? '',
    choices: (json['choices'] as List<dynamic>? ?? [])
        .map((e) => OrderChoice.fromJson(e as Map<String, dynamic>))
        .toList(),
    note: json['note'] as String?,
  );
}

class OrderUser {
  const OrderUser({required this.id, required this.fullName});

  final String id;
  final String fullName;

  factory OrderUser.fromJson(Map<String, dynamic> json) => OrderUser(
    id: json['id'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
  );
}

class Order {
  const Order({
    required this.id,
    required this.number,
    required this.source,
    required this.orderType,
    required this.tableLabel,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.cashReceived,
    required this.changeDue,
    required this.customer,
    required this.promotionCode,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.pointsEarned,
    required this.note,
    required this.items,
    required this.createdAt,
    required this.paidAt,
    required this.updatedAt,
    required this.createdBy,
  });

  final String id;
  final String number;

  /// "pos" | "app"
  final String source;

  /// "dine_in" | "takeaway" | "pickup"
  final String orderType;
  final String? tableLabel;

  /// open | pending | preparing | ready | completed | rejected | cancelled
  final String status;

  /// "unpaid" | "paid"
  final String paymentStatus;
  final String? paymentMethod;
  final int? cashReceived;
  final int? changeDue;
  final Customer? customer;
  final String? promotionCode;
  final int subtotal;
  final int discount;
  final int total;
  final int pointsEarned;
  final String? note;
  final List<OrderLine> items;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? updatedAt;
  final OrderUser? createdBy;

  bool get isPaid => paymentStatus == 'paid';

  String get statusLabel => statusLabelOf(status);

  String get orderTypeLabel => switch (orderType) {
    'takeaway' => 'Mang đi',
    'pickup' => 'Đến lấy',
    _ => tableLabel ?? 'Tại quán',
  };

  String get paymentMethodLabel => paymentMethodLabelOf(paymentMethod);

  /// "1x Cà phê sữa đá (L, ít đá) · 2x Trà đào cam sả"
  String get itemsSummary => items
      .map((l) {
        final opts = l.optionsText.isEmpty
            ? ''
            : ' (${l.optionsText.replaceAll(' · ', ', ')})';
        return '${l.quantity}x ${l.name}$opts';
      })
      .join(' · ');

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as String,
    number: json['number'] as String? ?? '',
    source: json['source'] as String? ?? 'pos',
    orderType: json['orderType'] as String? ?? 'dine_in',
    tableLabel: json['tableLabel'] as String?,
    status: json['status'] as String? ?? 'open',
    paymentStatus: json['paymentStatus'] as String? ?? 'unpaid',
    paymentMethod: json['paymentMethod'] as String?,
    cashReceived: (json['cashReceived'] as num?)?.toInt(),
    changeDue: (json['changeDue'] as num?)?.toInt(),
    customer: json['customer'] == null
        ? null
        : Customer.fromJson(json['customer'] as Map<String, dynamic>),
    promotionCode: json['promotionCode'] as String?,
    subtotal: (json['subtotal'] as num?)?.toInt() ?? 0,
    discount: (json['discount'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
    pointsEarned: (json['pointsEarned'] as num?)?.toInt() ?? 0,
    note: json['note'] as String?,
    items: (json['items'] as List<dynamic>? ?? [])
        .map((e) => OrderLine.fromJson(e as Map<String, dynamic>))
        .toList(),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    paidAt: DateTime.tryParse(json['paidAt'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    createdBy: json['createdBy'] == null
        ? null
        : OrderUser.fromJson(json['createdBy'] as Map<String, dynamic>),
  );
}

String statusLabelOf(String status) => switch (status) {
  'open' => 'Đang mở',
  'pending' => 'Chờ xác nhận',
  'preparing' => 'Đang pha',
  'ready' => 'Sẵn sàng',
  'completed' => 'Đã giao',
  'rejected' => 'Đã từ chối',
  'cancelled' => 'Đã huỷ',
  _ => status,
};

String paymentMethodLabelOf(String? method) => switch (method) {
  'cash' => 'Tiền mặt',
  'vietqr' => 'VietQR',
  'momo' => 'MoMo',
  'zalopay' => 'ZaloPay',
  _ => '',
};

class ShiftSummary {
  const ShiftSummary({
    required this.date,
    required this.orders,
    required this.revenue,
    required this.byMethod,
    required this.bySource,
    required this.pendingApp,
  });

  final String date;
  final int orders;
  final int revenue;
  final Map<String, int> byMethod;
  final Map<String, int> bySource;
  final int pendingApp;

  factory ShiftSummary.fromJson(Map<String, dynamic> json) {
    Map<String, int> ints(dynamic m) => (m as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
    );
    return ShiftSummary(
      date: json['date'] as String? ?? '',
      orders: (json['orders'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toInt() ?? 0,
      byMethod: ints(json['byMethod']),
      bySource: ints(json['bySource']),
      pendingApp: (json['pendingApp'] as num?)?.toInt() ?? 0,
    );
  }
}
