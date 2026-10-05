/// Mirrors `order.TableView` / `order.FloorPlan` from GET /pos/tables.
class StoreTable {
  const StoreTable({
    required this.id,
    required this.name,
    required this.zone,
    required this.seats,
    required this.status,
    this.orderId,
    this.orderNumber,
    this.orderStatus,
    this.paymentStatus,
    this.total,
    this.itemCount,
    this.minutes,
  });

  final String id;
  final String name;
  final String zone;
  final int seats;

  /// "free" | "serving" | "paid"
  final String status;

  final String? orderId;
  final String? orderNumber;
  final String? orderStatus;
  final String? paymentStatus;
  final int? total;
  final int? itemCount;

  /// Minutes since the order was opened.
  final int? minutes;

  bool get isFree => status == 'free';
  bool get isServing => status == 'serving';
  bool get isPaid => status == 'paid';

  String get statusLabel => switch (status) {
    'serving' => 'Đang phục vụ',
    'paid' => 'Đã thanh toán',
    _ => 'Trống',
  };

  /// "25 phút" — how long the guests have been sitting there.
  String get elapsedLabel {
    final m = minutes ?? 0;
    if (m < 1) return 'vừa mở';
    if (m < 60) return '$m phút';
    final h = m ~/ 60;
    final rest = m % 60;
    return rest == 0 ? '$h giờ' : '$h giờ $rest phút';
  }

  /// "mở 49 phút" / "vừa mở" — reads naturally either way.
  String get openedLabel => (minutes ?? 0) < 1 ? 'vừa mở' : 'mở $elapsedLabel';

  factory StoreTable.fromJson(Map<String, dynamic> json) => StoreTable(
    id: json['id'] as String,
    name: json['name'] as String,
    zone: json['zone'] as String? ?? '',
    seats: (json['seats'] as num?)?.toInt() ?? 0,
    status: json['status'] as String? ?? 'free',
    orderId: json['orderId'] as String?,
    orderNumber: json['orderNumber'] as String?,
    orderStatus: json['orderStatus'] as String?,
    paymentStatus: json['paymentStatus'] as String?,
    total: (json['total'] as num?)?.toInt(),
    itemCount: (json['itemCount'] as num?)?.toInt(),
    minutes: (json['minutes'] as num?)?.toInt(),
  );
}

class FloorPlan {
  const FloorPlan({
    required this.tables,
    required this.zones,
    required this.total,
    required this.free,
    required this.serving,
    required this.paid,
    required this.openRevenue,
    required this.takeawayOpen,
  });

  final List<StoreTable> tables;
  final List<String> zones;
  final int total;
  final int free;
  final int serving;
  final int paid;

  /// Money sitting on tables that have not paid yet.
  final int openRevenue;

  /// Held takeaway orders, which belong to no table.
  final int takeawayOpen;

  int get busy => serving + paid;

  List<StoreTable> inZone(String zone) =>
      tables.where((t) => t.zone == zone).toList();

  factory FloorPlan.fromJson(Map<String, dynamic> json) => FloorPlan(
    tables: (json['tables'] as List<dynamic>? ?? [])
        .map((e) => StoreTable.fromJson(e as Map<String, dynamic>))
        .toList(),
    zones: (json['zones'] as List<dynamic>? ?? []).cast<String>(),
    total: (json['total'] as num?)?.toInt() ?? 0,
    free: (json['free'] as num?)?.toInt() ?? 0,
    serving: (json['serving'] as num?)?.toInt() ?? 0,
    paid: (json['paid'] as num?)?.toInt() ?? 0,
    openRevenue: (json['openRevenue'] as num?)?.toInt() ?? 0,
    takeawayOpen: (json['takeawayOpen'] as num?)?.toInt() ?? 0,
  );
}
