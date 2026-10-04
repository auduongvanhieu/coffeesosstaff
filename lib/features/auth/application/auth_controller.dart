import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/device_context.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(tokenStorageProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  ),
);

/// Session state: `null` data = signed out. Loading on cold start while the
/// stored token is validated against /auth/me.
class AuthController extends AsyncNotifier<StaffUser?> {
  @override
  Future<StaffUser?> build() => ref.read(authRepositoryProvider).me();

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .login(email: email, password: password),
    );
    await _bindDevice();
  }

  Future<void> pinLogin(String pin) async {
    final device = ref.read(deviceContextProvider);
    if (device == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .pinLogin(storeId: device.storeId, pin: pin),
    );
    await _bindDevice();
  }

  /// Remember the store so the next launch shows the PIN pad.
  Future<void> _bindDevice() async {
    final user = state.value;
    if (user == null || user.storeId == null) return;
    await ref
        .read(deviceContextProvider.notifier)
        .save(
          DeviceContext(
            storeId: user.storeId!,
            storeName: user.storeName ?? '',
            brandName: user.brandName ?? '',
            brandLogoUrl: user.brandLogoUrl,
          ),
        );
  }

  /// Uploads a new profile photo and refreshes the session user.
  Future<void> uploadAvatar(Uint8List bytes, String filename) async {
    final user = await ref
        .read(authRepositoryProvider)
        .uploadAvatar(bytes, filename);
    state = AsyncData(user);
  }

  /// Clears a failed login so the error does not stick to the next screen.
  void resetError() {
    if (state.hasError) state = const AsyncData(null);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, StaffUser?>(AuthController.new);
