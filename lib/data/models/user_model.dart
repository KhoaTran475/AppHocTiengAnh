class UserModel {
  final int? id;
  final String username;
  final String role;
  final String createdAt;
  final bool isFaceAuthEnabled;
  final String? faceRegisteredAt;

  UserModel({
    this.id,
    required this.username,
    required this.role,
    required this.createdAt,
    this.isFaceAuthEnabled = false,
    this.faceRegisteredAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Xử lý isFaceAuthEnabled có thể trả về từ boolean (JSON) hoặc int 0/1 (SQLite)
    final rawFaceEnabled = map['is_face_auth_enabled'] ?? map['isFaceAuthEnabled'];
    final bool faceEnabled = rawFaceEnabled is bool
        ? rawFaceEnabled
        : (rawFaceEnabled is int ? rawFaceEnabled == 1 : false);

    final rawRegisteredAt = map['face_registered_at'] ?? map['faceRegisteredAt'];

    return UserModel(
      id: map['id'] as int?,
      username: map['username'] as String? ?? '',
      role: map['role'] as String? ?? 'learner',
      createdAt: map['createdAt'] as String? ?? map['created_at'] as String? ?? '',
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
      'is_face_auth_enabled': isFaceAuthEnabled ? 1 : 0,
      'face_registered_at': faceRegisteredAt,
    };
  }

  UserModel copyWith({
    int? id,
    String? username,
    String? role,
    String? createdAt,
    bool? isFaceAuthEnabled,
    String? faceRegisteredAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      isFaceAuthEnabled: isFaceAuthEnabled ?? this.isFaceAuthEnabled,
      faceRegisteredAt: faceRegisteredAt ?? this.faceRegisteredAt,
    );
  }
}
