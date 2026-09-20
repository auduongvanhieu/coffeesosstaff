/// Mirrors `menu.StoreMenu` from GET /pos/menu.
class StoreMenu {
  const StoreMenu({required this.storeId, required this.categories, required this.items});

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
}

class MenuCategory {
  const MenuCategory({required this.id, required this.name, required this.sortOrder});

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
  /// VND, integer.
  final int price;
  final bool available;
  /// Raw JSONB options from the brand menu; shape TBD per item type.
  final dynamic options;

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        imageUrl: json['imageUrl'] as String?,
        price: (json['price'] as num?)?.toInt() ?? (json['basePrice'] as num?)?.toInt() ?? 0,
        available: json['available'] as bool? ?? json['isAvailable'] as bool? ?? true,
        options: json['options'],
      );
}
