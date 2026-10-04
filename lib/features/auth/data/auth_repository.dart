import 'dart:typed_data';

import 'package:dio/dio.dart' show FormData, MultipartFile;

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/user.dart';

class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  /// POST /auth/login — shared by staff, managers and owners.
  Future<StaffUser> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final result = LoginResult.fromJson(res.data!);
    await _tokens.write(result.accessToken);
    return result.user;
  }

  /// POST /auth/pin-login — staff on a terminal already bound to a store.
  Future<StaffUser> pinLogin({
    required String storeId,
    required String pin,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/auth/pin-login',
      data: {'storeId': storeId, 'pin': pin},
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

  /// POST /pos/me/avatar — the staff member's own profile photo.
  Future<StaffUser> uploadAvatar(Uint8List bytes, String filename) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/pos/me/avatar',
      data: form,
    );
    return StaffUser.fromJson(res.data!);
  }

  Future<void> logout() => _tokens.clear();
}
