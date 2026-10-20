class UserModel {
  final int? id;
  final String username;
  final String role;
  final String createdAt;

  UserModel({
    this.id,
    required this.username,
    required this.role,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      username: map['username'] as String,
      role: map['role'] as String,
      createdAt: map['createdAt'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'createdAt': createdAt,
    };
  }
}
