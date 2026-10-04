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
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Content-Type': 'application/json'},
            ),
          ) {
    this.dio.interceptors.add(
      InterceptorsWrapper(
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
      ),
    );
  }

  final Dio dio;
  final TokenStorage _tokens;

  DioException _normalize(DioException err) {
    final status = err.response?.statusCode;
    final data = err.response?.data;
    if (data is Map<String, dynamic>) {
      // Backend (httpx.Fail) wraps errors as {"error": {"code", "message"}};
      // also accept a flat {"code", "message"} body.
      final body = data['error'] is Map<String, dynamic>
          ? data['error'] as Map<String, dynamic>
          : data;
      final code = body['code']?.toString() ?? 'error';
      final message = body['message']?.toString() ?? _fallbackMessage(status);
      return err.copyWith(error: ApiException(status, code, message));
    }
    if (status != null) {
      return err.copyWith(
        error: ApiException(status, 'http_$status', _fallbackMessage(status)),
      );
    }
    return err.copyWith(
      error: ApiException(
        null,
        'network',
        'Không kết nối được máy chủ, kiểm tra mạng và thử lại.',
      ),
    );
  }

  static String _fallbackMessage(int? status) => switch (status) {
    401 => 'Phiên đăng nhập không hợp lệ.',
    403 => 'Bạn không có quyền thực hiện thao tác này.',
    404 => 'Không tìm thấy dữ liệu.',
    _ when status != null && status >= 500 =>
      'Máy chủ gặp sự cố, vui lòng thử lại sau.',
    _ => 'Yêu cầu không hợp lệ.',
  };
}

/// Vietnamese copy for well-known backend error codes; falls back to the
/// server message for anything else.
const _codeMessages = <String, String>{
  'invalid_credentials': 'Email hoặc mật khẩu không đúng.',
  'invalid_pin': 'Mã PIN không đúng.',
  'invalid_order': 'Đơn hàng không hợp lệ.',
  'invalid_transition': 'Trạng thái đơn không cho phép thao tác này.',
  'already_paid': 'Đơn này đã được thanh toán.',
  'not_open': 'Đơn đã chốt, không sửa được.',
  'store_required': 'Tài khoản chưa gắn với cửa hàng nào.',
  'unauthorized': 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.',
  'forbidden': 'Bạn không có quyền thực hiện thao tác này.',
  'not_found': 'Không tìm thấy dữ liệu.',
  'conflict': 'Dữ liệu đã tồn tại.',
  'internal': 'Máy chủ gặp sự cố, vui lòng thử lại sau.',
};

/// Unwraps the [ApiException] attached by [ApiClient] or falls back to a
/// generic message. Use in controllers when surfacing errors to the UI.
String describeError(Object error) {
  final api = switch (error) {
    DioException(:final error) when error is ApiException => error,
    ApiException() => error,
    _ => null,
  };
  if (api == null) return 'Có lỗi xảy ra, vui lòng thử lại.';
  return _codeMessages[api.code] ?? api.message;
}
