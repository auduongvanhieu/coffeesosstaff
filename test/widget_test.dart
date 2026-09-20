import 'package:flutter_test/flutter_test.dart';
import 'package:coffeesos_staff/features/pos/domain/menu.dart';

void main() {
  test('StoreMenu parses backend payload', () {
    final menu = StoreMenu.fromJson({
      'storeId': 's1',
      'categories': [
        {'id': 'c1', 'name': 'Cà phê', 'sortOrder': 1},
      ],
      'items': [
        {
          'id': 'i1',
          'categoryId': 'c1',
          'name': 'Cà phê sữa',
          'description': null,
          'imageUrl': null,
          'basePrice': 30000,
          'price': 32000,
          'options': {},
          'isAvailable': true,
          'available': true,
          'sortOrder': 1,
        },
      ],
    });
    expect(menu.categories.single.name, 'Cà phê');
    expect(menu.items.single.price, 32000);
    expect(menu.items.single.available, isTrue);
  });
}
