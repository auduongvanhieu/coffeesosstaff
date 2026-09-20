/// Mirrors `auth.UserView` from the Go backend.
class StaffUser {
  const StaffUser({
    required this.id,
    required this.brandId,
    required this.storeId,
    required this.role,
    required this.level,
    required this.email,
    required this.fullName,
  });

  final String id;
  final String? brandId;
  final String? storeId;
  final String role;
  final int level;
  final String? email;
  final String fullName;

  factory StaffUser.fromJson(Map<String, dynamic> json) => StaffUser(
        id: json['id'] as String,
        brandId: json['brandId'] as String?,
        storeId: json['storeId'] as String?,
        role: json['role'] as String,
        level: (json['level'] as num).toInt(),
        email: json['email'] as String?,
        fullName: json['fullName'] as String? ?? '',
      );
}

class LoginResult {
  const LoginResult({required this.accessToken, required this.expiresAt, required this.user});

  final String accessToken;
  final DateTime expiresAt;
  final StaffUser user;

  factory LoginResult.fromJson(Map<String, dynamic> json) => LoginResult(
        accessToken: json['accessToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        user: StaffUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}
