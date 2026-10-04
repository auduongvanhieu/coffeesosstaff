import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loaded in `main()` before `runApp`; overridden in the root ProviderScope so
/// device-level state (store binding) is available synchronously to the router.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError('override sharedPreferencesProvider in main()'),
);

/// The store this terminal is bound to after the first email login. Enables
/// the PIN screen on later launches, exactly like the Figma "01 Đăng nhập".
class DeviceContext {
  const DeviceContext({
    required this.storeId,
    required this.storeName,
    required this.brandName,
    this.brandLogoUrl,
  });

  final String storeId;
  final String storeName;
  final String brandName;
  final String? brandLogoUrl;

  /// "Daily Bean · Quận 3" when the store name already carries the brand.
  String get displayName {
    if (brandName.isEmpty || storeName.startsWith(brandName)) return storeName;
    return '$brandName · $storeName';
  }
}

class DeviceContextController extends Notifier<DeviceContext?> {
  static const _kStoreId = 'coffeesos.staff.device.storeId';
  static const _kStoreName = 'coffeesos.staff.device.storeName';
  static const _kBrandName = 'coffeesos.staff.device.brandName';
  static const _kBrandLogo = 'coffeesos.staff.device.brandLogoUrl';

  @override
  DeviceContext? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final storeId = prefs.getString(_kStoreId);
    if (storeId == null || storeId.isEmpty) return null;
    return DeviceContext(
      storeId: storeId,
      storeName: prefs.getString(_kStoreName) ?? '',
      brandName: prefs.getString(_kBrandName) ?? '',
      brandLogoUrl: prefs.getString(_kBrandLogo),
    );
  }

  Future<void> save(DeviceContext ctx) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kStoreId, ctx.storeId);
    await prefs.setString(_kStoreName, ctx.storeName);
    await prefs.setString(_kBrandName, ctx.brandName);
    if (ctx.brandLogoUrl != null) {
      await prefs.setString(_kBrandLogo, ctx.brandLogoUrl!);
    } else {
      await prefs.remove(_kBrandLogo);
    }
    state = ctx;
  }

  Future<void> clear() async {
    final prefs = ref.read(sharedPreferencesProvider);
    for (final k in [_kStoreId, _kStoreName, _kBrandName, _kBrandLogo]) {
      await prefs.remove(k);
    }
    state = null;
  }
}

final deviceContextProvider =
    NotifierProvider<DeviceContextController, DeviceContext?>(
      DeviceContextController.new,
    );
