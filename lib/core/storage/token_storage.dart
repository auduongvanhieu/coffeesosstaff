import 'package:shared_preferences/shared_preferences.dart';

/// Persists the JWT between launches. Works on web (localStorage) and mobile.
class TokenStorage {
  static const _key = 'coffeesos.staff.accessToken';

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> write(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
