class User {
  final String id;
  final String email;
  final String role;
  final bool isVerified;
  final String? avatarUrl;

  const User({
    required this.id,
    required this.email,
    required this.role,
    required this.isVerified,
    this.avatarUrl,
  });

  bool get isStudent => role == 'student';
  bool get isFaculty => role == 'faculty';
  bool get isAdmin => role == 'admin' || role == 'super_admin';

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        isVerified: json['is_verified'] as bool? ?? false,
        avatarUrl: json['avatar_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role,
        'is_verified': isVerified,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };

  User copyWith({
    String? id,
    String? email,
    String? role,
    bool? isVerified,
    String? avatarUrl,
  }) =>
      User(
        id: id ?? this.id,
        email: email ?? this.email,
        role: role ?? this.role,
        isVerified: isVerified ?? this.isVerified,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );

  @override
  bool operator ==(Object other) =>
      other is User && other.id == id && other.email == email;

  @override
  int get hashCode => id.hashCode ^ email.hashCode;

  @override
  String toString() => 'User(id=$id, email=$email, role=$role)';
}
