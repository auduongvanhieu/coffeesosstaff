import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';

/// Error shape returned by the Go backend's httpx.Fail helper.
class ApiException implements Exception {
  ApiException(this.statusCode, this.code, this.message);

  final int? statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

class ApiClient {
  ApiClient(this._tokens, {Dio? dio})
      : dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Content-Type': 'application/json'},
            )) {
    this.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokens.read();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (err, handler) {
        handler.reject(_normalize(err));
      },
    ));
  }

  final Dio dio;
  final TokenStorage _tokens;

  DioException _normalize(DioException err) {
    final data = err.response?.data;
    if (data is Map<String, dynamic>) {
      final code = data['code']?.toString() ?? 'error';
      final message = data['message']?.toString() ?? err.message ?? 'Request failed';
      return err.copyWith(
        error: ApiException(err.response?.statusCode, code, message),
      );
    }
    return err.copyWith(
      error: ApiException(err.response?.statusCode, 'network', err.message ?? 'Network error'),
    );
  }
}

/// Unwraps the [ApiException] attached by [ApiClient] or falls back to a
/// generic message. Use in controllers when surfacing errors to the UI.
String describeError(Object error) {
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).message;
  }
  if (error is ApiException) return error.message;
  return 'Có lỗi xảy ra, vui lòng thử lại.';
}
