class UserModel {
  final int? id;
  final String username;
  final String role;
  final String createdAt;
  final String? email;
  final bool isEmailVerified;
  final bool isFaceAuthEnabled;
  final String? faceRegisteredAt;

  UserModel({
    this.id,
    required this.username,
    required this.role,
    required this.createdAt,
    this.email,
    this.isEmailVerified = false,
    this.isFaceAuthEnabled = false,
    this.faceRegisteredAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Xử lý isFaceAuthEnabled có thể trả về từ boolean (JSON) hoặc int 0/1 (SQLite)
    final rawFaceEnabled = map['is_face_auth_enabled'] ?? map['isFaceAuthEnabled'];
    final bool faceEnabled = rawFaceEnabled is bool
        ? rawFaceEnabled
        : (rawFaceEnabled is int ? rawFaceEnabled == 1 : false);

    final rawEmailVerified = map['is_email_verified'] ?? map['isEmailVerified'];
    final bool emailVerified = rawEmailVerified is bool
        ? rawEmailVerified
        : (rawEmailVerified is int ? rawEmailVerified == 1 : false);

    final rawRegisteredAt = map['face_registered_at'] ?? map['faceRegisteredAt'];

    return UserModel(
      id: map['id'] as int?,
      username: map['username'] as String? ?? '',
      role: map['role'] as String? ?? 'learner',
      createdAt: map['createdAt'] as String? ?? map['created_at'] as String? ?? '',
      email: map['email'] as String?,
      isEmailVerified: emailVerified,
      isFaceAuthEnabled: faceEnabled,
      faceRegisteredAt: rawRegisteredAt?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'createdAt': createdAt,
      'email': email,
      'is_email_verified': isEmailVerified ? 1 : 0,
      'is_face_auth_enabled': isFaceAuthEnabled ? 1 : 0,
      'face_registered_at': faceRegisteredAt,
    };
  }

  UserModel copyWith({
    int? id,
    String? username,
    String? role,
    String? createdAt,
    String? email,
    bool? isEmailVerified,
    bool? isFaceAuthEnabled,
    String? faceRegisteredAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      email: email ?? this.email,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isFaceAuthEnabled: isFaceAuthEnabled ?? this.isFaceAuthEnabled,
      faceRegisteredAt: faceRegisteredAt ?? this.faceRegisteredAt,
    );
  }
}
