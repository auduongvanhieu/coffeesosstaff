import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/user.dart';

class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  /// POST /auth/login — shared by staff, managers and owners.
  Future<StaffUser> login({required String email, required String password}) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final result = LoginResult.fromJson(res.data!);
    await _tokens.write(result.accessToken);
    return result.user;
  }

  /// GET /auth/me — restores the session from a stored token.
  Future<StaffUser?> me() async {
    final token = await _tokens.read();
    if (token == null || token.isEmpty) return null;
    try {
      final res = await _api.dio.get<Map<String, dynamic>>('/auth/me');
      return StaffUser.fromJson(res.data!);
    } catch (_) {
      await _tokens.clear();
      return null;
    }
  }

  Future<void> logout() => _tokens.clear();
}
