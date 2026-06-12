class User {
  final int id;
  final String email;
  final String? fullName;
  final String role;
  final bool isActive;
  final bool isBlocked;
  final String? createdAt;
  final String? lastLogin;

  const User({
    required this.id,
    required this.email,
    this.fullName,
    required this.role,
    required this.isActive,
    required this.isBlocked,
    this.createdAt,
    this.lastLogin,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        email: json['email'] as String,
        fullName: json['full_name'] as String?,
        role: json['role'] as String,
        isActive: json['is_active'] as bool? ?? true,
        isBlocked: json['is_blocked'] as bool? ?? false,
        createdAt: json['created_at'] as String?,
        lastLogin: json['last_login'] as String?,
      );

  String get displayName => fullName?.isNotEmpty == true ? fullName! : email;

  bool get isAdmin => role == 'it_admin';
}
