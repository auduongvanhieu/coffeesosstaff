/// Mirrors `menu.StoreMenu` from GET /pos/menu.
class StoreMenu {
  const StoreMenu({
    required this.storeId,
    required this.categories,
    required this.items,
  });

  final String storeId;
  final List<MenuCategory> categories;
  final List<MenuItem> items;

  factory StoreMenu.fromJson(Map<String, dynamic> json) => StoreMenu(
    storeId: json['storeId'] as String,
    categories: (json['categories'] as List<dynamic>? ?? [])
        .map((e) => MenuCategory.fromJson(e as Map<String, dynamic>))
        .toList(),
    items: (json['items'] as List<dynamic>? ?? [])
        .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  StoreMenu copyWithItem(MenuItem updated) => StoreMenu(
    storeId: storeId,
    categories: categories,
    items: [for (final i in items) i.id == updated.id ? updated : i],
  );
}

class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final int sortOrder;

  factory MenuCategory.fromJson(Map<String, dynamic> json) => MenuCategory(
    id: json['id'] as String,
    name: json['name'] as String,
    sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
  );
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.available,
    required this.options,
  });

  final String id;
  final String categoryId;
  final String name;
  final String? description;
  final String? imageUrl;

  /// VND, integer (store price override already applied by the backend).
  final int price;
  final bool available;
  final List<OptionGroup> options;

  bool get hasOptions => options.isNotEmpty;

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
    id: json['id'] as String,
    categoryId: json['categoryId'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    imageUrl: json['imageUrl'] as String?,
    price:
        (json['price'] as num?)?.toInt() ??
        (json['basePrice'] as num?)?.toInt() ??
        0,
    available:
        json['available'] as bool? ?? json['isAvailable'] as bool? ?? true,
    options: (json['options'] as List<dynamic>? ?? [])
        .map((e) => OptionGroup.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  MenuItem copyWith({bool? available}) => MenuItem(
    id: id,
    categoryId: categoryId,
    name: name,
    description: description,
    imageUrl: imageUrl,
    price: price,
    available: available ?? this.available,
    options: options,
  );
}

/// Size / ice / sugar / topping on a menu item.
class OptionGroup {
  const OptionGroup({
    required this.code,
    required this.name,
    required this.type,
    required this.required,
    required this.choices,
  });

  final String code;
  final String name;

  /// "single" | "multi"
  final String type;
  final bool required;
  final List<OptionChoice> choices;

  bool get isSingle => type != 'multi';

  factory OptionGroup.fromJson(Map<String, dynamic> json) => OptionGroup(
    code: json['code'] as String,
    name: json['name'] as String,
    type: json['type'] as String? ?? 'single',
    required: json['required'] as bool? ?? false,
    choices: (json['choices'] as List<dynamic>? ?? [])
        .map((e) => OptionChoice.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class OptionChoice {
  const OptionChoice({
    required this.code,
    required this.name,
    required this.priceDelta,
  });

  final String code;
  final String name;
  final int priceDelta;

  factory OptionChoice.fromJson(Map<String, dynamic> json) => OptionChoice(
    code: json['code'] as String,
    name: json['name'] as String,
    priceDelta: (json['priceDelta'] as num?)?.toInt() ?? 0,
  );
}
