import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Email + password remembered for the sign-in form, so staff do not retype
/// them on a shared terminal. flutter_secure_storage keeps them in the
/// platform keychain (Keychain on iOS/macOS, Keystore-backed storage on
/// Android, an encrypted entry on web), never in plain preferences.
class SavedLogin {
  const SavedLogin({required this.email, required this.password});

  final String email;
  final String password;
}

class CredentialStorage {
  CredentialStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _kEmail = 'coffeesos.staff.login.email';
  static const _kPassword = 'coffeesos.staff.login.password';

  final FlutterSecureStorage _storage;

  /// Returns the saved pair, or null when nothing was remembered. A failing
  /// keychain (private window, locked device) is treated as "nothing saved".
  Future<SavedLogin?> read() async {
    try {
      final email = await _storage.read(key: _kEmail);
      final password = await _storage.read(key: _kPassword);
      if (email == null || email.isEmpty || password == null) return null;
      return SavedLogin(email: email, password: password);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String email, String password) async {
    try {
      await _storage.write(key: _kEmail, value: email);
      await _storage.write(key: _kPassword, value: password);
    } catch (_) {
      // Remembering is a convenience; never block signing in over it.
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _kEmail);
      await _storage.delete(key: _kPassword);
    } catch (_) {}
  }
}

final credentialStorageProvider = Provider<CredentialStorage>(
  (ref) => CredentialStorage(),
);
